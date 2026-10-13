extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-interior-styles-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func run() -> void:
	var game = fresh()
	game.start_run(12345)
	game.begin_journey()
	var cities := {}
	for x in range(-24, 25, 3):
		for y in range(-24, 25, 3):
			var region: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE)
			var city: Dictionary = region.get("city", {})
			if not city.is_empty() and not cities.has(city.biome):
				cities[city.biome] = city
			if cities.size() == 4:
				break
		if cities.size() == 4:
			break
	assert(cities.size() == 4, "Find an actual generated town in every biome")
	for biome in range(4):
		var city: Dictionary = cities[biome]
		var places: Array = city.houses.map(func(house): return game.interiors.describe(city, house))
		var place: Dictionary = places.filter(func(candidate): return candidate.type in ["shop", "workshop"])[0]
		game._generate_surface(place.approach)
		game._clear_actors()
		game.state = "playing"
		assert(game.interiors.enter(game.interiors.target()), "Enter the actual styled business through its real door")
		assert(game.dungeon.biome == biome and game.interiors.view.biome == biome)
		assert(game.dungeon.walkable(game.stores.sources()[0].point), "Purposeful dressing must retain the real trading approach")
		var child := {}
		for entry in game.world_items.registered.values():
			var record: Dictionary = entry.record
			assert(record.visual_family == game.interiors.view.visual_family and game.interiors.view.styles.allows(record.model_id, biome))
			if not record.parent.is_empty() and not game.world_items.has_children(record.uid):
				child = record
		assert(not child.is_empty() and game.world_items.registered.has(child.parent), "Actual interior materials need registered real support links")
		var support: Dictionary = game.world_items.registered[child.parent].record
		game.player_point = game.dungeon.safe_position(game.world_items.position(support))
		assert(not game.world_items.pickup(support.uid), "Supports cannot be taken while their materials remain")
		game.player_point = game.dungeon.safe_position(game.world_items.position(child))
		assert(game.world_items.pickup(child.uid))
		assert(game.inventory.stolen_count(child.item) == 1 and not game.world_items.registered[child.uid].node.visible)
		var random_before: int = game.rng.state
		assert(game.save_game(1), game.menu_notice)
		game.queue_free()
		await process_frame
		game = fresh()
		assert(game.load_game(1) and game.layer == "interior")
		assert(game.interiors.current.id == place.id and game.dungeon.biome == biome and game.rng.state == random_before)
		assert(game.world_items.registered.has(child.uid) and not game.world_items.registered[child.uid].node.visible)
		assert(game.inventory.stolen_count(child.item) == 1 and game.world_items.registered[child.parent].node.visible)
		assert(game.world_items.return_stolen(city.id))
		assert(game.world_items.registered[child.uid].node.visible and game.inventory.stolen_count(child.item) == 0)
		game.state = "playing"
		assert(game.use_sanctum_sigil() and game.leave_sanctum() and game.dungeon.biome == biome)
		assert(game.interiors.leave() and game.player_point.is_equal_approx(place.approach))
	print("PASS: real businesses in four climates; family/support descriptors, protected trading, top-first theft, fresh-scene masks/RNG, restitution, Sanctum and exact outside return")
	game.queue_free()
	await process_frame
	quit()
