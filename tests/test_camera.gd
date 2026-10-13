extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-camera-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	var key := InputEventKey.new()
	key.pressed = true
	var original: float = game.target_yaw
	for code in [KEY_Q, KEY_R]:
		key.physical_keycode = code
		game._unhandled_key_input(key)
		assert(is_equal_approx(game.target_yaw, original), "Q/R must no longer rotate the camera")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	game._unhandled_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 0)
	original = game.target_yaw
	game._unhandled_input(motion)
	assert(not is_equal_approx(game.target_yaw, original), "Right-button dragging must orbit the camera")
	for frame in range(60):
		game._update_camera(1.0 / 60)
	assert(absf(angle_difference(game.camera_yaw, game.target_yaw)) < .001)
	game.camera_yaw = PI / 2
	assert(game.screen_movement(Vector2.RIGHT).is_equal_approx(Vector2.UP) and game.screen_movement(Vector2.DOWN).is_equal_approx(Vector2.RIGHT), "Movement must follow the rotated view")
	mouse.pressed = false
	game._unhandled_input(mouse)
	original = game.target_yaw
	game._unhandled_input(motion)
	assert(is_equal_approx(game.target_yaw, original), "Releasing right mouse must stop rotation")
	mouse.pressed = true
	game._unhandled_input(mouse)
	mouse.pressed = false
	game._input(mouse)
	game._unhandled_input(motion)
	assert(is_equal_approx(game.target_yaw, original), "A release consumed by the HUD must still stop rotation")
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	game._unhandled_input(mouse)
	game._unhandled_input(motion)
	assert(is_equal_approx(game.target_yaw, original), "Middle mouse must no longer start camera rotation")
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	mouse.pressed = true
	var zoom: float = game.surface_zoom
	game._unhandled_input(mouse)
	assert(game.surface_zoom < zoom)
	assert(is_equal_approx(game.camera.size, game.surface_zoom))
	mouse.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game._unhandled_input(mouse)
	assert(is_equal_approx(game.surface_zoom, zoom), "Wheel down must zoom back out")
	for area in ["overworld", "dungeon", "sanctum", "interior"]:
		game.layer = area
		mouse.button_index = MOUSE_BUTTON_WHEEL_UP
		for tick in range(40):
			game._unhandled_input(mouse)
		assert(is_equal_approx(game.camera.size, 12.0 if area == "overworld" else 10.0), "Zoom in must stop at the area limit")
		mouse.button_index = MOUSE_BUTTON_WHEEL_DOWN
		for tick in range(40):
			game._unhandled_input(mouse)
		var limit := 24.0 if area == "overworld" else 30.0 if area == "interior" else 22.0
		assert(is_equal_approx(game.camera.size, limit), "Zoom out must stop at the area limit")
	game.layer = "overworld"
	game.toggle_pause()
	original = game.target_yaw
	game._unhandled_key_input(key)
	mouse.button_index = MOUSE_BUTTON_RIGHT
	game._unhandled_input(mouse)
	game._unhandled_input(motion)
	assert(is_equal_approx(game.target_yaw, original), "Menu input must not rotate the world")
	zoom = game.surface_zoom
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	game._unhandled_input(mouse)
	assert(is_equal_approx(game.surface_zoom, zoom), "Menu input must not zoom the world")
	game.toggle_pause()
	assert(game.inventory.add("rune_lantern"))
	assert(game.world_items.open_placement("rune_lantern"))
	key.physical_keycode = KEY_R
	game._unhandled_key_input(key)
	assert(game.world_items.preview_rotation == 1, "R must still rotate placed items")
	mouse.button_index = MOUSE_BUTTON_RIGHT
	game._unhandled_input(mouse)
	game._unhandled_input(motion)
	assert(is_equal_approx(game.target_yaw, original), "Placement input must not orbit the camera")
	game.world_items.close()
	game.state = "dead"
	game.hp = 0
	game._unhandled_key_input(key)
	assert(game.state == "playing" and is_equal_approx(game.hp, game.max_hp), "R must still respawn the player")
	print("PASS: right-button orbit, Q/R removal, smoothing, release over HUD, view-relative movement, bounded wheel zoom in all areas, menu/placement isolation, R item rotation and respawn")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	quit()
