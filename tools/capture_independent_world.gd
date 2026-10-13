extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "res://artifacts/independent-world"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory.path_join("preview-saves")
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	call_deferred("capture")

func capture() -> void:
	game.start_run(91, 5)
	game._clear_actors()
	await frame("starter")
	var town := {}
	var entry := {}
	for x in range(-2, 3):
		for y in range(-2, 3):
			var region: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE)
			if not region.city.is_empty() and region.coordinate != Vector2i.ZERO:
				town = region.city
			if region.city.is_empty():
				for site in region.dungeons:
					if site.facing != Vector2i.DOWN:
						entry = site
	assert(not town.is_empty() and not entry.is_empty())
	game._generate_surface(Vector2(town.approach), false)
	game._clear_actors()
	game.exploration.observe_sites()
	await frame("jittered-town")
	game._generate_surface(Vector2(entry.approach), false)
	game._clear_actors()
	game.exploration.observe_sites()
	game.camera_yaw = atan2(entry.facing.x, entry.facing.y) + .65
	game.target_yaw = game.camera_yaw
	game._snap_camera()
	game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
	await frame("town-free-oriented-entry")
	game.toggle_map()
	await frame("actual-known-sites-and-roads")
	game.toggle_map()
	game.player_point = Vector2(entry.cell)
	game.grounded = true
	game.interact()
	assert(game.layer == "dungeon" and game.active_dungeon.id == entry.id)
	await frame("actual-dungeon-entry")
	game.return_to_surface()
	game._clear_actors()
	assert(game.player_point.is_equal_approx(Vector2(entry.approach)))
	await frame("actual-oriented-return")
	print("PASS: staged native Game; actual starter/jittered town, town-free oriented entrance, progressive atlas with real roads, physical E dungeon and oriented return. Town ", town.id, " / entry ", entry.id, " / facing ", entry.facing)
	game.queue_free()
	await process_frame
	quit()

func frame(label: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)
