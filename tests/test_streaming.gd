extends SceneTree

const World = preload("res://scripts/world.gd")
const Game = preload("res://scripts/game.gd")
const Streaming = preload("res://scripts/streaming_data.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var probe := Game.WorldView.new()
	assert(probe.has_method("prepare"), "Visual chunks must prepare within a per-frame budget before the crossing")
	probe.free()
	var worker := Streaming.new()
	for edition in [4, 5, 6]:
		var world := World.new()
		world.generate(12345, edition)
		var coordinate := World.chunk_at(Vector2(world.start)) + Vector2i(1, 0)
		worker.request(edition, 12345, edition, [coordinate])
		var results := {}
		var received := World.new()
		received.generate(12345, edition)
		for attempt in range(600):
			results.merge(worker.take(edition, received.regions, 12345, edition, received))
			if results.has(coordinate):
				break
			await create_timer(.005).timeout
		assert(results.has(coordinate))
		assert(results[coordinate] == world._build_chunk(coordinate), "Threaded cells, ecology and spawn IDs must exactly match production")
		assert(received.regions == world.regions and received.route_plans == world.route_plans)
		if edition >= 5:
			assert(received.site_planner.plans == world.site_planner.plans and received.site_planner.routes == world.site_planner.routes)
	var stale_coordinate := Vector2i(-9, -2)
	worker.request(77, 12345, 4, [stale_coordinate])
	worker.request(77, 9999, 6, [stale_coordinate])
	var fresh := {}
	var regions := {}
	for attempt in range(600):
		fresh.merge(worker.take(77, regions, 9999, 6))
		if fresh.has(stale_coordinate):
			break
		await create_timer(.005).timeout
	var expected := World.new()
	expected.generate(9999, 6)
	assert(fresh.get(stale_coordinate) == expected._build_chunk(stale_coordinate))
	assert(regions == expected.regions, "Transferred region records must match the actual seed and edition")
	worker.request(78, 9999, 6, [stale_coordinate], true)
	var warmed := World.new()
	warmed.generate(9999, 6)
	expected.nearby_sites(Vector2(stale_coordinate * World.CHUNK_SIZE))
	var warm_chunks := {}
	for attempt in range(600):
		warm_chunks.merge(worker.take(78, warmed.regions, 9999, 6, warmed))
		if warm_chunks.has(stale_coordinate) and warmed.regions == expected.regions and warmed.site_planner.plans == expected.site_planner.plans and warmed.site_planner.routes == expected.site_planner.routes:
			break
		await create_timer(.005).timeout
	assert(warm_chunks.get(stale_coordinate) == fresh[stale_coordinate])
	worker.stop()
	assert(not worker.thread.is_alive())
	assert(warmed.regions == expected.regions and warmed.site_planner.plans == expected.site_planner.plans and warmed.site_planner.routes == expected.site_planner.routes)
	var game := Game.new()
	var directory := "user://streaming-regression-%s" % Time.get_ticks_usec()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.world.generate(12345, 6)
	game.dungeon = game.world
	var origin := Vector2(game.world.start)
	game.world.load_around(origin)
	game._rebuild_navigation()
	for offset in [Vector2(16, 0), Vector2(32, 16), Vector2(-16, -16), Vector2.ZERO]:
		game.world.load_around(origin + offset)
		game._stream_navigation()
		var actual := graph(game)
		game._rebuild_navigation()
		assert(actual == graph(game), "Incremental navigation must preserve every walkable point and height-aware edge")
	var blocked: Vector2i = game.navigation_ids.keys()[0]
	game.world.obstacles.append(Rect2(Vector2(blocked) - Vector2(.3, .3), Vector2(.6, .6)))
	game._stream_navigation()
	var obstructed := graph(game)
	game._rebuild_navigation()
	assert(obstructed == graph(game), "Changed placed obstacles must invalidate retained navigation")
	game.world.obstacles.clear()
	game._stream_navigation()
	var reopened := graph(game)
	game._rebuild_navigation()
	assert(reopened == graph(game))
	game.world_view.reset()
	game.world_view.sync(game.world)
	var coordinate := World.chunk_at(origin) + Vector2i(3, 0)
	var prepared := {coordinate: game.world._build_chunk(coordinate)}
	game.world_view.prepare(game.world, prepared, [coordinate], 0)
	assert(not game.world_view.chunk_nodes.has(coordinate) and game.world_view.preparing.has(coordinate))
	for attempt in range(600):
		game.world_view.prepare(game.world, prepared, [coordinate], 1000)
		if game.world_view.prepared_nodes.has(coordinate):
			break
		await process_frame
	assert(game.world_view.prepared_nodes.has(coordinate))
	var ready: Node3D = game.world_view.prepared_nodes[coordinate]
	assert(not ready.visible and not game.world_view.chunk_nodes.has(coordinate), "Prepared visuals must stay outside active gameplay until loaded")
	var cell: Vector2i = prepared[coordinate].cells.keys().filter(func(value): return prepared[coordinate].cells[value].walkable)[0]
	prepared[coordinate].spawns = [{"id":"streaming-model-probe", "kind":0, "cell":cell}]
	game.prefetched_chunks = prepared
	game.prefetch_context = [game.world.get_instance_id(), game.world.run_seed, game.world.generator_version]
	var rng_before: int = game.rng.state
	game._prepare_surface_enemies([coordinate])
	assert(game.rng.state == rng_before, "Visual preparation must not spend combat randomness")
	var enemy_model: Node3D = game.prepared_enemy_models["streaming-model-probe"].model
	game.world.chunks[coordinate] = prepared[coordinate]
	game.world.load_around(origin + Vector2(16, 0))
	game.world_view.sync(game.world)
	assert(game.world_view.chunk_nodes[coordinate] == ready and ready.visible)
	game._spawn_enemy(Vector2(cell), 0, "streaming-model-probe")
	assert(game.enemies[-1].model == enemy_model and not game.prepared_enemy_models.has("streaming-model-probe"))
	assert(game.world_view.chunk_nodes.size() <= 25)
	var reference := Game.WorldView.new()
	root.add_child(reference)
	reference.sync(game.world)
	assert(visuals(ready) == visuals(reference.chunk_nodes[coordinate]), "Budgeted chunks must preserve synchronous geometry and placements")
	reference.queue_free()
	var abandoned := coordinate + Vector2i(1, 0)
	game.world_view.prepare(game.world, {abandoned: game.world._build_chunk(abandoned)}, [abandoned], 0)
	game.world_view.prepare(game.world, {}, [], 0)
	assert(game.world_view.preparing.is_empty() and game.world_view.prepared_nodes.is_empty())
	var part := MeshInstance3D.new()
	part.mesh = game.Voxels.mesh([[Vector3.ZERO, Vector3.ONE, Color("447857")]])
	var shared: Mesh = game.world_view._shared_batch_mesh(part, true)
	assert(shared == game.world_view._shared_batch_mesh(part, true))
	assert(shared.surface_get_arrays(0) == part.mesh.surface_get_arrays(0))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c17a7a")
	part.set_surface_override_material(0, material)
	assert(shared != game.world_view._shared_batch_mesh(part, true), "Different materials must never share the prepared mesh")
	part.free()
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: worker terrain/region warming match editions 4/5/6; navigation matches full rebuild with obstacles; budgeted visuals preserve geometry and bounded activation; prepared enemy models reuse without spending combat RNG")
	quit()

func graph(game) -> Dictionary:
	var result := {}
	for cell in game.navigation_ids:
		var neighbors := []
		for direction in World.DIRECTIONS:
			var next: Vector2i = cell + direction
			if game.navigation_ids.has(next) and game.astar.are_points_connected(game.navigation_ids[cell], game.navigation_ids[next]):
				neighbors.append(next)
		result[cell] = neighbors
	return result

func visuals(node: Node3D) -> Array:
	var result := [node.get_class(), node.transform]
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			result.append(node.mesh.surface_get_arrays(surface))
	if node is MultiMeshInstance3D:
		result.append(node.multimesh.buffer)
		for surface in range(node.multimesh.mesh.get_surface_count()):
			result.append(node.multimesh.mesh.surface_get_arrays(surface))
	for child in node.get_children():
		if child is Node3D:
			result.append(visuals(child))
	return result
