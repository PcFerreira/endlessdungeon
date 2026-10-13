extends SceneTree

const Game = preload("res://scripts/game.gd")
var first
var second
var endpoint := "ws://127.0.0.1:8080/play"

func _initialize() -> void:
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--endpoint="):
			endpoint = argument.trim_prefix("--endpoint=")
	first = make_game("first")
	second = make_game("second")
	second.hide()
	second.interface.root.hide()
	second.camera.current = false
	first.camera.current = true
	call_deferred("run_checks")

func make_game(label: String):
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-socket-%s-%s" % [label, Time.get_ticks_usec()]
	game.settings_path = game.save_directory.path_join("settings.cfg")
	game.online.config_path = game.save_directory + "-token.cfg"
	root.add_child(game)
	game.set_physics_process(false)
	return game

func run_checks() -> void:
	var suffix := str(Time.get_ticks_usec())
	first.online.open_lobby()
	first.online.endpoint = endpoint
	await capture("online-lobby")
	first.online.connect_account("register", "NativeA_" + suffix, "test-password-only-123", "mage")
	second.online.open_lobby()
	second.online.endpoint = endpoint
	second.online.connect_account("register", "NativeB_" + suffix, "test-password-only-123", "sword")
	if not await wait_for_sessions():
		return
	var first_id: String = first.online.player_id
	var second_id: String = second.online.player_id
	var origin := position(first)
	assert(first.world.get_script() == first.online.RemoteWorld and first.world.chunks.size() == 25)
	assert(first.enemies.is_empty() and second.enemies.is_empty())
	var direction := clear_direction(first, origin)
	assert(direction != Vector2.ZERO)
	var deadline := Time.get_ticks_msec() + 1600
	var next_input := Time.get_ticks_msec()
	while Time.get_ticks_msec() < deadline:
		if Time.get_ticks_msec() >= next_input:
			first.online.sequence += 1
			first.online.send({"type": "input", "seq": first.online.sequence, "direction": [direction.x, direction.y]})
			next_input = Time.get_ticks_msec() + 50
		first.online.render(1.0 / 60)
		second.online.render(1.0 / 60)
		await process_frame
	first.online.sequence += 1
	first.online.send({"type": "input", "seq": first.online.sequence, "direction": [0, 0]})
	await create_timer(.3).timeout
	var destination := position(first)
	assert(destination.distance_to(origin) > .5, "Server-authoritative input must move the player")
	assert(second.online.players.has(first_id) and first.online.players.has(second_id))
	assert(Vector2(second.online.players[first_id].position[0], second.online.players[first_id].position[1]).distance_to(destination) < .2)
	assert(second.online.avatars.has(first_id))
	first.online.render(.05)
	await capture("online-public-world")
	first.state = "paused"
	await capture("online-world-menu")
	first.state = "playing"
	var before: Dictionary = first.inventory.snapshot()
	assert(not first.save_game(1) and not first.world_items.take_nearest())
	first.cast("blink")
	assert(first.inventory.snapshot() == before and first.projectiles.is_empty())
	first.online.disconnect_world()
	assert(first.state == "menu" and first.online.avatars.is_empty())
	first.online.open_lobby()
	first.online.connect_account("resume")
	if not await wait_for_sessions():
		return
	assert(first.online.player_id == first_id and position(first).distance_to(destination) < .2)
	first.online.disconnect_world()
	second.online.disconnect_world()
	DirAccess.remove_absolute(first.online.config_path)
	DirAccess.remove_absolute(second.online.config_path)
	first.queue_free()
	second.queue_free()
	print("PASS two actual Game WebSocket accounts, server chunks, movement, peer visibility and token resume")
	quit()

func wait_for_sessions() -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		if first.online.session and second.online.session and first.online.players.size() == 2 and second.online.players.size() == 2:
			return true
		await process_frame
	push_error("Online socket timeout: %s / %s" % [first.online.status, second.online.status])
	quit(1)
	return false

func position(game) -> Vector2:
	var player: Dictionary = game.online.players[game.online.player_id]
	return Vector2(player.position[0], player.position[1])

func clear_direction(game, origin: Vector2) -> Vector2:
	var direction := Vector2.ZERO
	var distance := 0.0
	for candidate in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]:
		var destination: Vector2 = game.world.move_actor(origin, candidate * 3.8)
		if destination.distance_to(origin) > distance:
			direction = candidate
			distance = destination.distance_to(origin)
	return direction

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK)
