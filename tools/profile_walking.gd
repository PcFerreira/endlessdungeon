extends SceneTree

class MeasuredGame extends "res://scripts/game.gd":
	var costs := {}
	var walking_heading := Vector2.ZERO
	func measure(key: String, action: Callable) -> void:
		var start := Time.get_ticks_usec()
		action.call()
		costs[key] = costs.get(key, 0.0) + (Time.get_ticks_usec() - start) / 1000.0
	func _process(delta: float) -> void:
		measure("game_process_ms", func(): super._process(delta))
	func _physics_process(delta: float) -> void:
		if render_warmup.busy:
			return
		measure("physics_ms", func():
			player_point = dungeon.move_actor(player_point, walking_heading * 3.8 * delta, player_y, not grounded)
			move_heading = walking_heading
			aim = walking_heading
			simulate(delta)
			player_mesh.animate(walking_heading.length() > 0, grounded)
			player_mesh.position.y = 0 if player_mesh.rigged else sin(time * 11) * .035)
	func _refresh_surface() -> void:
		measure("refresh_surface_ms", func():
			if not _surface_stream_ready():
				costs["deferred_ring"] = true
				return
			measure("chunk_install_ms", func(): _take_preloaded_surface())
			var start := Time.get_ticks_usec()
			var changed: bool = world.load_around(player_point)
			costs["chunk_data_ms"] = costs.get("chunk_data_ms", 0.0) + (Time.get_ticks_usec() - start) / 1000.0
			if changed:
				measure("chunk_visual_ms", func(): world_view.sync(world))
				measure("chunk_items_ms", func(): world_items.register_location())
				if not floating_hub.active() and not dimension.active:
					measure("chunk_life_ms", func(): life.sync(world, player_point))
				measure("chunk_nav_ms", _stream_navigation)
				measure("chunk_enemies_ms", _sync_surface_enemies))
	func _preload_surface(direction: Vector2) -> void:
		measure("preload_ms", func(): super._preload_surface(walking_heading if walking_heading != Vector2.ZERO else direction))
	func _prepare_surface_enemies(coordinates: Array) -> void:
		var before := prepared_enemy_models.keys()
		measure("enemy_prepare_ms", func(): super._prepare_surface_enemies(coordinates))
		if costs.enemy_prepare_ms > 20:
			for id in prepared_enemy_models:
				if id not in before:
					costs.slow_enemy_asset = prepared_enemy_models[id].model.get_meta("asset_id", "")
	func location_name() -> String:
		var start := Time.get_ticks_usec()
		var value := super.location_name()
		costs["location_name_ms"] = costs.get("location_name_ms", 0.0) + (Time.get_ticks_usec() - start) / 1000.0
		return value

class MeasuredStreaming extends "res://scripts/streaming_data.gd":
	var take_ms := 0.0
	func take(token: int, regions: Dictionary = {}, seed_value = null, edition: int = 0, world = null) -> Dictionary:
		var start := Time.get_ticks_usec()
		var result := super.take(token, regions, seed_value, edition, world)
		take_ms += (Time.get_ticks_usec() - start) / 1000.0
		return result

class MeasuredMap extends "res://scripts/minimap.gd":
	var costs := {}
	func prepare_chart(center: Vector2i, span: int) -> void:
		var start := Time.get_ticks_usec()
		super.prepare_chart(center, span)
		costs["chart_ms"] = costs.get("chart_ms", 0.0) + (Time.get_ticks_usec() - start) / 1000.0
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		costs["map_draw_ms"] = costs.get("map_draw_ms", 0.0) + (Time.get_ticks_usec() - start) / 1000.0

var game
var map
var directory := "user://walking-profile-%s" % Time.get_ticks_usec()
var sources: Dictionary
var samples := []
var path := PackedVector2Array()
var frame_start := 0
var draw_start := 0

func before_draw() -> void:
	draw_start = Time.get_ticks_usec()
	game.costs["scene_process_ms"] = (draw_start - frame_start) / 1000.0

func after_draw() -> void:
	game.costs["render_submit_wait_ms"] = (Time.get_ticks_usec() - draw_start) / 1000.0
	game.costs["render_setup_ms"] = RenderingServer.get_frame_setup_time_cpu()
	game.costs["viewport_render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
	game.costs["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)

func walking_direction() -> Vector2:
	while not path.is_empty() and path[0].distance_to(game.player_point) < .12:
		path.remove_at(0)
	if path.is_empty():
		var from: int = game.astar.get_closest_point(game.player_point)
		var choices: Array = game.navigation_ids.keys()
		choices.sort_custom(func(a,b): return a.x > b.x)
		for cell in choices:
			if Vector2(cell).distance_to(game.player_point) < 20:
				continue
			path = game.astar.get_point_path(from, game.navigation_ids[cell])
			if path.size() > 2:
				path.remove_at(0)
				break
	return game.player_point.direction_to(path[0]) if not path.is_empty() else Vector2.ZERO

func inputs(paths: Array = []) -> Dictionary:
	var result := {}
	if not paths.is_empty():
		for path in paths:
			result[path] = FileAccess.get_sha256(path)
		return result
	for folder in ["scripts", "config"]:
		for name in DirAccess.get_files_at("res://" + folder):
			if name.get_extension() in ["gd", "json"]:
				var path: String = "res://" + folder + "/" + name
				if folder == "config" or ResourceLoader.has_cached(path):
					result[path] = FileAccess.get_sha256(path)
	result["res://tools/profile_walking.gd"] = FileAccess.get_sha256("res://tools/profile_walking.gd")
	return result

func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	else:
		root.size = Vector2i(1280, 800)
		root.show()
		DisplayServer.window_move_to_foreground()
		print("WALK_WINDOW visible=%s drawable=%s render_loop=%s" % [root.visible, DisplayServer.window_can_draw(), RenderingServer.is_render_loop_enabled()])
	sources = inputs()
	game = MeasuredGame.new()
	game.streaming_data = MeasuredStreaming.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	game.render_warmup.enabled = not "--no-warmup" in OS.get_cmdline_user_args()
	game.world_view.fuse_terrain = not "--terrain-batches" in OS.get_cmdline_user_args()
	game.world_view.measure_preparation = true
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.set_physics_process(false)
	game.start_run(12345, game.World.NEW_JOURNEY_EDITION)
	if not "--plain-world" in OS.get_cmdline_user_args():
		game.has_journey = false
		game.state = "title"
		game.begin_journey()
		if not await settle_loading():
			await finish(1)
			return
		game.player_point = game.world.hub.portal
		game._snap_camera()
		assert(game.floating_hub.target().kind == "depart" and game.floating_hub.interact())
		if not await settle_loading():
			await finish(1)
			return
	game.has_journey = true
	game._generate_surface(game.player_point + Vector2(80, 0))
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		RenderingServer.frame_pre_draw.connect(before_draw)
		RenderingServer.frame_post_draw.connect(after_draw)
	for node in game.interface.find_children("*", "Control", true, false):
		if node.get_script() == game.interface.Minimap:
			node.set_script(MeasuredMap)
			node.game = game
			map = node
			break
	assert(map != null)
	if "--no-map" in OS.get_cmdline_user_args():
		map.hide()
		map.set_process(false)
	if not await settle_loading():
		await finish(1)
		return
	for frame in range(30):
		await process_frame
	game._snap_camera()
	game.set_physics_process(true)
	var previous := Time.get_ticks_usec()
	game.costs.clear()
	map.costs.clear()
	frame_start = previous
	var origin: Vector2 = game.player_point
	var frame_count := 1200
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="):
			frame_count = argument.trim_prefix("--frames=").to_int()
	for frame in range(frame_count):
		await process_frame
		var now := Time.get_ticks_usec()
		var sample := {"frame":frame, "wall_ms":(now - previous) / 1000.0, "process_ms":Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "point":[game.player_point.x,game.player_point.y], "chunk":str(game.world.chunk_at(game.player_point)), "state":game.state}
		previous = now
		sample.merge(game.costs)
		sample.merge(map.costs)
		sample.worker_take_ms = game.streaming_data.take_ms
		game.streaming_data.take_ms = 0.0
		if not game.world_view.preparation_spikes.is_empty():
			sample.preparation_spikes = game.world_view.preparation_spikes.duplicate()
			game.world_view.preparation_spikes.clear()
		game.costs.clear()
		frame_start = Time.get_ticks_usec()
		map.costs.clear()
		samples.append(sample)
		game.walking_heading = walking_direction()
		game.hp = game.max_hp
		if frame % 300 == 0:
			print("WALK_FRAME %s distance=%.1f" % [frame, game.player_point.distance_to(origin)])
	game.walking_heading = Vector2.ZERO
	var after := inputs(sources.keys())
	var stable := sources == after
	for path in inputs():
		if path.ends_with(".gd") and not sources.has(path):
			stable = false
	var moved: bool = game.player_point.distance_to(origin) > 10
	var drawn: bool = DisplayServer.get_name() == "headless" or samples.filter(func(sample): return sample.has("render_submit_wait_ms")).size() >= frame_count * .9
	if DisplayServer.get_name() != "headless":
		RenderingServer.frame_pre_draw.disconnect(before_draw)
		RenderingServer.frame_post_draw.disconnect(after_draw)
	var output := "res://artifacts/streaming/walking-%s.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"accepted":stable and moved and drawn, "renderer":DisplayServer.get_name(), "input_scope":"loaded scripts, starting configuration and profiler; unexpected loaded scripts reject", "inputs":sources, "inputs_after":after, "provider":game.world.get_script().resource_path, "warmup":game.render_warmup.enabled, "fused_terrain":game.world_view.fuse_terrain, "no_map":"--no-map" in OS.get_cmdline_user_args(), "distance":game.player_point.distance_to(origin), "samples":samples}, "\t"))
	file.close()
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(output.replace(".json", ".png"))
	print("WALK_PROFILE: " + ProjectSettings.globalize_path(output))
	print("%s: source-stable supported walking with actual render samples" % ("PASS" if stable and moved and drawn else "REJECT"))
	await finish(0 if stable and moved and drawn else 1)

func finish(code: int) -> void:
	game.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	quit(code)

func settle_loading() -> bool:
	for frame in range(600):
		await process_frame
		if not game.render_warmup.busy and not is_instance_valid(game.warmup_overlay):
			return true
	print("REJECT: loading incomplete busy=%s cursor=%s materials=%s pending=%s scene=%s frames=%s visible=%s drawable=%s" % [game.render_warmup.busy, game.render_warmup.cursor, game.render_warmup.materials.size(), game.render_warmup.pending_frame, game.render_warmup.scene_pending, game.render_warmup.scene_frames, root.visible, DisplayServer.window_can_draw()])
	return false
