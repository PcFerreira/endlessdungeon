extends RefCounted

const PATH := "res://config/world_content.json"
const Registry = preload("res://scripts/asset_registry.gd")
const Placement = preload("res://scripts/contextual_placement.gd")
const Dressing = preload("res://scripts/interior_dressing.gd")
var data: Dictionary = {}
var error := ""
var registry := Registry.new()

func _init(path: String = PATH) -> void:
	reload(path)

func reload(path: String = PATH) -> bool:
	var document = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not valid(document):
		error = "Invalid world content catalogue: " + path
		return false
	data = document
	error = ""
	return true

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1:
		return false
	var defaults = document.get("interior_defaults")
	if not defaults is Dictionary or not defaults.get("props") is Array or not defaults.get("readable") is Dictionary or not pair(defaults.readable.get("point")) or not pair(defaults.readable.get("approach")):
		return false
	if not defaults.props.all(prop_valid):
		return false
	for section in ["enemies", "interiors"]:
		if not document.get(section) is Array or document[section].is_empty():
			return false
		var ids := {}
		for entry in document[section]:
			if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id) or not entry.get("name") is String:
				return false
			ids[entry.id] = true
			if entry.has("names") and (not entry.names is Array or entry.names.is_empty() or not entry.names.all(func(value): return value is String and not value.is_empty())):
				return false
			if section == "enemies":
				if not entry.get("ranged") is bool or not query_valid(entry.get("visual")) or not entry.get("habitat") is Dictionary:
					return false
				for key in ["hp", "speed", "reach", "windup", "period", "damage", "height", "weight"]:
					if not numeric(entry.get(key)) or entry[key] <= 0:
						return false
				for key in ["biomes", "facets", "families"]:
					if not entry.habitat.get(key, []) is Array:
						return false
				for biome in entry.habitat.get("biomes", []):
					if not numeric(biome) or biome != int(biome) or biome < 0 or biome > 3:
						return false
				for key in ["facets", "families"]:
					if not entry.habitat.get(key, []).all(func(value): return value is String):
						return false
				if entry.weight != int(entry.weight) or entry.weight > 100:
					return false
			else:
				if entry.has("dressing_type") and (not entry.dressing_type is String or not Dressing.data.types.has(entry.dressing_type)):
					return false
				if not pair(entry.get("size")) or entry.size[0] < 10 or entry.size[1] < 10 or entry.size[0] > 40 or entry.size[1] > 40 or not entry.get("floor") is String or not entry.get("book") is String or not entry.get("layouts") is Array or entry.layouts.is_empty():
					return false
				if entry.size[0] != int(entry.size[0]) or entry.size[1] != int(entry.size[1]) or not entry.floor.is_valid_hex_number(false):
					return false
				if entry.get("rest") != null and not pair(entry.rest):
					return false
				var layouts := {}
				for layout in entry.layouts:
					if not layout is Dictionary or not layout.get("id") is String or layouts.has(layout.id) or not layout.get("props") is Array:
						return false
					layouts[layout.id] = true
					for prop in layout.props:
						if not prop_valid(prop):
							return false
					if not Placement.room_valid(entry, defaults, layout):
						return false
	return true

static func query_valid(query) -> bool:
	if not query is Dictionary or not query.get("tags", []) is Array or not query.get("patterns", ["*"]) is Array or not query.get("pack", "") is String:
		return false
	return query.get("tags", []).all(func(value): return value is String) and query.get("patterns", ["*"]).all(func(value): return value is String)

static func prop_valid(prop) -> bool:
	if not prop is Dictionary or not prop.get("fallback") is String or not pair(prop.get("point")) or not pair(prop.get("footprint")) or not numeric(prop.get("height")) or prop.height <= 0:
		return false
	if prop.has("wall") and (not prop.wall is String or not Placement.WALLS.has(prop.wall)):
		return false
	if prop.has("facing") and (not pair(prop.facing) or Vector2(prop.facing[0], prop.facing[1]).length_squared() != 1):
		return false
	if prop.has("face") and (not pair(prop.face) or prop.face == prop.point):
		return false
	if prop.has("elevation") and (not numeric(prop.elevation) or prop.elevation < 0):
		return false
	if prop.get("elevation", 0) > 0 and not prop.has("wall"):
		return false
	return prop.footprint[0] > 0 and prop.footprint[1] > 0 and (not prop.has("query") or query_valid(prop.query))

static func numeric(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func pair(value) -> bool:
	return value is Array and value.size() == 2 and numeric(value[0]) and numeric(value[1])

func entries(section: String) -> Array:
	return data.get(section, [])

func get_entry(section: String, id: String) -> Dictionary:
	for entry in entries(section):
		if entry.id == id:
			return entry
	return {}

func models(query: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in registry.find("model", query.get("tags", []), query.get("pack", "")):
		var patterns: Array = query.get("patterns", ["*"])
		if patterns.any(func(pattern): return asset.id.matchn(pattern)):
			result.append(asset)
	return result

func choose_model(query: Dictionary, seed_value: int, saved_id: String = "") -> String:
	var candidates := models(query)
	if not saved_id.is_empty() and candidates.any(func(asset): return asset.id == saved_id):
		return saved_id
	return "" if candidates.is_empty() else candidates[posmod(seed_value, candidates.size())].id
