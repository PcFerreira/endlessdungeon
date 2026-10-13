extends SceneTree

const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_life_view.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var stage: Node3D
var camera: Camera3D

class EpisodeLife extends RefCounted:
	var cities := {}
	var episode := {}
	func event_at(_id: String) -> Dictionary:
		return episode

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
	camera.size = 5.5
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	var world := World.new()
	world.generate(12345)
	var city: Dictionary = world.region_at(world.start).city.duplicate(true)
	world.load_around(city.cell)
	for biome in [0, 2]:
		var gallery := Node3D.new()
		stage.add_child(gallery)
		city.biome = biome
		var index := 0
		for visual in ["crates", "meal", "banner", "books", "market"]:
			var life := EpisodeLife.new()
			life.cities = {city.id: city}
			life.episode = {"instance_id": "fixture:%s:%s" % [biome, visual], "phase": "active", "label": visual.capitalize(), "visual": visual}
			var view := View.new()
			gallery.add_child(view)
			view._update_episode({"life": life, "world": world, "enemies": [], "player_point": Vector2(city.cell)})
			view.episode_root.position = Vector3((index % 3 - 1) * 1.8, 0, (index / 3 - .5) * 1.8)
			var floor := Voxels.cube(Vector3(1.5, .08, 1.5), Color("546d6a"))
			floor.position = view.episode_root.position + Vector3(0, -.04, 0)
			gallery.add_child(floor)
			index += 1
		for direction in [-1, 1]:
			camera.position = Vector3(direction * 5, 6, direction * 8)
			camera.look_at(Vector3(0, .45, 0))
			for frame in range(8):
				await process_frame
			RenderingServer.force_draw()
			assert(root.get_texture().get_image().save_png("res://artifacts/local-episodes-biome%s-camera%s.png" % [biome, direction]) == OK)
		gallery.queue_free()
		await process_frame
	print("PASS: five actual episode presentation recipes in both families from opposing native views")
	stage.queue_free()
	await process_frame
	quit()
