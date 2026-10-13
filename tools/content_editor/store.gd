extends RefCounted

const Edits = preload("res://scripts/content_edits.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Registry = preload("res://scripts/asset_registry.gd")
var path: String
var document: Dictionary
var fingerprint := ""
var error := ""
var dirty := false
var base_items: Dictionary = {}
var base_enemies: Array = []
var registry := Registry.new()
var icon_images := {}

func _init(file_path: String = Edits.PATH) -> void:
	path = file_path
	if not reload():
		document = Edits.empty_document()

func reload() -> bool:
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var value = Edits.empty_document() if text.is_empty() else JSON.parse_string(text)
	if not Edits.valid(value):
		error = "Invalid edits file; existing changes are retained."
		return false
	document = value
	fingerprint = text.sha256_text()
	dirty = false
	error = ""
	return true

func load_catalogues() -> void:
	base_items = Items.source_definitions()
	base_enemies = Enemies.source_types()

func entries(section: String) -> Array:
	if section == "enemies":
		return Edits.enemies(base_enemies, document)
	var result := []
	var items := Edits.items(base_items, document)
	for id in items:
		var entry: Dictionary = items[id].duplicate(true)
		entry.id = id
		result.append(entry)
	return result

func patch(section: String, id: String, values: Dictionary) -> void:
	document[section][id] = values.duplicate(true)
	dirty = true

func reset_entry(section: String, id: String) -> void:
	document[section].erase(id)
	dirty = true

func set_item_removed(id: String, removed: bool) -> bool:
	if not entries("items").any(func(entry): return entry.id == id):
		error = "Unknown item: " + id
		return false
	var values: Dictionary = document.items.get(id, {}).duplicate(true)
	values.removed = removed
	patch("items", id, values)
	error = ""
	return true

func adopt(asset: Dictionary, section: String, kind: String = "material") -> String:
	var id: String = "editor:" + asset.id
	for entry in entries(section):
		if entry.id == id:
			return id
	var entry := {"id": id, "name": asset.title, "enabled": true, "source_asset": asset.id, "source_pack": "editor"}
	if section == "enemies":
		if asset.kind != "model":
			error = "Monsters need a staged 3D model."
			return ""
		entry.merge({"hp": 60.0, "damage": 12.0, "speed": 1.3, "reach": .9, "windup": .5, "period": 1.5, "height": 1.3, "weight": 1, "ranged": false, "visual_mode": "imported", "level": 1, "level_mode": "depth", "habitat": {"biomes": [0, 1, 2, 3], "facets": [], "families": ["*"]}, "visual": {"tags": [], "pack": asset.pack, "patterns": [asset.id]}})
	else:
		if asset.kind not in ["model", "texture"]:
			error = "Items need a staged model or texture."
			return ""
		entry.merge({"kind": kind, "stack": 10, "description": "", "icon": asset.path if asset.kind == "texture" else "res://assets/items/oak_chair.svg", "loot_sources": ["chest"] if kind == "furnishing" else ["enemy", "chest"]})
		if asset.kind == "model":
			entry.asset_id = asset.id
		if kind == "equipment":
			entry.merge({"slot": "weapon", "classes": ["mage", "sword", "spellsword"], "power": .05})
	document["add_" + section].append(entry)
	dirty = true
	error = ""
	return id

func validate_references() -> bool:
	icon_images.clear()
	if base_items.is_empty():
		load_catalogues()
	var items := Edits.items(base_items, document)
	for definition in Edits.enemies(base_enemies, document):
		for entry in definition.get("drops", {}).get("entries", []):
			if not items.has(entry.item) or items[entry.item].kind == "bound":
				error = "Unknown or bound drop item: " + entry.item
				return false
		if (definition.id.begins_with("editor:") or document.enemies.get(definition.id, {}).has("source_asset")) and definition.has("source_asset") and registry.get_asset(definition.source_asset).get("kind") != "model":
			error = "Monster model is not staged: " + definition.source_asset
			return false
	for id in items:
		if not id.begins_with("editor:") and not document.items.has(id):
			continue
		var item: Dictionary = items[id]
		if item.kind == "equipment" and (item.get("slot") not in ["weapon", "armor", "charm"] or not Edits.strings(item.get("classes")) or item.classes.is_empty() or not item.classes.all(func(value): return value in ["mage", "sword", "spellsword"])):
			error = "Equipment needs a valid slot and class list: " + id
			return false
		if item.has("asset_id") and registry.get_asset(item.asset_id).get("kind") != "model":
			error = "Item model is not staged: " + str(item.asset_id)
			return false
		if not FileAccess.file_exists(item.icon):
			error = "Item icon is missing: " + str(item.icon)
			return false
		if item.icon.get_extension().to_lower() not in ["png", "svg", "jpg", "jpeg", "webp"]:
			error = "Item icon must be an image: " + str(item.icon)
			return false
		var image: Image
		if icon_images.has(item.icon):
			image = icon_images[item.icon]
		else:
			image = Image.new()
			var decoded: int = image.load_svg_from_string(FileAccess.get_file_as_string(item.icon)) if item.icon.get_extension().to_lower() == "svg" else image.load(item.icon)
			if decoded != OK or image.is_empty():
				error = "Cannot decode item icon: " + str(item.icon)
				return false
			icon_images[item.icon] = image
		if item.has("icon_region"):
			var crop: Array = item.icon_region
			if crop[0] + crop[2] > image.get_width() or crop[1] + crop[3] > image.get_height():
				error = "Icon crop exceeds the image: " + id
				return false
			if not image.get_region(Rect2i(int(crop[0]), int(crop[1]), int(crop[2]), int(crop[3]))).get_used_rect().has_area():
				error = "Icon crop has no visible pixels: " + id
				return false
		elif not image.get_used_rect().has_area():
			error = "Item icon has no visible pixels: " + id
			return false
	return true

func save() -> bool:
	if not Edits.valid(document):
		error = "Invalid fields. Check names, positive combat values, levels and drop probabilities before saving."
		return false
	if not validate_references():
		return false
	var lock := path + ".lock"
	var claimed := DirAccess.make_dir_absolute(ProjectSettings.globalize_path(lock))
	if claimed != OK:
		error = "Another workbench is saving. Retry after it finishes. Lock: " + lock
		return false
	var saved := _publish()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lock))
	return saved

func _publish() -> bool:
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if text.sha256_text() != fingerprint:
		error = "The edits file changed in another editor. Reload before saving."
		return false
	var serialized := JSON.stringify(document, "\t") + "\n"
	var temporary := path + ".tmp-%s" % Time.get_ticks_usec()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		error = "Cannot write: " + path
		return false
	file.store_string(serialized)
	file.close()
	if not Edits.valid(JSON.parse_string(FileAccess.get_file_as_string(temporary))):
		error = "Cannot validate the saved document."
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	if not _unchanged():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	if not text.is_empty():
		var backup := FileAccess.open(path + ".backup", FileAccess.WRITE)
		if backup == null:
			error = "Cannot create the previous-version backup."
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			return false
		backup.store_string(text)
		backup.close()
	if not _unchanged():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		error = "Cannot publish the edits file."
		return false
	fingerprint = serialized.sha256_text()
	dirty = false
	error = ""
	return true

func _unchanged() -> bool:
	var current := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if current.sha256_text() != fingerprint:
		error = "The edits file changed during save. Reload before saving."
		return false
	return true
