extends SceneTree

const Dungeon = preload("res://scripts/dungeon.gd")
const View = preload("res://scripts/dungeon_view.gd")
const Areas = preload("res://scripts/area_catalog.gd")
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17232c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	for family in Areas.DUNGEONS:
		var dungeon := Dungeon.new()
		dungeon.generate(12345, 1, family)
		var view := View.new()
		stage.add_child(view)
		view.build(dungeon, 1)
		for node in view.cell_nodes.values():
			node.visible = true
		view.portal.visible = false
		for index in range(4):
			var center := Vector2(dungeon.rooms[index].get_center())
			var target := Vector3(center.x, .35, center.y)
			for reverse in [false, true]:
				var yaw := PI * 1.25 if reverse else PI / 4
				camera.position = target + Vector3(sin(yaw) * 11, 12, cos(yaw) * 11)
				camera.look_at(target)
				view.update_camera(yaw)
				for frame in range(5):
					await process_frame
				RenderingServer.force_draw()
				var path := "res://artifacts/purpose-%s-%s%s.png" % [family, index, "-reverse" if reverse else ""]
				assert(root.get_texture().get_image().save_png(path) == OK)
		view.queue_free()
		await process_frame
	print("PASS: all 24 room roles rendered from both sides at the default dungeon gameplay zoom")
	stage.queue_free()
	await process_frame
	quit()
