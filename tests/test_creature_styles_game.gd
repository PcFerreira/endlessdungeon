extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-creature-styles-%s" % Time.get_ticks_usec()

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

func verify(game) -> void:
	var styles = game.EnemyModels.creatures.styles
	for enemy in game.enemies:
		var biome: int = game.dungeon.biome if game.layer == "dungeon" else game.world.cell_info(Vector2i(enemy.point.round())).biome
		assert(enemy.model.get_meta("biome") == biome)
		assert(enemy.model.get_meta("asset_id") == enemy.variant)
		if enemy.model.has_meta("wonder_id"):
			assert(enemy.model.get_meta("representation") == "original_wonder_voxel" and enemy.model.get_meta("visual_family") == styles.family_for(biome))
			assert(enemy.variant.begins_with("wonder:" + enemy.species + ":"))
		elif game.layer == "dungeon":
			assert(enemy.model.get_meta("representation") == "generated_voxel" and enemy.model.get_meta("visual_family") == "block_voxel")
			assert(enemy.variant.begins_with("voxel-monster:1:"), "Dungeon monsters retain their generated style descriptor")
		else:
			assert(styles.allows(enemy.model.get_meta("render_asset"), biome), "Surface enemy render identity must belong to its owning climate")
	for actor in game.life.actors.values():
		if actor.kind == "animal" and game.layer == "overworld":
			assert(actor.has("biome"))
			var model: Node3D = game.life_view.models[actor.id]
			assert(model.get_meta("source_asset") == actor.asset_id)
			if actor.asset_id.begins_with("wonder:"):
				assert(model.get_meta("representation") == "original_wonder_voxel" and model.get_meta("visual_family") == styles.family_for(actor.biome))
			else:
				assert(styles.allows(model.get_meta("render_asset"), actor.biome))

func run() -> void:
	var game = fresh()
	game.start_run(12345)
	game.begin_journey()
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
	assert(sites.size() == 4)
	var animal_checks := 0
	for biome in range(4):
		if game.layer == "dungeon":
			game.return_to_surface()
		game._generate_surface(Vector2(sites[biome].cell) + Vector2(0, 2))
		verify(game)
		animal_checks += game.life.actors.values().filter(func(actor): return actor.kind == "animal").size()
		var life: Dictionary = game.life.snapshot()
		assert(game.save_game(2))
		game.queue_free()
		await process_frame
		game = fresh()
		assert(game.load_game(2) and game.life.snapshot() == life)
		verify(game)
		game.enter_dungeon(sites[biome])
		assert(game.enemies.size() > 0)
		var enemy: Dictionary = game.enemies[0]
		var id: String = enemy.id
		var point: Vector2 = enemy.point
		game._clear_actors()
		game._spawn_enemy(point, 0, id, {"species": game.EnemyCatalog.TYPES[0].id, "variant": "quaternius_cube_world/Enemies/glTF/Skeleton.gltf", "attack": .7})
		verify(game)
		var identity: Array = [game.enemies[0].species, game.enemies[0].variant, game.enemies[0].model.get_meta("render_asset")]
		var random_before: int = game.rng.state
		assert(game.save_game(1))
		game.queue_free()
		await process_frame
		game = fresh()
		assert(game.load_game(1) and game.rng.state == random_before)
		verify(game)
		var restored: Array = game.enemies.filter(func(candidate): return candidate.id == id)
		assert(restored.size() == 1 and [restored[0].species, restored[0].variant, restored[0].model.get_meta("render_asset")] == identity)
		game.state = "playing"
		assert(game.use_sanctum_sigil() and game.leave_sanctum())
		verify(game)
	assert(animal_checks > 0, "Actual streaming must include fauna")
	print("PASS: four-climate streaming (%s animals), generated dungeon monsters, preserved species/style descriptors, fresh-scene disk/RNG and Sanctum reconstruction" % animal_checks)
	game.queue_free()
	await process_frame
	quit()
