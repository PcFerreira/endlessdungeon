extends SceneTree

const Law = preload("res://scripts/city_law.gd")
const Life = preload("res://scripts/world_life.gd")
const World = preload("res://scripts/world.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var law := Law.new()
	root.add_child(law)
	assert(Law.valid_config(law.config))
	var invalid := law.config.duplicate(true)
	invalid.pursuit_radius = 1000
	assert(not Law.valid_config(invalid))
	invalid = law.config.duplicate(true)
	invalid.damage = NAN
	assert(not Law.valid_config(invalid))
	var world := World.new()
	world.generate(12345)
	world.load_around(Vector2(world.start))
	var life := Life.new()
	life.reset(12345)
	life.sync(world, Vector2(world.start))
	var guard: Dictionary = life.residents().filter(func(actor): return actor.role == "guard")[0]
	var player := Vector2(world.region_at(world.start).city.cell) + Vector2(1,8)
	var claim := {"city_id":guard.city_id,"count":1,"hostile":false}
	assert(law.mode(guard, {}, player) == "patrol")
	assert(law.mode(guard, claim, player) == "guard_demand", "The watch must demand restitution before hostility")
	claim.hostile = true
	assert(law.mode(guard, claim, player) == "guard_pursuit")
	guard.law_mode = "guard_pursuit"
	assert(law.mode(guard, claim, guard.origin + Vector2(40,0)) == "guard_return")
	guard.law_mode = "guard_pursuit"
	assert(law.mode(guard, {}, player) == "guard_return")
	var first: Vector2 = guard.point
	for index in range(120):
		life.advance(.1)
		law.direct(world, guard, "guard_pursuit", player)
		life.step(world, player, .1)
		assert(world.walkable(guard.point) and guard.point.distance_to(guard.origin) <= 20)
		assert(life.route_requests <= 1)
	assert(guard.point.distance_to(first) > 2, "Hostile guards must physically pursue")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
	assert(Life.valid_snapshot(snapshot), "Guard pursuit paths must be valid save records")
	var restored := Life.new()
	assert(restored.restore(snapshot, 12345))
	restored.sync(world, Vector2(world.start))
	assert(restored.actors[guard.id].point.is_equal_approx(guard.point))
	var bad := snapshot.duplicate(true)
	bad.actors[guard.id].path = [[99999,99999]]
	assert(not Life.valid_snapshot(bad))
	bad = snapshot.duplicate(true)
	bad.actors[guard.id].law_windup_tick = bad.tick + 1000
	assert(not Life.valid_snapshot(bad))
	for index in range(160):
		life.advance(.1)
		var mode: String = law.mode(guard, {}, player)
		law.direct(world, guard, mode, player)
		life.step(world, player + Vector2(10,0), .1)
	assert(guard.law_mode == "patrol", "Cleared guards must return to their ordinary patrol")
	law.free()
	print("PASS: demand-first guard decisions, bounded physical pursuit, restitution return, one-route work budget, validated pursuit saves and rejected corrupt attack/path fields")
	quit()
