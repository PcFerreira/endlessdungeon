extends SceneTree

const Game = preload("res://scripts/game.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/discovery-preview-saves"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.start_run(91)
	game.begin_journey()
	var variants := {}
	for x in range(-5,6):
		for y in range(-5,6):
			if variants.size() == game.exploration.catalog.entries.size():
				break
			var region: Dictionary = game.world.region_at(Vector2i(x,y) * Game.World.REGION_SIZE)
			var entry: Dictionary = Sites.plan(game.world, region, game.exploration.catalog)
			if not entry.is_empty():
				variants[entry.template_id] = entry
	assert(variants.size() == game.exploration.catalog.entries.size(), "Native capture must cover all current discovery families")
	for entry in variants.values():
		var approach := Vector2(entry.approach[0], entry.approach[1])
		game._generate_surface(approach, false)
		game._clear_actors()
		game.player_point = approach
		game.player_y = game.world.ground_height(approach)
		game.player.position = game.to_world(approach)
		game.grounded = true
		game._snap_camera()
		game.exploration.sync()
		assert(game.exploration.view.markers.has(entry.id))
		await frame("discovery-" + entry.template_id)
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		event.pressed = true
		game._unhandled_key_input(event)
		assert(game.state == "discovery_reader")
		await frame("discovery-reader-" + entry.template_id)
		game.exploration.mark_site(entry.id)
		assert(game.waypoint.id == entry.site_id)
		game.exploration.close()
	game.expansion.toggle_journal()
	await frame("discovery-journal")
	var id: String = game.exploration.entries.keys()[0]
	game.exploration.read_saved(id)
	assert(game.state == "discovery_reader")
	await frame("discovery-journal-reader")
	game.exploration.close()
	assert(game.state == "journal")
	game.expansion.close_lore()
	print("PASS: native roadside markers/readers for four families, actual E interaction, real ruin markers, collected journal and rereading")
	game.queue_free()
	await process_frame
	await create_timer(.1).timeout
	quit()

func frame(label: String) -> void:
	for index in range(5):
		await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	assert(image.save_png("res://artifacts/" + label + ".png") == OK)
