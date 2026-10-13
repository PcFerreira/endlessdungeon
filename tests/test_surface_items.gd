extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-surface-items-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game._clear_actors()
	game.world_items.register_location()
	assert(not game.world_items.registered.is_empty(), "Actual surface dressing must expose items")
	var city: Dictionary = game.world.region_at(game.world.start).city
	for source in game.world_items.registered.values():
		var record: Dictionary = source.record
		assert(record.get("visual_family", "") == game.world_view.construction.catalog.styles.family_for(city.biome), "Generated portable sources must retain actual biome family")
		assert(game.world_view.construction.catalog.styles.allows(record.get("model_id", ""), city.biome), "Generated portable descriptors must name the actual compatible model")
	var goods := {}
	for entry in game.world_items.registered.values():
		if entry.record.uid.contains(":left_goods"):
			goods = entry
			break
	assert(not goods.is_empty(), "A real authored market must expose its individual goods")
	var record: Dictionary = goods.record
	var node: Node3D = goods.node
	var stall: Node3D = node.get_parent()
	var fixed_count := stall.get_child_count()
	var source_transform: Transform3D = node.global_transform
	game.player_point = game.world.safe_position(game.world_items.position(record))
	game._snap_camera()
	assert(game.world_items.pickup(record.uid))
	assert(not node.visible and stall.visible and stall.get_child_count() == fixed_count)
	assert(game.inventory.stolen_count(record.item) == 1 and game.world_items.wanted(city.id).count == 1)
	if game.inventory.ITEMS[record.item].kind == "consumable":
		game.hp = game.max_hp * .5
		var hp_before: float = game.hp
		var bag_before: Dictionary = game.inventory.snapshot()
		assert(not game.use_item(record.item), "A stolen-only consumable cannot be consumed")
		assert(game.hp == hp_before and game.inventory.snapshot() == bag_before, "Failed consumption must preserve resources and custody")
	assert(node.global_transform == source_transform, "Hiding goods does not move the stall geometry")
	var plate: String = record.parent
	assert(not plate.is_empty() and not game.world_items.has_children(plate))
	var taken_ids := [record.uid]
	var blocked := {}
	for entry in game.world_items.registered.values():
		if not entry.record.get("blocked_cells", []).is_empty():
			blocked = entry.record
			break
	assert(not blocked.is_empty(), "A real independent city fixture exposes authored blocked cells")
	var cell := Vector2i(blocked.blocked_cells[0][0], blocked.blocked_cells[0][1])
	assert(not game.world.tiles.has(cell))
	for entry in game.world_items.registered.values():
		if entry.record.parent == blocked.uid:
			game.player_point = game.world.safe_position(game.world_items.position(entry.record))
			game._snap_camera()
			assert(game.world_items.pickup(entry.record.uid))
			taken_ids.append(entry.record.uid)
	game.player_point = game.world.safe_position(game.world_items.position(blocked))
	assert(game.world_items.pickup(blocked.uid) and game.world.tiles.has(cell))
	taken_ids.append(blocked.uid)
	game._generate_surface(Vector2(game.world.start) + Vector2(200, 0))
	game._generate_surface(Vector2(game.world.start))
	for uid in taken_ids:
		assert(game.world_items.registered.has(uid) and not game.world_items.registered[uid].node.visible)
	assert(game.world.tiles.has(cell), "Streaming re-applies the source collision mask")
	assert(game.save_game(1) and game.load_game(1))
	for uid in taken_ids:
		assert(not game.world_items.registered[uid].node.visible)
	assert(game.world.tiles.has(cell))
	assert(game.world_items.return_stolen(city.id))
	for uid in taken_ids:
		assert(game.world_items.registered[uid].node.visible)
	assert(not game.world.tiles.has(cell), "Restitution restores authored source collision")
	assert(game.inventory.stolen_count(record.item) == 0)
	assert(game.save_game(2) and game.load_game(2))
	for uid in taken_ids:
		assert(game.world_items.registered[uid].node.visible)
	var target := Vector2.INF
	for x in range(-4, 5):
		for y in range(-4, 5):
			var candidate: Vector2 = game.player_point + Vector2(x, y)
			if game.world.ground_height(candidate) > 0 and game.world_items.placement("health_potion", candidate, 0).problem.is_empty():
				target = candidate
				break
		if target != Vector2.INF:
			break
	assert(target != Vector2.INF and game.world_items.place("health_potion", target))
	var placed: Dictionary = game.world_items.state.placed[-1]
	assert(is_equal_approx(game.world_items.placed_nodes[placed.uid].position.y, game.world.ground_height(target)))
	assert(game.world_items.open_placement("health_potion"))
	game.world_items.target = target
	game.world_items._process(0)
	var preview: Dictionary = game.world_items.placement("health_potion", target, game.world_items.preview_rotation).record
	var preview_point: Vector2 = game.world_items.position(preview)
	assert(is_equal_approx(game.world_items.ghost.position.y, game.world.ground_height(preview_point) + preview.elevation), "Preview applies terrain height once, plus its actual support elevation")
	game.world_items.close()
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: generated market goods/independent fixtures, exact structural transforms, city ownership, blocked-cell release, chunk streaming, disk masks and restitution restoring actual geometry/collision")
	quit()
