extends SceneTree

const World = preload("res://scripts/world.gd")
const Catalog = preload("res://scripts/biome_landmark_catalog.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const Micro = preload("res://scripts/micro_biome_catalog.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		if failures.size() <= 30:
			print("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run_checks")

func _worker_cells(examples: Dictionary, output: Dictionary) -> void:
	var world := World.new()
	world.generate(91, 7)
	var records := {}
	for plan in examples.values():
		var points: Array[Vector2i] = []
		for x in range(plan.footprint.position.x, plan.footprint.end.x):
			for y in range(plan.footprint.position.y, plan.footprint.end.y):
				points.append(Vector2i(x, y))
		points.append_array([plan.door, plan.approach, plan.approach_far])
		for cell in points:
			records[cell] = world.cell_info(cell)
	output.records = records

func run_checks() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/biome-landmarks/plans-seed91.json"))
	var world := World.new()
	world.generate(91, 7)
	var examples := {}
	var expected := {}
	var crossing := 0
	for record in document.examples.values():
		var center := Vector2i(record.center[0], record.center[1])
		var plan := Catalog.plan(world, Composition.feature(91, center))
		check(not plan.is_empty() and plan.kind == record.kind, "Accepted actual archetype must reconstruct: " + record.kind)
		if plan.is_empty():
			continue
		examples[plan.kind] = plan
		world.load_around(Vector2(center))
		for x in range(plan.footprint.position.x, plan.footprint.end.x):
			for y in range(plan.footprint.position.y, plan.footprint.end.y):
				var cell := Vector2i(x, y)
				var info := world.cell_info(cell)
				expected[cell] = info
				check(info.get("landmark_id", "") == plan.id and info.get("landmark_kind", "") == plan.kind, "Actual generated plot identifies its landmark: " + plan.kind)
				check(info.terrain == "paving" and info.prop.is_empty() and info.detail.is_empty(), "Entire physical plot clears natural flora and uses paving: " + plan.kind)
				check(is_equal_approx(info.height, plan.height), "Entire physical plot uses the supported maximum plateau: " + plan.kind)
				check(info.walkable == not plan.solid_cells.has(cell), "Cell collision matches exact blueprint mask: " + plan.kind)
				check(world.walkable(Vector2(cell)) == info.walkable, "Streamed navigation matches generated landmark collision")
				crossing += int(World.chunk_at(Vector2(cell)) != World.chunk_at(Vector2(center)))
		for cell in [plan.door, plan.approach, plan.approach_far]:
			var info := world.cell_info(cell)
			expected[cell] = info
			check(info.walkable and info.prop.is_empty() and info.detail.is_empty(), "Door and both approach steps are physically clear: " + plan.kind)
			if not plan.footprint.has_point(cell):
				check(is_equal_approx(info.height, world._surface_height(cell, world.region_at(cell), false)), "Outside approach retains its raw supported floor")
		var moved := world.move_actor(Vector2(plan.approach_far), Vector2(plan.door - plan.approach_far))
		check(moved.distance_to(Vector2(plan.door)) < .01, "Real movement reaches the open doorway: " + plan.kind)
		var wall_tested := false
		for solid in plan.solid_cells:
			check(not world.walkable(Vector2(solid)), "Actual structural cell blocks the actor: " + plan.kind)
			if wall_tested:
				continue
			for direction in World.DIRECTIONS:
				var open: Vector2i = solid + direction
				if plan.footprint.has_point(open) and world.walkable(Vector2(open)):
					var against := world.move_actor(Vector2(open), Vector2(solid - open))
					check(against.distance_to(Vector2(solid)) > .5, "Real movement cannot enter a visible structural wall: " + plan.kind)
					wall_tested = true
					break
		check(wall_tested, "Every landmark has an actual reachable wall edge")
		var rebuilt := world._build_chunk(World.chunk_at(Vector2(center)))
		for cell in rebuilt.cells:
			if expected.has(cell):
				check(rebuilt.cells[cell] == expected[cell], "Actual chunk generation matches direct plan cells")
	check(examples.size() == 8 and crossing > 0, "All eight physical structures include negative chunk-boundary coverage")
	var first_worker := {}
	var second_worker := {}
	var first_task := WorkerThreadPool.add_task(_worker_cells.bind(examples, first_worker), false, "landmark-world-one")
	var second_task := WorkerThreadPool.add_task(_worker_cells.bind(examples, second_worker), false, "landmark-world-two")
	WorkerThreadPool.wait_for_task_completion(first_task)
	WorkerThreadPool.wait_for_task_completion(second_task)
	check(first_worker.records == expected and second_worker.records == expected, "Separate actual generation workers reproduce physical landmark records")
	if world.has_method("_landmark_plan"):
		for x in range(50):
			world._landmark_plan(Composition.feature(91, Vector2i(x * 64, 0)))
		check(world.landmark_plans.size() <= 32, "Landmark plan cache stays bounded after unrelated feature queries")
		world.generate(12345, 7)
		check(world.landmark_plans.is_empty(), "Generating another seed clears cached landmark identities")
	else:
		check(false, "World must expose a bounded physical landmark plan cache")
	var hub = load("res://scripts/hub_world.gd").new()
	hub.generate(91, 7)
	for cell in expected:
		check(hub.cell_info(cell) == expected[cell], "Actual fresh HubWorld exterior keeps the same physical landmark cells")
	var legacy := World.new()
	legacy.generate(91, 6)
	for plan in examples.values():
		check(not legacy.cell_info(plan.point).has("landmark_id"), "Legacy edition6 has no landmark metadata or new blockers")
	var micro_examples: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/micro-biomes/plans-seed91.json")).examples
	world.generate(91, 7)
	for record in micro_examples.values():
		var center := Vector2i(record.center[0], record.center[1])
		var plan := Micro.plan(world, Composition.feature(91, center))
		check(not plan.is_empty() and plan.id == record.id, "Every accepted micro pocket retains its identity and safe approach")
		check(world.cell_info(center).get("landmark_id", "").is_empty(), "Physical structures never replace an accepted micro feature")
	print("Landmark physical checks: ", checks, " assertions, ", failures.size(), " failures, ", examples.size(), " archetypes, ", crossing, " crossing cells")
	if failures.is_empty():
		print("PASS: eight actual flat landmark plots, exact solids/open doors, real actor movement, independent workers, chunk boundaries, bounded cache and preserved legacy/micro contracts")
	quit(0 if failures.is_empty() else 1)
