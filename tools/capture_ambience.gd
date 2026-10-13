extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/ambience-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1280,800)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_run(12345)
	game.has_journey = true
	game.state = "playing"
	await _frame("town")
	var biomes := {}
	for x in range(-2048,2049,64):
		for y in range(-2048,2049,64):
			var cell := Vector2i(x,y)
			var info: Dictionary = game.world.cell_info(cell)
			if info.walkable and info.terrain == "land" and game.world.city_distance(Vector2(cell), game.world.region_at(cell).city.cell) > 16:
				if not biomes.has(info.biome):
					biomes[info.biome] = cell
			if biomes.size() == 4:
				break
		if biomes.size() == 4:
			break
	assert(biomes.size() == 4)
	for biome in biomes:
		game._generate_surface(Vector2(biomes[biome]))
		await _frame("biome-%s" % biome)
	game._generate_surface(Vector2(game.world.start))
	assert(game.use_sanctum_sigil())
	await _frame("sanctum")
	assert(game.use_sanctum_sigil())
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.enter_dungeon(site)
	await _frame("dungeon")
	game.state = "paused"
	game.open_options()
	await _frame("options")
	game.close_options()
	game.show_credits()
	await _frame("credits")
	print("PASS: native ambience presentation in town, four biomes, Sanctum and dungeon; Options and audio credits")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func _frame(name: String) -> void:
	game.ambience.context_timer = 0
	game.ambience.update(game, 2)
	game._snap_camera()
	for frame in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	assert(root.get_texture().get_image().save_png("res://artifacts/ambience-%s.png" % name) == OK)
