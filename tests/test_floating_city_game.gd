extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://floating-city-test-%s" % Time.get_ticks_usec()

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var game = fresh()
	game.start_run(12345, 6)
	game.has_journey = false
	game.state = "title"
	game.begin_journey()
	assert(game.location_name() == "Lanternwake", "A player's first actual journey must begin in the floating lobby")
	assert(game.world.has_method("spawn_point") and game.player_point == game.world.spawn_point())
	assert(game.enemies.is_empty() and not game.world_ground.visible)
	var hub: Dictionary = game.world.hub.city_record()
	game.player_point = hub.houses[0].approach
	game._snap_camera()
	game.interact()
	assert(game.state == "hub_board" and game.floating_hub.current.guild_id == "lantern_wardens")
	game.floating_hub.close()
	for hall in hub.houses:
		game.player_point = hall.approach
		game._snap_camera()
		game.interact()
		assert(game.state == "hub_board")
		game.floating_hub.enter_hall()
		assert(game.layer == "interior" and game.interiors.current.id == hall.id and game.interiors.current.name == hall.use_name, "Each guild hall must enter its real supported room")
		assert(game.save_game(3) and game.load_game(3) and game.interiors.leave(), "Guild interiors must restore and return to the floating approach")
		assert(game.location_name() == "Lanternwake" and game.player_point == hall.approach)
	game.player_point = hub.outdoor_lots[0].approach
	game._snap_camera()
	assert(game.inventory.add("gold_coin", 10))
	game.interact()
	assert(game.state == "store" and game.stores.current.id == hub.outdoor_lots[0].id)
	var amount: int = game.inventory.count("health_potion")
	assert(game.stores.buy("health_potion") and game.inventory.count("health_potion") == amount + 1)
	var stock: Dictionary = game.stores.snapshot()
	game.stores.close()
	assert(game.save_game(1))
	var other = fresh()
	assert(other.load_game(1) and other.location_name() == "Lanternwake" and other.stores.snapshot() == stock)
	var point: Vector2 = other.player_point
	assert(other.use_sanctum_sigil() and other.leave_sanctum() and other.player_point == point)
	other.player_point = other.world.hub.portal
	other._snap_camera()
	other.interact()
	assert(other.layer == "overworld" and other.player_point.distance_to(Vector2(other.world.start)) < 1 and other.world_ground.visible)
	assert(other.floating_hub.recall() and other.location_name() == "Lanternwake")
	assert(other.save_game(2) and other.load_game(2) and other.stores.snapshot() == stock)
	var bad: Dictionary = other.make_save_data()
	bad.progress.floating_city.theme = "missing"
	assert(not other.saves.validate(bad), "Invalid seasonal state must be rejected before replacing a journey")
	game.queue_free()
	other.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: actual first-spawn hub, all three guild charters/interior disk returns, finite market purchase, hub disk/home return, world departure/recall and seasonal save rejection")
	quit()
