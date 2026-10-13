extends SceneTree

const HubWorld = preload("res://scripts/hub_world.gd")
const Game = preload("res://scripts/game.gd")
const Streaming = preload("res://scripts/streaming_data.gd")
var directory := "user://worldgate-stream-test-%s" % Time.get_ticks_usec()

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
	await worker_checks()
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.start_run(12345, game.World.NEW_JOURNEY_EDITION)
	game.has_journey = false
	game.state = "title"
	game.begin_journey()
	game.player_point = game.world.hub.portal
	game.grounded = true
	assert(game.floating_hub.target().kind == "depart" and game.floating_hub.interact())
	assert(game.world is HubWorld and not game.floating_hub.active())
	assert(Streaming.supports(game.world, game.player_point))
	assert(not Streaming.supports(game.world, game.world.hub.spawn), "The authored island keeps explicit loading")
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
	print("PASS: actual fresh Worldgate departure retains supported terrain until the bounded prepared ring is ready; worker preserves hub cells and gate metadata")
	await finish(game, 0)

func worker_checks() -> void:
	var worker := Streaming.new()
	for edition in [6, 7]:
		var expected := HubWorld.new()
		expected.generate(12345, edition)
		var received := HubWorld.new()
		received.generate(12345, edition)
		var coordinates := [Game.World.chunk_at(Vector2(expected.start)), Game.World.chunk_at(Vector2(expected.hub.center)), Game.World.chunk_at(Vector2(expected.hub.reserved.end))]
		var chunks := {}
		for coordinate in coordinates:
			chunks[coordinate] = expected._build_chunk(coordinate)
		worker.request(edition, 12345, edition, coordinates, false, expected.hub.theme)
		var result := {}
		for attempt in range(600):
			result.merge(worker.take(edition, received.regions, 12345, edition, received))
			if result.size() == chunks.size():
				break
			await create_timer(.005).timeout
		assert(result == chunks and received.regions == expected.regions and received.route_plans == expected.route_plans)
		assert(received.region_at(expected.start).hub_world_gate == Vector2(expected.start))
	worker.stop()
	var finite = preload("res://scripts/finite_world.gd").new()
	var remote = Game.OnlineClient.RemoteWorld.new()
	assert(not Streaming.supports(finite, Vector2.ZERO) and not Streaming.supports(remote, Vector2.ZERO))
