extends SceneTree

const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_view.gd")
const Catalog = preload("res://scripts/world_dressing_catalog.gd")
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("24343b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	var world := World.new()
	world.generate(12345)
	var points := {}
	for x in range(-2048, 2049, 64):
		for y in range(-2048, 2049, 64):
			var cell := Vector2i(x, y)
			var biome := world._biome_at(cell)
			if points.has(biome):
				continue
			if not [Vector2i(-20, -20), Vector2i(20, -20), Vector2i(-20, 20), Vector2i(20, 20)].all(func(offset): return world._biome_at(cell + offset) == biome):
				continue
			var region: Dictionary = world.region_at(cell)
			var info := world.cell_info(cell)
			if World.city_distance(Vector2(cell), region.city.cell) >= 30 and info.terrain == "land" and info.walkable:
				points[biome] = cell
	assert(points.size() == 4, "Find an actual quiet landscape in every climate")
	for biome in points:
		var point: Vector2i = points[biome]
		world.load_around(Vector2(point))
		var view := View.new()
		stage.add_child(view)
		view.sync(world)
		var target := Vector3(point.x, world.ground_height(Vector2(point)) + .7, point.y)
		for reverse in [false, true]:
			var yaw := PI * 1.25 if reverse else PI / 4
			camera.position = target + Vector3(sin(yaw) * 15, 16, cos(yaw) * 15)
			camera.look_at(target)
			view.update_visibility(Vector2(point), target.y, yaw)
			await frame("environment-biome-%s%s" % [biome, "-reverse" if reverse else ""])
		view.queue_free()
		await process_frame
	var catalog := Catalog.new()
	var roles: Array = catalog.styles.data.roles
	camera.size = 13
	for family in catalog.styles.data.families:
		var gallery := Node3D.new()
		stage.add_child(gallery)
		for index in range(roles.size()):
			var role: String = roles[index]
			var size: Array = catalog.styles.data.sizes[role]
			var model := catalog.styles.native_model(role, family, Vector2.ONE * float(size[0]), float(size[1]))
			model.position = Vector3((index % 3 - 1) * 3, 0, (index / 3 - 1) * 3)
			gallery.add_child(model)
		camera.position = Vector3(10, 11, 13)
		camera.look_at(Vector3(0, .8, 0))
		await frame("environment-fallback-" + family)
		gallery.queue_free()
		await process_frame
	print("PASS: actual four-biome landscapes from both sides and both complete same-family fallback galleries")
	stage.queue_free()
	await process_frame
	quit()

func frame(name: String) -> void:
	for index in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK)
