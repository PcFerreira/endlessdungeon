extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-sanctum-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	assert(game.has_method("use_sanctum_sigil"), "The starting sigil must open the player's pocket home")
	var point: Vector2 = game.player_point
	game.hp = 39
	game._drop(point + Vector2(3, 0), "health")
	game.jump()
	assert(not game.use_sanctum_sigil() and game.layer == "overworld", "Recall requires stable footing")
	game._snap_camera()
	game._spawn_enemy(point + Vector2.RIGHT, 0, "test-hostile")
	assert(not game.use_sanctum_sigil(), "The sigil cannot bypass nearby enemies")
	var hostile: Dictionary = game.enemies[-1]
	hostile.node.queue_free()
	game.enemies.erase(hostile)
	var random_state: int = game.rng.state
	assert(game.use_sanctum_sigil() and game.layer == "sanctum")
	assert(game.enemies.is_empty() and game.hp == 39 and game.dungeon.walkable(game.player_point))
	game._hurt_player(1000)
	assert(game.hp == 39, "The pocket home must be safe")
	game.player_point = game.dungeon.hearth + Vector2.DOWN
	game.interact()
	assert(game.hp == game.max_hp and game.mana == game.max_mana)
	assert(game.use_sanctum_sigil() and game.layer == "overworld")
	assert(game.player_point.is_equal_approx(point) and game.pickups.size() == 1)
	assert(game.rng.state == random_state and game.hp == game.max_hp, "Home rest must persist without consuming the outside RNG")
	var site: Dictionary = game.world.nearest_site(point, "dungeon")
	game.enter_dungeon(site)
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000)
	game.build.skill_points = 1
	game.player_point = Vector2(game.dungeon.start) + Vector2.DOWN
	game._snap_camera()
	point = game.player_point
	var drops: int = game.pickups.size()
	assert(game.use_sanctum_sigil())
	assert(game.learn_skill("power"))
	game.player_point = game.dungeon.hearth + Vector2.DOWN
	assert(game.save_game(1))
	var data: Dictionary = game.make_save_data()
	data.home.return_journey.location.layer = "sanctum"
	assert(not game.saves.validate(data), "A pocket home cannot contain a recursive return destination")
	game.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.load_game(1) and game.layer == "sanctum")
	assert(game.build.ranks.power == 1 and game.use_sanctum_sigil())
	assert(game.layer == "dungeon" and game.active_dungeon.id == site.id and game.player_point.is_equal_approx(point))
	assert(game.enemies.is_empty() and game.pickups.size() == drops and game.build.ranks.power == 1 and game.build.skill_points == 0)
	var legacy: Dictionary = game.make_save_data()
	legacy.erase("home")
	assert(game.saves.write(2, legacy) and game.load_game(2), "Existing journeys without a home field must remain loadable")
	assert(game.use_sanctum_sigil())
	game.return_to_sanctuary()
	assert(game.layer == "overworld" and game.sanctum_return.is_empty())
	print("PASS: safe sigil recall, hearth rest, exact world/dungeon return with suspended drops/RNG, skills learned at home, fresh-scene home saves, legacy saves, recursive destination rejection, sanctuary escape")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	await create_timer(.15).timeout
	quit()
