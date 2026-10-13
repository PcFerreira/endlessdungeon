extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Areas = preload("res://scripts/area_catalog.gd")
var registry := Registry.new()
var data: Dictionary = {}
var error := ""

func _init(path: String = "res://config/town_architecture.json") -> void:
	if not FileAccess.file_exists(path):
		error = "Missing town architecture catalogue"
		return
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(document):
		error = "Invalid town architecture catalogue"
		return
	data = document
	for template in data.templates.values():
		for part in template.parts:
			if part.has("asset") and registry.get_asset(part.asset).get("kind", "") != "model":
				error = "Unknown town construction model: " + part.asset
				return

static func _vector(value) -> bool:
	return value is Array and value.size() == 3 and value.all(func(number): return (number is float or number is int) and is_finite(number))

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("templates") is Dictionary or document.templates.is_empty() or not document.get("themes") is Dictionary or not document.themes.has("generic"):
		return false
	for id in document.templates:
		var template = document.templates[id]
		if not id is String or id.is_empty() or not template is Dictionary or not template.get("name") is String or template.get("kind") not in ["house", "civic"] or not template.get("series") is String or not template.get("uses") is Array or not template.uses.all(func(use): return use is String and Areas.DATA.building_uses.has(use)) or (template.kind == "house" and template.uses.is_empty()):
			return false
		if not template.get("themes") is Array or not template.themes.all(func(theme): return theme is String) or not template.get("parts") is Array or template.parts.is_empty() or template.parts.size() > 24:
			return false
		if not Areas._number(template.get("front_yaw", 0)):
			return false
		for part in template.parts:
			if not part is Dictionary or not _vector(part.get("point")) or not _vector(part.get("size")) or part.size.any(func(value): return value <= 0 or value > 8) or part.point[1] < 0 or not Areas._number(part.get("yaw", 0)):
				return false
			if not (part.get("asset") is String or part.get("primitive") in ["stone", "wood"]):
				return false
	for theme in document.themes.values():
		if not theme is Dictionary or theme.get("palette") not in ["blue", "green", "red", "yellow"]:
			return false
		for kind in ["houses", "civics"]:
			if not theme.get(kind) is Array or theme[kind].is_empty() or not theme[kind].all(func(id): return id is String and document.templates.has(id) and document.templates[id].kind == ("house" if kind == "houses" else "civic")):
				return false
	for theme in document.themes.values():
		for use in Areas.DATA.building_uses:
			if not theme.houses.any(func(id): return use in document.templates[id].uses):
				return false
	return true

func theme_for(city: Dictionary) -> String:
	var theme: String = city.get("theme_id", "")
	if data.themes.has(theme):
		return theme
	var aliases := {"city_woodland":"woodland", "city_winter_hearth":"winter", "city_caravan":"caravan", "city_market":"merchant", "city_mushroom_common":"fungal"}
	theme = aliases.get(city.get("archetype_id", ""), "generic")
	return theme if data.themes.has(theme) else "generic"

func choose(house: Dictionary, city: Dictionary) -> Dictionary:
	if not error.is_empty():
		return {}
	var theme := theme_for(city)
	var kind := "civics" if house.get("kind", "house") == "civic" else "houses"
	var use: String = house.get("use_id", "")
	var candidates: Array = data.themes[theme][kind].filter(func(id): return kind == "civics" or use in data.templates[id].uses)
	if candidates.is_empty():
		candidates = data.themes.generic[kind].filter(func(id): return kind == "civics" or use in data.templates[id].uses)
	if candidates.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("architecture:%s:%s:%s" % [city.get("id", ""),house.get("id", ""),theme])
	var id: String = candidates[rng.randi_range(0,candidates.size() - 1)]
	var result: Dictionary = data.templates[id].duplicate(true)
	result.id = id
	result.theme = theme
	var palette: String = data.themes[theme].palette
	for part in result.parts:
		if part.has("asset") and part.asset.begins_with("kaykit_medieval_hexagon/"):
			part.asset = part.asset.replace("/blue/", "/" + palette + "/").replace("_blue.gltf", "_" + palette + ".gltf")
	return result
