extends SceneTree

const Game = preload("res://scripts/game.gd")
const Cache = preload("res://scripts/render_cache.gd")
var game
var samples := []
var directory := "user://stream-profile-%s" % Time.get_ticks_usec()

func inputs() -> Dictionary:
	var result := {}
	for path in ["res://scripts/game.gd", "res://scripts/world.gd", "res://scripts/world_view.gd", "res://scripts/streaming_data.gd", "res://scripts/site_planner.gd", "res://scripts/road_routes.gd", "res://scripts/surface_location_view.gd", "res://scripts/enemy_models.gd", "res://scripts/foraging.gd", "res://scripts/forage_catalog.gd", "res://config/foraging.json", "res://config/environment_styles.json", "res://config/world_activity.json", "res://assets/render_cache/catalog.json", "res://assets/landmark_cache/catalog.json"]:
		if FileAccess.file_exists(path):
			result[path] = FileAccess.get_sha256(path)
	return result

func _initialize() -> void:
	call_deferred("profile")

func timed(action: Callable) -> float:
	var start := Time.get_ticks_usec()
	action.call()
	return (Time.get_ticks_usec() - start) / 1000.0

func profile() -> void:
	var source_inputs := inputs()
	Cache.enabled = not "--baseline" in OS.get_cmdline_user_args()
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345, game.World.NEW_JOURNEY_EDITION)
	game.has_journey = true
	game.world_view.measure_preparation = true
	if DisplayServer.get_name() != "headless":
		for frame in range(12):
			await RenderingServer.frame_post_draw
	var origin: Vector2 = game.player_point
	for index in range(1, 21):
		var point := origin + Vector2(index * 16, 0)
		var sample := {"index":index, "point":[point.x, point.y]}
		if "--prefetch" in OS.get_cmdline_user_args():
			game.player_point = point - Vector2(2, 0)
			var start := Time.get_ticks_usec()
			var prepare_peak := 0.0
			for attempt in range(300):
				prepare_peak = maxf(prepare_peak, timed(func(): game._preload_surface(Vector2.RIGHT)))
				if game.prefetched_chunks.size() >= 5 and game.prefetched_chunks.keys().all(func(coordinate): return game.world.chunks.has(coordinate) or game.world_view.prepared_nodes.has(coordinate)):
					break
				await create_timer(.005).timeout
			sample.prefetch_wait_ms = (Time.get_ticks_usec() - start) / 1000.0
			sample.prepare_peak_ms = prepare_peak
			sample.preparation_spikes = game.world_view.preparation_spikes.duplicate()
			game.world_view.preparation_spikes.clear()
		game.player_point = point
		sample.generate_ms = timed(func(): game._take_preloaded_surface(); game.world.load_around(point))
		game.player_point = point
		var coordinate: Vector2i = game.World.chunk_at(point)
		for cell in game.world.chunks[coordinate].cells:
			if game.world.walkable(Vector2(cell)) and game.World.chunk_at(Vector2(cell)) == coordinate:
				game.player_point = Vector2(cell)
				break
		sample.view_ms = timed(func(): game.world_view.sync(game.world))
		sample.items_ms = timed(func(): game.world_items.register_location())
		sample.life_ms = timed(func(): game.life.sync(game.world, game.player_point))
		sample.navigation_ms = timed(func(): game._rebuild_navigation() if "--baseline" in OS.get_cmdline_user_args() else game._stream_navigation())
		sample.enemies_ms = timed(func(): game._sync_surface_enemies())
		sample.life_view_ms = timed(func(): game.life_view.sync(game))
		sample.forage_ms = timed(func(): game.foraging.sync())
		sample.tick_ms = timed(func(): game.simulate(1.0 / 60))
		game._snap_camera()
		if DisplayServer.get_name() != "headless":
			var frame_start := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			sample.post_draw_wait_ms = (Time.get_ticks_usec() - frame_start) / 1000.0
			sample.process_frame_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
			if "--capture" in OS.get_cmdline_user_args() and index in [1, 7, 13, 20]:
				DirAccess.make_dir_recursive_absolute("res://artifacts/streaming")
				root.get_viewport().get_texture().get_image().save_png("res://artifacts/streaming/native-crossing-%02d.png" % index)
		sample.terrain_cache = game.world_view.terrain_meshes.size()
		sample.nodes = game.world_view.find_children("*", "", true, false).size()
		samples.append(sample)
		print("STREAM_SAMPLE: " + JSON.stringify(sample))
		await process_frame
	var output := "res://artifacts/streaming/profile-%s.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":OS.get_name(), "renderer":DisplayServer.get_name(), "edition":game.world.generator_version, "seed":12345, "inputs":source_inputs, "inputs_after":inputs(), "samples":samples}, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	for path in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(path))
	DirAccess.remove_absolute(directory)
	print("PROFILE: " + ProjectSettings.globalize_path(output))
	print("PASS: measured actual field streaming stages with isolated settings/saves")
	quit()
