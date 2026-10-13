extends SceneTree

const Actors = preload("res://scripts/actor_models.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202936")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e5e9f3")
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	light.light_energy = 1.15
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	var roles := ["fountain_keeper", "milewarden", "relic_mender", "retired_delver", "guard", "merchant", "pilgrim", "courier", "villager", "scholar", "hunter", "relic_mender"]
	for biome in range(4):
		var gallery := Node3D.new()
		stage.add_child(gallery)
		var title := Label3D.new()
		title.text = "VOXEL PEOPLE / " + ["River & moss", "Plum & ink", "Rust & slate", "Orchard & rose"][biome]
		title.position = Vector3(0,2.1,-2.8)
		title.font_size = 42
		title.pixel_size = .006
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		gallery.add_child(title)
		var actors: Array[Node3D] = []
		for index in range(roles.size()):
			var context := {"id":"gallery:%s:%s" % [biome,index], "city_id":"gallery-town:%s:%s" % [biome,index % 2], "biome":biome, "role":roles[index]}
			var actor := Actors.create(index,context)
			actor.position = Vector3((index % 4 - 1.5) * 1.75,0,(index / 4 - 1) * 1.7)
			gallery.add_child(actor)
			actors.append(actor)
			var floor := Voxels.cube(Vector3(1.35,.08,1.2),Color("3a4757"))
			floor.position = actor.position + Vector3(0,-.04,0)
			gallery.add_child(floor)
			var label := Label3D.new()
			label.text = roles[index].replace("_", " ")
			label.position = actor.position + Vector3(0,-.12,.62)
			label.font_size = 28
			label.pixel_size = .0035
			label.modulate = Color("d2c6ac")
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			gallery.add_child(label)
		for view in range(2):
			title.position.z = -2.8 if view == 0 else 2.8
			camera.position = Vector3(5,6,11) if view == 0 else Vector3(-5,6,-11)
			camera.look_at(Vector3(0,.5,0))
			await _save("voxel-npcs-%s-%s" % [biome,view])
		for index in range(actors.size()):
			var player: AnimationPlayer = actors[index].get_child(0).get_node("AnimationPlayer")
			player.play("Attack" if roles[index] in ["guard","milewarden"] else ["Idle", "Walk", "Wave", "Idle"][index % 4])
			player.advance(.3)
			player.pause()
		camera.position = Vector3(5,6,11)
		camera.look_at(Vector3(0,.5,0))
		title.text = "IDLE / WALK / GREETING / WATCH ATTACK"
		title.position.z = -2.8
		await _save("voxel-npcs-%s-motion" % biome)
		gallery.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	var Game = load("res://scripts/game.gd")
	var game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/voxel-npc-preview-saves"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	var resident: Dictionary = game.life.residents().filter(func(actor): return not actor.get("traveling",false)).back()
	game.surface_zoom = 12
	game.player_point = resident.point + Vector2(.6,0)
	game._snap_camera()
	assert(game.expansion.target().get("id", "") == resident.id)
	await _save("voxel-npcs-world")
	game.interact()
	assert(game.state == "dialogue" and game.expansion.speaker.id == resident.id)
	await _save("voxel-npcs-dialogue")
	game.queue_free()
	await process_frame
	print("PASS: 48 actual generated NPCs, four climate palettes, opposing views, limb animation poses and actual world/dialogue presentation")
	quit()

func _save(filename: String) -> void:
	for frame in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % filename) == OK)
