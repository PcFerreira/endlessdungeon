extends SceneTree

const Scenery = preload("res://scripts/scenery.gd")
var scene: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	assert(DirAccess.make_dir_recursive_absolute("res://artifacts/town-voxels") == OK)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_voxels/catalog.json"))
	for theme in ["japanese","chinese","korean","halloween","christmas","cyberpunk","mage","fairy"]:
		scene = Node3D.new()
		root.add_child(scene)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("283544")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("e3e4df")
		environment.environment.ambient_light_energy = .7
		scene.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48,-30,0)
		sun.light_energy = 1.1
		sun.shadow_enabled = true
		scene.add_child(sun)
		var assets: Array = catalog.assets.filter(func(asset): return asset.theme == theme)
		var index := 0
		for asset in assets:
			var packed: PackedScene = load(asset.scene)
			var model: Node3D = packed.instantiate()
			model.position = Vector3((index % 3 - 1) * 7,0,(index / 3) * 7 - 3)
			scene.add_child(model)
			var floor_node := MeshInstance3D.new()
			var floor_mesh := BoxMesh.new()
			floor_mesh.size = Vector3(6.2,.12,5.5)
			floor_node.mesh = floor_mesh
			var floor_material := StandardMaterial3D.new()
			floor_material.albedo_color = Color("637079")
			floor_node.material_override = floor_material
			floor_node.position = model.position + Vector3(0,-.07,0)
			scene.add_child(floor_node)
			var name := Label3D.new()
			name.text = asset.name
			name.font_size = 32
			name.pixel_size = .008
			name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			name.position = model.position + Vector3(0,asset.bounds.size[1] + .45,0)
			scene.add_child(name)
			index += 1
		camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 23 if assets.size() > 5 else 21
		camera.position = Vector3(15,19,22)
		scene.add_child(camera)
		camera.look_at(Vector3(0,1,1))
		camera.current = true
		await frame(theme + "-front")
		camera.position = Vector3(-15,19,-22)
		camera.look_at(Vector3(0,1,1))
		await frame(theme + "-reverse")
		print("CAPTURE: " + theme + " / " + str(assets.size()) + " assets")
		scene.queue_free()
		await process_frame
	print("PASS: eight original themed voxel galleries, 44 exported assets, opposing cameras")
	quit()

func frame(label: String) -> void:
	for index in range(5):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/town-voxels/" + label + ".png") == OK)
