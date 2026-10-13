extends SceneTree

const Game = preload("res://scripts/game.gd")
const Points = preload("res://tools/biome_review_points.gd")
var game
var directory := "user://test-biome-game-%s" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run_checks")

func new_game():
	var value := Game.new()
	value.records_enabled = false
	value.save_directory = directory
	value.settings_path = directory.path_join("settings.cfg")
	root.add_child(value)
	value.set_physics_process(false)
	return value

func run_checks() -> void:
	game = new_game()
	game.start_run(91, 6)
	var points := Points.find(game.world)
	var counts := {}
	for id in points:
		game._generate_surface(Vector2(points[id].cell), false)
		game._clear_actors()
		var info: Dictionary = game.world.cell_info(Vector2i(game.player_point.round()))
		assert(info.biome_id == id and game.world.Biomes.valid_cell(info))
		assert(game.location_name().contains(game.world.Biomes.name_for(info)))
		var observed := {}
		for chunk in game.world_view.chunk_nodes.values():
			for node in chunk.get_children():
				if node.has_meta("biome_role"):
					assert(node is MultiMeshInstance3D and node.multimesh.instance_count > 0)
					assert(game.world_view.biome_models.items.styles.allows(node.get_meta("asset_id"), node.get_meta("biome")))
					observed[node.get_meta("biome_role")] = true
		assert(game.world_view.terrain_meshes.size() <= 768 and game.world_view.biome_templates.size() <= 128)
		counts[id] = observed.keys()
		if id in ["dense_forest", "haunted_hollows", "marsh", "jungle", "autumn_woodland", "fungal_grove", "volcanic_wastes", "highlands", "coast", "crystal_tundra"]:
			assert(not observed.is_empty(), "A new biome needs actual rendered ecology: " + id)
	assert(counts.dense_forest.has("dense_canopy") and counts.dense_forest.has("forest_understory"))
	assert(counts.haunted_hollows.has("haunted_tree") and counts.haunted_hollows.has("pumpkin"))
	var before: Dictionary = game.world.cell_info(Vector2i(game.player_point.round())).duplicate(true)
	var point: Vector2 = game.player_point
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = new_game()
	assert(game.load_game(1) and game.world.generator_version == 6 and game.player_point == point)
	assert(game.world.cell_info(Vector2i(point.round())) == before)
	game._clear_actors()
	assert(game.use_sanctum_sigil() and game.leave_sanctum())
	assert(game.world.generator_version == 6 and game.world.cell_info(Vector2i(point.round())) == before)
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: fourteen actual edition-6 streamed biome palettes/ecology/family identities, bounded presentation caches, named dense/haunted vegetation and fresh disk/home terrain restoration; ", counts)
	quit()
