extends SceneTree

const World = preload("res://scripts/world.gd")
const Life = preload("res://scripts/world_life.gd")
const Activity = preload("res://scripts/world_activity.gd")
const Inventory = preload("res://scripts/inventory.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var world := World.new()
	world.generate(12345)
	world.load_around(Vector2(world.start))
	var life := Life.new()
	life.reset(12345)
	life.sync(world, Vector2(world.start))
	var travelers: Array = life.residents().filter(func(actor): return actor.get("traveling", false))
	var guards: Array = life.residents().filter(func(actor): return actor.role == "guard")
	assert(not travelers.is_empty() and not guards.is_empty(), "Road travelers and town guards must stream naturally")
	var merchant: Dictionary = travelers.filter(func(actor): return actor.role == "merchant")[0]
	var first: Vector2 = merchant.point
	for index in range(300):
		life.advance(.1)
		life.step(world, Vector2(world.start) + Vector2(5,5), .1)
		assert(life.route_requests <= 1 and life.actors.size() <= Life.MAX_ACTORS)
		for actor in life.actors.values():
			assert(world.walkable(actor.point))
	assert(merchant.point.distance_to(first) > 2, "Travel must move physically along roads")
	assert(guards.any(func(actor): return actor.activity == "patrol" or actor.activity == "watch"))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
	assert(Life.valid_snapshot(saved))
	var restored := Life.new()
	assert(restored.restore(saved, 12345))
	restored.sync(world, Vector2(world.start))
	assert(restored.actors[merchant.id].point.is_equal_approx(merchant.point))
	var bad: Dictionary = saved.duplicate(true)
	bad.actors[merchant.id].point = [99999,0]
	assert(not Life.valid_snapshot(bad))
	bad = saved.duplicate(true)
	bad.actors[merchant.id].road_direction = 0
	assert(not Life.valid_snapshot(bad))
	var replay := Life.new()
	replay.reset(12345)
	replay.advance(life.tick * .5 + life.fraction)
	replay.sync(world, Vector2(world.start))
	var replay_again := Life.new()
	replay_again.reset(12345)
	replay_again.advance(life.tick * .5 + life.fraction)
	replay_again.sync(world, Vector2(world.start))
	assert(replay.snapshot() == replay_again.snapshot())
	var unobserved := Life.new()
	unobserved.reset(12345)
	unobserved.sync(world, Vector2(world.start))
	var old_point: Vector2 = unobserved.actors[merchant.id].point
	unobserved.advance(10)
	unobserved.sync(world, Vector2(world.start))
	assert(unobserved.actors[merchant.id].point.distance_to(old_point) > 1, "Unobserved travelers must continue with the world clock")
	var activity := Activity.new()
	assert(Activity.valid(activity.data))
	var invalid := activity.data.duplicate(true)
	invalid.travelers = [invalid.travelers[0]]
	assert(not Activity.valid(invalid))
	invalid = activity.data.duplicate(true)
	invalid.travelers[1].id = "merchant"
	assert(not Activity.valid(invalid))
	var extended := activity.data.duplicate(true)
	var new_role: Dictionary = extended.travelers[1].duplicate(true)
	new_role.id = "wandering_bard"
	extended.travelers.append(new_role)
	assert(Activity.valid(extended))
	var episodes := {}
	for cycle in range(8):
		for second in [4,40,110,150,221]:
			life.tick = (cycle * 240 + second) * 2
			var episode := life.event_at("city:0:0")
			episodes[episode.kind] = true
	assert(episodes.size() >= 8, "Town episodes need recurring content variations")
	var inventory := Inventory.new()
	var before := inventory.snapshot()
	activity.trade(inventory, merchant, "health_potion", "mage")
	assert(inventory.snapshot() == before)
	assert(inventory.add("ember_shard", 12))
	var count: int = inventory.count("health_potion")
	activity.trade(inventory, merchant, "health_potion", "mage")
	assert(inventory.count("health_potion") == count + 1 and inventory.count("ember_shard") == 9)
	activity.trade(inventory, merchant, "sanctum_sigil", "mage")
	assert(inventory.count("ember_shard") == 9)
	assert(inventory.add("oak_chair", 200) and inventory.slots_used() == inventory.CAPACITY)
	before = inventory.snapshot()
	activity.trade(inventory, merchant, "rune_lantern", "mage")
	assert(inventory.snapshot() == before, "Full-backpack barter must roll back its payment")
	var coins := Inventory.new()
	assert(coins.add("gold_coin", 12))
	var potion_count: int = coins.count("health_potion")
	activity.trade(coins, merchant, "health_potion", "mage", "gold_coin")
	assert(coins.count("health_potion") == potion_count + 1 and coins.count("gold_coin") == 8 and coins.count("ember_shard") == 0)
	assert(coins.add_owned("gold_coin","city:0:0","coin:test"))
	coins.remove("gold_coin",8)
	before = coins.snapshot()
	activity.trade(coins, merchant, "health_potion", "mage", "gold_coin")
	assert(coins.snapshot() == before, "Merchant payments cannot spend stolen coins")
	var habitats := {}
	for x in range(-5,6):
		for y in range(-5,6):
			var chunk: Dictionary = world._build_chunk(Vector2i(x,y))
			assert(chunk.spawns.size() <= 2)
			assert(chunk == world._build_chunk(Vector2i(x,y)))
			for spawn in chunk.spawns:
				assert(spawn.has("area_id") and spawn.has("home") and spawn.has("radius"))
				assert(Vector2(spawn.cell).distance_to(spawn.home) <= spawn.radius)
				assert(chunk.cells[spawn.cell].terrain == "land")
				habitats[spawn.area_id] = true
	assert(habitats.size() > 6)
	world.load_around(Vector2(-96,35))
	life.sync(world, Vector2(-96,35))
	assert(Life.valid_snapshot(JSON.parse_string(JSON.stringify(life.snapshot()))))
	print("PASS: natural road travelers/merchants, moving guards, deterministic varied episodes, bounded routes, canonical travel saves, transactional barter and clustered monster habitats")
	quit()
