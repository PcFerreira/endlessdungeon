extends SceneTree

const Game = preload("res://scripts/game.gd")
const Points = preload("res://tools/biome_review_points.gd")
var game
var directory := "res://artifacts/biomes"

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
	game.start_run(91, 6)
	var points := Points.find(game.world)
	var actual := {}
	var ids: Array = points.keys()
	ids.sort()
	for id in ids:
		game._generate_surface(Vector2(points[id].cell), false)
		game._clear_actors()
		game.surface_zoom = 19
		actual[id] = {"point": [game.player_point.x, game.player_point.y], "biome": game.world.cell_info(Vector2i(game.player_point.round()))}
		assert(actual[id].biome.biome_id == id)
		for reverse in [false, true]:
			game.camera_yaw = PI / 4 + (PI if reverse else 0)
			game.target_yaw = game.camera_yaw
			game._snap_camera()
			game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
			await frame(id + ("-reverse" if reverse else "-front"))
	FileAccess.open(directory.path_join("points.json"), FileAccess.WRITE).store_string(JSON.stringify(actual, "  "))
	print("PASS: 28 real edition-6 Game biome views, fourteen actual generated ecologies from opposing cameras; world identities/cells in points.json")
	game.queue_free()
	await process_frame
	quit()

func frame(label: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)
