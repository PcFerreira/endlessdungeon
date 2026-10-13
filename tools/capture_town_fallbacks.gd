extends SceneTree

const Game = preload("res://scripts/game.gd")
const Fixtures = preload("res://tests/test_town_fallback_styles.gd")
var game

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-town-fallback-native-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.expansion.set_process_input(false)
	game.remove_child(game.world_view)
	game.world_view.queue_free()
	game.world_view = Fixtures.MissingView.new()
	game.world_view.architecture = Fixtures.MissingArchitecture.new()
	game.world_view.living_residents = true
	game.add_child(game.world_view)
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
	for biome in range(4):
		game._generate_surface(Vector2(cities[biome].cell) + Vector2(0, 3), false)
		game.state = "playing"
		game.surface_zoom = 19
		for yaw in [PI / 4, PI * 1.25]:
			game.camera_yaw = yaw
			game.target_yaw = yaw
			game._snap_camera()
			game.world_view.update_visibility(game.player_point, game.player_y, yaw)
			for frame in range(8):
				await process_frame
			RenderingServer.force_draw()
			assert(root.get_texture().get_image().save_png("res://artifacts/town-fallback-biome%s-camera%s.png" % [biome, int(yaw * 100)]) == OK)
	print("PASS: eight actual missing-resource town views, both families/all climates/opposing cameras at gameplay zoom")
	game.queue_free()
	await process_frame
	quit()
