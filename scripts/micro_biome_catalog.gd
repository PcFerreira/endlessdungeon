extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
const Forage = preload("res://scripts/forage_catalog.gd")
const IntegerText = preload("res://scripts/integer_text.gd")
const PATH := "res://config/micro_biomes.json"
const FEATURE_SIZE := 64
const GRID_LIMIT := 156249
const CELL_LIMIT := 9999999
const RECIPES := ["fairy_ring", "ancient_grove", "wildflowers", "cactus_shade", "oasis_bank", "frozen_pond", "haunted_memorial", "firefly_fen", "bamboo_hollow", "harvest_glade", "mycelial_nursery", "basalt_vent", "windward_outcrop", "tide_garden", "crystal_pocket"]
const WATER_RECIPES := ["oasis_bank", "frozen_pond", "firefly_fen", "tide_garden"]
static var DATA: Dictionary = _read()
static var profiles: Dictionary = _profiles()
static var water_offsets: Dictionary = {}

static func _read() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(data), "Invalid micro biome catalogue")
	return data

static func valid(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or data.get("edition") != 7 or data.get("feature_chance_denominator") != 3 or not data.get("profiles") is Dictionary or data.profiles.size() != Biomes.DATA.profiles.size():
		return false
	var ids := {}
	for biome in Biomes.DATA.profiles:
		var entries = data.profiles.get(biome)
		if not entries is Array or entries.size() < 2 or entries.size() > 3:
			return false
		for profile in entries:
			if not profile is Dictionary or not profile.get("id") is String or profile.id.is_empty() or profile.id.to_snake_case() != profile.id or ":" in profile.id or "/" in profile.id or profile.id.length() > 64 or ids.has(profile.id) or profile.get("recipe") not in RECIPES or not profile.get("water_required") is bool or profile.water_required != (profile.recipe in WATER_RECIPES):
				return false
			if not profile.get("name") is String or profile.name.is_empty() or profile.name.length() > 80 or not profile.get("flavor") is String or profile.flavor.is_empty() or profile.flavor.length() > 240:
				return false
			if not Forage.DATA.items.has(profile.get("reward_item")) or not Forage.DATA.biomes[biome].entries.any(func(entry): return entry.item == profile.reward_item):
				return false
			for rule in [["radius", 6, 20], ["quantity", 2, 5], ["coins", 8, 20], ["weight", 1, 8]]:
				if not Forage.integer(profile.get(rule[0]), rule[1], rule[2]):
					return false
			ids[profile.id] = true
	return true

static func _profiles() -> Dictionary:
	var result := {}
	for biome in DATA.profiles:
		for entry in DATA.profiles[biome]:
			var profile: Dictionary = entry.duplicate()
			profile.biome_id = biome
			result[profile.id] = profile
	return result

static func by_id(profile_id: String) -> Dictionary:
	return profiles.get(profile_id, {}).duplicate()

static func _canonical(value: String, limit: int = -1) -> bool:
	return IntegerText.valid(value) and (limit < 0 or IntegerText.bounded(value, limit)) and str(value.to_int()) == value

static func _grid(feature_id: String) -> Dictionary:
	var fields := feature_id.split(":")
	if fields.size() != 2 or not _canonical(fields[0], GRID_LIMIT) or not _canonical(fields[1], GRID_LIMIT):
		return {}
	return {"grid": Vector2i(fields[0].to_int(), fields[1].to_int())}

static func fields(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() != 6 or parts[0] != "micro" or parts[1] != "7" or not _canonical(parts[2]):
		return {}
	var grid := _grid(parts[3] + ":" + parts[4])
	var profile := by_id(parts[5])
	if grid.is_empty() or profile.is_empty():
		return {}
	return {"seed": parts[2].to_int(), "grid": grid.grid, "profile_id": profile.id, "biome_id": profile.biome_id}

static func _candidate(seed_value: int, feature_id: String) -> bool:
	return not _grid(feature_id).is_empty() and Biomes.salt(seed_value, "composition-v7:" + feature_id + ":active") % 3 != 0 and Biomes.salt(seed_value, "micro-v7:" + feature_id + ":chance") % int(DATA.feature_chance_denominator) == 0

static func profile_for(seed_value: int, feature_id: String, biome_id: String) -> Dictionary:
	if not DATA.profiles.has(biome_id) or not _candidate(seed_value, feature_id):
		return {}
	var entries: Array = DATA.profiles[biome_id]
	var total := 0
	for entry in entries:
		total += int(entry.weight)
	var roll := Biomes.salt(seed_value, "micro-v7:" + feature_id + ":profile:" + biome_id) % total
	for entry in entries:
		roll -= int(entry.weight)
		if roll < 0:
			return by_id(entry.id)
	return {}

static func nature_world(world, cell: Vector2i) -> bool:
	var path: String = world.get_script().resource_path
	return path == "res://scripts/world.gd" or (path == "res://scripts/hub_world.gd" and not world.hub.reserved.has_point(cell))

static func _protected(world, cell: Vector2i, region: Dictionary) -> bool:
	if not nature_world(world, cell) or world._road_at(cell, region) or not world.city_at(Vector2(cell), 4).is_empty():
		return true
	for site in world.sites_in(region):
		var footprint: Rect2i = site.get("footprint", Rect2i(site.cell - Vector2i.ONE * 3, Vector2i.ONE * 7))
		if footprint.grow(2).has_point(cell) or Vector2(cell).distance_to(Vector2(site.get("approach", site.cell))) < 3:
			return true
	return false

static func _dry(world, cell: Vector2i) -> bool:
	if absi(cell.x) > CELL_LIMIT or absi(cell.y) > CELL_LIMIT or world._natural_water(cell):
		return false
	var info: Dictionary = world.cell_info(cell)
	return info.get("terrain") == "land" and info.get("walkable", false) and not _protected(world, cell, world.region_at(cell))

static func _water(world, center: Vector2i, radius: int) -> Dictionary:
	if not water_offsets.has(radius):
		var offsets: Array[Vector2i] = []
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if x * x + y * y <= radius * radius:
					offsets.append(Vector2i(x, y))
		offsets.sort_custom(func(a, b):
			if a.length_squared() != b.length_squared():
				return a.length_squared() < b.length_squared()
			return a.x < b.x if a.y == b.y else a.y < b.y)
		water_offsets[radius] = offsets
	for offset in water_offsets[radius]:
		var cell: Vector2i = center + offset
		if absi(cell.x) <= CELL_LIMIT and absi(cell.y) <= CELL_LIMIT and world._natural_water(cell) and world.cell_info(cell).get("terrain") == "water" and not _protected(world, cell, world.region_at(cell)):
			return {"water_cell": cell}
	return {}

static func plan(world, feature: Dictionary) -> Dictionary:
	if world.generator_version != 7 or not feature.get("id") is String or not feature.get("center") is Vector2i or not nature_world(world, feature.center) or not _candidate(world.run_seed, feature.id):
		return {}
	var Composition = load("res://scripts/biome_composition.gd")
	var authoritative: Dictionary = Composition.feature(world.run_seed, feature.center)
	if authoritative.id != feature.id or authoritative.center != feature.center or not authoritative.active or not _dry(world, authoritative.center):
		return {}
	var info: Dictionary = world.cell_info(authoritative.center)
	var profile := profile_for(world.run_seed, authoritative.id, info.biome_id)
	if profile.is_empty():
		return {}
	var approach := Vector2i.ZERO
	var supported := false
	for turn in range(4):
		var direction: Vector2i = world.DIRECTIONS[(turn + int(authoritative.turn)) % 4]
		var middle: Vector2i = authoritative.center + direction
		var candidate: Vector2i = authoritative.center + direction * 2
		if _dry(world, middle) and _dry(world, candidate) and absf(world.cell_info(middle).height - info.height) <= .51 and absf(world.cell_info(candidate).height - world.cell_info(middle).height) <= .51:
			approach = candidate
			supported = true
			break
	if not supported:
		return {}
	var water := _water(world, authoritative.center, int(profile.radius)) if profile.water_required else {}
	if profile.water_required and water.is_empty():
		return {}
	var result: Dictionary = profile.duplicate()
	result.profile_id = profile.id
	result.id = "micro:7:%s:%s:%s" % [world.run_seed, authoritative.id, profile.id]
	result.center = authoritative.center
	result.point = authoritative.center
	result.approach = approach
	result.turn = authoritative.turn
	result.feature_id = authoritative.id
	result.grid = _grid(authoritative.id).grid
	result.merge(water)
	return result
