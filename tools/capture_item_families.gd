extends SceneTree

const Catalog = preload("res://scripts/item_catalog.gd")
const Visual = preload("res://scripts/item_visual.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("293b43")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	var samples := ["gold_coin", "health_potion", "aether_potion", "ember_shard", "iron_sword", "arcane_staff", "traveler_coat", "silver_charm", "oak_chair", "rune_lantern", "wool_rug"]
	var groups := {}
	for id in Catalog.definitions:
		var item: Dictionary = Catalog.definitions[id]
		if item.get("world_prop", false) or not item.has("source_pack"):
			continue
		var key: String = item.source_pack + ":" + item.kind
		if not groups.has(key):
			groups[key] = id
	for id in groups.values():
		if id not in samples:
			samples.append(id)
	var pictures := 0
	for family in ["block_voxel", "flat_lowpoly"]:
		for page in range(ceili(samples.size() / 12.0)):
			var gallery := Node3D.new()
			stage.add_child(gallery)
			for slot in range(12):
				var index := page * 12 + slot
				if index >= samples.size():
					break
				var id: String = samples[index]
				var model := Visual.model(Catalog.definitions[id], 1.05, family, id)
				assert(model != null, id + " / " + Visual.families.error)
				assert(model.get_meta("visual_family") == family)
				model.position = Vector3((slot % 4 - 1.5) * 2, 0, (slot / 4 - 1) * 2)
				gallery.add_child(model)
				var floor := Voxels.cube(Vector3(1.3, .08, 1.3), Color("546d6a"))
				floor.position = model.position + Vector3(0, -.04, 0)
				gallery.add_child(floor)
				var label := Label3D.new()
				label.text = Catalog.definitions[id].name
				label.position = model.position + Vector3(0, -.17, .75)
				label.font_size = 24
				label.pixel_size = .005
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				gallery.add_child(label)
			for direction in [-1, 1]:
				camera.position = Vector3(direction * 5, 9, direction * 15)
				camera.look_at(Vector3(0, .3, 0))
				for frame in range(8):
					await process_frame
				RenderingServer.force_draw()
				assert(root.get_texture().get_image().save_png("res://artifacts/items-family-%s-page%s-camera%s.png" % [family, page, direction]) == OK)
				pictures += 1
			gallery.queue_free()
			await process_frame
	print("PASS: %s actual item-source/kind representatives and core rewards/furniture in both families, %s opposing native views" % [samples.size(), pictures])
	stage.queue_free()
	await process_frame
	quit()
