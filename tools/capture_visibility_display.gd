extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/display-preview-saves"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.expansion.set_process_input(false)
	game.exploration.set_process_input(false)
	game.start_run(12345)
	game._clear_actors()
	game.life_view.sync(game)
	game.notification_time = 0
	for offset in [Vector2(12,0), Vector2(-12,0), Vector2(0,12), Vector2(0,-12)]:
		var point: Vector2 = game.world.safe_position(game.player_point + offset, 3)
		if game.world.walkable(point) and point.distance_to(game.player_point) > 9:
			game._spawn_enemy(point, 0, "visible:%s" % game.enemies.size())
	assert(game.enemies.size() >= 3)
	game._update_enemies(0)
	for zoom in [19,24]:
		game.camera.size = zoom
		game._snap_camera()
		game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
		var on_screen := 0
		for enemy in game.enemies:
			var position: Vector3 = game.to_world(enemy.point) + Vector3(0,.6,0)
			if not game.camera.is_position_behind(position) and root.get_visible_rect().has_point(game.camera.unproject_position(position)):
				assert(enemy.node.visible and not enemy.active)
				on_screen += 1
		assert(on_screen >= 2)
		await frame("enemies-visible-zoom-%s" % zoom)
	game.open_options()
	await frame("display-options-default")
	print("Display size %s / usable window limit %s" % [DisplayServer.screen_get_size(), game.window_resolution_limit()])
	var tested := 0
	for size in [Vector2i(1024,768), Vector2i(1280,720), Vector2i(1280,800), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		if not game.resolution_fits(size):
			continue
		var selector: OptionButton = game.interface.overlay.find_child("Resolution", true, false)
		var index: int = game.resolution_choices().find(size)
		assert(index >= 0 and not selector.is_item_disabled(index))
		selector.select(index)
		selector.item_selected.emit(index)
		await frames()
		assert(root.size == size and game.windowed_resolution == size)
		await frame("display-options-%sx%s" % [size.x,size.y])
		tested += 1
	assert(tested >= 2)
	game.close_options()
	root.size = Vector2i(1400,800)
	await frames()
	game.open_options()
	await frames()
	assert(game.windowed_resolution == root.size and Vector2i(1400,800) in game.resolution_choices())
	assert(game.set_resolution(Vector2i(1920,1080)))
	await frames()
	var preferred: Vector2i = game.windowed_resolution
	var fullscreen: CheckBox = game.interface.overlay.find_child("Fullscreen", true, false)
	fullscreen.button_pressed = true
	await create_timer(1.5).timeout
	await frames()
	assert(game.is_fullscreen() and game.windowed_resolution == preferred)
	var selector: OptionButton = game.interface.overlay.find_child("Resolution", true, false)
	assert(selector.disabled)
	await frame("display-options-fullscreen")
	fullscreen = game.interface.overlay.find_child("Fullscreen", true, false)
	fullscreen.button_pressed = false
	await create_timer(1.5).timeout
	await frames()
	assert(not game.is_fullscreen() and root.size == preferred, "Fullscreen return wanted %s, got %s (stored %s, mode %s)" % [preferred, root.size, game.windowed_resolution, root.mode])
	game.records_enabled = true
	game._save_settings()
	var settings := ConfigFile.new()
	assert(settings.load(game.settings_path) == OK)
	assert(settings.get_value("video", "resolution") == preferred)
	assert(game.set_resolution(Vector2i(1024,768)))
	game._load_settings()
	await frames()
	assert(root.size == preferred and game.windowed_resolution == preferred)
	game.records_enabled = false
	game.close_options()
	game.set_resolution(Vector2i(1280,800))
	print("PASS: native camera-area distant enemies without aggro, signal-driven resolution choices at %s window sizes, menu bounds, fullscreen return and isolated persisted display settings" % tested)
	game.queue_free()
	await process_frame
	quit()

func frames() -> void:
	for index in range(12):
		await process_frame

func frame(label: String) -> void:
	await frames()
	assert(game.layer == "overworld", "Display preview must stay on its captured surface")
	if game.state == "options":
		var bounds := Rect2(Vector2.ZERO, game.interface.overlay.size)
		for panel in game.interface.overlay.find_children("*", "PanelContainer", true, false):
			if panel.get_parent() is CenterContainer:
				assert(bounds.encloses(panel.get_global_rect()), "Options must fit the viewport")
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
