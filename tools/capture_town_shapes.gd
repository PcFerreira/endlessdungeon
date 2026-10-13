extends SceneTree

const Areas = preload("res://scripts/area_catalog.gd")
const Models = preload("res://scripts/world_voxels.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("6e8e9b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e4e9d3")
	environment.environment.ambient_light_energy = .7
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	scene.add_child(sun)
	var ground := Voxels.cube(Vector3(25,.4,19),Color("789261"))
	ground.position = Vector3(0,-.24,0)
	scene.add_child(ground)
	var index := 0
	for use_id in Areas.DATA.building_uses:
		var use: Dictionary = Areas.DATA.building_uses[use_id]
		var architecture: Dictionary = Areas.CITIES[Areas.DATA.start_city].architecture.duplicate(true)
		architecture.merge(use.get("architecture",{}),true)
		var facing: Vector2i = [Vector2i.DOWN,Vector2i.RIGHT,Vector2i.UP,Vector2i.LEFT][index % 4]
		var house := {"footprint": Rect2i(0,0,3,2),"height": architecture.height[0],"style": index % 4,"architecture": architecture,"facing": facing}
		var model := Voxels.instance(Models.house(house,1))
		model.position = Vector3((index % 4) * 5 - 7.5,0,(index / 4) * 5 - 4)
		model.rotation.y = atan2(facing.x,facing.y)
		scene.add_child(model)
		label(scene,use.name,model.position + Vector3(0,3.5,0))
		index += 1
	index = 0
	for city_id in ["city_crossroads","city_woodland","city_mushroom_common","city_winter_hearth"]:
		var recipe: Dictionary = Areas.CITIES[city_id].outdoor_lots[1]
		var model := Voxels.instance(Models.outdoor_lot({"kind": recipe.kind,"recipe": recipe}))
		model.position = Vector3(index * 5 - 7.5,0,6)
		scene.add_child(model)
		label(scene,recipe.name,model.position + Vector3(0,1.8,0))
		index += 1
	var market_recipe: Dictionary = Areas.CITIES["city_market"].outdoor_lots[0]
	var market := Voxels.instance(Models.outdoor_lot({"kind": "market","recipe": market_recipe}))
	market.position = Vector3(0,0,-8)
	scene.add_child(market)
	label(scene,market_recipe.name,market.position + Vector3(0,1.8,0))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27
	camera.position = Vector3(15,22,24)
	scene.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	for angle in ["front","reverse"]:
		for frame in range(5):
			await process_frame
		RenderingServer.force_draw()
		assert(root.get_texture().get_image().save_png("res://artifacts/town-uses-" + angle + ".png") == OK)
		camera.position = Vector3(-15,22,-24)
		camera.look_at(Vector3.ZERO)
	print("PASS: native building uses, directional rectangular footprints, awnings, crop forms and supported market fallback")
	quit()

func label(parent: Node3D, text: String, point: Vector3) -> void:
	var node := Label3D.new()
	node.text = text
	node.position = point
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.font_size = 32
	node.pixel_size = .008
	parent.add_child(node)
