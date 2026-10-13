extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const World = preload("res://scripts/world.gd")
const Targets = preload("res://scripts/regional_targets.gd")
const SOURCES := ["landmark", "book", "witness"]
const CAPABILITIES := ["regional_history", "collection", "event_aftermath"]
const PASSAGES := ["title", "author", "text", "landmark_text", "book_text", "witness_text"]
var definitions: Array[Dictionary] = []
var errors: Array[String] = []
var records: Dictionary = {}

func _init(entries: Array = []) -> void:
	var source: Array = Registry.new().find("text", ["regional-history"]) if entries.is_empty() else entries
	for entry in source:
		if not _valid_definition(entry):
			errors.append("Invalid regional history: " + str(entry.get("id", "unknown") if entry is Dictionary else "unknown"))
			continue
		if definitions.any(func(existing): return existing.id == entry.id):
			errors.append("Duplicate regional history: " + entry.id)
			continue
		definitions.append(entry.duplicate(true))
	definitions.sort_custom(func(a, b): return a.id < b.id)

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value, minimum: int, maximum: int) -> bool:
	return _number(value) and value == floorf(value) and value >= minimum and value <= maximum

static func _text(value, resolved: bool = false) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 8000 and (not resolved or (not value.contains("{") and not value.contains("}")))

static func _sources(value) -> bool:
	if not value is Array or value.is_empty() or value.size() > SOURCES.size():
		return false
	var seen := {}
	for source in value:
		if source not in SOURCES or seen.has(source):
			return false
		seen[source] = true
	return true

static func _notes(value, resolved: bool = false) -> bool:
	if not value is Array or value.size() > 16:
		return false
	var seen := {}
	for note in value:
		if not note is Dictionary or not _text(note.get("kind")) or note.kind.length() > 128 or note.get("phase") != "aftermath" or not _text(note.get("text"), resolved) or seen.has(note.kind):
			return false
		seen[note.kind] = true
	return true

static func _valid_definition(entry) -> bool:
	if not entry is Dictionary or not _text(entry.get("id")) or entry.id.length() > 128 or not _text(entry.get("motif")) or not _integer(entry.get("version"), 1, 1000000):
		return false
	for key in PASSAGES:
		if not _text(entry.get(key)):
			return false
		if entry[key].length() > (128 if key in ["title", "author"] else 1500):
			return false
		var resolved: String = entry[key].replace("{city_name}", "Town").replace("{dungeon_name}", "Ruin")
		if not _text(resolved, true):
			return false
	if not entry.get("biomes") is Array or not entry.get("requires") is Array or not _sources(entry.get("collection")) or not _notes(entry.get("event_notes")):
		return false
	for biome in entry.biomes:
		if not _integer(biome, 0, 3):
			return false
	for capability in entry.requires:
		if capability not in CAPABILITIES:
			return false
	for note in entry.event_notes:
		if not _text(note.text.replace("{city_name}", "Town").replace("{dungeon_name}", "Ruin"), true):
			return false
	return true

func plan(world, region: Dictionary, landmark: Dictionary) -> Dictionary:
	if region.get("city", {}).is_empty():
		return {}
	var key := Sites.region_key(world, region)
	if records.has(key):
		return records[key]
	var pool: Array[Dictionary] = []
	for definition in definitions:
		if definition.biomes.is_empty() or definition.biomes.any(func(value): return int(value) == int(region.city.biome)):
			pool.append(definition)
	var sites := Targets.dungeons(world, region)
	if pool.is_empty() or sites.is_empty():
		return {}
	var salt: int = hash("regional-history:1:%s" % key) & 0x7fffffff
	var definition: Dictionary = pool[salt % pool.size()]
	var site: Dictionary = sites[0] if world.generator_version >= 5 else sites[Sites._salt(world.run_seed, key + ":site") % sites.size()]
	for candidate in sites:
		if candidate.id == landmark.get("site_id", ""):
			site = candidate
	var result := {"region_id": key, "run_seed": str(world.run_seed), "generator_version": world.generator_version, "coordinate": [region.coordinate.x, region.coordinate.y], "city_id": region.city.id, "city_name": region.city.name, "site_id": site.id, "site_name": site.name, "site_cell": [site.cell.x, site.cell.y], "template_id": definition.id, "template_version": int(definition.version), "motif": definition.motif, "required_sources": definition.collection.duplicate(), "sources": {}, "event_notes": definition.event_notes.duplicate(true), "notes": {}}
	if landmark.is_empty():
		result.required_sources.erase("landmark")
	if region.city.books.is_empty():
		result.required_sources.erase("book")
	if region.city.residents.is_empty():
		result.required_sources.erase("witness")
	if result.required_sources.is_empty():
		return {}
	for key_name in PASSAGES:
		result[key_name] = _bind(definition[key_name], result)
	for note in result.event_notes:
		note.text = _bind(note.text, result)
	return result

static func _bind(text: String, record: Dictionary) -> String:
	return text.replace("{city_name}", record.city_name).replace("{dungeon_name}", record.site_name)

func learn(record: Dictionary, source: String) -> bool:
	if record.is_empty() or source not in record.required_sources:
		return false
	if not records.has(record.region_id):
		if not valid_snapshot({"version": 1, "records": {record.region_id: record}}, record.run_seed):
			return false
		records[record.region_id] = record.duplicate(true)
	var saved: Dictionary = records[record.region_id]
	if saved.sources.has(source):
		return false
	saved.sources[source] = true
	return true

func complete(key: String) -> bool:
	return records.has(key) and records[key].required_sources.all(func(source): return records[key].sources.has(source))

func observe(key: String, event: Dictionary) -> bool:
	if not records.has(key) or event.get("phase") != "aftermath" or event.get("home_city_id") != records[key].city_id:
		return false
	var record: Dictionary = records[key]
	for recipe in record.event_notes:
		if recipe.kind != event.get("kind") or not _text(event.get("instance_id")) or not _integer(event.get("finish_tick"), 0, 1000000000000):
			continue
		if record.notes.get(recipe.kind, {}).get("instance_id", "") == event.instance_id:
			return false
		record.notes[recipe.kind] = {"instance_id": event.instance_id, "finish_tick": int(event.finish_tick), "text": recipe.text}
		return true
	return false

func snapshot() -> Dictionary:
	return {"version": 1, "records": records.duplicate(true)}

static func valid_snapshot(data, seed_value: String = "") -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not data.get("records") is Dictionary:
		return false
	for key in data.records:
		var record = data.records[key]
		if not key is String or not record is Dictionary or record.get("region_id") != key or not _integer(record.get("generator_version"), 1, 1000000) or not _integer(record.get("template_version"), 1, 1000000):
			return false
		for field in ["coordinate", "site_cell"]:
			var point = record.get(field)
			if not point is Array or point.size() != 2 or not _integer(point[0], -9999999, 9999999) or not _integer(point[1], -9999999, 9999999):
				return false
		for field in PASSAGES + ["run_seed", "city_id", "city_name", "site_id", "site_name", "template_id", "motif"]:
			if not _text(record.get(field), true) or (field not in PASSAGES and record[field].length() > 512):
				return false
			if field in ["title", "author"] and record[field].length() > 512:
				return false
		if not record.run_seed.is_valid_int() or (not seed_value.is_empty() and record.run_seed != seed_value):
			return false
		if key != "region:%s:%s:%s:%s" % [int(record.generator_version), record.run_seed, int(record.coordinate[0]), int(record.coordinate[1])] or record.city_id != "city:%s:%s" % [int(record.coordinate[0]), int(record.coordinate[1])]:
			return false
		if int(record.generator_version) >= 5:
			if not Targets.valid_city(record.run_seed.to_int(), record.city_id) or not Targets.valid_dungeon(record.run_seed.to_int(), record.site_id, record.site_cell, Vector2i(record.coordinate[0], record.coordinate[1])):
				return false
		elif not record.site_id.begins_with("ruin:%s:%s:" % [int(record.coordinate[0]), int(record.coordinate[1])]):
			return false
		if not _sources(record.get("required_sources")) or not record.get("sources") is Dictionary or not _notes(record.get("event_notes"), true) or not record.get("notes") is Dictionary:
			return false
		for source in record.sources:
			if source not in record.required_sources or not record.sources[source] is bool or record.sources[source] != true:
				return false
		for kind in record.notes:
			var note = record.notes[kind]
			if not record.event_notes.any(func(recipe): return recipe.kind == kind) or not note is Dictionary or not _text(note.get("instance_id")) or not _integer(note.get("finish_tick"), 0, 1000000000000) or not _text(note.get("text"), true):
				return false
			if not record.event_notes.any(func(recipe): return recipe.kind == kind and recipe.text == note.text) or note.instance_id.length() > 512:
				return false
			var prefix: String = record.city_id + ":" + kind + ":"
			if not note.instance_id.begins_with(prefix) or not note.instance_id.trim_prefix(prefix).is_valid_int() or note.instance_id.trim_prefix(prefix).to_int() < 0:
				return false
	return true

func restore(data: Dictionary, seed_value: String = "") -> bool:
	if not valid_snapshot(data, seed_value):
		return false
	records.clear()
	for key in data.get("records", {}):
		var record: Dictionary = data.records[key].duplicate(true)
		for field in ["generator_version", "template_version"]:
			record[field] = int(record[field])
		for field in ["coordinate", "site_cell"]:
			record[field] = [int(record[field][0]), int(record[field][1])]
		for note in record.notes.values():
			note.finish_tick = int(note.finish_tick)
		records[key] = record
	return true
