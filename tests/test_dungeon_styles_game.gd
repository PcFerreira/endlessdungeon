extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-dungeon-styles-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func run() -> void:
	var game = fresh()
	game.start_run(12345)
	var sites := {}
	for x in range(-24, 25, 3):
		for y in range(-24, 25, 3):
			var region: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE)
			for site in region.dungeons:
				var biome: int = game.world._biome_at(site.cell)
				if not sites.has(biome):
					sites[biome] = site
			if sites.size() == 4:
				break
		if sites.size() == 4:
			break
	assert(sites.size() == 4, "Find an actual generated dungeon entry in every climate")
	for biome in range(4):
		var site: Dictionary = sites[biome]
		if game.layer == "dungeon":
			game.return_to_surface()
		game._generate_surface(Vector2(site.cell) + Vector2(0, 2))
		game.enter_dungeon(site)
		assert(game.dungeon.biome == biome and game.dungeon_view.biome == biome, "Actual entry must pass its surface climate to generation/presentation")
		assert(game.dungeon_view.visual_family == game.dungeon_view.styles.family_for(biome))
		var descriptors := {}
		for uid in game.world_items.registered:
			var record: Dictionary = game.world_items.registered[uid].record
			assert(record.visual_family == game.dungeon_view.visual_family and game.dungeon_view.styles.allows(record.model_id, biome))
			descriptors[uid] = [record.model_id, record.visual_family, record.parent]
		assert(not descriptors.is_empty(), "Actual dungeon adaptation must retain portable fixtures and support identities")
		var random_before: int = game.rng.state
		assert(game.save_game(1), game.menu_notice)
		game.queue_free()
		await process_frame
		game = fresh()
		assert(game.load_game(1), "A fresh scene must restore the actual styled dungeon")
		assert(game.active_dungeon.id == site.id and game.dungeon.biome == biome and game.dungeon_view.biome == biome)
		assert(game.rng.state == random_before, "Style restoration must retain the actual combat RNG state")
		for uid in descriptors:
			assert(game.world_items.registered.has(uid), "Styled source IDs must survive disk reconstruction")
			var record: Dictionary = game.world_items.registered[uid].record
			assert([record.model_id, record.visual_family, record.parent] == descriptors[uid])
		game.state = "playing"
		game._clear_actors()
		game.sanctum_return.clear()
		assert(game.use_sanctum_sigil(), "Styled dungeon must remain a valid Sanctum return context")
		assert(game.leave_sanctum() and game.dungeon.biome == biome and game.active_dungeon.id == site.id)
	print("PASS: actual dungeon entries in all four climates; owning biome, rendered/portable identities, fresh-scene disk reconstruction, combat RNG and Sanctum return")
	game.queue_free()
	await process_frame
	quit()
