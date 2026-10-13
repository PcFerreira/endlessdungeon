extends SceneTree

const Game = preload("res://scripts/game.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/history-preview-saves"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func move_to(point: Vector2) -> void:
	game._generate_surface(point, false)
	game._clear_actors()
	game.player_point = point
	game.player_y = game.world.ground_height(point)
	game.player.position = game.to_world(point)
	game.grounded = true
	game._snap_camera()
	game.exploration.sync()

func capture() -> void:
	game.set_physics_process(false)
	game.start_run(91)
	game.begin_journey()
	assert(not game.exploration.history.definitions.is_empty(), "History must come from the shipped registry")
	var region: Dictionary = game.world.region_at(game.world.start)
	var key := Sites.region_key(game.world, region)
	var book: Dictionary = region.city.books[0]
	move_to(book.approach)
	game.interact()
	assert(game.state == "reader")
	assert(not game.exploration.book_appendix().is_empty())
	await frame("history-local-book", true)
	game.expansion.close_lore()
	game.life.sync(game.world, Vector2(region.city.cell))
	var resident: Dictionary = game.life.residents().filter(func(actor): return actor.id == region.city.residents[0].id)[0]
	move_to(resident.point)
	assert(game.expansion.open_dialogue(resident))
	await frame("history-conversation")
	assert(game.exploration.read_witness(resident))
	await frame("history-witness")
	game.exploration.close()
	assert(game.state == "dialogue")
	game.expansion.close_lore()
	var marker := Sites.plan(game.world, region, game.exploration.catalog)
	assert(not marker.is_empty())
	move_to(Vector2(marker.approach[0], marker.approach[1]))
	game.interact()
	assert(game.state == "discovery_reader")
	assert(game.exploration.history.complete(key))
	await frame("history-landmark")
	game.exploration.close()
	game.life.advance(75)
	game.interact()
	assert(game.exploration.history.records[key].notes.size() == 1)
	await frame("history-aftermath", true)
	game.exploration.close()
	game.expansion.toggle_journal()
	await frame("history-journal")
	game.exploration.read_history(key)
	assert(game.state == "discovery_reader")
	game.exploration.mark_history(key)
	assert(game.waypoint.id == game.exploration.history.records[key].site_id)
	await frame("history-collected-account")
	game.exploration.close()
	game.expansion.close_lore()
	print("PASS: native registry-backed local book, history conversation, landmark, actual event aftermath and completed regional collection")
	game.queue_free()
	await process_frame
	await create_timer(.1).timeout
	quit()

func frame(label: String, end: bool = false) -> void:
	for index in range(5):
		await process_frame
	if end:
		var overlay: Control = game.expansion.overlay if game.state == "reader" else game.exploration.overlay
		for scroll in overlay.find_children("*", "ScrollContainer", true, false):
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await process_frame
	RenderingServer.force_draw()
	var capture := root.get_texture().get_image()
	assert(capture.save_png("res://artifacts/" + label + ".png") == OK)
