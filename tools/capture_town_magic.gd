extends SceneTree

const Game = preload("res://scripts/game.gd")
const World = preload("res://scripts/world.gd")
const Areas = preload("res://scripts/area_catalog.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/town-magic-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.expansion.set_process_input(false)
	var selected := {}
	for seed_value in range(16):
		var world := World.new()
		world.generate(seed_value)
		for x in range(-4,5):
			for y in range(-4,5):
				var city: Dictionary = world.region_at(Vector2i(x,y) * World.REGION_SIZE).city
				if Areas.DATA.magic_profiles.has(city.magic.profile_id) and not selected.has(city.magic.profile_id):
					selected[city.magic.profile_id] = {"seed": seed_value,"point": city.cell + Vector2i(0,3)}
		if selected.size() == Areas.DATA.magic_profiles.size():
			break
	assert(selected.size() == Areas.DATA.magic_profiles.size())
	for profile_id in selected:
		var record: Dictionary = selected[profile_id]
		game.start_run(record.seed)
		game._generate_surface(Vector2(record.point),false)
		game.waypoint = game.world.nearest_site(game.player_point,"dungeon")
		game.begin_journey()
		game.camera_yaw = PI * .25
		game.target_yaw = game.camera_yaw
		game.surface_zoom = 24
		game._snap_camera()
		await frame("town-magic-" + profile_id)
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point,game.player_y,game.camera_yaw)
		await frame("town-magic-" + profile_id + "-reverse")
		game.surface_zoom = 14
		game._snap_camera()
		await frame("town-magic-" + profile_id + "-detail")
	game.start_run(12345)
	game.begin_journey()
	var city: Dictionary = game.world.region_at(game.world.start).city
	var keeper: Dictionary = game.life.actors[city.residents[0].id]
	game._generate_surface(keeper.point - Vector2(1,0),false)
	game.interact()
	assert(game.state == "dialogue")
	game.expansion.town_charm()
	await frame("town-magic-reader",false)
	print("PASS: six actual dense towns/civic charms from both sides, normal camera detail and real resident account")
	game.queue_free()
	await process_frame
	quit()

func frame(label: String, playing: bool = true) -> void:
	if playing:
		game.state = "playing"
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK)
