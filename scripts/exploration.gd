extends CanvasLayer

const Catalog = preload("res://scripts/discovery_catalog.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const View = preload("res://scripts/discovery_view.gd")
const History = preload("res://scripts/regional_history.gd")
const QuestUI = preload("res://scripts/local_quest_ui.gd")
const QuestState = preload("res://scripts/local_quests.gd")
const Knowledge = preload("res://scripts/site_knowledge.gd")
var game
var catalog := Catalog.new()
var history := History.new()
var view := View.new()
var quests := QuestUI.new()
var knowledge := Knowledge.new()
var observation_timer := 0.0
var legacy_knowledge := false
var entries: Dictionary = {}
var nearby: Dictionary = {}
var plans: Dictionary = {}
var overlay := Control.new()
var return_state := "playing"
var world_id := 0
var chunk := Vector2i(999999, 999999)
var book_region := ""

func _ready() -> void:
	layer = 5
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.hide()
	add_child(view)
	quests.game = game
	add_child(quests)

func _process(delta: float) -> void:
	if game != null and not game.offline_actions_allowed():
		return
	if game == null:
		return
	sync()
	if game.state == "playing" and game.layer == "overworld":
		observation_timer -= delta
		if observation_timer <= 0:
			observation_timer = .25
			observe_sites()

func known_sites() -> Array[Dictionary]:
	return knowledge.visible_sites(game.world.nearby_sites(game.player_point))

func observe_sites() -> void:
	if game != null and not game.offline_actions_allowed():
		return
	if game == null or not game.has_journey or game.layer != "overworld":
		return
	for site in game.world.nearby_sites(game.player_point):
		if game.visited_cities.has(site.id) or game.dungeon_progress.has(site.id):
			knowledge.remember(site, "visited", str(game.run_seed))
		if not game.world.chunks.has(game.world.chunk_at(Vector2(site.cell))):
			continue
		var offset: Vector2 = game.player_point - Vector2(site.cell)
		if site.type == "city" and maxf(absf(offset.x), absf(offset.y)) <= 13:
			knowledge.remember(site, "visited", str(game.run_seed))
		elif site.type in ["ruin", "castle", "church", "temple"] and site.footprint.has_point(Vector2i(game.player_point.round())) and game.world.walkable(game.player_point):
			knowledge.remember(site, "visited", str(game.run_seed))
		elif offset.length() <= 10 and game.world.line_clear(game.player_point, Vector2(site.get("approach", site.cell + Vector2i(0, 2)))):
			knowledge.remember(site, "seen", str(game.run_seed))

func note_site(id: String, cell: Array) -> void:
	if game == null:
		return
	var site: Dictionary = game.world.site_by_id(id, Vector2i(cell[0], cell[1]))
	if not site.is_empty():
		knowledge.remember(site, "rumor", str(game.run_seed))

func reconcile_knowledge() -> void:
	if legacy_knowledge:
		for record in entries.values() + history.records.values() + quests.state.records.values():
			note_site(record.site_id, record.site_cell)
		if not game.waypoint.is_empty():
			knowledge.remember(game.waypoint, "rumor", str(game.run_seed))
		legacy_knowledge = false
	if not game.active_dungeon.is_empty():
		knowledge.remember(game.active_dungeon, "visited", str(game.run_seed))
	observe_sites()

func sync() -> void:
	if game.layer != "overworld" or not game.has_journey:
		view.visible = false
		return
	if world_id != game.world.get_instance_id() or chunk != game.world.current_chunk:
		world_id = game.world.get_instance_id()
		chunk = game.world.current_chunk
		var regions := {}
		for coordinate in game.world.chunks:
			var region: Dictionary = game.world.region_at(coordinate * game.world.CHUNK_SIZE)
			regions[Sites.region_key(game.world, region)] = region
		for key in plans.keys():
			if not regions.has(key):
				plans.erase(key)
		nearby.clear()
		for key in regions:
			if not plans.has(key):
				var saved := _remembered_region(key)
				plans[key] = saved if not saved.is_empty() else Sites.plan(game.world, regions[key], catalog)
			var entry: Dictionary = plans[key]
			if not entry.is_empty() and game.world.chunks.has(game.world.chunk_at(Vector2(entry.point[0], entry.point[1]))):
				nearby[entry.id] = entry
	view.sync(game, nearby)

func _remembered_region(key: String) -> Dictionary:
	for entry in entries.values():
		if entry.region_id == key:
			return entry
	return {}

func reset() -> void:
	entries.clear()
	history.records.clear()
	quests.reset()
	knowledge.reset()
	observation_timer = 0.0
	legacy_knowledge = false
	book_region = ""
	plans.clear()
	nearby.clear()
	world_id = 0
	chunk = Vector2i(999999, 999999)
	view.clear()
	_clear_overlay()

func snapshot() -> Dictionary:
	return {"version": 1, "entries": entries.duplicate(true), "regions": history.snapshot(), "quests": quests.state.snapshot(), "knowledge": knowledge.snapshot()}

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _point(value) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1]) and value[0] == floorf(value[0]) and value[1] == floorf(value[1]) and absf(value[0]) < 10000000 and absf(value[1]) < 10000000

static func valid_snapshot(data, seed_value: String = "") -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not data.get("entries") is Dictionary:
		return false
	if not History.valid_snapshot(data.get("regions", {}), seed_value):
		return false
	if not QuestState.valid_snapshot(data.get("quests", {}), seed_value):
		return false
	if not Knowledge.valid_snapshot(data.get("knowledge", {}), seed_value):
		return false
	for id in data.entries:
		var entry = data.entries[id]
		if not id is String or not entry is Dictionary or entry.get("id") != id:
			return false
		for key in ["region_id", "run_seed", "template_id", "family", "title", "author", "text", "marker_label", "model_id", "city_id", "city_name", "site_id", "site_name"]:
			if not entry.get(key) is String or entry[key].is_empty() or entry[key].length() > (8000 if key == "text" else 512):
				return false
		if not entry.run_seed.is_valid_int() or (not seed_value.is_empty() and entry.run_seed != seed_value) or entry.text.contains("{") or entry.author.contains("{"):
			return false
		for key in ["point", "approach", "site_cell"]:
			if not _point(entry.get(key)):
				return false
		for key in ["generator_version", "template_version", "biome", "ground_height", "marker_width", "marker_height"]:
			if not _number(entry.get(key)):
				return false
		for key in ["generator_version", "template_version", "biome"]:
			if entry[key] != floorf(entry[key]):
				return false
		if entry.generator_version < 1 or entry.template_version < 1 or entry.biome < 0 or entry.biome > 3 or entry.marker_width <= 0 or entry.marker_width > 1.5 or entry.marker_height <= 0 or entry.marker_height > 1.5:
			return false
		if id != "discovery:%s:%s@%s" % [entry.region_id, entry.template_id, int(entry.template_version)]:
			return false
		if int(entry.generator_version) >= 5:
			var coordinate: Vector2i = Sites.Targets.Planner.coordinate(Vector2i(entry.point[0], entry.point[1]))
			if entry.region_id != "region:%s:%s:%s:%s" % [int(entry.generator_version), entry.run_seed, coordinate.x, coordinate.y] or not Sites.Targets.valid_city(entry.run_seed.to_int(), entry.city_id) or not Sites.Targets.valid_dungeon(entry.run_seed.to_int(), entry.site_id, entry.site_cell, coordinate):
				return false
	return true

static func _normalized(entry: Dictionary) -> Dictionary:
	var result := entry.duplicate(true)
	for key in ["generator_version", "template_version", "biome"]:
		result[key] = int(result[key])
	for key in ["point", "approach", "site_cell"]:
		result[key] = [int(result[key][0]), int(result[key][1])]
	for key in ["ground_height", "marker_width", "marker_height"]:
		result[key] = float(result[key])
	return result

func restore(data: Dictionary, seed_value: String = "") -> bool:
	if not valid_snapshot(data, seed_value):
		return false
	reset()
	for id in data.get("entries", {}):
		entries[id] = _normalized(data.entries[id])
	history.restore(data.get("regions", {}), seed_value)
	quests.state.restore(data.get("quests", {}), seed_value)
	knowledge.restore(data.get("knowledge", {}), seed_value)
	legacy_knowledge = not data.has("knowledge")
	return true

func remember(entry: Dictionary) -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	if entries.has(entry.id) or not valid_snapshot({"version": 1, "entries": {entry.id: entry}}, entry.run_seed):
		return false
	entries[entry.id] = _normalized(entry)
	note_site(entry.site_id, entry.site_cell)
	return true

func target() -> Dictionary:
	if game.layer != "overworld" or game.state != "playing":
		return {}
	sync()
	var result := {}
	var distance := 1.85
	for entry in nearby.values():
		var point := Vector2(entry.point[0], entry.point[1])
		var delta: float = game.player_point.distance_to(point)
		if delta < distance and game.dungeon.line_clear(game.player_point, point):
			result = entry
			distance = delta
	return result

func hint() -> String:
	var entry := target()
	return "" if entry.is_empty() else "E: Read " + entry.title

func interact() -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	var entry := target()
	if entry.is_empty():
		return false
	if not game.sanctum_problem().is_empty():
		game.notify("Find safe ground before reading the landmark.")
		return true
	var region: Dictionary = game.world.region_at(Vector2i(entry.point[0], entry.point[1]))
	var record := _learn_history(region, "landmark")
	if not entries.has(entry.id) and not record.is_empty():
		entry = entry.duplicate(true)
		entry.text += "\n\n%s\n%s\n\n%s" % [record.title, record.text, record.landmark_text]
	remember(entry)
	game._auto_save()
	_open(entries.get(entry.id, entry), "playing")
	return true

func read_saved(id: String) -> void:
	if entries.has(id) and game.state == "journal":
		game.expansion.overlay.hide()
		_open(entries[id], "journal")

func _clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.hide()

func _open(entry: Dictionary, previous: String) -> void:
	_clear_overlay()
	return_state = previous
	game.state = "discovery_reader"
	game.rotating_camera = false
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.04, .58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = game.interface._panel(center, Vector2(650,0), Color("766950"))
	var box = game.interface._vbox(panel, 12)
	game.interface._label(box, entry.title, 27, Color("e5e0d5"), true)
	game.interface._label(box, entry.author, 14, Color("c3a576"))
	var text: String = entry.text
	if history.records.has(entry.region_id):
		text += _aftermath(history.records[entry.region_id])
	game.expansion._text(box, text, 260)
	game.interface._label(box, "%s / Linked place: %s" % [entry.city_name, entry.site_name], 13, Color("c3a576"))
	game.interface._label(box, "Recorded in your field journal.", 13)
	game.interface._button(box, "Mark the linked ruin", mark_site.bind(entry.id), Vector2(0,36))
	game.interface._button(box, "Back to journal" if previous == "journal" else "Close", close, Vector2(0,36))
	overlay.show()

func mark_site(id: String) -> void:
	if not entries.has(id):
		return
	var entry: Dictionary = entries[id]
	_mark_target(entry)

func close() -> void:
	_clear_overlay()
	game.state = return_state
	if return_state == "journal":
		game.expansion._show_journal()
	elif return_state == "dialogue":
		game.expansion._show_dialogue()

func _input(event: InputEvent) -> void:
	if game != null and game.state == "discovery_reader" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_J]:
		close()
		get_viewport().set_input_as_handled()

func journal_rows(parent: VBoxContainer) -> void:
	quests.journal_rows(parent)
	game.interface._label(parent, "Regional histories / %s" % history.records.size(), 17, Color("c3a576"))
	if history.records.is_empty():
		game.interface._label(parent, "Read a local book or ask a resident about local history.", 14)
	var regions: Array = history.records.keys()
	regions.sort()
	for key in regions:
		var record: Dictionary = history.records[key]
		var progress := "%s/%s sources" % [record.sources.size(), record.required_sources.size()]
		if history.complete(key):
			progress = "Account complete"
		game.interface._button(parent, "%s / %s / %s" % [record.city_name, record.title, progress], read_history.bind(key), Vector2(0,40))
	game.interface._label(parent, "Roadside discoveries / %s" % entries.size(), 17, Color("c3a576"))
	if entries.is_empty():
		game.interface._label(parent, "Read a marker beside a road to keep its story here.", 14)
	var ids: Array = entries.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary = entries[id]
		game.interface._button(parent, "%s / %s" % [entry.title, entry.city_name], read_saved.bind(id), Vector2(0,40))

func regional_record(region: Dictionary) -> Dictionary:
	if region.get("city", {}).is_empty():
		return {}
	var key := Sites.region_key(game.world, region)
	var marker := _remembered_region(key)
	if marker.is_empty():
		marker = plans[key] if plans.has(key) else Sites.plan(game.world, region, catalog)
	return history.plan(game.world, region, marker)

func _learn_history(region: Dictionary, source: String) -> Dictionary:
	var record := regional_record(region)
	if record.is_empty():
		return {}
	history.learn(record, source)
	note_site(record.site_id, record.site_cell)
	if not history.records.has(record.region_id):
		return {}
	history.observe(record.region_id, game.life.event_at(region.city.id))
	return history.records[record.region_id]

func record_book(id: String) -> void:
	book_region = ""
	if game.layer != "overworld":
		return
	var region: Dictionary = game.world.region_at(Vector2i(game.player_point.round()))
	for book in region.get("city", {}).get("books", []):
		if book.book_id == id and game.player_point.distance_to(book.point) < 2 and game.dungeon.line_clear(game.player_point, book.approach):
			var record := _learn_history(region, "book")
			book_region = record.get("region_id", "")
			return

func book_appendix() -> String:
	if not history.records.has(book_region):
		return ""
	var record: Dictionary = history.records[book_region]
	return "\n\nLocal archive / %s\n%s\n\n%s%s" % [record.title, record.text, record.book_text, _aftermath(record)]

func has_local_history(resident: Dictionary) -> bool:
	if game.layer != "overworld" or resident.is_empty():
		return false
	var region: Dictionary = game.world.region_at(Vector2i(resident.point))
	if region.get("city", {}).is_empty():
		return false
	if resident.get("city_id", "") != region.city.id or not resident.get("id", "").begins_with(region.city.id + ":npc:"):
		return false
	var record := regional_record(region)
	return not record.is_empty() and "witness" in record.required_sources

func read_witness(resident: Dictionary) -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	if game.state != "dialogue" or game.expansion.speaker.get("id", "") != resident.get("id", "") or not has_local_history(resident):
		return false
	var region: Dictionary = game.world.region_at(Vector2i(resident.point))
	var record := _learn_history(region, "witness")
	if record.is_empty():
		return false
	game.expansion.overlay.hide()
	game._auto_save()
	_show_history(record, "witness", "dialogue")
	return true

func read_history(key: String) -> void:
	if game.state != "journal" or not history.records.has(key):
		return
	game.expansion.overlay.hide()
	_show_history(history.records[key], "", "journal")

static func _aftermath(record: Dictionary) -> String:
	var text := ""
	var kinds: Array = record.notes.keys()
	kinds.sort()
	for kind in kinds:
		text += "\n\nLater local note\n" + record.notes[kind].text
	return text

func _show_history(record: Dictionary, source: String, previous: String) -> void:
	_clear_overlay()
	return_state = previous
	game.state = "discovery_reader"
	game.rotating_camera = false
	var shade := ColorRect.new()
	shade.color = Color(.025, .035, .04, .82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = game.interface._panel(center, Vector2(650,0), Color("766950"))
	var box = game.interface._vbox(panel, 12)
	game.interface._label(box, record.title, 27, Color("e5e0d5"), true)
	game.interface._label(box, record.author, 14, Color("c3a576"))
	var text: String = record.text
	var sources: Array = record.required_sources if source.is_empty() else [source]
	for collected in sources:
		if record.sources.has(collected):
			text += "\n\n%s\n%s" % [collected.capitalize(), record[collected + "_text"]]
	text += _aftermath(record)
	game.expansion._text(box, text, 260)
	var labels: Array[String] = []
	for required in record.required_sources:
		labels.append("%s: %s" % [required.capitalize(), "recorded" if record.sources.has(required) else "unread"])
	game.interface._label(box, " / ".join(labels), 13, Color("c3a576"))
	game.interface._button(box, "Mark " + record.site_name, mark_history.bind(record.region_id), Vector2(0,36))
	game.interface._button(box, "Back to " + ("conversation" if previous == "dialogue" else "journal"), close, Vector2(0,36))
	overlay.show()

func mark_history(key: String) -> void:
	if not history.records.has(key):
		return
	var record: Dictionary = history.records[key]
	_mark_target(record)

func _mark_target(record: Dictionary) -> void:
	var site: Dictionary = game.world.site_by_id(record.site_id, Vector2i(record.site_cell[0], record.site_cell[1]))
	if site.is_empty():
		return
	knowledge.remember(site, "rumor", str(game.run_seed))
	game.waypoint = site
	game.notify("Route marked: " + site.name)
	game._auto_save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not quests.is_inside_tree():
		quests.free()
	if what == NOTIFICATION_PREDELETE and not view.is_inside_tree():
		view.free()
		if not overlay.is_inside_tree():
			overlay.free()
