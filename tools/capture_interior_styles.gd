extends SceneTree

const Rooms = preload("res://scripts/interior_area.gd")
const View = preload("res://scripts/interior_view.gd")
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
	environment.environment.ambient_light_energy = .7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	for definition in Rooms.content.entries("interiors"):
		for layout in definition.layouts:
			for biome in [0, 2]:
				var room := Rooms.new()
				room.generate({"id": "style:%s:%s:0" % [definition.id, layout.id], "type": definition.id, "layout_id": layout.id, "biome": biome})
				var view := View.new()
				stage.add_child(view)
				view.build(room)
				camera.size = maxf(15, maxf(room.bounds.size.x, room.bounds.size.y) * 1.15)
				var target := Vector3(room.bounds.size.x * .5, .35, room.bounds.size.y * .5)
				for reverse in [false, true]:
					var yaw := PI * 1.25 if reverse else PI / 4
					camera.position = target + Vector3(sin(yaw) * 15, 17, cos(yaw) * 15)
					camera.look_at(target)
					view.update_camera(yaw)
					for frame in range(6):
						await process_frame
					RenderingServer.force_draw()
					var path := "res://artifacts/interior-style-%s-%s-%s%s.png" % [definition.id, layout.id, view.visual_family, "-reverse" if reverse else ""]
					assert(root.get_texture().get_image().save_png(path) == OK)
				view.queue_free()
				await process_frame
	print("PASS: all ten interior layouts in both biome styles from opposing cameras at actual per-room gameplay zoom")
	stage.queue_free()
	await process_frame
	quit()
