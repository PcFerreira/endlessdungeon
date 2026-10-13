extends Node

const Streaming = preload("res://scripts/streaming_data.gd")
const World = preload("res://scripts/world.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Icons = preload("res://scripts/icon_grid.gd")
const Game = preload("res://scripts/game.gd")

func _ready() -> void:
	call_deferred("checks")

func checks() -> void:
	var worker := Streaming.new()
	worker.request(91, 91, 7, [Vector2i(1, 1)])
	var started := worker.thread.is_started()
	var chunks := {}
	if started:
		for attempt in range(1200):
			chunks.merge(worker.take(91, {}, 91, 7))
			if chunks.has(Vector2i(1, 1)):
				break
			await get_tree().create_timer(.005).timeout
	worker.stop()
	var symbols_ok := true
	for kind in Icons.SHAPES:
		var icon := Icons.symbol(kind)
		symbols_ok = symbols_ok and icon != null and icon.get_width() == 64 and not icon.get_image().is_empty()
	var items_ok := true
	var svg_count := 0
	for item in Items.definitions.values():
		if item.get("icon", "").get_extension().to_lower() != "svg":
			continue
		var texture := Items.icon(item)
		svg_count += 1
		items_ok = items_ok and texture != null and texture.get_width() > 0 and not texture.get_image().is_empty()
		if not items_ok:
			break
	if not started or not chunks.has(Vector2i(1, 1)) or not symbols_ok or not items_ok or svg_count == 0:
		print("FAIL: release runtime worker=%s chunks=%s menu_icons=%s item_icons=%s svg_count=%s" % [started, chunks.size(), symbols_ok, items_ok, svg_count])
		get_tree().quit(1)
		return
	var expected := World.new()
	expected.generate(91, 7)
	if chunks[Vector2i(1, 1)] != expected._build_chunk(Vector2i(1, 1)):
		print("FAIL: release worker terrain differs from the owning generator")
		get_tree().quit(1)
		return
	if not await game_streaming():
		get_tree().quit(1)
		return
	print("PASS: release-safe worker startup/terrain and real menu/item SVG pixels (%s items); debug=%s" % [svg_count, OS.is_debug_build()])
	get_tree().quit()

func game_streaming() -> bool:
	var game := Game.new()
	var directory := "user://release-streaming-%s" % Time.get_ticks_usec()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_run(12345, 7)
	game.has_journey = false
	game.state = "title"
	game.begin_journey()
	game.player_point = game.world.hub.portal
	game._snap_camera()
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	game._unhandled_key_input(event)
	var passed: bool = not game.floating_hub.active() and game.world.get_script() == Streaming.HubWorld
	var initial: Vector2i = game.world.current_chunk
	for crossing in range(3):
		if not passed:
			break
		var target: Vector2i = game.world.current_chunk + Vector2i.RIGHT
		var candidates: Array = game.world.cells.keys().filter(func(cell): return World.chunk_at(Vector2(cell)) == target and game.world.walkable(Vector2(cell)))
		if candidates.is_empty():
			passed = false
			break
		game.player_point = Vector2(candidates[0])
		game._snap_camera()
		for attempt in range(1200):
			game._preload_surface(Vector2.RIGHT)
			game._refresh_surface()
			if game.world.current_chunk == target:
				break
			await get_tree().create_timer(.002).timeout
		passed = game.world.current_chunk == target and game.world.chunks.size() == 25 and game.world_view.chunk_nodes.size() == 25 and game.navigation_ids.has(Vector2i(game.player_point.round()))
		print("RELEASE_CROSSING %s chunk=%s data=%s visuals=%s" % [crossing + 1, game.world.current_chunk, game.world.chunks.size(), game.world_view.chunk_nodes.size()])
	passed = passed and game.world.current_chunk != initial
	game.queue_free()
	await get_tree().process_frame
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	if not passed:
		print("FAIL: packed release Game must leave the physical Worldgate and activate three new complete chunk rings")
	return passed
