extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/menu-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	await save_frame("main-menu")
	game.start_run(12345)
	game.state = "title"
	await save_frame("title")
	game.show_credits()
	await save_frame("credits")
	game.close_credits()
	game.state = "playing"
	await save_frame("exploration")
	assert(game.use_sanctum_sigil())
	for frame in range(30):
		game.simulate(1.0 / 60)
	await save_frame("sanctum")
	game.player_point = game.dungeon.hearth + Vector2.DOWN
	game._snap_camera()
	game.interact()
	await save_frame("sanctum-hearth")
	game.target_yaw = PI * 1.25
	for frame in range(60):
		game.simulate(1.0 / 60)
	await save_frame("sanctum-rotated")
	game.state = "paused"
	await save_frame("sanctum-paused")
	game.state = "playing"
	assert(game.use_sanctum_sigil())
	await save_frame("sanctum-return")
	assert(game.save_game(1))
	game.state = "paused"
	await save_frame("pause-menu")
	game.open_save_menu(false)
	await save_frame("save-menu")
	game.close_save_menu()
	game.open_save_menu(true)
	await save_frame("load-menu")
	game.close_save_menu()
	game.open_options()
	await save_frame("options")
	game.close_options()
	game.state = "playing"
	for angle in [PI / 2, PI, -PI / 2]:
		game.target_yaw = angle
		for frame in range(60):
			game.simulate(1.0 / 60)
		await save_frame("camera-world-%s" % int(rad_to_deg(angle)))
	game.target_yaw = PI / 4
	game.camera_yaw = PI / 4
	game._snap_camera()
	game.jump()
	for frame in range(15):
		game.simulate(1.0 / 60)
	await save_frame("jump")
	game._snap_camera()
	game.state = "paused"
	await save_frame("audio-settings")
	game.state = "playing"
	game.state = "map"
	await save_frame("atlas")
	game.state = "playing"
	var biomes := {}
	for x in range(-256, 257, 8):
		for y in range(-256, 257, 8):
			var cell: Vector2i = game.world.start + Vector2i(x, y)
			var info: Dictionary = game.world.cell_info(cell)
			if info.terrain != "land" or not info.walkable:
				continue
			if Vector2(cell).distance_to(game.world.region_at(cell).city.cell) < 16:
				continue
			if not biomes.has(info.biome) or Vector2(cell).distance_to(game.world.start) < Vector2(biomes[info.biome]).distance_to(game.world.start):
				biomes[info.biome] = cell
	for biome in biomes:
		game._generate_surface(Vector2(biomes[biome]))
		await save_frame("biome-%s" % biome)
	game._generate_surface(Vector2(game.world.start))
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game._generate_surface(Vector2(site.cell) + Vector2(0, 2))
	await save_frame("dungeon-entrance")
	game.enter_dungeon(site)
	await save_frame("dungeon")
	game.target_yaw = PI * 1.25
	for frame in range(60):
		game.simulate(1.0 / 60)
	await save_frame("camera-dungeon")
	game.target_yaw = PI / 4
	game.camera_yaw = PI / 4
	game._snap_camera()
	for enemy in game.enemies:
		enemy.node.queue_free()
	game.enemies.clear()
	game._spawn_enemy(game.player_point + Vector2(2.3, 0), 0)
	game._spawn_enemy(game.player_point + Vector2(1.5, 1.8), 1)
	game._spawn_enemy(game.player_point + Vector2(-1.2, 2.2), 2)
	game.select_target(game.enemies[0])
	game.cast_slot(1)
	game.cast_slot(2)
	for frame in range(8):
		game.simulate(1.0 / 60)
	await save_frame("combat")
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000)
	game.player_point = Vector2(game.dungeon.exit)
	game.interact()
	await save_frame("depth-two")
	game.depth = game.active_dungeon.floors
	game._generate_floor()
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000)
	game.player_point = Vector2(game.dungeon.exit) + Vector2.DOWN
	game._snap_camera()
	game.dungeon_view.reveal(game.dungeon, game.player_point)
	game.dungeon_view.animate(.1, true)
	await save_frame("final-chest")
	game.interact()
	await save_frame("chest-claimed")
	assert(game.save_game(2))
	game.toggle_grimoire()
	await save_frame("grimoire-mage")
	game.interface.grimoire_tabs.current_tab = 1
	await save_frame("grimoire-abilities")
	game.toggle_grimoire()
	game.learn_skill("power")
	game.interface.grimoire_tab = 0
	game.toggle_grimoire()
	await save_frame("grimoire-learned")
	game.toggle_grimoire()
	game.return_to_surface()
	await save_frame("returned-to-world")
	for id in ["sword", "spellsword"]:
		game.state = "title"
		game.choose_class(id)
		await save_frame("class-" + id)
		game.state = "playing"
		game._generate_surface(Vector2(game.world.start))
		await save_frame("world-" + id)
		game.toggle_grimoire()
		await save_frame("grimoire-" + id)
		game.toggle_grimoire()
	game.hp = 0
	game.state = "dead"
	await save_frame("death")
	game.return_to_menu()
	await save_frame("continue-menu")
	print("Captured new HUD, sanctum/hearth/return, menus, saves/options, camera orbit, classes/grimoire, biomes, dungeon rewards, combat, and death in artifacts/")
	game.queue_free()
	await create_timer(.15).timeout
	quit()

func save_frame(label: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	if not FileAccess.file_exists("res://artifacts/.gdignore"):
		FileAccess.open("res://artifacts/.gdignore", FileAccess.WRITE).close()
	var image := root.get_texture().get_image()
	var result := image.save_png("res://artifacts/%s.png" % label)
	assert(result == OK)
