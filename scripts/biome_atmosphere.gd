extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
const PATH := "res://config/biome_atmosphere.json"
const MOTES := ["firefly", "spore", "ember", "leaf", "snow", "none"]
const BEDS := ["forest_air", "wind", "mountain_air", "river", "dungeon_air"]
const CUES := ["bird", "frog", "wonder", "pool:cricket", "pool:wind"]
static var DATA: Dictionary = _read()

static func _read() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(data), "Invalid named biome atmosphere")
	return data

static func _number(value, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= minimum and value <= maximum

static func valid(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("profiles") is Dictionary or data.profiles.size() != Biomes.DATA.profiles.size():
		return false
	for id in Biomes.DATA.profiles:
		var profile = data.profiles.get(id)
		if not profile is Dictionary or profile.get("bed_pool") not in BEDS or profile.get("cue") not in CUES or profile.get("mote") not in MOTES:
			return false
		for field in ["ambient", "sun", "color"]:
			if not profile.get(field) is String or not Color.html_is_valid(profile[field]):
				return false
		if not _number(profile.get("ambient_energy"), .72, 1.08) or not _number(profile.get("sun_energy"), .72, 1.08) or not _number(profile.get("bed_gain"), .35, 1.0) or not _number(profile.get("cue_interval"), 10, 36) or not _number(profile.get("mote_height"), .4, 1.5) or not _number(profile.get("drift"), .1, .6) or not _number(profile.get("wisps"), 0, 4) or profile.wisps != int(profile.wisps):
			return false
	return true

static func sample(mixture: Array) -> Dictionary:
	var weights := {}
	var total := 0.0
	for component in mixture:
		if DATA.profiles.has(component.id) and component.weight > 0:
			weights[component.id] = weights.get(component.id, 0.0) + component.weight
			total += component.weight
	if total == 0:
		weights.greenwood = 1.0
		total = 1.0
	var ids: Array = weights.keys()
	ids.sort_custom(func(a, b): return a < b if weights[a] == weights[b] else weights[a] > weights[b])
	var result: Dictionary = DATA.profiles[ids[0]].duplicate()
	result.id = ids[0]
	result.cue_mix = {}
	for field in ["ambient", "sun", "color"]:
		result[field] = Color(0, 0, 0, 0)
	for field in ["ambient_energy", "sun_energy", "bed_gain", "cue_interval", "wisps", "mote_height", "drift"]:
		result[field] = 0.0
	for id in ids:
		var profile: Dictionary = DATA.profiles[id]
		var weight: float = weights[id] / total
		for field in ["ambient", "sun", "color"]:
			result[field] += Color(profile[field]) * weight
		for field in ["ambient_energy", "sun_energy", "bed_gain", "cue_interval", "wisps", "mote_height", "drift"]:
			result[field] += profile[field] * weight
		result.cue_mix[profile.cue] = result.cue_mix.get(profile.cue, 0.0) + weight
	result.wisps = roundi(result.wisps)
	return result
