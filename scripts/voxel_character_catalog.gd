extends RefCounted

const BONES = ["Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
const COLORS = ["skin", "hair", "cloth", "trim", "pants", "leather", "metal", "paper", "eye"]
var data: Dictionary = {}
var error := ""

func _init(path: String = "res://config/voxel_characters.json") -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(document):
		error = "Invalid voxel character recipes: " + path
		return
	data = document

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not _number(document.get("height")) or document.height < .8 or document.height > 1.5:
		return false
	for key in ["skins", "hair_colors"]:
		if not document.get(key) is Array or document[key].is_empty() or document[key].size() > 32 or not document[key].all(func(color): return color is String and Color.html_is_valid(color)):
			return false
	if not document.get("builds") is Dictionary or document.builds.is_empty() or document.builds.size() > 16:
		return false
	for build in document.builds.values():
		if not build is Dictionary or not ["width","head"].all(func(key): return _number(build.get(key)) and build[key] >= 6 and build[key] <= 10 and build[key] == roundf(build[key])):
			return false
	if not document.get("palettes") is Dictionary or document.palettes.is_empty() or document.palettes.size() > 32:
		return false
	for palette in document.palettes.values():
		if not palette is Dictionary or not ["cloth","trim","pants","leather","metal"].all(func(key): return palette.get(key) is String and Color.html_is_valid(palette[key])):
			return false
	if not document.get("biomes") is Dictionary:
		return false
	for biome in range(4):
		if not _choices(document.biomes.get(str(biome)), document.palettes):
			return false
	for kind in ["hair", "beards", "outfits", "hats", "accessories"]:
		if not document.get(kind) is Dictionary or document[kind].is_empty() or document[kind].size() > 64:
			return false
		for pieces in document[kind].values():
			if not pieces is Array or pieces.size() > 32 or not pieces.all(_piece):
				return false
	if not document.get("roles") is Dictionary or document.roles.size() > 64 or not document.roles.has("retired_delver") or not document.roles.has("villager"):
		return false
	for role in document.roles.values():
		if not role is Dictionary or not ["outfits", "hats", "accessories"].all(func(kind): return _choices(role.get(kind), document[kind])):
			return false
	return true

static func _choices(values, source: Dictionary) -> bool:
	return values is Array and not values.is_empty() and values.size() <= 64 and values.all(func(value): return value is String and source.has(value))

static func _number(value) -> bool:
	return (value is float or value is int) and is_finite(value)

static func _piece(piece) -> bool:
	if not piece is Dictionary or piece.get("bone") not in BONES or piece.get("color") not in COLORS:
		return false
	for key in ["point", "size"]:
		if not piece.get(key) is Array or piece[key].size() != 3 or not piece[key].all(func(value): return _number(value) and absf(value) <= 48 and is_equal_approx(value * 4, roundf(value * 4))):
			return false
	return piece.size.all(func(value): return value > 0)
