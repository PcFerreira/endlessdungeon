extends RefCounted

static var DATA: Dictionary = _read()
static var pools: Dictionary = {}
const LEGACY_IDS := ["greenwood", "meadows", "desert", "frostlands"]

static func _read() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://config/biomes.json"))
	assert(valid(value), "Invalid biome ecology catalogue")
	for profile in value.profiles.values():
		profile.climates = profile.climates.map(func(climate): return int(climate))
	return value

static func _number(value, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= minimum and value <= maximum

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.get("edition") != 6 or not _number(value.get("size_multiplier"), 1, 20) or not _number(value.get("zone_size"), 128, 16384) or not _number(value.get("transition_width"), 16, 1024) or value.transition_width >= value.zone_size / 2 or not _number(value.get("climate_transition"), .005, .1) or not value.get("profiles") is Dictionary:
		return false
	for id in LEGACY_IDS + ["dense_forest", "haunted_hollows", "marsh", "jungle", "autumn_woodland", "fungal_grove", "volcanic_wastes", "highlands", "coast", "crystal_tundra"]:
		var entry = value.profiles.get(id)
		if not entry is Dictionary or not entry.get("name") is String or entry.name.is_empty() or not entry.get("climates") is Array or entry.climates.is_empty() or not entry.climates.all(func(climate): return _number(climate, 0, 3) and climate == int(climate)) or not _number(entry.get("weight"), 0, 16) or entry.weight != int(entry.weight) or not _number(entry.get("density"), 0, 300) or entry.density != int(entry.density) or not _number(entry.get("detail_chance"), 0, .4):
			return false
		for key in ["color", "earth", "rock"]:
			if not entry.get(key) is String or not Color.html_is_valid(entry[key]):
				return false
		for key in ["props", "details"]:
			if not entry.get(key) is Array or entry[key].is_empty() or not entry[key].all(func(role): return role is String and not role.is_empty()):
				return false
	for climate in range(4):
		if not value.profiles.values().any(func(profile): return profile.weight > 0 and profile.climates.any(func(number): return int(number) == climate)):
			return false
	return true

static func salt(seed_value: int, key: String) -> int:
	var value: int = hash("ecology-v6:%s:%s" % [seed_value, key]) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	return value ^ (value >> 16)

static func _profile(coordinate: Vector2i, climate: int, seed_value: int) -> String:
	if not pools.has(climate):
		var pool: Array[String] = []
		for id in DATA.profiles:
			var profile: Dictionary = DATA.profiles[id]
			if profile.climates.has(climate):
				for index in int(profile.weight):
					pool.append(id)
		pools[climate] = pool
	return pools[climate][salt(seed_value, str(coordinate) + ":profile") % pools[climate].size()]

static func _mixture(weights: Dictionary) -> Array[Dictionary]:
	var ids: Array = weights.keys()
	ids.sort_custom(func(a, b): return a < b if weights[a] == weights[b] else weights[a] > weights[b])
	ids = ids.slice(0, 8)
	var total := 0.0
	for id in ids:
		total += weights[id]
	var units := {}
	var remainder := {}
	var remaining := 16
	for id in ids:
		var share: float = weights[id] * 16 / total
		units[id] = floori(share)
		remainder[id] = share - units[id]
		remaining -= units[id]
	ids.sort_custom(func(a, b): return a < b if remainder[a] == remainder[b] else remainder[a] > remainder[b])
	for index in range(remaining):
		units[ids[index]] += 1
	ids.sort()
	var result: Array[Dictionary] = []
	for id in ids:
		if units[id] > 0:
			result.append({"id": id, "weight": float(units[id]) / 16})
	return result

static func _weights(closest: Array, seed_value: int, heat: float, rain: float, coast: float) -> Array[Dictionary]:
	var width: float = DATA.climate_transition
	var cold := 1 - smoothstep(-.22 - width, -.22 + width, heat)
	var hot := smoothstep(.23 - width, .23 + width, heat)
	var temperate := 1 - cold - hot
	var forest := smoothstep(-width, width, rain)
	var climates := [temperate * forest, temperate * (1 - forest), hot, cold]
	var weights := {}
	for zone in closest:
		var spatial := 1 - smoothstep(0, DATA.transition_width, zone.distance - closest[0].distance)
		if spatial <= 0:
			continue
		for climate in range(4):
			if climates[climate] <= 0:
				continue
			var id := _profile(zone.coordinate, climate, seed_value)
			weights[id] = weights.get(id, 0.0) + spatial * climates[climate]
	if coast:
		var total := 0.0
		for weight in weights.values():
			total += weight
		for id in weights:
			weights[id] *= (1 - .75 * coast) / total
		weights["coast"] = .75 * coast
	return _mixture(weights)

static func sample(cell: Vector2i, climate: int, seed_value: int, heat: float, rain: float, coast = 0.0) -> Dictionary:
	var coast_strength := clampf(float(coast), 0, 1)
	var size: int = DATA.zone_size
	var coordinate := Vector2i(floori(float(cell.x) / size), floori(float(cell.y) / size))
	var closest := []
	for x in range(coordinate.x - 1, coordinate.x + 2):
		for y in range(coordinate.y - 1, coordinate.y + 2):
			var zone := Vector2i(x, y)
			var jitter := Vector2(salt(seed_value, str(zone) + ":x") % 1000, salt(seed_value, str(zone) + ":y") % 1000) / 1000.0 * .4 + Vector2.ONE * .3
			var center := (Vector2(zone) + jitter) * size
			closest.append({"coordinate": zone, "distance": Vector2(cell).distance_to(center)})
	closest.sort_custom(func(a, b): return str(a.coordinate) < str(b.coordinate) if a.distance == b.distance else a.distance < b.distance)
	var id := _profile(closest[0].coordinate, climate, seed_value)
	var secondary := _profile(closest[1].coordinate, climate, seed_value)
	var difference: float = closest[1].distance - closest[0].distance
	var blend: float = .5 * (1 - smoothstep(0, DATA.transition_width, difference)) if id != secondary else 0
	var alternative := -1
	var climate_distance := INF
	if absf(heat + .22) < DATA.climate_transition:
		alternative = 3 if climate != 3 else (0 if rain > 0 else 1)
		climate_distance = absf(heat + .22)
	elif absf(heat - .23) < DATA.climate_transition:
		alternative = 2 if climate != 2 else (0 if rain > 0 else 1)
		climate_distance = absf(heat - .23)
	elif climate in [0, 1] and absf(rain) < DATA.climate_transition:
		alternative = 1 - climate
		climate_distance = absf(rain)
	if alternative >= 0:
		var transition: float = .5 * (1 - smoothstep(0, DATA.climate_transition, climate_distance))
		if transition > blend:
			secondary = _profile(closest[0].coordinate, alternative, seed_value)
			blend = transition
	var coastal := .75 * coast_strength
	if coastal >= .5:
		secondary = id
		id = "coast"
		blend = 1 - coastal
	elif coastal > blend:
		secondary = "coast"
		blend = coastal
	return {"biome": climate, "biome_id": id, "biome_secondary": secondary, "biome_blend": snappedf(blend, 1.0 / 16), "biome_mix": _weights(closest, seed_value, heat, rain, coast_strength)}

static func valid_mix(value) -> bool:
	if not value is Array or value.is_empty() or value.size() > 8:
		return false
	var ids := {}
	var total := 0
	for part in value:
		if not part is Dictionary or not part.get("id") is String or not DATA.profiles.has(part.id) or ids.has(part.id) or not _number(part.get("weight"), 1.0 / 16, 1):
			return false
		var units: float = part.weight * 16
		if units != floorf(units):
			return false
		ids[part.id] = true
		total += int(units)
	return total == 16

static func valid_cell(info: Dictionary) -> bool:
	return _number(info.get("biome"), 0, 3) and info.biome == int(info.biome) and DATA.profiles.has(info.get("biome_id", "")) and DATA.profiles[info.biome_id].climates.has(int(info.biome)) and DATA.profiles.has(info.get("biome_secondary", "")) and _number(info.get("biome_blend"), 0, .5) and (not info.has("biome_mix") or valid_mix(info.biome_mix))

static func name_for(info: Dictionary) -> String:
	if info.get("biome_id") == "coast" and info.biome == 3:
		return "Frostbound Coast"
	return DATA.profiles.get(info.get("biome_id", ""), DATA.profiles[LEGACY_IDS[int(info.biome)]]).name

static func color_for(info: Dictionary, key: String = "color") -> Color:
	if info.has("biome_mix"):
		var result := Color(0, 0, 0, 1)
		for part in info.biome_mix:
			var color := Color(DATA.profiles[part.id][key])
			result.r += color.r * part.weight
			result.g += color.g * part.weight
			result.b += color.b * part.weight
		return result
	var first: Dictionary = DATA.profiles.get(info.get("biome_id", ""), DATA.profiles[LEGACY_IDS[int(info.biome)]])
	var second: Dictionary = DATA.profiles.get(info.get("biome_secondary", ""), first)
	return Color(first[key]).lerp(Color(second[key]), info.get("biome_blend", 0.0))

static func palette_key(info: Dictionary) -> String:
	if info.has("biome_mix"):
		var parts: PackedStringArray = []
		for part in info.biome_mix:
			parts.append("%s=%s" % [part.id, int(part.weight * 16)])
		parts.sort()
		return ",".join(parts)
	return "%s:%s:%s" % [info.get("biome_id", ""), info.get("biome_secondary", ""), info.get("biome_blend", 0.0)]
