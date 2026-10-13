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
	await process_frame
	var amount: int = game.inventory.count("health_potion")
	assert(game.stores.buy("health_potion") and game.inventory.count("health_potion") == amount + 1)
	var stock: Dictionary = game.stores.snapshot()
	game.stores.close()
	assert(game.save_game(1))
	var other = fresh()
	assert(other.load_game(1) and other.location_name() == "Lanternwake" and other.stores.snapshot() == stock)
	var point: Vector2 = other.player_point
	assert(other.use_sanctum_sigil() and other.leave_sanctum() and other.player_point == point)
	assert(other.use_sanctum_sigil())
	assert(not other.floating_hub.from_sanctum(), "The hub portal must reject remote activation")
	other.player_point = Vector2(5, 7)
	other._snap_camera()
	other.grounded = false
	assert(not other.floating_hub.from_sanctum(), "Portal travel must reject an airborne character")
	other.grounded = true
	assert(other.interaction_hint() == "E: Travel to Lanternwake", "The protected Sanctum study gate must lead to the central hub")
	other.interact()
	assert(other.layer == "overworld" and other.location_name() == "Lanternwake" and other.stores.snapshot() == stock)
	other.player_point = other.floating_hub.portal_point("sanctum")
	other._snap_camera()
	other.cooldowns.bolt = .25
	other.cooldowns.nova = 4.0
	var live_cooldowns: Dictionary = other.cooldowns.duplicate()
	other.interact()
	assert(other.layer == "sanctum", "Lanternwake's personal gate must open the actual furnished Sanctum")
	assert(other.cooldowns == live_cooldowns, "A historical return thread must not rewind current spell cooldowns")
	assert(other.save_game(2) and other.load_game(2) and other.cooldowns == live_cooldowns, "Live cooldowns must survive a home disk restore")
	assert(other.leave_sanctum() and other.player_point == point, "The Sanctum Journey portal must retain the original location through a hub side trip")
	assert(other.cooldowns == live_cooldowns)
	other.player_point = other.world.hub.portal
	other._snap_camera()
	other.interact()
	assert(other.layer == "overworld" and other.player_point.distance_to(Vector2(other.world.start)) < 1 and other.world_ground.visible)
	assert(other.floating_hub.recall() and other.location_name() == "Lanternwake")
	assert(other.save_game(2) and other.load_game(2) and other.stores.snapshot() == stock)
	other.player_point = other.floating_hub.portal_point("dimension")
	other._snap_camera()
	assert(other.interaction_hint() == "E: Travel to Morrowmere")
	other.interact()
	assert(other.dimension.active and other.world.dimension_id == "morrowmere", "The Portal Court interaction must delegate to the actual realm provider")
	assert(other.dimension.return_to_hub() and other.player_point == other.floating_hub.portal_point("dimension") and other.stores.snapshot() == stock)
	var bad: Dictionary = other.make_save_data()
	bad.progress.floating_city.theme = "missing"
	assert(not other.saves.validate(bad), "Invalid seasonal state must be rejected before replacing a journey")
	var legacy = fresh()
	legacy.start_run(34567, 4)
	assert(legacy.inventory.add("gold_coin", 9))
	var original: Vector2 = legacy.player_point
	var terrain: Dictionary = legacy.world.cell_info(Vector2i(original.round()))
	var coins: int = legacy.inventory.count("gold_coin")
	assert(legacy.use_sanctum_sigil())
	legacy.player_point = Vector2(5, 7)
	legacy._snap_camera()
	assert(legacy.floating_hub.from_sanctum() and legacy.location_name() == "Lanternwake")
	assert(legacy.run_seed == 34567 and legacy.world.generator_version == 4 and legacy.inventory.count("gold_coin") == coins)
	assert(legacy.world.cell_info(Vector2i(original.round())) == terrain, "Legacy travel must preserve seed, edition, terrain and owned possessions")
	assert(legacy.save_game(3) and legacy.load_game(3) and legacy.location_name() == "Lanternwake", "A legacy hero's newly connected hub must survive disk restore")
	legacy.player_point = legacy.floating_hub.portal_point("sanctum")
	legacy._snap_camera()
	legacy.interact()
	assert(legacy.leave_sanctum() and legacy.player_point == original)
	legacy._clear_actors()
	legacy.player_point = legacy.world.safe_position(original + Vector2(3, 0))
	legacy._snap_camera()
	var later_origin: Vector2 = legacy.player_point
	assert(later_origin != original and legacy.use_sanctum_sigil())
	legacy.player_point = Vector2(5, 7)
	legacy._snap_camera()
	assert(legacy.floating_hub.from_sanctum())
	assert(legacy.dimension.outside_return.location.point == [later_origin.x, later_origin.y], "A later Sanctum visit must retain its current origin rather than an older hub trip")
	game.queue_free()
	other.queue_free()
	legacy.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: first-spawn hub, guilds/shops, grounded Sanctum and Portal Court travel, original Journey return, legacy seed/terrain/inventory and hub disk restores, Worldgate and seasons")
	quit()
