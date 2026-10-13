extends SceneTree

const Scenery = preload("res://scripts/scenery.gd")
var scenery := Scenery.new()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("333e4b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = .6
	environment.environment = settings
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	scene.add_child(camera)
	var base := "kaykit_furniture/content/addons/kaykit_furniture_bits/Assets/gltf/"
	for name in ["shelf_A_big", "shelf_B_large_decorated", "chair_A", "bed_single_A"]:
		var model := scenery.model(base + name + ".gltf", 1.3, 1.2)
		scene.add_child(model)
		for side in [1, -1]:
			camera.position = Vector3(1.5 * side, 2.1, 4.0 * side)
			camera.look_at(Vector3(0, .6, 0))
			for index in range(4):
				await process_frame
			RenderingServer.force_draw()
			assert(root.get_texture().get_image().save_png("res://artifacts/facing-%s-%s.png" % [name, "positive-z" if side > 0 else "negative-z"]) == OK)
		scene.remove_child(model)
		model.free()
	scene.queue_free()
	await process_frame
	print("PASS: native positive/negative Z views of shelf, seat and bed authored fronts")
	quit()
