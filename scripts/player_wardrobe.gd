extends RefCounted

const NPC = preload("res://scripts/voxel_character_generator.gd")
const COLORS := ["skin", "hair", "cloth", "trim", "pants", "leather", "metal", "paper", "eye", "outer", "hat", "boots", "gloves", "bag", "belt"]
const SOURCES := {"head": "hair", "beard": "beards", "headwear": "hats", "costume": "outfits", "belt": "accessories", "accessory": "accessories"}
const COLOR_FIELDS := {"skin": "skins", "hair": "hair_colors", "outfit": "cloth_colors", "trim": "cloth_colors", "trousers": "cloth_colors", "boots_color": "cloth_colors", "outer_color": "cloth_colors", "headwear_color": "cloth_colors", "eye_color": "eye_colors"}
static var data: Dictionary = _read()

static func _read() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_wardrobe.json"))
	assert(valid(document), "Invalid player wardrobe")
	return document

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1:
		return false
	for key in ["skins", "hair_colors", "cloth_colors", "eye_colors"]:
		if not document.get(key) is Array or document[key].is_empty() or document[key].size() > 32:
			return false
		for color in document[key]:
			if not color is Dictionary or not color.get("label") is String or not color.get("color") is String or not Color.html_is_valid(color.color):
				return false
	if not document.get("body_types") is Dictionary or document.body_types.is_empty() or document.body_types.size() > 16:
		return false
	for build in document.body_types.values():
		if not build is Dictionary or not build.get("label") is String:
			return false
		for key in ["width", "head"]:
			if not number(build.get(key)) or build[key] < 6 or build[key] > 10 or build[key] != int(build[key]):
				return false
	if not document.get("collections") is Dictionary:
		return false
	for key in ["head", "beard", "headwear", "costume", "outerwear", "gloves", "boots", "belt", "accessory"]:
		if not document.collections.get(key) is Dictionary or document.collections[key].is_empty() or document.collections[key].size() > 64:
			return false
		for recipe in document.collections[key].values():
			if not recipe is Dictionary or not recipe.get("label") is String or not recipe.get("parts") is Array or recipe.parts.size() > 32:
				return false
			if recipe.has("base") and not NPC.catalog.data.get(SOURCES.get(key, ""), {}).has(recipe.base):
				return false
			for part in recipe.parts:
				if not part is Dictionary or part.get("bone") not in NPC.Catalog.BONES or part.get("color") not in COLORS:
					return false
				for dimension in ["point", "size"]:
					if not part.get(dimension) is Array or part[dimension].size() != 3 or not part[dimension].all(func(value): return number(value) and absf(value) <= 48 and is_equal_approx(value * 4, roundf(value * 4))):
						return false
				if not part.size.all(func(value): return value > 0):
					return false
	if not document.get("presets") is Dictionary or document.presets.is_empty() or document.presets.size() > 32:
		return false
	for id in document.presets:
		var preset = document.presets[id]
		if not id is String or not id.begins_with("voxel:") or not preset is Dictionary or not preset.get("label") is String or not preset.get("fields") is Dictionary:
			return false
		for key in preset.fields:
			var value = preset.fields[key]
			if COLOR_FIELDS.has(key):
				if not number(value) or value != int(value) or value < 0 or value >= document[COLOR_FIELDS[key]].size():
					return false
			elif key == "ancestry":
				if value not in ["human", "elf", "dwarf", "orc", "halfling"]:
					return false
			elif key == "body_type":
				if not document.body_types.has(value):
					return false
			elif not document.collections.has(key) or not document.collections[key].has(value):
				return false
	return true

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func pieces(kind: String, id: String) -> Array:
	var recipe: Dictionary = data.collections.get(kind, {}).get(id, {})
	var result: Array = NPC.catalog.data.get(SOURCES.get(kind, ""), {}).get(recipe.get("base", ""), []).duplicate(true)
	result.append_array(recipe.get("parts", []).duplicate(true))
	return result

static func colors(key: String) -> Array[Color]:
	var result: Array[Color] = []
	for entry in data[key]:
		result.append(Color(entry.color))
	return result
