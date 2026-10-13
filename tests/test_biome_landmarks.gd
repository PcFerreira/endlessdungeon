extends SceneTree

const World = preload("res://scripts/world.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const Micro = preload("res://scripts/micro_biome_catalog.gd")
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

func _worker_plans(examples: Dictionary, output: Dictionary) -> void:
	var Catalog = load("res://scripts/biome_landmark_catalog.gd")
	var world := World.new()
	world.generate(91, 7)
	var plans := {}
	for kind in examples:
		plans[kind] = Catalog.plan(world, Composition.feature(91, examples[kind].center))
	output.plans = plans
	output.cells = world.cells.size()
	output.chunks = world.chunks.size()

func run_checks() -> void:
	if not FileAccess.file_exists("res://scripts/biome_landmark_catalog.gd"):
		check(false, "Biome landmarks need a real blueprint catalogue and recursion-free planner")
		quit(1)
		return
	var Catalog = load("res://scripts/biome_landmark_catalog.gd")
	check(Catalog.valid(Catalog.DATA), "Landmark blueprint catalogue must validate")
	var reached := {}
	for biome in Catalog.DATA.biomes:
		for x in range(-96, 97):
			var feature_id := "%s:-7" % x
			var profile: Dictionary = Catalog.profile_for(91, feature_id, biome)
			check(profile == Catalog.profile_for(91, feature_id, biome), "Landmark profile selection must replay")
			if profile.is_empty():
				continue
			reached[profile.kind] = true
			check(not Micro._candidate(91, feature_id), "Every possible micro pocket retains its original feature")
			check(profile.size.x <= 7 and profile.size.y <= 7 and profile.body_height + profile.foundation_depth <= 8, "Landmark blueprint stays inside physical bounds")
			check(not profile.solid_local.has(profile.door_local), "Visible doorway must be physically clear")
			check(profile.interaction != "cache" or Forage.DATA.items.has(profile.reward_item), "Cache reward uses actual biome material")
	check(reached.size() == 8, "All eight archetypes are reachable from authored biome pools")
	var invalid: Dictionary = Catalog.DATA.duplicate(true)
	invalid.profiles.mage_tower.body_height = 8.1
	check(not Catalog.valid(invalid), "Oversized structures are rejected")
	invalid = Catalog.DATA.duplicate(true)
	invalid.profiles.watchtower.solid_local.append(invalid.profiles.watchtower.door_local)
	check(not Catalog.valid(invalid), "A blocked visible doorway is rejected")
	invalid = Catalog.DATA.duplicate(true)
	invalid.biomes.greenwood.reward_items[0] = "missing_material"
	check(not Catalog.valid(invalid), "Unknown landmark rewards are rejected")
	for seed_value in [-9223372036854775807, 0, 9223372036854775807]:
		check(Catalog.fields("landmark:7:%s:-4:8:monolith" % seed_value).seed == seed_value, "Landmark IDs preserve exact signed64 seed")
	check(Catalog.fields("landmark:7:-9223372036854775808:-4:8:well").seed == -9223372036854775807 - 1, "Landmark IDs preserve signed64 minimum")
	for id in ["landmark:7:9223372036854775808:0:0:well", "landmark:7:0:4294967296:0:well", "landmark:6:0:0:0:well", "landmark:7:0:+1:0:well", "landmark:7:0:0:0:missing"]:
		check(Catalog.fields(id).is_empty(), "Malformed/unsupported IDs are rejected before conversion")
	var world := World.new()
	world.generate(91, 7)
	var examples := {}
	var contexts := {}
	var rejected := 0
	var anchors: Dictionary = load("res://tools/biome_review_points.gd").find(world)
	seed(943)
	var first := randi()
	var next := randi()
	seed(943)
	check(randi() == first, "Independent RNG probe starts from the same state")
	for biome in anchors:
		var origin := Vector2i(floori(float(anchors[biome].cell.x) / 64), floori(float(anchors[biome].cell.y) / 64))
		for ring in range(14):
			for x in range(-ring, ring + 1):
				for y in range(-ring, ring + 1):
					if absi(x) != ring and absi(y) != ring:
						continue
					var feature := Composition.feature(91, (origin + Vector2i(x, y)) * 64)
					if not Catalog._candidate(91, feature.id):
						continue
					var ecology := world.biome_at(feature.center)
					var profile: Dictionary = Catalog.profile_for(91, feature.id, ecology.biome_id)
					if profile.is_empty() or examples.has(profile.kind):
						continue
					var plan: Dictionary = Catalog.plan(world, feature)
					if plan.is_empty():
						rejected += 1
						continue
					examples[plan.kind] = plan
					contexts[plan.biome_id] = true
				if examples.size() == 8:
					break
			if examples.size() == 8:
				break
		if examples.size() == 8:
			break
	for plan in examples.values():
		check(plan == Catalog.plan(world, Composition.feature(91, plan.center)), "Authoritative natural landmark plan must replay")
		check(Catalog.fields(plan.id).kind == plan.kind, "Plan identity and archetype agree")
		check(plan.footprint.has_point(plan.point) and not plan.solid_cells.has(plan.point), "Interaction point is inside the plot on an open cell")
		var minimum := INF
		var maximum := -INF
		for x in range(plan.footprint.position.x, plan.footprint.end.x):
			for y in range(plan.footprint.position.y, plan.footprint.end.y):
				var point := Vector2i(x, y)
				var region := world.region_at(point)
				var height := world._surface_height(point, region, false)
				minimum = minf(minimum, height)
				maximum = maxf(maximum, height)
				check(not world._natural_water(point) and not world._road_at(point, region), "Entire footprint must use actual dry offroad ground")
				check(world.city_at(Vector2(point), 4).is_empty() and not World.sites_in(region).any(func(site): return site.get("footprint", Rect2i(site.cell - Vector2i.ONE * 3, Vector2i.ONE * 7)).grow(2).has_point(point)), "Entire footprint keeps settlements and site margins clear")
		check(maximum - minimum <= .5 and is_equal_approx(plan.height, maximum), "Ground plateau derives from a supported half-step envelope")
		for point in [plan.door, plan.approach, plan.approach_far]:
			check(not plan.solid_cells.has(point) and not world._natural_water(point), "Three doorway and approach cells remain dry and clear")
			check(absf(world._surface_height(point, world.region_at(point), false) - plan.height) <= .5, "Actual entry path stays within a traversable half step")
	check(examples.size() == 8 and contexts.size() >= 2 and rejected > 0, "All eight kinds need actual mixed-biome terrain and exclusion proof: " + str(examples.keys()))
	check(randi() == next and world.run_seed == 91, "Planner cannot consume global or generation randomness")
	var hub = load("res://scripts/hub_world.gd").new()
	hub.generate(91, 7)
	for plan in examples.values():
		check(Catalog.plan(hub, Composition.feature(91, plan.center)) == plan, "Actual HubWorld exterior preserves natural landmark plans")
	var legacy := World.new()
	legacy.generate(91, 6)
	check(Catalog.plan(legacy, Composition.feature(91, legacy.start)).is_empty(), "Legacy world physical contracts remain excluded")
	check(Catalog.plan(hub, Composition.feature(91, hub.hub.center)).is_empty(), "Authored hub island excludes natural structures")
	var catalogue_before: Dictionary = Catalog.profiles.duplicate(true)
	var first_worker := {}
	var second_worker := {}
	var task_one := WorkerThreadPool.add_task(_worker_plans.bind(examples, first_worker), false, "landmark-plans-one")
	var task_two := WorkerThreadPool.add_task(_worker_plans.bind(examples, second_worker), false, "landmark-plans-two")
	WorkerThreadPool.wait_for_task_completion(task_one)
	WorkerThreadPool.wait_for_task_completion(task_two)
	check(first_worker.plans == examples and second_worker.plans == examples, "Two actual plain-data workers must reproduce every supported archetype")
	check(first_worker.cells == 0 and second_worker.cells == 0 and first_worker.chunks == 0 and second_worker.chunks == 0, "Plans must not build streamed cells or actors in worker tasks")
	check(Catalog.profiles == catalogue_before, "Workers cannot mutate shared blueprint profiles")
	if failures.is_empty():
		var records := {}
		for kind in examples:
			var record: Dictionary = examples[kind].duplicate(true)
			for field in ["size", "body_size", "body_center", "door_local", "center", "grid", "facing", "door", "point", "approach", "approach_far"]:
				record[field] = [record[field].x, record[field].y]
			for field in ["solid_local", "solid_cells"]:
				record[field] = record[field].map(func(cell): return [cell.x, cell.y])
			record.footprint = [record.footprint.position.x, record.footprint.position.y, record.footprint.size.x, record.footprint.size.y]
			records[kind] = record
		DirAccess.make_dir_recursive_absolute("res://artifacts/biome-landmarks")
		var file := FileAccess.open("res://artifacts/biome-landmarks/plans-seed91.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"seed": 91, "edition": 7, "catalog_sha256": FileAccess.get_sha256(Catalog.PATH), "examples": records}, "\t"))
	print("Landmark catalogue checks: ", checks, " assertions, ", failures.size(), " failures, ", examples.size(), " actual archetypes, ", contexts.size(), " ecologies")
	if failures.is_empty():
		print("PASS: eight typed blueprints, canonical IDs, preserved micro candidates, recursion-free real protected plots, supported doors and deterministic Hub exterior replay")
	quit(0 if failures.is_empty() else 1)
