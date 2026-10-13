extends SceneTree

const Game = preload("res://scripts/game.gd")
var first
var second
var endpoint := "ws://127.0.0.1:18089/play"
var revision := "floating-hub-client-fixture"
var directory := "user://floating-online-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--endpoint="):
			endpoint = argument.trim_prefix("--endpoint=")
		if argument.begins_with("--revision="):
			revision = argument.trim_prefix("--revision=")
	call_deferred("checks")

func fresh(label: String):
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory.path_join(label)
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.online.config_path = directory.path_join(label + "-token.cfg")
	game.online.content_revision = revision
	game.online.open_lobby()
	game.online.endpoint = endpoint
	return game

func wait_until(condition: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		if first.online.session:
			first.online.render(1.0 / 60)
		if second.online.session:
			second.online.render(1.0 / 60)
		await process_frame
	assert(condition.call(), message + " / " + first.online.status)

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/floating-city-online-%s.png" % label) == OK)

func checks() -> void:
	first = fresh("first")
	second = fresh("second")
	second.hide()
	second.interface.root.hide()
	second.camera.current = false
	first.camera.current = true
	var suffix := str(Time.get_ticks_usec())
	first.online.connect_account("register", "HubA_" + suffix, "Lanternwake-native-only-123", "mage")
	second.online.connect_account("register", "HubB_" + suffix, "Lanternwake-native-only-123", "sword")
	await wait_until(func(): return first.online.session and second.online.session and first.online.players.size() == 2, "Two accounts must meet in the shared floating lobby")
	assert(first.location_name() == "Lanternwake" and first.world.get_script() == first.online.RemoteWorld)
	assert(first.player_y == 14 and first.online.avatars.has(second.online.player_id))
	var generated: int = first.offline_generation_calls
	await capture("arrival")
	first.online.send({"type": "hub_travel", "destination": "world"})
	await wait_until(func(): return first.notification.contains("Stand beside"), "Off-gate refusal must keep the public session alive")
	assert(first.online.session and first.state == "playing")
	first.interact()
	assert(first.state == "hub_board")
	await capture("commons")
	first.floating_hub.close()
	var deadline := Time.get_ticks_msec() + 10000
	var next_input := 0
	while first.player_point.distance_to(Vector2(32, -4041)) > 1 and Time.get_ticks_msec() < deadline:
		if Time.get_ticks_msec() >= next_input:
			first.online.sequence += 1
			first.online.send({"type": "input", "seq": first.online.sequence, "direction": [0, 1]})
			next_input = Time.get_ticks_msec() + 50
		first.online.render(1.0 / 60)
		await process_frame
	assert(first.player_point.distance_to(Vector2(32, -4041)) < 1.5)
	first.online.sequence += 1
	first.online.send({"type": "input", "seq": first.online.sequence, "direction": [0, 0]})
	first.interact()
	await wait_until(func(): return first.state == "playing" and first.player_point.distance_to(Vector2(64, 67)) < .5, "Travel must wait for streamed destination and snap to the natural gate")
	assert(first.world.ready_around(first.player_point) and first.player.visible and first.world_view.visible)
	assert(first.offline_generation_calls == generated)
	assert(first.camera_focus.distance_to(first.player.position) < .01)
	await capture("worldgate-destination")
	first.interact()
	await wait_until(func(): return first.state == "playing" and first.player_point.distance_to(Vector2(32, -4058)) < .5, "Returning must replay the pruned hub chunks and region")
	assert(first.world.ready_around(first.player_point) and first.location_name() == "Lanternwake" and first.player_y == 14)
	assert(first.offline_generation_calls == generated)
	await capture("returned")
	var id: String = first.online.player_id
	first.online.disconnect_world()
	first.online.open_lobby()
	first.online.endpoint = endpoint
	first.online.connect_account("resume")
	await wait_until(func(): return first.online.session and first.online.player_id == id, "Opaque-token resume must restore the hub account")
	assert(first.location_name() == "Lanternwake")
	first.online.disconnect_world()
	second.online.disconnect_world()
	first.queue_free()
	second.queue_free()
	await process_frame
	for label in ["first", "second"]:
		var path := directory.path_join(label)
		for file in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(file))
		DirAccess.remove_absolute(path)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: two real public Game accounts, shared hub peers/commons, nonterminal refusal, actual dock movement, streamed gate/return with camera snap, no local terrain and token resume")
	quit()
