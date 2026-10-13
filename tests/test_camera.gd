extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_Q
	var original: float = game.target_yaw
	game._unhandled_key_input(key)
	assert(not is_equal_approx(game.target_yaw, original), "Q must rotate the camera")
	for frame in range(60):
		game.simulate(1.0 / 60)
	assert(absf(angle_difference(game.camera_yaw, game.target_yaw)) < .001)
	game.camera_yaw = PI / 2
	assert(game.screen_movement(Vector2.RIGHT).is_equal_approx(Vector2.UP) and game.screen_movement(Vector2.DOWN).is_equal_approx(Vector2.RIGHT), "Movement must follow the rotated view")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	game._unhandled_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 0)
	original = game.target_yaw
	game._unhandled_input(motion)
	assert(not is_equal_approx(game.target_yaw, original))
	mouse.pressed = false
	game._unhandled_input(mouse)
	original = game.target_yaw
	game._unhandled_input(motion)
	assert(is_equal_approx(game.target_yaw, original), "Releasing middle mouse must stop rotation")
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	mouse.pressed = true
	var zoom: float = game.surface_zoom
	game._unhandled_input(mouse)
	assert(game.surface_zoom < zoom)
	game.state = "paused"
	original = game.target_yaw
	game._unhandled_key_input(key)
	assert(is_equal_approx(game.target_yaw, original), "Menu input must not rotate the world")
	print("PASS: keyboard/drag camera rotation, smoothing, release, view-relative movement, zoom, menu isolation")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()
