extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://world-items-preview-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("capture")

func frame(name: String) -> void:
	for index in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK)

func capture() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	var site: Dictionary = game.world.region_at(game.world.start).dungeons[0]
	game.enter_dungeon(site)
	for floor_number in range(1, site.floors + 1):
		for enemy in game.enemies.duplicate():
			game._hit_enemy(enemy, 100000)
		game.player_point = Vector2(game.dungeon.exit) + Vector2.DOWN * .8
		game.interact()
	for cell in game.dungeon.tiles:
		if game.dungeon.walkable(Vector2(cell)) and Vector2(cell).distance_to(game.dungeon.start) > 3 and Vector2(cell).distance_to(game.dungeon.exit) > 3:
			game.player_point = Vector2(cell)
			break
	game._snap_camera()
	game.dungeon_view.reveal(game.dungeon, game.player_point)
	assert(game.world_items.claim_base() and game.world_items.set_rest_point())
	assert(game.inventory.add("oak_chair", 2))
	var target := Vector2.INF
	for x in range(-4, 5):
		for y in range(-4, 5):
			var candidate: Vector2 = game.player_point + Vector2(x, y)
			if game.world_items.placement("oak_chair", candidate, 0).problem.is_empty():
				target = candidate
				break
		if target != Vector2.INF:
			break
	assert(target != Vector2.INF)
	assert(game.world_items.open_placement("oak_chair"))
	game.world_items.target = target
	var before: Dictionary = game.inventory.snapshot()
	var tick: int = game.life.tick
	game._physics_process(1)
	assert(game.life.tick == tick)
	await frame("base-placement-preview")
	assert(game.inventory.snapshot() == before, "Preview does not consume the item")
	game.world_items.close()
	assert(game.inventory.snapshot() == before)
	assert(game.world_items.open_placement("oak_chair"))
	game.world_items.target = target
	await process_frame
	assert(game.world_items.confirm())
	game.world_items.close()
	assert(game.inventory.count("oak_chair") == 1)
	await frame("base-chair-rest-point")
	assert(game.world_items.open_placement())
	await frame("base-controls")
	game.world_items.close()
	assert(game.save_game(1) and game.load_game(1))
	game.set_physics_process(false)
	await frame("base-restored")
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: native real dungeon-base claim, placement preview/cancel/confirm, paused simulation, furniture/rest marker, base controls and fresh disk restoration")
	quit()
