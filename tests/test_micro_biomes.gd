extends SceneTree

const World = preload("res://scripts/world.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const Forage = preload("res://scripts/forage_catalog.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not FileAccess.file_exists("res://scripts/micro_biome_catalog.gd"):
		check(false, "Exploration needs a real micro biome catalogue and protected terrain planner")
		quit(1)
		return
	var Micro = load("res://scripts/micro_biome_catalog.gd")
	check(Micro.valid(Micro.DATA), "Authored micro biome catalogue validates")
	var selected := {}
	for biome in Micro.DATA.profiles:
		for x in range(-40, 41):
			var profile: Dictionary = Micro.profile_for(91, "%s:7" % x, biome)
			check(profile == Micro.profile_for(91, "%s:7" % x, biome), "Micro profile selection is deterministic")
			if not profile.is_empty():
				selected[profile.id] = true
				check(Forage.DATA.items.has(profile.reward_item), "Micro rewards use actual material definitions")
	check(selected.size() == 28, "Both authored micro profiles in all14 biomes must be reachable")
	for profile_id in ["fairy_ring", "mycelial_nursery"]:
		var profile: Dictionary = Micro.by_id(profile_id)
		var ecology := {"biome_id": profile.biome_id, "biome": 0}
		var focus := {"id": "0:0", "center": Vector2i.ZERO, "distance": 0.0, "turn": 0, "active": true}
		var caps := 0
		for x in range(-8, 9):
			for y in range(-8, 9):
				var cell := Vector2i(x, y)
				focus.distance = Vector2(cell).length()
				var dressing := Composition.sample(91, cell, ecology, false, 0, profile, focus)
				if focus.distance <= 2.25:
					check(dressing.clear and dressing.prop_override.is_empty() and dressing.detail_override.is_empty() and dressing.detail_chance == 0, "Mushroom cache core must retain visible negative space")
				if focus.distance <= profile.radius:
					check(dressing.detail_override != "mushroom", "Micro mushroom focal groups must avoid inherited tall generic mushroom clutter")
				if dressing.detail_override == "biome:giant_mushroom":
					caps += 1
		check(caps >= 6 and caps <= 28, "Mushroom micro groups must retain a bounded visible cap arrangement: " + profile_id)
		var placement := Composition.visual(91, Vector2i(3, 3), true, "biome:giant_mushroom")
		check(placement.scale.y * 2.15 < .8 and placement.scale.x * .9 < .6, "Mushroom detail bodies must remain below standing player and cache labels")
	check(Micro.profile_for(91, "4294967296:7", "greenwood").is_empty(), "Wrapped feature grids must be rejected before conversion")
	check(Micro.profile_for(91, "+1:7", "greenwood").is_empty(), "Noncanonical feature IDs are rejected")
	var invalid: Dictionary = Micro.DATA.duplicate(true)
	invalid.profiles.desert[0].reward_item = "missing_reward"
	check(not Micro.valid(invalid), "Unknown reward material must be rejected")
	invalid = Micro.DATA.duplicate(true)
	invalid.profiles.marsh[0].coins = 100000
	check(not Micro.valid(invalid), "Cash rewards must remain bounded")
	for seed_value in [-9223372036854775807, 0, 9223372036854775807]:
		var id := "micro:7:%s:-4:8:fairy_ring" % seed_value
		check(Micro.fields(id).seed == seed_value, "Canonical micro IDs retain exact signed64 seed")
	check(Micro.fields("micro:7:-9223372036854775808:-4:8:fairy_ring").seed == -9223372036854775807 - 1, "Canonical micro IDs retain signed64 minimum without overflow")
	for id in ["micro:7:9223372036854775808:0:0:fairy_ring", "micro:7:0:4294967296:0:fairy_ring", "micro:6:0:0:0:fairy_ring", "micro:7:0:0:0:missing", "micro:7:0:+1:0:fairy_ring"]:
		check(Micro.fields(id).is_empty(), "Malformed or unsupported micro identity is rejected: " + id)
	var world := World.new()
	world.generate(91, 7)
	var examples := {}
	var wet_examples := 0
	var rejected := 0
	var seen := {}
	seed(478)
	var first := randi()
	var next := randi()
	seed(478)
	check(randi() == first, "Independent global RNG probe starts from the same state")
	var anchors: Dictionary = load("res://tools/biome_review_points.gd").find(world)
	anchors.coast.cell = Vector2i(-21516, -5152)
	for biome in anchors:
		var origin := Vector2i(floori(float(anchors[biome].cell.x) / 64), floori(float(anchors[biome].cell.y) / 64))
		var found := false
		for ring in range(65 if biome == "coast" else 9):
			for x in range(-ring, ring + 1):
				for y in range(-ring, ring + 1):
					if absi(x) == ring or absi(y) == ring:
						var feature := Composition.feature(world.run_seed, (origin + Vector2i(x, y)) * 64)
						if not Micro.profile_for(world.run_seed, feature.id, biome).is_empty() and world.biome_at(feature.center).biome_id == biome:
							seen[feature.id] = feature
				if examples.has(biome):
					break
			for feature in seen.values():
				var plan: Dictionary = Micro.plan(world, feature)
				if plan.is_empty():
					rejected += 1
					continue
				if plan.biome_id == biome:
					examples[biome] = plan
					found = true
					break
			if found:
				break
			seen.clear()
		seen.clear()
	for plan in examples.values():
		var feature := Composition.feature(world.run_seed, plan.center)
		check(plan == Micro.plan(world, feature), "Actual ground plan replays deterministically")
		check(Micro.fields(plan.id).profile_id == plan.profile_id, "Generated plan ID uses its authoritative profile")
		for point in [plan.center, plan.point, plan.approach]:
			var info := world.cell_info(point)
			var region := world.region_at(point)
			check(info.terrain == "land" and info.walkable and not world._natural_water(point), "Reward and approach stand on actual natural dry supported land")
			check(not world._road_at(point, region) and world.city_at(Vector2(point), 4).is_empty(), "Micro features keep actual roads and town approaches clear")
			check(not World.sites_in(region).any(func(site): return site.get("footprint", Rect2i(site.cell - Vector2i.ONE * 3, Vector2i.ONE * 7)).grow(2).has_point(point)), "Micro features keep authored sites and entrances clear")
		if plan.has("water_cell"):
			wet_examples += 1
			check(world._natural_water(plan.water_cell) and world.cell_info(plan.water_cell).terrain == "water", "Water micro recipes must have actual natural water, never invented water or bridges")
			check(Vector2(plan.water_cell).distance_to(Vector2(plan.center)) <= plan.radius, "Water habitat stays inside the named micro area")
	check(examples.size() == 14, "Actual edition7 natural plans must occur in all14 ecology profiles: " + str(examples.keys()))
	check(wet_examples > 0 and rejected > 0, "Actual terrain scan must exercise water eligibility and exclusions")
	check(randi() == next and world.run_seed == 91, "Plans cannot consume global or generation randomness")
	var fake := Composition.feature(91, world.start)
	fake.center = world.start
	check(Micro.plan(world, fake).is_empty(), "Forged feature center on town spawn is rejected")
	var legacy := World.new()
	legacy.generate(91, 6)
	check(Micro.plan(legacy, Composition.feature(91, legacy.start)).is_empty(), "Legacy worlds do not gain a new micro dressing contract")
	var hub_world = load("res://scripts/hub_world.gd").new()
	hub_world.generate(91, 7)
	check(not Micro.nature_world(hub_world, hub_world.hub.center), "Authored hub reservation is excluded")
	for plan in examples.values():
		check(Micro.plan(hub_world, Composition.feature(91, plan.center)) == plan, "HubWorld exterior preserves actual natural exploration plans")
	if failures.is_empty():
		var records := {}
		for biome in examples:
			var record: Dictionary = examples[biome].duplicate()
			for field in ["center", "point", "approach", "grid", "water_cell"]:
				if record.has(field):
					record[field] = [record[field].x, record[field].y]
			records[biome] = record
		DirAccess.make_dir_recursive_absolute("res://artifacts/micro-biomes")
		var file := FileAccess.open("res://artifacts/micro-biomes/plans-seed91.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"seed": 91, "edition": 7, "catalog_sha256": FileAccess.get_sha256(Micro.PATH), "examples": records}, "\t"))
	print("Micro biome checks: ", checks, " assertions, ", failures.size(), " failures, ", examples.size(), " actual ecologies, ", wet_examples, " wet plans")
	if failures.is_empty():
		print("PASS:28 reachable micro profiles, exact IDs/rewards, real protected edition7 ground, actual natural-water eligibility and deterministic replay")
	quit(0 if failures.is_empty() else 1)
