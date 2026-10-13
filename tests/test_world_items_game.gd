extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-world-items-%s" % Time.get_ticks_usec()

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func _initialize() -> void:
	call_deferred("checks")

func placement_point(game, item: String) -> Vector2:
	for x in range(-4, 5):
		for y in range(-4, 5):
			var point: Vector2 = game.player_point + Vector2(x, y)
			if game.world_items.placement(item, point, 0).problem.is_empty():
				return point
	return Vector2.INF

func checks() -> void:
	var game = fresh()
	game.start_run(12345)
	game._clear_actors()
	var city: Dictionary = game.world.region_at(game.world.start).city
	var building: Dictionary = game.interiors.describe(city, city.houses[0])
	game._generate_surface(building.approach)
	assert(game.interiors.enter(game.interiors.target()))
	assert(not game.world_items.registered.is_empty(), "Actual interior dressing exposes portable models")
	var original: Dictionary = game.world_items.registered.values()[0].record
	game.player_point = game.dungeon.safe_position(game.world_items.position(original))
	var random_before: int = game.rng.state
	assert(game.world_items.pickup(original.uid))
	assert(game.inventory.stolen_count(original.item) == 1 and game.world_items.wanted(city.id).count == 1)
	assert(not game.world_items.registered[original.uid].node.visible)
	assert(game.rng.state == random_before)
	assert(game.save_game(1))
	var snapshot: Dictionary = game.make_save_data()
	assert(game.saves.validate(snapshot))
	var forged: Dictionary = snapshot.duplicate(true)
	forged.inventory.stolen.clear()
	assert(not game.saves.validate(forged), "Ownership cannot disappear from the backpack")
	var loaded = fresh()
	assert(loaded.load_game(1) and loaded.inventory.stolen_count(original.item) == 1)
	assert(not loaded.world_items.registered[original.uid].node.visible)
	assert(loaded.world_items.return_stolen(city.id) and loaded.world_items.registered[original.uid].node.visible)
	assert(loaded.inventory.count(original.item) == 0 and loaded.world_items.wanted(city.id).is_empty())
	assert(loaded.interiors.leave())
	assert(loaded.inventory.add("health_potion"))
	var point := placement_point(loaded, "health_potion")
	assert(point != Vector2.INF and loaded.world_items.place("health_potion", point))
	var uid: String = loaded.world_items.state.placed[0].uid
	var amount: int = loaded.inventory.count("health_potion")
	var away: Vector2 = loaded.player_point
	assert(loaded.use_sanctum_sigil())
	assert(loaded.inventory.add("ember_shard"))
	assert(loaded.world_items.place("ember_shard", Vector2(8, 12)))
	assert(loaded.leave_sanctum() and loaded.player_point.is_equal_approx(away))
	assert(loaded.world_items.state.placed.size() == 2 and loaded.world_items.placed_nodes.has(uid))
	loaded.player_point = point + Vector2(.6, 0)
	assert(loaded.world_items.pickup(uid) and loaded.inventory.count("health_potion") == amount + 1)
	var site: Dictionary = loaded.world.region_at(loaded.world.start).dungeons[0]
	loaded.enter_dungeon(site)
	assert(not loaded.world_items.claim_base())
	for floor_number in range(1, site.floors + 1):
		assert(loaded.depth == floor_number)
		for enemy in loaded.enemies.duplicate():
			loaded._hit_enemy(enemy, 100000)
		loaded.player_point = Vector2(loaded.dungeon.exit) + Vector2.DOWN * .8
		loaded.interact()
	assert(loaded.claimed_chests.has(site.id))
	for cell in loaded.dungeon.tiles:
		if loaded.dungeon.walkable(Vector2(cell)) and Vector2(cell).distance_to(loaded.dungeon.start) > 3 and Vector2(cell).distance_to(loaded.dungeon.exit) > 3:
			loaded.player_point = Vector2(cell)
			break
	assert(loaded.world_items.claim_base())
	assert(loaded.world_items.set_rest_point())
	var rest: Vector2 = loaded.player_point
	loaded.hp = 1
	loaded.mana = 0
	loaded.interact()
	assert(loaded.hp == loaded.max_hp and loaded.mana == loaded.max_mana)
	assert(loaded.inventory.add("oak_chair"))
	point = placement_point(loaded, "oak_chair")
	assert(point != Vector2.INF and loaded.world_items.place("oak_chair", point))
	assert(not loaded.dungeon.walkable(point))
	assert(loaded.save_game(2))
	var resumed = fresh()
	assert(resumed.load_game(2) and resumed.world_items.state.bases.has(site.id))
	assert(not resumed.dungeon.walkable(point) and resumed.world_items.rest_hint() == "E: Rest at your base")
	resumed.return_to_surface()
	resumed.hp = 0
	resumed.state = "dead"
	resumed.respawn()
	assert(resumed.layer == "dungeon" and resumed.player_point.is_equal_approx(rest))
	assert(resumed.enemies.is_empty() and not resumed.dungeon.walkable(point))
	if site.floors > 1:
		assert(resumed.world_items.visit_base_floor(1) and resumed.depth == 1 and resumed.enemies.is_empty())
		assert(resumed.world_items.visit_base_floor(site.floors) and not resumed.dungeon.walkable(point))
	var legacy: Dictionary = resumed.make_save_data()
	legacy.progress.erase("world_items")
	legacy.inventory.erase("stolen")
	assert(resumed.saves.validate(legacy) and resumed.Journey.restore(resumed, legacy))
	assert(resumed.world_items.state.placed.is_empty() and resumed.world_items.state.bases.is_empty())
	for node in [game, loaded, resumed]:
		node.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: actual city props and theft disk reload, anti-laundering validation, world/Sanctum carry, all-floor clearing, furniture collision, saved base/rest/respawn, floor revisits and legacy optional defaults")
	quit()
