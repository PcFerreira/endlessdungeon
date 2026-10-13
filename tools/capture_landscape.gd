extends SceneTree

const Game = preload("res://scripts/game.gd")
const World = preload("res://scripts/world.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/landscape-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.expansion.set_process_input(false)
	game.start_run(12345)
	game.begin_journey()
	climate_map(false)
	climate_map(true)
	var layouts := {}
	for seed_value in range(24):
		var world := World.new()
		world.generate(seed_value)
		var city: Dictionary = world.region_at(world.start).city
		if not layouts.has(city.layout_id):
			layouts[city.layout_id] = seed_value
	for layout in layouts:
		game.start_run(layouts[layout])
		game.surface_zoom = 21
		game._snap_camera()
		await frame("town-layout-" + layout)
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point,game.player_y,game.camera_yaw)
		await frame("town-layout-" + layout + "-reverse")
	game.start_run(12345)
	await frame("landscape-atlas","map")
	game.state = "playing"
	var spans := {}
	for x in range(-4,5):
		for y in range(-4,5):
			var region: Dictionary = game.world.region_at(Vector2i(x,y) * World.REGION_SIZE)
			for bridge in region.bridges.values():
				if bridge.length >= 6 and bridge.length <= 38:
					spans["east-west" if bridge.axis.x != 0 else "north-south"] = bridge
	assert(spans.size() == 2)
	for direction in spans:
		var bridge: Dictionary = spans[direction]
		var point := (Vector2(bridge.from) + Vector2(bridge.to)) * .5
		game._generate_surface(point,false)
		assert(game.world.cell_info(Vector2i(game.player_point.round())).terrain == "bridge")
		game.surface_zoom = 24
		game._snap_camera()
		game.world_view.update_visibility(game.player_point,game.player_y,game.camera_yaw)
		await frame("bridge-" + direction)
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point,game.player_y,game.camera_yaw)
		await frame("bridge-" + direction + "-reverse")
	print("PASS: biome maps before/after; three connected town layouts and two bridge orientations from opposing cameras")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func climate_map(previous: bool) -> void:
	var world := World.new()
	world.generate(12345)
	if previous:
		world.temperature.frequency = .009
		world.temperature.fractal_octaves = 3
		world.moisture.frequency = .015
		world.moisture.fractal_octaves = 3
	var map := Image.create(512,512,false,Image.FORMAT_RGB8)
	for x in range(512):
		for y in range(512):
			map.set_pixel(x,y,World.MAP_COLORS[world._biome_at(Vector2i(x - 256,y - 256) * 4)])
	assert(map.save_png("res://artifacts/climate-%s.png" % ("before" if previous else "after")) == OK)

func frame(label: String, state: String = "playing") -> void:
	game.state = state
	for index in range(5):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
