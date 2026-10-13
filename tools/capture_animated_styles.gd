extends SceneTree

const Registry = preload("res://scripts/asset_registry.gd")
const Style = preload("res://scripts/animated_model_style.gd")
const EnemyModels = preload("res://scripts/enemy_models.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var stage: Node3D
var camera: Camera3D
var models := []

func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("28343e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9
	camera.position = Vector3(8, 9, 14)
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	camera.look_at(Vector3(0, .6, 0))
	var registry := Registry.new()
	var renderer := Style.new()
	var ids := ["quaternius_ultimate_monsters/glTF/Orc.gltf", "quaternius_cube_world/Animals/glTF/Cat.gltf", "kaykit_skeletons/content/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Mage.glb"]
	for row in range(ids.size()):
		for column in range(3):
			var holder := Node3D.new()
			var model := registry.instantiate(ids[row])
			assert(model != null)
			if column > 0:
				assert(renderer.convert(model, "block_voxel" if column == 1 else "flat_lowpoly", 18))
			holder.add_child(model)
			stage.add_child(holder)
			var box := EnemyModels.bounds(model)
			var factor := 1.3 / maxf(box.size.x, maxf(box.size.y, box.size.z))
			holder.scale = Vector3.ONE * factor
			model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
			holder.position = Vector3((column - 1) * 2.5, 0, (row - 1) * 2.1)
			models.append(holder)
			var floor := Voxels.cube(Vector3(1.5, .1, 1.5), Color("52686d"))
			floor.position = holder.position + Vector3(0, -.05, 0)
			stage.add_child(floor)
			var label := Label3D.new()
			label.text = ["Source", "Block voxel", "Faceted"][column]
			label.position = holder.position + Vector3(0, -.2, .8)
			label.font_size = 36
			label.pixel_size = .005
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			stage.add_child(label)
	for model in models:
		EnemyModels.animate(model, "walk")
	for pose in range(2):
		for player in stage.find_children("*", "AnimationPlayer", true, false):
			player.advance(.25)
		for frame in range(8):
			await process_frame
		RenderingServer.force_draw()
		assert(root.get_texture().get_image().save_png("res://artifacts/animated-styles-%s.png" % pose) == OK)
	print("PASS: three actual rigged sources and both geometric derivatives in two moving poses")
	stage.queue_free()
	await process_frame
	quit()
