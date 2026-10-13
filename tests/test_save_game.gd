extends SceneTree

const Game = preload("res://scripts/game.gd")
const Store = preload("res://scripts/save_store.gd")
var game
var directory := "user://test-saves-%s" % Time.get_ticks_usec()

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
	game.state = "title"
	game.choose_class("spellsword")
	game.state = "playing"
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.dungeon_progress[site.id] = site.floors
	game.enter_dungeon(site)
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000)
	game.player_point = Vector2(game.dungeon.exit) + Vector2.DOWN
	game.interact()
	assert(game.learn_skill("power"))
	game.equip_ability("fire", 9)
	game.hp = 37
	game.mana = 42
	game.cooldowns.fire = .8
	game._snap_camera()
	game.jump()
	game.simulate(.15)
	var point: Vector2 = game.player_point
	var altitude: float = game.player_y
	assert(game.save_game(1))
	assert(game.saves.latest_slot() == 1)
	game.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.load_game(1))
	assert(game.run_seed == 12345 and game.layer == "dungeon" and game.depth == site.floors)
	assert(game.build.class_id == "spellsword" and game.build.ranks.power == 1 and game.ACTION_BAR[9] == "fire")
	assert(game.claimed_chests.has(site.id) and game.enemies.is_empty())
	assert(game.player_point.is_equal_approx(point) and is_equal_approx(game.player_y, altitude))
	assert(not game.grounded and game.hp == 37 and game.mana > 42 and game.cooldowns.fire > 0)
	game.state = "playing"
	game.interact()
	assert(game.build.skill_points == 0, "Reloading must not duplicate a chest reward")
	game.return_to_surface()
	game.hp = 29
	var surface: Vector2 = game.player_point
	assert(game.save_game(1))
	var primary: String = game.saves.slot_path(1)
	FileAccess.open(primary, FileAccess.WRITE).store_string("{broken")
	assert(game.load_game(1) and game.layer == "dungeon", "A damaged primary must recover the preceding backup")
	assert(game.menu_notice.contains("backup"))
	assert(game.save_game(2))
	var invalid: Dictionary = game.make_save_data()
	invalid.build.class_id = "unknown"
	assert(not game.saves.write(3, invalid), "Invalid snapshots must never replace a slot")
	FileAccess.open(game.saves.slot_path(3), FileAccess.WRITE).store_string('{"version":999}')
	var before: Vector2 = game.player_point
	assert(not game.load_game(3) and game.player_point == before, "Failed loads must leave the current journey intact")
	game.return_to_surface()
	game.player_point = surface
	game._snap_camera()
	assert(game.save_game(2) and game.load_game(2) and game.layer == "overworld" and game.player_point.is_equal_approx(surface))
	var city: Dictionary = game.world.nearest_site(surface, "city")
	game.player_point = Vector2(city.houses[0].footprint.get_center())
	assert(game.save_game(2) and game.load_game(2))
	assert(game.world.walkable(game.player_point), "A load inside an obstacle must recover to an open position")
	var sites: Array = game.world.region_at(game.world.start).dungeons
	game.enter_dungeon(sites[0] if sites[0].id != site.id else sites[1])
	var enemy: Dictionary = game.enemies[0]
	game.player_point = game.dungeon.safe_position(enemy.point + Vector2.DOWN)
	game._snap_camera()
	enemy.hp -= 7
	enemy.slow = 1.2
	enemy.attack = .6
	enemy.windup = .3
	enemy.active = true
	game.select_target(enemy)
	game.cast("bolt")
	game._drop(game.player_point, "health")
	game.camera_yaw = 1.2
	game.target_yaw = 1.7
	var enemy_id: String = enemy.id
	var enemy_hp: float = enemy.hp
	var random_state: int = game.rng.state
	assert(game.save_game(2) and game.load_game(2))
	assert(game.selected_target.id == enemy_id and game.selected_target.hp == enemy_hp and game.selected_target.windup == .3)
	assert(game.projectiles.size() == 1 and game.projectiles[0].target.id == enemy_id and game.pickups.size() == 1)
	assert(game.rng.state == random_state and is_equal_approx(game.camera_yaw, 1.2) and is_equal_approx(game.target_yaw, 1.7))
	game.records_enabled = true
	game.return_to_menu()
	assert(game.state == "menu")
	assert(FileAccess.file_exists(game.saves.slot_path(0)), "Returning to the menu must autosave")
	game.continue_journey()
	assert(game.state == "playing")
	print("PASS: disk saves across fresh scenes; builds/rewards/discovery, world/dungeon location, live enemies/projectiles/pickups, jump/resources/cooldowns/camera/RNG, backup recovery, invalid data, safe relocation, autosave/menu/continue")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	await create_timer(.15).timeout
	quit()
