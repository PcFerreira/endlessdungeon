extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://item-stacks-preview-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("capture")

func fresh():
	var scene := Game.new()
	scene.records_enabled = false
	scene.save_directory = directory
	scene.settings_path = directory.path_join("settings.cfg")
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process_unhandled_input(false)
	scene.set_process_unhandled_key_input(false)
	return scene

func frame(name: String) -> void:
	for index in range(6):
		await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK)

func capture() -> void:
	game = fresh()
	game.start_run(12345)
	game._clear_actors()
	var target := Vector2.INF
	for cell in game.world.tiles:
		var point := Vector2(cell)
		if game.world.ground_height(point) < .5 or not game.world.walkable(point):
			continue
		var flat := true
		for x in range(-1, 2):
			for y in range(-1, 2):
				if game.world.ground_height(point + Vector2(x, y)) != game.world.ground_height(point):
					flat = false
		if not flat:
			continue
		game.player_point = game.world.safe_position(point + Vector2.DOWN * 2)
		var proposal: Dictionary = game.world_items.placement("rune_lantern", point, 0)
		if proposal.problem.is_empty() and proposal.record.parent.is_empty():
			target = point
			break
	assert(target != Vector2.INF, "The actual world must offer clear raised ground")
	game._snap_camera()
	game.camera.size = 9
	assert(game.inventory.add("rune_lantern", 5))
	assert(game.world_items.open_placement("rune_lantern"))
	game.world_items.target = target
	await frame("stacks-ground-preview")
	var ground: float = game.world.ground_height(target)
	assert(is_equal_approx(game.world_items.ghost.position.y, ground), "Preview must touch raised terrain")
	for level in range(4):
		if level > 0:
			assert(game.world_items.open_placement("rune_lantern"))
		var screen: Vector2 = game.camera.unproject_position(game.to_world(target, level * .8))
		assert(game.world_items.point_from_screen(screen).is_equal_approx(target), "Clicking the stack top must retain its floor location")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = screen
		game._unhandled_input(click)
		assert(game.world_items.state.placed.size() == level + 1, "Actual clicks must create supported layers")
		var record: Dictionary = game.world_items.state.placed[-1]
		var bounds: AABB = game.world_items.visual_bounds(game.world_items.placed_nodes[record.uid])
		assert(is_equal_approx(bounds.position.y, ground + level * .8) and is_equal_approx(bounds.size.y, .8), "Each rendered layer must meet the item below")
	game.world_items.close()
	await frame("stacks-four-items")
	assert(game.world_items.open_placement("health_potion"))
	game.world_items.target = target + Vector2.RIGHT
	await frame("stacks-ground-icon-preview")
	for sprite in game.world_items.ghost.find_children("*", "Sprite3D", true, false):
		assert(sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y)
	game.world_items.close()
	assert(game.world_items.open_placement("rune_lantern"))
	game.world_items.target = target
	await frame("stacks-fifth-rejected")
	assert(not game.world_items.confirm() and game.inventory.count("rune_lantern") == 1)
	game.world_items.close()
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = fresh()
	assert(game.load_game(1) and game.world_items.state.placed.size() == 4)
	game.camera.size = 9
	for record in game.world_items.state.placed:
		assert(is_equal_approx(game.world_items.placed_nodes[record.uid].position.y, ground + record.elevation))
	await frame("stacks-restored")
	for level in range(3, -1, -1):
		assert(game.world_items.take_nearest())
		assert(game.world_items.state.placed.size() == level)
	assert(game.inventory.count("rune_lantern") == 5)
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: actual raised world terrain, grounded ghost/models, mouse stacking to four, fifth rejection, disk-restored layers and nearest top-first pickup")
	quit()
