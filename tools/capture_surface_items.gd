extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://surface-items-preview-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("capture")

func frame(name: String) -> void:
	game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK)

func capture() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	game._clear_actors()
	game.world_items.register_location()
	var goods := {}
	for entry in game.world_items.registered.values():
		if entry.record.uid.ends_with(":left_goods"):
			goods = entry
			break
	assert(not goods.is_empty())
	var record: Dictionary = goods.record
	game.player_point = game.world.safe_position(game.world_items.position(record))
	game._snap_camera()
	assert(game.world_items.open_placement())
	await frame("market-world-objects")
	assert(game.world_items.pickup(record.uid))
	assert(not goods.node.visible and goods.node.get_parent().visible)
	await frame("market-goods-taken")
	game.world_items.close()
	game.toggle_inventory()
	game.interface.inventory_selected = record.item
	game.interface.previous_state = ""
	await frame("market-stolen-backpack")
	game.toggle_inventory()
	assert(game.save_game(1) and game.load_game(1))
	game.set_physics_process(false)
	assert(not game.world_items.registered[record.uid].node.visible)
	assert(game.world_items.return_stolen(record.owner))
	assert(game.world_items.registered[record.uid].node.visible)
	assert(game.world_items.open_placement())
	await frame("market-goods-returned")
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: native generated market goods, unchanged stall/support, stolen backpack marking, disk source mask and exact original-city restoration")
	quit()
