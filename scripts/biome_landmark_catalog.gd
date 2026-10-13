extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
const Forage = preload("res://scripts/forage_catalog.gd")
const Micro = preload("res://scripts/micro_biome_catalog.gd")
const PATH := "res://config/biome_landmarks.json"
const KINDS := ["monolith", "well", "watchtower", "mage_tower", "tomb", "ruined_cottage", "shrine", "ruined_arch"]
const CACHE_KINDS := ["watchtower", "mage_tower", "tomb", "ruined_cottage"]
static var DATA: Dictionary = _read()
static var profiles: Dictionary = _profiles()

static func _read() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(data), "Invalid biome landmark catalogue")
	return data

static func _pair(value, low: int, high: int) -> bool:
	return value is Array and value.size() == 2 and value.all(func(number): return Forage.integer(number, low, high))

static func _number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= low and value <= high

static func _point(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))

static func valid(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or data.get("edition") != 7 or data.get("feature_chance_denominator") != 4 or not data.get("profiles") is Dictionary or data.profiles.size() != KINDS.size() or not data.get("biomes") is Dictionary or data.biomes.size() != Biomes.DATA.profiles.size():
		return false
	for kind in KINDS:
		var profile = data.profiles.get(kind)
		if not profile is Dictionary or profile.get("kind") != kind or not profile.get("name") is String or profile.name.is_empty() or not profile.get("flavor") is String or profile.flavor.is_empty():
			return false
		if not _pair(profile.get("size"), 5, 7) or not profile.size.all(func(number): return int(number) in [5, 7]) or not _pair(profile.get("body_size"), 1, 5) or not profile.body_size.all(func(number): return int(number) % 2 == 1) or not _pair(profile.get("body_center"), -2, 2) or not _pair(profile.get("door_local"), -3, 3):
			return false
		if not _number(profile.get("body_height"), 1, 8) or not _number(profile.get("foundation_depth"), 0, .25) or profile.body_height + profile.foundation_depth > 8 or not profile.get("solid_local") is Array or profile.solid_local.is_empty() or profile.solid_local.size() > 25:
			return false
		var size := _point(profile.size)
		if size.x != size.y:
			return false
		var plot := Rect2i(-size / 2, size)
		var body_size := _point(profile.body_size)
		var body := Rect2i(_point(profile.body_center) - body_size / 2, body_size)
		if not plot.encloses(body) or _point(profile.door_local) != Vector2i(0, size.y / 2 - 1):
			return false
		var occupied := {}
		for cell in profile.solid_local:
			if not _pair(cell, -3, 3) or not body.has_point(_point(cell)) or occupied.has(str(cell)) or cell == profile.door_local:
				return false
			occupied[str(cell)] = true
		var interaction := "cache" if kind in CACHE_KINDS else ("well" if kind == "well" else "story")
		if profile.get("interaction") != interaction or not Forage.integer(profile.get("quantity"), 2 if interaction == "cache" else 0, 5 if interaction == "cache" else 0) or not Forage.integer(profile.get("coins"), 8 if interaction == "cache" else 0, 24 if interaction == "cache" else 0):
			return false
	for biome in Biomes.DATA.profiles:
		var pool = data.biomes.get(biome)
		if not pool is Dictionary or not pool.get("flavor") is String or pool.flavor.is_empty() or not pool.get("reward_items") is Array or pool.reward_items.size() != 2 or not pool.reward_items.all(func(item): return Forage.DATA.items.has(item) and Forage.DATA.biomes[biome].entries.any(func(entry): return entry.item == item)) or not pool.get("entries") is Array or pool.entries.is_empty():
			return false
		var kinds := {}
		for entry in pool.entries:
			if not entry is Dictionary or entry.get("kind") not in KINDS or kinds.has(entry.kind) or not Forage.integer(entry.get("weight"), 1, 8):
				return false
			kinds[entry.kind] = true
	return true

static func _profiles() -> Dictionary:
	var result := {}
	for kind in KINDS:
		var profile: Dictionary = DATA.profiles[kind].duplicate(true)
		for field in ["size", "body_size", "body_center", "door_local"]:
			profile[field] = _point(profile[field])
		profile.solid_local = profile.solid_local.map(func(cell): return _point(cell))
		result[kind] = profile
	return result

static func by_id(kind: String) -> Dictionary:
	return profiles.get(kind, {}).duplicate(true)

static func fields(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() != 6 or parts[0] != "landmark" or parts[1] != "7" or not Micro._canonical(parts[2]) or parts[5] not in KINDS:
		return {}
	var grid := Micro._grid(parts[3] + ":" + parts[4])
	if grid.is_empty():
		return {}
	return {"seed": parts[2].to_int(), "grid": grid.grid, "kind": parts[5]}

static func _candidate(seed_value: int, feature_id: String) -> bool:
	return not Micro._grid(feature_id).is_empty() and not Micro._candidate(seed_value, feature_id) and Biomes.salt(seed_value, "composition-v7:" + feature_id + ":active") % 3 != 0 and Biomes.salt(seed_value, "landmark-v7:" + feature_id + ":chance") % int(DATA.feature_chance_denominator) == 0

static func profile_for(seed_value: int, feature_id: String, biome_id: String) -> Dictionary:
	if not DATA.biomes.has(biome_id) or not _candidate(seed_value, feature_id):
		return {}
	var pool: Dictionary = DATA.biomes[biome_id]
	var total := 0
	for entry in pool.entries:
		total += int(entry.weight)
	var roll := Biomes.salt(seed_value, "landmark-v7:" + feature_id + ":kind:" + biome_id) % total
	for entry in pool.entries:
		roll -= int(entry.weight)
		if roll < 0:
			var profile := by_id(entry.kind)
			profile.biome_id = biome_id
			profile.flavor += " " + pool.flavor
			profile.reward_item = pool.reward_items[Biomes.salt(seed_value, "landmark-v7:" + feature_id + ":reward:" + biome_id) % pool.reward_items.size()]
			return profile
	return {}

static func rotate(local: Vector2i, turn: int) -> Vector2i:
	for index in posmod(turn, 4):
		local = Vector2i(local.y, -local.x)
	return local

static func _ground(world, cell: Vector2i) -> Dictionary:
	if absi(cell.x) > Micro.CELL_LIMIT or absi(cell.y) > Micro.CELL_LIMIT or not Micro.nature_world(world, cell) or world._natural_water(cell):
		return {}
	var region: Dictionary = world.region_at(cell)
	if world._road_at(cell, region) or not world.city_at(Vector2(cell), 4).is_empty():
		return {}
	for site in world.sites_in(region):
		var footprint: Rect2i = site.get("footprint", Rect2i(site.cell - Vector2i.ONE * 3, Vector2i.ONE * 7))
		if footprint.grow(2).has_point(cell) or Vector2(cell).distance_to(Vector2(site.get("approach", site.cell))) < 3:
			return {}
	return {"height": world._surface_height(cell, region, false)}

static func plan(world, feature: Dictionary) -> Dictionary:
	if world.generator_version != 7 or not feature.get("id") is String or not feature.get("center") is Vector2i or not Micro.nature_world(world, feature.center) or not _candidate(world.run_seed, feature.id):
		return {}
	var Composition = load("res://scripts/biome_composition.gd")
	var authoritative: Dictionary = Composition.feature(world.run_seed, feature.center)
	if authoritative.id != feature.id or authoritative.center != feature.center or not authoritative.active:
		return {}
	var ecology: Dictionary = world.biome_at(authoritative.center)
	var profile := profile_for(world.run_seed, authoritative.id, ecology.biome_id)
	if profile.is_empty():
		return {}
	var plot := Rect2i(authoritative.center - profile.size / 2, profile.size)
	var minimum := INF
	var maximum := -INF
	for x in range(plot.position.x, plot.end.x):
		for y in range(plot.position.y, plot.end.y):
			var ground := _ground(world, Vector2i(x, y))
			if ground.is_empty():
				return {}
			minimum = minf(minimum, ground.height)
			maximum = maxf(maximum, ground.height)
			if maximum - minimum > .5:
				return {}
	var facing := rotate(Vector2i.DOWN, int(authoritative.turn))
	var door: Vector2i = authoritative.center + rotate(profile.door_local, int(authoritative.turn))
	for step in range(3):
		var ground := _ground(world, door + facing * step)
		if ground.is_empty() or absf(ground.height - maximum) > .5:
			return {}
	var solid_cells: Array[Vector2i] = []
	for local in profile.solid_local:
		solid_cells.append(authoritative.center + rotate(local, int(authoritative.turn)))
	var result: Dictionary = profile.duplicate(true)
	result.merge({"id": "landmark:7:%s:%s:%s" % [world.run_seed, authoritative.id, profile.kind], "center": authoritative.center, "grid": Micro._grid(authoritative.id).grid, "feature_id": authoritative.id, "turn": authoritative.turn, "facing": facing, "footprint": plot, "solid_cells": solid_cells, "door": door, "point": door, "approach": door + facing, "approach_far": door + facing * 2, "height": maximum})
	return result
