extends RefCounted

const VERSION := 1
const Build = preload("res://scripts/character_build.gd")
const World = preload("res://scripts/world.gd")
var directory := "user://saves"
var last_error := ""

func slot_path(slot: int) -> String:
	return directory.path_join("slot-%s.json" % slot)

static func number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func vector(value) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1]) and absf(value[0]) < 10000000 and absf(value[1]) < 10000000

static func strings(value) -> bool:
	if not value is Array:
		return false
	for item in value:
		if not item is String:
			return false
	return true

func validate(data, allow_sanctum: bool = true) -> bool:
	if not data is Dictionary or data.get("generator_version") != World.GENERATOR_VERSION or not number(data.get("saved_at")):
		return false
	if not data.get("seed") is String or not data.seed.is_valid_int() or not data.get("rng_state") is String or not data.rng_state.is_valid_int():
		return false
	for key in ["build", "location", "stats", "progress", "view"]:
		if not data.get(key) is Dictionary:
			return false
	var build := Build.new()
	if not build.restore(data.build):
		return false
	var place: Dictionary = data.location
	if not place.get("layer") in ["overworld", "dungeon", "sanctum"] or not place.get("name") is String:
		return false
	var home = data.get("home", {"item": "sanctum_sigil", "return_journey": {}})
	if not home is Dictionary or home.get("item") != "sanctum_sigil" or not home.get("return_journey") is Dictionary:
		return false
	if place.layer == "sanctum":
		if not allow_sanctum or home.return_journey.is_empty() or not validate(home.return_journey, false):
			return false
		if home.return_journey.seed != data.seed:
			return false
	elif not home.return_journey.is_empty():
		return false
	for key in ["point", "surface_return", "sanctuary", "site_cell", "aim", "heading"]:
		if not vector(place.get(key)):
			return false
	if not place.get("site_id") is String or not place.get("selected") is String or not place.get("grounded") is bool:
		return false
	for key in ["player_y", "velocity", "depth"]:
		if not number(place.get(key)):
			return false
	if place.depth < 1 or place.depth > 20 or place.depth != floorf(place.depth):
		return false
	var stats: Dictionary = data.stats
	for key in ["hp", "mana", "kills", "elapsed", "guard", "invulnerable", "best_depth"]:
		if not number(stats.get(key)) or stats[key] < 0:
			return false
	if not stats.get("cooldowns") is Dictionary:
		return false
	for spell in Build.ABILITIES:
		if not number(stats.cooldowns.get(spell)) or stats.cooldowns[spell] < 0:
			return false
	for key in ["yaw", "target_yaw", "surface_zoom", "dungeon_zoom"]:
		if not number(data.view.get(key)):
			return false
	var progress: Dictionary = data.progress
	for key in ["encounters", "floors", "discovery"]:
		if not progress.get(key) is Dictionary:
			return false
	for key in ["claimed", "cities"]:
		if not strings(progress.get(key)):
			return false
	if not progress.get("waypoint") is String or not vector(progress.get("waypoint_cell")):
		return false
	for id in progress.floors:
		var depth = progress.floors[id]
		if not id is String or not number(depth) or depth < 1 or depth > 20 or depth != floorf(depth):
			return false
	for id in progress.encounters:
		var record = progress.encounters[id]
		if not id is String or not record is Dictionary or not number(record.get("hp")) or record.hp < 0 or not vector(record.get("point")):
			return false
		for key in ["slow", "attack", "windup"]:
			if not number(record.get(key, 0)) or record.get(key, 0) < 0:
				return false
		if not record.get("active", false) is bool:
			return false
	for id in progress.discovery:
		if not id is String or not progress.discovery[id] is Array:
			return false
		for cell in progress.discovery[id]:
			if not vector(cell):
				return false
	if not data.get("pickups") is Array or not data.get("projectiles") is Array:
		return false
	for pickup in data.pickups:
		if not pickup is Dictionary or not pickup.get("kind") in ["health", "mana"] or not vector(pickup.get("point")):
			return false
	for shot in data.projectiles:
		if not shot is Dictionary or not shot.get("spell") in ["bolt", "fire", "hostile"] or not shot.get("hostile") is bool or not shot.get("target") is String:
			return false
		if not vector(shot.get("point")) or not vector(shot.get("direction")):
			return false
		for key in ["height", "life", "trail"]:
			if not number(shot.get(key)):
				return false
	return true

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "Empty slot."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "This save could not be opened."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"error": "This save is damaged."}
	var envelope: Dictionary = parser.data
	if envelope.get("version") != VERSION:
		return {"error": "This save belongs to a different game version."}
	if not envelope.get("payload") is String or not envelope.get("checksum") is String or envelope.payload.sha256_text() != envelope.checksum:
		return {"error": "This save is incomplete or damaged."}
	if parser.parse(envelope.payload) != OK or not validate(parser.data):
		return {"error": "This save is incompatible or damaged."}
	return {"data": parser.data}

func read(slot: int) -> Dictionary:
	var path := slot_path(slot)
	var primary := _read_file(path)
	if primary.has("data"):
		return {"data": primary.data, "error": "", "recovered": false, "empty": false}
	var backup := _read_file(path + ".bak")
	if backup.has("data"):
		return {"data": backup.data, "error": "", "recovered": true, "empty": false}
	return {"data": {}, "error": primary.error, "recovered": false, "empty": not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak")}

func write(slot: int, data: Dictionary) -> bool:
	last_error = ""
	if slot < 0 or slot > 3 or not validate(data):
		last_error = "The journey could not be saved."
		return false
	var base := ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(base) != OK:
		last_error = "The save folder could not be created."
		return false
	var path := ProjectSettings.globalize_path(slot_path(slot))
	var payload := JSON.stringify(data, "", true, true)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "The save could not be written."
		return false
	file.store_string(JSON.stringify({"version": VERSION, "checksum": payload.sha256_text(), "payload": payload}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not _read_file(path + ".tmp").has("data"):
		last_error = "The save could not be completed."
		return false
	if _read_file(path).has("data"):
		if DirAccess.copy_absolute(path, path + ".bak.tmp") != OK or DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak") != OK:
			last_error = "The previous save could not be backed up."
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		last_error = "The save could not be completed."
		return false
	return true

func latest_slot() -> int:
	var newest := -1
	var timestamp := -1.0
	for slot in range(4):
		var result := read(slot)
		if not result.data.is_empty() and result.data.saved_at > timestamp:
			timestamp = result.data.saved_at
			newest = slot
	return newest

func summary(slot: int) -> Dictionary:
	var result := read(slot)
	var label := "Autosave" if slot == 0 else "Slot %s" % slot
	if result.data.is_empty():
		return {"label": label, "text": "Empty" if result.empty else result.error, "valid": false}
	var data: Dictionary = result.data
	var date := Time.get_datetime_string_from_unix_time(int(data.saved_at)).replace("T", " ")
	return {"label": label, "text": "%s / %s\n%s UTC%s" % [Build.CLASSES[data.build.class_id].name, data.location.name, date, " / backup" if result.recovered else ""], "valid": true}
