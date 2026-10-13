extends RefCounted

const MOTIONS = ["still","core","head","arm","leg","crawler_leg","wing","tail","turret"]
const COLORS = ["body","dark","shade","trim","tooth","metal","accent","eye"]
var data: Dictionary = {}
var error := ""

func _init(path: String = "res://config/voxel_monsters.json") -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(document):
		error = "Invalid voxel monster catalogue: " + path
		return
	data = document

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("templates") is Dictionary or document.templates.is_empty() or document.templates.size() > 64 or not document.templates.has(document.get("default_template")):
		return false
	if not document.get("builds") is Dictionary or document.builds.is_empty() or document.builds.size() > 16:
		return false
	for key in document.builds:
		if not _id(key) or not _number(document.builds[key]) or document.builds[key] < .75 or document.builds[key] > 1.25:
			return false
	if not document.get("tones") is Array or document.tones.is_empty() or document.tones.size() > 8 or not document.tones.all(func(value): return _number(value) and absf(value) <= .2):
		return false
	if not document.get("palettes") is Dictionary or document.palettes.is_empty() or document.palettes.size() > 32:
		return false
	for key in document.palettes:
		var palette = document.palettes[key]
		if not _id(key) or not palette is Dictionary or not COLORS.slice(0,6).all(func(color): return palette.get(color) is String and Color.html_is_valid(palette[color])):
			return false
	if not document.get("biomes") is Dictionary:
		return false
	for biome in range(4):
		var choices = document.biomes.get(str(biome))
		if not choices is Array or choices.is_empty() or choices.size() > 8 or not choices.all(func(colors): return colors is Array and colors.size() == 2 and colors.all(func(color): return color is String and Color.html_is_valid(color))):
			return false
	for id in document.templates:
		var template = document.templates[id]
		if not _id(id) or not template is Dictionary or template.get("locomotion") not in ["biped","quadruped","crawler","float","fly","slime","stationary"] or not _choices(template.get("palettes"),document.palettes):
			return false
		if not template.get("parts") is Dictionary or template.parts.is_empty() or template.parts.size() > 16:
			return false
		for name in template.parts:
			var part = template.parts[name]
			if not _id(name) or not part is Dictionary or not _vector(part.get("pivot")) or part.get("motion") not in MOTIONS or not _number(part.get("phase")) or absf(part.phase) != 1 or not part.get("pieces") is Array or part.pieces.is_empty() or part.pieces.size() > 48 or not part.pieces.all(_piece):
				return false
		if not template.get("ornaments") is Dictionary or template.ornaments.is_empty() or template.ornaments.size() > 16:
			return false
		for name in template.ornaments:
			var pieces = template.ornaments[name]
			if not _id(name) or not pieces is Array or pieces.size() > 24 or not pieces.all(func(piece): return _piece(piece) and template.parts.has(piece.get("part"))):
				return false
	if not document.get("selectors") is Array or document.selectors.is_empty() or document.selectors.size() > 256:
		return false
	for selector in document.selectors:
		if not selector is Dictionary or not document.templates.has(selector.get("template")):
			return false
		for key in ["ids","names"]:
			if not selector.get(key,[]) is Array or not selector.get(key,[]).all(func(value): return value is String and not value.is_empty()):
				return false
		if selector.get("ids",[]).is_empty() and selector.get("names",[]).is_empty():
			return false
		if selector.has("palettes") and (not _choices(selector.palettes,document.palettes) or not selector.palettes.all(func(id): return id in document.templates[selector.template].palettes)):
			return false
	return true

func profile(definition: Dictionary) -> Dictionary:
	for selector in data.selectors:
		if definition.id in selector.get("ids",[]) or selector.get("names",[]).any(func(pattern): return str(definition.get("name","")).matchn(pattern)):
			return selector
	return {"template":data.default_template}

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(value)

static func _id(value) -> bool:
	return value is String and value.is_valid_identifier()

static func _choices(values, source: Dictionary) -> bool:
	return values is Array and not values.is_empty() and values.all(func(value): return value is String and source.has(value))

static func _vector(value) -> bool:
	return value is Array and value.size() == 3 and value.all(func(n): return _number(n) and absf(n) <= 64 and is_equal_approx(n * 4,roundf(n * 4)))

static func _piece(piece) -> bool:
	return piece is Dictionary and _vector(piece.get("point")) and _vector(piece.get("size")) and piece.size.all(func(n): return n > 0) and piece.get("color") in COLORS
