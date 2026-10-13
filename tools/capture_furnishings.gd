extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://furnishings-preview-%s" % Time.get_ticks_usec()

func new_game():
	var fresh := Game.new()
	fresh.records_enabled = false
	fresh.save_directory = directory
	fresh.settings_path = directory.path_join("settings.cfg")
	root.add_child(fresh)
	fresh.set_physics_process(false)
	fresh.set_process_unhandled_input(false)
	fresh.set_process_unhandled_key_input(false)
	return fresh

func _initialize() -> void:
	call_deferred("capture")

func item_for(asset_suffix: String) -> String:
	for id in game.inventory.ITEMS:
		if game.inventory.ITEMS[id].get("asset_id", "").ends_with(asset_suffix):
			return id
	assert(false, "Missing supported furnishing: " + asset_suffix)
	return ""

func place(id: String, point: Vector2, rotation: int = 0) -> void:
	game.furnishing_editor.select_item(id)
	game.furnishing_editor.target = point
	game.furnishing_editor.rotation = rotation
	assert(game.furnishing_editor.confirm())

func capture() -> void:
	game = new_game()
	game.start_run(12345)
	game._clear_actors()
	var table := item_for("/table_medium.gltf")
	var shelf := item_for("/shelf_A_big.gltf")
	var display := item_for("/Mug.gltf")
	for id in ["oak_chair", "oak_chair", "wool_rug", "rune_lantern", table, shelf, display]:
		assert(game.inventory.add(id))
	assert(game.use_sanctum_sigil())
	assert(game.furnishing_editor.open("oak_chair"))
	game.furnishing_editor.target = Vector2(10, 17)
	game.furnishing_editor.update_preview()
	assert(not game.furnishing_editor.confirm() and game.inventory.count("oak_chair") == 2)
	await frame("furnishings-invalid-portal")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.camera.unproject_position(Vector3(8, 0, 11))
	game._unhandled_input(click)
	assert(game.furnishings.records.size() == 1 and game.inventory.count("oak_chair") == 1)
	place("oak_chair", Vector2(6, 14), 1)
	place("wool_rug", Vector2(8, 11))
	place("rune_lantern", Vector2(12, 12))
	place(table, Vector2(12, 10))
	place(display, Vector2(12, 10))
	place(shelf, Vector2(4.5, 9))
	await frame("furnishings-editor-arranged")
	game.furnishing_editor.close()
	game.player_point = Vector2(10, 12)
	game._snap_camera()
	game.camera.size = 22
	await frame("furnishings-home")
	game.target_yaw = PI * 1.25
	game.camera_yaw = game.target_yaw
	game._snap_camera()
	game.sanctum_view.update_camera(game.camera_yaw)
	await frame("furnishings-home-reverse")
	assert(game.save_game(1))
	var saved: Dictionary = game.furnishings.snapshot()
	game.queue_free()
	await process_frame
	game = new_game()
	assert(game.load_game(1) and game.furnishings.snapshot() == saved)
	assert(game.sanctum_view.furniture_nodes.size() == 7)
	game.target_yaw = PI / 4
	game.camera_yaw = game.target_yaw
	assert(game.furnishing_editor.open())
	game.furnishing_editor.select_placed(game.furnishings.records[0].uid)
	game.furnishing_editor.target = Vector2(8.75, 13)
	game.furnishing_editor.rotation = 3
	game.furnishing_editor.update_preview()
	assert(game.furnishing_editor.proposal.problem.is_empty(), "The move preview must remain a legal supported position")
	await frame("furnishings-move-preview")
	game.furnishing_editor.cancel_selection()
	assert(game.furnishings.snapshot() == saved, "Cancelling a move must preserve the saved arrangement")
	game.furnishing_editor.select_placed(game.furnishings.records[0].uid)
	assert(game.furnishing_editor.pickup() and game.inventory.count("oak_chair") == 1)
	while game.inventory.slots_used() < game.inventory.CAPACITY:
		assert(game.inventory.add("ember_shard", 99))
	for record in game.furnishings.records:
		if record.item == "rune_lantern":
			game.furnishing_editor.select_placed(record.uid)
			break
	var full_saved: Dictionary = game.furnishings.snapshot()
	assert(not game.furnishing_editor.pickup() and game.furnishings.snapshot() == full_saved)
	await frame("furnishings-backpack-full")
	game.furnishing_editor.close()
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: native furnishing UI, actual ground click, invalid portal, supported shelf/tabletop, rotation, ghost cancellation, full-backpack refund protection and fresh-scene saved rendering")
	quit()

func frame(label: String) -> void:
	for index in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
