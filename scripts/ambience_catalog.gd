extends RefCounted

const PATH := "res://config/world_ambience.json"
const WISP_CAP := 6

static func load_data() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(document), "Invalid world ambience catalogue: " + PATH)
	return document

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("surface") is Array or document.surface.is_empty() or not document.get("locations") is Dictionary:
		return false
	for profile in document.surface + document.locations.values():
		if not _profile(profile, true):
			return false
	for key in ["water", "town"]:
		if not _profile(document.get(key), false):
			return false
	var weather = document.get("weather")
	if not weather is Dictionary or not weather.get("biomes") is Array or not weather.biomes.all(func(value): return (value is int or value is float) and value == int(value) and value >= 0 and value <= 3) or not weather.get("region_modulus") is float and not weather.get("region_modulus") is int:
		return false
	if weather.region_modulus < 2 or weather.region_modulus > 100 or weather.region_modulus != int(weather.region_modulus) or not weather.get("particles") is float and not weather.get("particles") is int:
		return false
	if weather.particles < 1 or weather.particles > 96 or weather.particles != int(weather.particles) or not weather.get("rain_pool") is String:
		return false
	for section in ["bed_pools", "effect_pools", "cue_pools"]:
		if not document.get(section) is Dictionary:
			return false
		for value in document[section].values():
			if section == "cue_pools":
				if not value is Array or value.is_empty() or not value.all(func(role): return role is String):
					return false
			elif not value is String:
				return false
	if not document.get("npc_palettes") is Array or document.npc_palettes.is_empty() or not document.npc_palettes.all(func(value): return value is String and Color.html_is_valid(value)):
		return false
	for key in ["npc_roles", "npc_recipes", "npc_models"]:
		if not document.get(key) is Dictionary or document[key].is_empty():
			return false
	for role in document.npc_roles:
		var id = document.npc_roles[role]
		if not id is String or not document.npc_recipes.has(id) or not document.npc_models.get(role) is Array or document.npc_models[role].is_empty():
			return false
		for query in document.npc_models[role]:
			if not query is Dictionary or not query.get("pack") is String:
				return false
			for field in ["tags", "patterns"]:
				if not query.get(field) is Array or query[field].is_empty() or not query[field].all(func(value): return value is String and not value.is_empty()):
					return false
	for recipe in document.npc_recipes.values():
		if not recipe is Dictionary or not recipe.get("orbit") is bool or not recipe.get("pieces") is Array or recipe.pieces.is_empty() or recipe.pieces.size() > 24:
			return false
		for piece in recipe.pieces:
			if not piece is Dictionary or not _vector(piece.get("size"), true) or not _vector(piece.get("point"), false) or piece.get("color") not in ["accent", "shade", "paper", "slate"] or not piece.get("charm") is bool or not piece.get("glow") is bool:
				return false
	return true

static func _profile(profile, color: bool) -> bool:
	if not profile is Dictionary or not profile.get("bed") is String or profile.bed.is_empty() or not profile.get("cue") is String or profile.cue.is_empty():
		return false
	var count = profile.get("wisps")
	return (count is int or count is float) and is_finite(count) and count == int(count) and count >= 0 and count <= WISP_CAP and (not color or (profile.get("color") is String and Color.html_is_valid(profile.color)))

static func _vector(value, positive: bool) -> bool:
	return value is Array and value.size() == 3 and value.all(func(number): return (number is int or number is float) and is_finite(number) and absf(number) <= 2 and (not positive or number > 0))
