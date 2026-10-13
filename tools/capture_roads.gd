extends SceneTree

const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_view.gd")
var world := World.new()
var view := View.new()
var camera := Camera3D.new()
var frames: Array[Dictionary] = []

func _initialize() -> void:
	world.generate(12345,6)
	var scene := Node3D.new()
	root.add_child(scene)
	scene.add_child(view)
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 34
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	light.shadow_enabled = true
	scene.add_child(light)
	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("172632")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e3eaf4")
	environment.ambient_light_energy = .7
	sky.environment = environment
	scene.add_child(sky)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/road-polish"))
	call_deferred("capture")

func capture() -> void:
	var region: Dictionary = world.region_at(world.start)
	var curve := Vector2i.ZERO
	for route in region.routes:
		for index in range(1,route.path.size() - 1):
			var point: Vector2i = route.path[index]
			var incoming: Vector2i = point - route.path[index - 1]
			var outgoing: Vector2i = route.path[index + 1] - point
			if incoming.x != 0 and incoming.y != 0 and Vector2(incoming).cross(Vector2(outgoing)) != 0 and Vector2(point).distance_to(Vector2(world.start)) > 30 and not world._natural_water(point):
				curve = point
				break
		if curve != Vector2i.ZERO:
			break
	assert(curve != Vector2i.ZERO)
	await frame("rounded-road",Vector2(curve),.8)
	await frame("rounded-road-reverse",Vector2(curve),.8 + PI)
	var selected := 0
	for bridge in region.bridges.values():
		if bridge.length < 5 or bridge.length > 22 or (bridge.from.x != bridge.to.x and bridge.from.y != bridge.to.y):
			continue
		var point := (Vector2(bridge.from) + Vector2(bridge.to)) / 2
		await frame("bridge-%s" % selected,point,.8)
		await frame("bridge-%s-reverse" % selected,point,.8 + PI)
		frames[-1].banks = [pair(bridge.landing_from),pair(bridge.landing_to)]
		selected += 1
		if selected == 2:
			break
	assert(selected == 2)
	var map := {"seed":12345,"edition":6,"frames":frames,"routes":[],"bridges":[]}
	for route in region.routes:
		map.routes.append({"id":route.id,"path":route.path.map(func(point): return pair(point))})
	for bridge in region.bridges.values():
		map.bridges.append({"id":bridge.id,"from":pair(bridge.from),"to":pair(bridge.to),"landing_from":pair(bridge.landing_from),"landing_to":pair(bridge.landing_to)})
	var output := FileAccess.open("res://artifacts/road-polish/gallery.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(map,"  "))
	print("PASS: six native actual terrain-aware road and bridge views, including both approaches and opposing cameras")
	quit()

func pair(point: Vector2i) -> Array:
	return [point.x,point.y]

func frame(name: String, point: Vector2, yaw: float) -> void:
	world.load_around(point)
	view.sync(world)
	var target := Vector3(point.x,world.ground_height(point),point.y)
	camera.position = target + Vector3(sin(yaw) * 24,23,cos(yaw) * 24)
	camera.look_at(target)
	view.update_visibility(point,target.y,yaw)
	for index in range(12):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/road-polish/%s.png" % name) == OK)
	frames.append({"image":name + ".png","point":[point.x,point.y],"yaw":yaw})
