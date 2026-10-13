extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://deferred-stream-test-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func finish(game, code: int) -> void:
	game.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	quit(code)

func checks() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.start_run(12345, game.World.NEW_JOURNEY_EDITION)
	var old_chunk: Vector2i = game.world.current_chunk
	var target := old_chunk + Vector2i(2, 0)
	for cell in game.navigation_ids:
		if game.World.chunk_at(Vector2(cell)) == target:
			game.player_point = Vector2(cell)
			break
	assert(game.World.chunk_at(game.player_point) == target and game.world.walkable(game.player_point), "The retained terrain ring supports walking ahead while an earlier outer ring catches up")
	var rng_before: int = game.rng.state
	game._refresh_surface()
	if game.world.current_chunk != old_chunk:
		push_error("An unprepared outer ring must retain the loaded terrain instead of synchronously generating/building it during walking")
		await finish(game, 1)
		return
	assert(game.rng.state == rng_before and game.world.walkable(game.player_point))
	game.streaming_data.stop()
	var pending := {}
	for x in range(target.x - game.World.CHUNK_RADIUS, target.x + game.World.CHUNK_RADIUS + 1):
		for y in range(target.y - game.World.CHUNK_RADIUS, target.y + game.World.CHUNK_RADIUS + 1):
			var coordinate := Vector2i(x, y)
			if not game.world.chunks.has(coordinate):
				pending[coordinate] = game.world._build_chunk(coordinate)
	assert(pending.size() > 9, "Catch-up must cover more than nine incoming roots without discarding already completed preparation")
	game.prefetch_context = [game.world.get_instance_id(), game.world.run_seed, game.world.generator_version]
	game.prefetched_chunks = pending
	game._refresh_surface()
	assert(game.world.current_chunk == old_chunk, "Ready data alone cannot trigger a synchronous visual build")
	for attempt in range(1000):
		game.world_view.prepare(game.world, pending, pending.keys(), 1000)
		assert(game.world_view.preparing.size() <= 9 and game.world_view.preparing.size() + game.world_view.prepared_nodes.size() <= 25)
		if pending.keys().all(func(coordinate): return game.world_view.prepared_nodes.has(coordinate)):
			break
		await process_frame
	assert(pending.keys().all(func(coordinate): return game.world_view.prepared_nodes.has(coordinate)))
	game._refresh_surface()
	assert(game.world.current_chunk == target and game.world.chunks.size() == 25 and game.world_view.chunk_nodes.size() == 25)
	assert(game.world.walkable(game.player_point) and game.navigation_ids.has(Vector2i(game.player_point.round())))
	print("PASS: walking retains supported terrain while data/visuals are pending, then promotes the complete bounded ring")
	await finish(game, 0)
