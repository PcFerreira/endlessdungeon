extends SceneTree

const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_view.gd")
const Layout = preload("res://scripts/town_voxel_layout.gd")
var directory := "res://artifacts/town-voxel-integration"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var world := World.new()
	world.generate(0)
	var samples := {}
	for x in range(-5,6):
		for y in range(-5,6):
			var city: Dictionary = world.region_at(Vector2i(x,y) * World.REGION_SIZE).city
			if city.get("theme_id", "") in Layout.THEMES and not samples.has(city.theme_id):
				samples[city.theme_id] = city.duplicate(true)
	assert(samples.size() == 8)
	var manifest := []
	for theme in Layout.THEMES:
		var city: Dictionary = samples[theme]
		world.load_around(Vector2(city.cell))
		var scene := Node3D.new()
		root.add_child(scene)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("293a4b")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("dae5ef")
		environment.environment.ambient_light_energy = .8
		scene.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48,-30,0)
		sun.light_energy = 1.1
		sun.shadow_enabled = true
		scene.add_child(sun)
		var view := View.new()
		scene.add_child(view)
		view.sync(world)
		view.update_visibility(Vector2(city.cell),city.height)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 32
		scene.add_child(camera)
		var center := Vector3(city.cell.x,city.height + 1,city.cell.y)
		camera.position = center + Vector3(19,25,24)
		camera.look_at(center)
		camera.current = true
		await frame(theme + "-front")
		camera.position = center + Vector3(-19,25,-24)
		camera.look_at(center)
		await frame(theme + "-reverse")
		manifest.append({"theme":theme,"city_id":city.id,"settlement_type":city.settlement_type_id,"biome":city.biome,"family":view.architecture.styles.family_for(city.biome),"houses":city.houses.size(),"gateway":not city.get("gateway",{}).is_empty()})
		print("CAPTURE: actual " + theme + " / " + city.id)
		scene.queue_free()
		await process_frame
	var file := FileAccess.open(directory + "/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  ") + "\n")
	file.close()
	print("PASS: eight actual procedural town renders from opposing cameras, with production terrain, buildings, markets, gates and town magic")
	quit()

func frame(label: String) -> void:
	for index in range(5):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(directory + "/" + label + ".png") == OK)
