extends SceneTree

const Catalog = preload("res://scripts/world_dressing_catalog.gd")
const Construction = preload("res://scripts/world_construction.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
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
	camera.size = 14
	camera.position = Vector3(11, 14, 17)
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	camera.look_at(Vector3(0, .5, 0))
	var catalog := Catalog.new()
	var construction := Construction.new()
	var scenery := Scenery.new()
	for family in catalog.styles.data.families:
		var roles: Array = catalog.styles.data.cultural_roles
		for page in range(ceili(roles.size() / 12.0)):
			var gallery := Node3D.new()
			stage.add_child(gallery)
			for index in range(page * 12, mini(roles.size(), page * 12 + 12)):
				var role: String = roles[index]
				var model := scenery.model(catalog.styles.native_id(family, role), 1.3)
				var slot := index % 12
				model.position = Vector3((slot % 4 - 1.5) * 2.5, 0, (slot / 4 - 1) * 2.8)
				gallery.add_child(model)
				label(gallery, role, model.position + Vector3(0, -.12, .9))
			await frame("cultural-native-%s-%s" % [family, page])
			gallery.queue_free()
			await process_frame
		var plans := []
		for recipe in catalog.data.recipes:
			var climates: Array = recipe.get("biomes", [0, 1, 2, 3]).filter(func(biome): return catalog.styles.family_for(int(biome)) == family)
			if climates.is_empty():
				continue
			var context := {"biome": climates[0], "city_type": recipe.get("city_types", ["city_market"])[0], "family": recipe.get("families", [""])[0], "region_id": "native-style"}
			plans.append(catalog.plan(recipe, context, 12345))
		for page in range(ceili(plans.size() / 9.0)):
			var gallery := Node3D.new()
			stage.add_child(gallery)
			for index in range(page * 9, mini(plans.size(), page * 9 + 9)):
				var plan: Dictionary = plans[index]
				var model := construction.build(plan)
				assert(model != null and model.get_meta("visual_family") == family)
				var slot := index % 9
				model.position = Vector3((slot % 3 - 1) * 3.6, 0, (slot / 3 - 1) * 3.1)
				gallery.add_child(model)
				label(gallery, plan.recipe_id, model.position + Vector3(0, -.12, 1.2))
			await frame("cultural-ensembles-%s-%s" % [family, page])
			gallery.queue_free()
			await process_frame
	print("PASS: both complete cultural role galleries and every climate-eligible assembly in each biome style")
	stage.queue_free()
	await process_frame
	quit()

func label(parent: Node3D, title: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = title.replace("_", " ")
	label.position = point
	label.font_size = 30
	label.pixel_size = .005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func frame(name: String) -> void:
	for index in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK)
