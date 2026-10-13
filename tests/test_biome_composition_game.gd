extends SceneTree

const Game = preload("res://scripts/game.gd")
const Points = preload("res://tools/biome_review_points.gd")
const SOURCE_PATHS := ["scripts/game.gd", "scripts/world.gd", "scripts/world_view.gd", "scripts/biome_composition.gd", "scripts/biome_models.gd", "scripts/world_ambience.gd", "scripts/biome_atmosphere.gd", "scripts/save_store.gd", "scripts/journey.gd", "scripts/world_life.gd", "scripts/streaming_data.gd", "config/biomes.json", "config/biome_composition.json", "config/biome_art.json", "config/biome_atmosphere.json", "scripts/micro_biome_catalog.gd", "scripts/micro_biome_exploration.gd", "scripts/micro_biome_view.gd", "scripts/exploration.gd", "config/micro_biomes.json"]
var game
var directory := "user://test-biome-composition-game-%s" % OS.get_process_id()
var source_hashes := {}

func _initialize() -> void:
	source_hashes = hashes()
	call_deferred("run_checks")

func hashes() -> Dictionary:
	var result := {}
	for path in SOURCE_PATHS:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result

func placement_check(cell: Vector2i) -> void:
	var world = game.world
	var coordinate = world.chunk_at(Vector2(cell))
	var job: Dictionary = game.world_view._chunk_job(world, coordinate, {"cells": {cell: world.cell_info(cell)}})
	game.world_view._build_chunk_cell(job, cell)
	for groups in job.terrain_groups.values():
		for placement in groups:
			assert(placement.basis == Basis.IDENTITY, "Plant variation must preserve terrain transforms")
	var info: Dictionary = world.cell_info(cell)
	for key in job.prop_groups:
		var role: String = info.prop if not info.prop.is_empty() else info.detail
		var variation: Dictionary = world.Composition.visual(world.run_seed, cell, role == info.detail, role)
		var expected := Basis(Vector3.UP, variation.turn * PI / 2).scaled(variation.scale)
		for placement in job.prop_groups[key]:
			assert(placement.basis.is_equal_approx(expected), "Actual prebatch placement must apply seeded yaw and scale")
			assert(placement.origin.y == info.height, "Plants must remain grounded at actual terrain height")
		if role in ["biome:dense_crown", "biome:jungle_crown"]:
			assert(variation.scale.y >= 1 and variation.scale.x <= 1 and variation.scale.z <= 1, "Crown instances retain occupied footprint and upper clearance")
	game.world_view.remove_child(job.root)
	job.root.queue_free()

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
	game.start_run(91, 7)
	var points := Points.find(game.world)
	var counts := {}
	for id in points:
		game._generate_surface(Vector2(points[id].cell), false)
		game._clear_actors()
		var info: Dictionary = game.world.cell_info(Vector2i(game.player_point.round()))
		assert(info.biome_id == id and game.world.Biomes.valid_cell(info))
		assert(game.location_name().contains(game.world.Biomes.name_for(info)))
		var observed := {}
		var placed := false
		for chunk in game.world.chunks.values():
			for cell in chunk.cells:
				var candidate: Dictionary = chunk.cells[cell]
				if not placed and not candidate.prop.is_empty():
					placement_check(cell)
					placed = true
		assert(placed, "Actual generated biome needs a transformed plant or rock")
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
	assert(counts.dense_forest.has("dense_crown") and counts.dense_forest.has("forest_understory"))
	assert(counts.haunted_hollows.has("haunted_tree") and counts.haunted_hollows.has("pumpkin"))
	var before: Dictionary = game.world.cell_info(Vector2i(game.player_point.round())).duplicate(true)
	var point: Vector2 = game.player_point
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = new_game()
	assert(game.load_game(1) and game.world.generator_version == 7 and game.player_point == point)
	assert(game.world.cell_info(Vector2i(point.round())) == before)
	game._clear_actors()
	assert(game.use_sanctum_sigil() and game.leave_sanctum())
	assert(game.world.generator_version == 7 and game.world.cell_info(Vector2i(point.round())) == before)
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	assert(hashes() == source_hashes, "Accept only unchanged generation/render/save sources")
	print("PASS: fourteen actual edition-7 streamed biome palettes/ecology/family identities, bounded presentation caches, named dense/haunted vegetation and fresh disk/home terrain restoration; ", counts)
	quit()
