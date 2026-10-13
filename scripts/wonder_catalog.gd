extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
const Models = preload("res://scripts/wonder_models.gd")
static var DATA: Dictionary = _read()

static func _read() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://config/wonder_folk.json"))
	assert(valid(value), "Invalid wonder folk catalogue")
	return value

static func number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1:
		return false
	var ids := {}
	for group in ["npcs", "creatures"]:
		if not value.get(group) is Dictionary or value[group].is_empty() or value[group].size() > 32:
			return false
		for id in value[group]:
			var entry = value[group][id]
			if not id is String or not id.is_valid_identifier() or id not in Models.IDS or ids.has(id) or not entry is Dictionary or not entry.get("name") is String or entry.name.strip_edges().is_empty() or entry.name.length() > 80 or not entry.get("biomes") is Array or entry.biomes.is_empty() or not entry.biomes.all(func(biome): return biome is String and Biomes.DATA.profiles.has(biome)):
				return false
			ids[id] = true
			if not number(entry.get("height"), .3, 1.5) or not number(entry.get("speed"), .5, 1.4):
				return false
			if group == "npcs":
				if entry.get("role") not in ["pilgrim", "scholar", "hunter", "courier"] or entry.get("trade_profile") not in ["", "market", "provisions"]:
					return false
				for key in ["activity", "work"]:
					if not entry.get(key) is String or entry[key].strip_edges().is_empty() or entry[key].length() > 1000:
						return false
				if not entry.get("greetings") is Array or entry.greetings.is_empty() or entry.greetings.size() > 8 or not entry.greetings.all(func(text): return text is String and not text.strip_edges().is_empty() and text.length() <= 1000):
					return false
			else:
				if entry.get("disposition") not in ["peaceful", "neutral", "hostile"] or not entry.get("families") is Array or not entry.families.all(func(family): return family is String and family.begins_with("dungeon_")) or not entry.get("ranged") is bool:
					return false
				for key in ["weight", "hp", "damage", "reach", "windup", "period"]:
					if not number(entry.get(key), 0 if key == "damage" else .1, 200):
						return false
				if entry.weight != int(entry.weight) or entry.weight > 8 or (entry.disposition == "peaceful" and (entry.damage != 0 or entry.ranged or not entry.families.is_empty())):
					return false
	return true

static func enemy_definitions() -> Array:
	var result := []
	for id in DATA.creatures:
		var entry: Dictionary = DATA.creatures[id]
		if entry.disposition == "peaceful":
			continue
		var definition := entry.duplicate(true)
		definition.id = id
		definition.wonder_id = id
		definition.visual_mode = "generated"
		definition.voxel_shape = 0
		definition.aggressive = entry.disposition == "hostile"
		definition.retaliates = true
		definition.visual = {"patterns": []}
		definition.habitat = {"biomes": [], "facets": [], "biome_ids": entry.biomes.duplicate(), "families": entry.families.duplicate()}
		result.append(definition)
	return result

static func ambient(id: String) -> Dictionary:
	var entry: Dictionary = DATA.creatures.get(id, {})
	if entry.get("disposition") != "peaceful":
		return {}
	var result := entry.duplicate(true)
	result.id = id
	result.asset_id = "wonder:" + id
	result.medium = "land"
	result.idle = "Idle"
	result.walk = "Walk"
	return result

static func ambient_for(biome_id: String, salt: int) -> Dictionary:
	if posmod(salt, 3) != 0:
		return {}
	var choices: Array = DATA.creatures.keys().filter(func(id): return DATA.creatures[id].disposition == "peaceful" and biome_id in DATA.creatures[id].biomes)
	return {} if choices.is_empty() else ambient(choices[posmod(floori(float(salt) / 3), choices.size())])

static func source(id: String) -> bool:
	return id.begins_with("wonder:") and not ambient(id.trim_prefix("wonder:")).is_empty()
