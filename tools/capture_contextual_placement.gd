extends SceneTree

const Game = preload("res://scripts/game.gd")
const Areas = preload("res://scripts/area_catalog.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://placement-preview-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	var city: Dictionary = game.world.region_at(game.world.start).city
	var site: Dictionary = game.world.region_at(game.world.start).dungeons[0].duplicate(true)
	for family in Areas.DUNGEONS:
		site.id = "placement-preview:" + family
		site.family = family
		game.enter_dungeon(site)
		game._clear_actors()
		game.notification_time = 0
		game.camera.size = 14
		for yaw in [PI / 4, PI * 1.25]:
			game.target_yaw = yaw
			game.camera_yaw = yaw
			game._snap_camera()
			game.dungeon_view.update_camera(yaw)
			await frame("placement-" + family + ("-reverse" if yaw > PI else ""))
		game.return_to_surface()
	for definition in game.InteriorArea.content.entries("interiors"):
		var place: Dictionary = game.interiors.describe(city, city.houses[0])
		place.type = definition.id
		place.name = definition.name
		for layout in definition.layouts:
			game._generate_surface(place.approach)
			place.layout_id = layout.id
			game._generate_interior(place.duplicate(true))
			game.notification_time = 0
			game.target_yaw = PI / 4
			game.camera_yaw = PI / 4
			game._snap_camera()
			game.interiors.view.update_camera(game.camera_yaw)
			await frame("placement-room-" + place.type + "-" + layout.id)
	print("PASS: contextual dressing native captures for six dungeon families in both orientations and all ten interior layouts")
	var directory: String = game.save_directory
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	quit()

func frame(label: String) -> void:
	for index in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
