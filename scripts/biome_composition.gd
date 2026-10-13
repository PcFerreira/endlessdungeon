extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
const FEATURE_SIZE := 64
const MOTIFS := ["copse", "flowers", "cactus", "pines", "memorial", "wetland", "jungle", "harvest", "mushrooms", "fissure", "outcrop", "shore", "crystals"]
static var DATA: Dictionary = _read()

static func _read() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://config/biome_composition.json"))
	assert(valid(value), "Invalid biome composition catalogue")
	return value

static func _number(value, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= minimum and value <= maximum

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.get("edition") != 7 or not value.get("profiles") is Dictionary or value.profiles.size() != Biomes.DATA.profiles.size():
		return false
	for id in Biomes.DATA.profiles:
		var profile = value.profiles.get(id)
		if not profile is Dictionary or profile.get("motif") not in MOTIFS or not profile.get("focal_roles") is Array or profile.focal_roles.is_empty() or not profile.focal_roles.all(func(role): return role is String and not role.is_empty()):
			return false
		for range_spec in [["patch_size", 24, 48], ["clearing_radius", 3, 7], ["grove_density", 70, 250], ["open_density", 0, 35], ["grove_details", .05, .45], ["open_details", 0, .12], ["focal_radius", 3, 7]]:
			if not _number(profile.get(range_spec[0]), range_spec[1], range_spec[2]):
				return false
	return true

static func _salt(seed_value: int, key: String) -> int:
	return Biomes.salt(seed_value, "composition-v7:" + key)

static func _field(seed_value: int, cell: Vector2i, id: String, scale: float) -> float:
	var point := Vector2(cell) / scale
	var base := Vector2i(floori(point.x), floori(point.y))
	var fraction := point - Vector2(base)
	fraction = fraction * fraction * (Vector2.ONE * 3 - fraction * 2)
	var values: Array[float] = []
	for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		values.append(float(_salt(seed_value, "%s:field:%s" % [id, base + offset]) % 1024) / 1023)
	return lerpf(lerpf(values[0], values[1], fraction.x), lerpf(values[2], values[3], fraction.x), fraction.y)

static func feature(seed_value: int, cell: Vector2i) -> Dictionary:
	var coordinate := Vector2i(floori(float(cell.x) / FEATURE_SIZE), floori(float(cell.y) / FEATURE_SIZE))
	var nearest := INF
	var result := {}
	for x in range(coordinate.x - 1, coordinate.x + 2):
		for y in range(coordinate.y - 1, coordinate.y + 2):
			var grid := Vector2i(x, y)
			var key := "%s:%s" % [x, y]
			var center := grid * FEATURE_SIZE + Vector2i(18 + _salt(seed_value, key + ":feature-x") % 29, 18 + _salt(seed_value, key + ":feature-y") % 29)
			var distance := Vector2(cell).distance_squared_to(Vector2(center))
			if distance < nearest:
				nearest = distance
				result = {"id": key, "center": center, "distance": sqrt(distance), "turn": _salt(seed_value, key + ":turn") % 4, "active": _salt(seed_value, key + ":active") % 3 != 0}
	return result

static func _local(cell: Vector2i, focus: Dictionary) -> Vector2i:
	var local: Vector2i = cell - focus.center
	for turn in int(focus.turn):
		local = Vector2i(-local.y, local.x)
	return local

static func _stand(seed_value: int, cell: Vector2i, id: String, focus: Dictionary) -> Dictionary:
	var profile: Dictionary = DATA.profiles[id]
	var grove := smoothstep(.25, .75, _field(seed_value, cell, id, profile.patch_size))
	grove *= smoothstep(profile.clearing_radius, profile.clearing_radius + 8, focus.distance)
	return {"grove": grove, "density": lerpf(profile.open_density, profile.grove_density, grove), "detail_chance": lerpf(profile.open_details, profile.grove_details, grove)}

static func sample(seed_value: int, cell: Vector2i, ecology: Dictionary, wet_edge: bool = false, slope: float = 0, micro: Dictionary = {}, focus: Dictionary = {}) -> Dictionary:
	if focus.is_empty():
		focus = feature(seed_value, cell)
	var id: String = ecology.biome_id
	var threshold: float = float(_salt(seed_value, "ecotone:%s" % cell) % 1024) / 1024
	var cumulative := 0.0
	var density := 0.0
	var details := 0.0
	var grove := 0.0
	var mix: Array = ecology.get("biome_mix", [{"id": id, "weight": 1.0}])
	for part in mix:
		var stand := _stand(seed_value, cell, part.id, focus)
		density += stand.density * part.weight
		details += stand.detail_chance * part.weight
		grove += stand.grove * part.weight
		if threshold >= cumulative and threshold < cumulative + part.weight:
			id = part.id
		cumulative += part.weight
	var profile: Dictionary = DATA.profiles[id]
	var natural: Dictionary = Biomes.DATA.profiles[id]
	var props: Array = natural.props.duplicate()
	var detail_roles: Array = natural.details.duplicate()
	if id == "dense_forest":
		props = ["biome:dense_crown", "biome:dense_crown", "tree_b"]
	elif id == "jungle":
		props = ["biome:jungle_crown", "biome:jungle_crown", "biome:jungle_canopy"]
	elif id == "haunted_hollows":
		props = ["biome:haunted_tree", "biome:haunted_tree", "dead_a"]
		detail_roles = ["biome:forest_understory"]
	elif id == "autumn_woodland":
		detail_roles = ["biome:forest_understory"]
	elif id == "marsh":
		detail_roles = ["biome:forest_understory"]
	elif id == "volcanic_wastes":
		detail_roles = ["biome:highland_rock"]
	elif id == "crystal_tundra":
		props = ["pine", "biome:highland_rock"]
		detail_roles = ["biome:highland_rock"]
	if id == "coast" and int(ecology.biome) == 3:
		props = ["pine", "rock"]
	var result := {"density": density, "detail_chance": details, "grove": grove, "props": props, "details": detail_roles, "profile_id": id, "zone": "clearing" if focus.distance <= profile.clearing_radius else ("stand" if grove >= .55 else "open"), "motif": profile.motif, "feature_id": focus.id if focus.active else "", "prop_override": "", "detail_override": "", "clear": focus.distance <= profile.clearing_radius}
	var local := _local(cell, focus)
	var radius: float = profile.focal_radius
	var seed_roll := _salt(seed_value, "detail:%s" % cell)
	if id == "marsh" and wet_edge:
		result.details = ["biome:reeds"]
		result.detail_chance = .4
		result.density *= .25
		result.detail_override = "biome:reeds" if seed_roll % 3 != 0 else ""
	if focus.active:
		match profile.motif:
			"copse", "pines", "jungle":
				if focus.distance >= profile.clearing_radius and focus.distance <= profile.clearing_radius + 3 and seed_roll % 4 == 0:
					result.detail_override = "biome:jungle_understory" if profile.motif == "jungle" else "biome:forest_understory"
				if local == Vector2i(-2, -2):
					result.detail_override = "biome:highland_rock" if profile.motif == "pines" else "mushroom"
			"flowers":
				if focus.distance < radius + 4 and absi(local.y - roundi(sin(local.x * .3) * 2)) <= 1 and seed_roll % 3 != 0:
					result.detail_override = profile.focal_roles[seed_roll % 2]
			"cactus":
				if local in [Vector2i(-2, -2), Vector2i(2, -1), Vector2i(0, 2)]:
					result.prop_override = "cactus"
				elif focus.distance < radius + 1 and absi(local.y + 2) <= 1 and seed_roll % 4 == 0:
					result.detail_override = "biome:highland_rock"
			"memorial":
				if local in [Vector2i(-2, -2), Vector2i(0, -2), Vector2i(2, -2), Vector2i(-2, 0), Vector2i(2, 0)]:
					result.prop_override = "biome:grave"
				elif focus.distance >= radius and focus.distance < radius + 2 and seed_roll % 4 == 0:
					result.detail_override = "biome:pumpkin"
			"wetland":
				if not wet_edge and focus.distance < radius and seed_roll % 3 == 0:
					result.detail_override = "biome:forest_understory"
			"harvest":
				if focus.distance >= radius and focus.distance <= radius + 2 and seed_roll % 3 == 0:
					result.detail_override = "biome:pumpkin"
			"mushrooms":
				if local in [Vector2i(-2, -1), Vector2i(1, -2), Vector2i(2, 1)]:
					result.prop_override = "biome:giant_mushroom"
				elif focus.distance < radius and seed_roll % 3 != 0:
					result.detail_override = "mushroom"
			"fissure":
				if absi(local.x) <= radius and local.y == 0:
					result.detail_override = "biome:lava_crack"
				elif absi(local.x) <= radius and absi(local.y) == 2 and posmod(local.x, 3) == 0:
					result.prop_override = "biome:basalt"
			"outcrop":
				if local in [Vector2i(-2, -1), Vector2i(0, -2), Vector2i(2, 0)]:
					result.prop_override = "biome:highland_rock"
			"shore":
				if wet_edge:
					result.density *= .15
					if seed_roll % 3 == 0:
						result.detail_override = "biome:coastal_grass"
				elif focus.distance >= radius and focus.distance <= radius + 3 and seed_roll % 4 == 0:
					result.detail_override = "biome:coastal_grass"
			"crystals":
				if local in [Vector2i(-2, -1), Vector2i(0, -2), Vector2i(2, 1)]:
					result.prop_override = "biome:crystal"
				elif focus.distance < radius and seed_roll % 4 == 0:
					result.detail_override = "biome:crystal"
	if profile.motif == "outcrop":
		result.density *= lerpf(.7, 1.0, clampf(slope, 0, 1))
	if not micro.is_empty() and focus.distance <= micro.radius:
		_micro_recipe(result, focus, local, seed_roll, micro, int(ecology.biome), wet_edge)
	return result

static func _micro_recipe(result: Dictionary, focus: Dictionary, local: Vector2i, roll: int, profile: Dictionary, climate: int, wet_edge: bool) -> void:
	result.micro_biome_id = profile.id
	result.micro_biome_name = profile.name
	result.motif = profile.recipe
	if profile.recipe in ["fairy_ring", "mycelial_nursery"]:
		result.prop_override = ""
		result.detail_override = ""
		result.details = ["biome:forest_understory"]
		result.detail_chance = .08
		if focus.distance <= 2.25:
			result.clear = true
			result.detail_chance = 0
			return
	match profile.recipe:
		"fairy_ring":
			if focus.distance >= 3 and focus.distance <= 3.75 and roll % 4 != 0:
				result.detail_override = "biome:giant_mushroom"
		"ancient_grove":
			if focus.distance >= 5 and focus.distance <= 9:
				result.density = maxf(result.density, 190)
				result.props = ["pine"] if climate == 3 else (["biome:autumn_tree"] if profile.biome_id == "autumn_woodland" else ["biome:dense_crown", "oak"])
				result.detail_chance = .3
		"wildflowers":
			if absi(local.y - roundi(sin(local.x * .4) * 2)) <= 2 and roll % 4 != 0:
				result.detail_override = "flowers" if roll % 2 == 0 else "flowers_b"
		"cactus_shade":
			if local in [Vector2i(-3, -2), Vector2i(2, -3), Vector2i(3, 2)]:
				result.prop_override = "cactus"
		"oasis_bank", "firefly_fen", "frozen_pond", "tide_garden":
			if wet_edge:
				result.detail_override = "biome:coastal_grass" if profile.recipe == "tide_garden" else "biome:reeds"
				result.density *= .2
			elif profile.recipe == "frozen_pond" and focus.distance > 6:
				result.props = ["pine", "rock"]
		"haunted_memorial":
			if focus.distance >= 5 and focus.distance <= 7 and roll % 3 == 0:
				result.detail_override = "biome:pumpkin"
		"bamboo_hollow":
			if focus.distance >= 5 and focus.distance <= 9:
				result.density = maxf(result.density, 190)
				result.props = ["biome:jungle_canopy"]
				result.detail_chance = .38
				result.details = ["biome:jungle_understory"]
		"harvest_glade":
			if absi(local.x) <= 5 and absi(local.y) == 3 and posmod(local.x, 2) == 0:
				result.detail_override = "biome:pumpkin"
		"mycelial_nursery":
			if focus.distance >= 3.5 and focus.distance <= 6 and roll % 5 == 0 and not (local.y >= 0 and absi(local.x) <= 1):
				result.detail_override = "biome:giant_mushroom"
			elif local == Vector2i(0, -6):
				result.prop_override = "biome:giant_mushroom"
		"basalt_vent":
			if absi(local.y) <= 1 and absi(local.x) >= 2 and absi(local.x) <= 7:
				result.detail_override = "biome:lava_crack"
		"windward_outcrop":
			if focus.distance >= 3 and focus.distance <= 7 and roll % 3 == 0:
				result.detail_override = "biome:highland_rock"
		"crystal_pocket":
			if focus.distance >= 2.5 and focus.distance <= 5 and roll % 3 == 0:
				result.detail_override = "biome:crystal"

static func visual(seed_value: int, cell: Vector2i, detail: bool = false, role: String = "") -> Dictionary:
	var value := _salt(seed_value, "%s:visual:%s" % [cell, detail])
	var scale_xz := .82 + float(value % 4) * .05
	var scale_y := .88 + float((value / 4) % 5) * .04
	if role in ["biome:dense_crown", "biome:jungle_crown"]:
		scale_y = 1.0 + float((value / 4) % 4) * .03
	if detail and role == "biome:crystal":
		scale_xz *= .45
		scale_y *= .45
	if detail and role == "biome:giant_mushroom":
		scale_xz *= .55
		scale_y *= .3
	return {"turn": value % 4, "scale": Vector3(scale_xz, scale_y, scale_xz), "variant": value % 6}
