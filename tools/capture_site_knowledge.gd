extends SceneTree

const Game = preload("res://scripts/game.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const Map = preload("res://scripts/minimap.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/site-knowledge-preview-saves"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func atlas():
	for control in game.interface.find_children("*", "Control", true, false):
		if control.get_script() == Map and control.world_map_mode:
			return control
	return null

func capture() -> void:
	game.set_physics_process(false)
	var marker := {}
	var region := {}
	for seed_value in [91, 12345, 7763, 2048]:
		game.start_run(seed_value)
		game.begin_journey()
		game._clear_actors()
		region = game.world.region_at(game.world.start)
		marker = Sites.plan(game.world, region, game.exploration.catalog)
		if not marker.is_empty() and Vector2(marker.point[0], marker.point[1]).distance_to(Vector2(marker.site_cell[0], marker.site_cell[1])) > 13:
			break
	assert(not marker.is_empty())
	game.toggle_map()
	await frame("knowledge-atlas-unknown")
	assert(atlas() != null and atlas().map_sites().size() == 1, "A new atlas must not reveal every nearby dungeon")
	game.toggle_map()
	game._generate_surface(Vector2(marker.approach[0], marker.approach[1]), false)
	game._clear_actors()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	game._unhandled_key_input(event)
	assert(game.state == "discovery_reader")
	await frame("knowledge-real-clue")
	game.exploration.mark_site(marker.id)
	var site: Dictionary = game.waypoint
	assert(site.id == marker.site_id and game.exploration.knowledge.state(site.id) == "rumor")
	game.exploration.close()
	game.toggle_map()
	await frame("knowledge-atlas-reported")
	assert(atlas().map_sites().any(func(entry): return entry.id == site.id and entry.knowledge == "rumor"))
	game.toggle_map()
	game._generate_surface(Vector2(site.cell) + Vector2(0, 2), false)
	game._clear_actors()
	game.exploration.observe_sites()
	assert(game.exploration.knowledge.state(site.id) == "seen")
	await frame("knowledge-approach-seen")
	game.toggle_map()
	await frame("knowledge-atlas-seen")
	game.toggle_map()
	game._unhandled_key_input(event)
	assert(game.layer == "dungeon" and game.exploration.knowledge.state(site.id) == "visited")
	await frame("knowledge-actual-entry")
	game.return_to_surface()
	game._clear_actors()
	game._generate_surface(Vector2(region.city.cell) + Vector2(0, 3), false)
	game._clear_actors()
	assert(game.save_game(1))
	assert(game.load_game(1))
	game.toggle_map()
	await frame("knowledge-atlas-visited-restored")
	assert(atlas().map_sites().any(func(entry): return entry.id == site.id and entry.knowledge == "visited"))
	print("PASS: native unknown/reported/seen/visited atlas, actual clue and dungeon E, visible approach, route and disk restoration")
	game.queue_free()
	await process_frame
	quit()

func frame(label: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK)
