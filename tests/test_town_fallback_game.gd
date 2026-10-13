extends SceneTree

const Game = preload("res://scripts/game.gd")
const Fixtures = preload("res://tests/test_town_fallback_styles.gd")
var directory := "user://test-town-fallback-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.remove_child(game.world_view)
	game.world_view.queue_free()
	game.world_view = Fixtures.MissingView.new()
	game.world_view.architecture = Fixtures.MissingArchitecture.new()
	game.world_view.living_residents = true
	game.add_child(game.world_view)
	return game

func verify(game, city: Dictionary) -> Dictionary:
	var result := {}
	for node in game.world_view.find_children("*", "MeshInstance3D", true, false):
		if not node.has_meta("fallback_role"):
			continue
		assert(game.world_view.construction.catalog.styles.allows(node.get_meta("render_asset"), city.biome))
		result[node.get_meta("source_uid")] = [node.get_meta("render_asset"), node.get_meta("render_height")]
	assert(result.size() == city.houses.size() + city.outdoor_lots.size() + 1)
	return result

func run() -> void:
	var game = fresh()
	game.start_run(12345)
	game.begin_journey()
	var cities := {}
	for x in range(-12, 13):
		for y in range(-12, 13):
			var city: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE).city
			if not cities.has(city.biome):
				cities[city.biome] = city
			if cities.size() == 4:
				break
		if cities.size() == 4:
			break
	assert(cities.size() == 4)
	for biome in range(4):
		var city: Dictionary = cities[biome]
		game._generate_surface(Vector2(city.cell) + Vector2(0, 3), false)
		var identity := verify(game, city)
		var house: Dictionary = city.houses.filter(func(entry): return entry.interior_type == "shop")[0]
		var target: Dictionary = game.interiors.describe(city, house)
		game._generate_surface(target.approach, false)
		game.interact()
		assert(game.layer == "interior")
		game.interiors.leave()
		assert(game.player_point.is_equal_approx(target.approach))
		var random_before: int = game.rng.state
		assert(game.save_game(1))
		game.queue_free()
		await process_frame
		game = fresh()
		assert(game.load_game(1) and game.rng.state == random_before)
		assert(verify(game, game.world.region_at(city.cell).city) == identity)
	print("PASS: forced missing-resource towns in all climates, actual streamed family/height/source IDs, real business entry/exit, fresh-scene disk and combat RNG")
	game.queue_free()
	await process_frame
	quit()
