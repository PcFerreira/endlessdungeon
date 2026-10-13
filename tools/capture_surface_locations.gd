extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "res://artifacts/surface-locations"

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
	game.start_run(0, 5)
	var selected := {}
	for radius in range(33):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				for raw in game.world.site_planner.slots(Vector2i(x, y)).locations:
					var biome: int = game.world._biome_at(raw.cell)
					var key: String = "%s-%s" % [raw.type, biome]
					if not selected.has(key):
						selected[key] = {"id": raw.id, "cell": raw.cell}
		if selected.size() == 16:
			break
	assert(selected.size() == 16, "Native review needs actual generated places in all four climates")
	var ids: Array = selected.keys()
	ids.sort()
	var captured := []
	for id in ids:
		var found: Dictionary = selected[id]
		var site: Dictionary = game.world.site_by_id(found.id, found.cell)
		assert(not site.is_empty())
		game.surface_zoom = 24
		game._generate_surface(Vector2(site.cell), false)
		game._clear_actors()
		game.world_items.register_location()
		game.exploration.observe_sites()
		for reverse in [false, true]:
			game.camera_yaw = atan2(site.facing.x, site.facing.y) + .65 + (PI if reverse else 0)
			game.target_yaw = game.camera_yaw
			game._snap_camera()
			game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
			await frame("%s-%s" % [id, "reverse" if reverse else "front"])
		captured.append({"kind": site.type, "biome": site.biome, "id": site.id, "cell": [site.cell.x, site.cell.y], "facing": [site.facing.x, site.facing.y]})
	FileAccess.open(directory.path_join("sites.json"), FileAccess.WRITE).store_string(JSON.stringify(captured, "  "))
	print("PASS: 32 actual Game views of four composed independent purposes across all four generated climates, opposing cameras at surface zoom 24; real IDs/facings in sites.json")
	game.queue_free()
	await process_frame
	quit()

func frame(label: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)
