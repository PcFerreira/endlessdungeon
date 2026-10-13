extends SceneTree

const Game = preload("res://scripts/game.gd")
const World = preload("res://scripts/world.gd")
const Types = preload("res://scripts/town_types.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/town-types-preview-saves"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.expansion.set_process_input(false)
	var selected := {}
	for seed_value in range(4):
		var world := World.new()
		world.generate(seed_value)
		for x in range(-5,6):
			for y in range(-5,6):
				var city: Dictionary = world.region_at(Vector2i(x,y) * World.REGION_SIZE).city
				var id: String = city.settlement_type_id
				if Types.DATA.types.has(id) and not selected.has(id):
					selected[id] = {"seed":seed_value,"point":city.cell + Vector2i(0,3)}
	assert(selected.size() == Types.DATA.types.size())
	for id in selected:
		var record: Dictionary = selected[id]
		game.start_run(record.seed)
		game._generate_surface(Vector2(record.point),false)
		game.begin_journey()
		game.surface_zoom = 22
		game.camera_yaw = PI * .25
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		await frame("town-type-" + id)
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point,game.player_y,game.camera_yaw)
		await frame("town-type-" + id + "-reverse")
		if Types.DATA.types[id].has("exterior_style"):
			game.surface_zoom = 14
			game._snap_camera()
			await frame("town-type-" + id + "-detail")
		print("CAPTURE: " + id)
	var city: Dictionary = game.world.region_at(Vector2i(game.player_point)).city
	var keeper: Dictionary = game.life.actors[city.residents[0].id]
	game._generate_surface(keeper.point - Vector2(1,0),false)
	game.interact()
	assert(game.state == "dialogue")
	game.expansion.town_charm()
	await frame("town-type-reader",false)
	print("PASS: %s actual added town identities from opposing views, themed exterior details and a real charm reader" % selected.size())
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
