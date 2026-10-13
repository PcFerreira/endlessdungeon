extends SceneTree

const Models = preload("res://scripts/enemy_models.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Generator = preload("res://scripts/voxel_monster_generator.gd")
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
	environment.environment.ambient_light_color = Color("e4e7f3")
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	light.light_energy = 1.15
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.5
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	var examples := {}
	for kind in range(Enemies.TYPES.size()):
		var style := Generator.appearance(Enemies.TYPES[kind],kind,"",kind % 4)
		if not examples.has(style.template):
			examples[style.template] = kind
	assert(examples.size() == Generator.catalog.data.templates.size(), "Every authored template needs a real catalogue example")
	var names: Array = examples.keys()
	for page in range(ceili(names.size() / 12.0)):
		var gallery := Node3D.new()
		stage.add_child(gallery)
		var actors: Array[Node3D] = []
		var title := _label("DUNGEON MONSTERS / BODY FAMILIES",Vector3(0,2.25,-2.8),40)
		gallery.add_child(title)
		for slot in range(mini(12,names.size() - page * 12)):
			var name: String = names[page * 12 + slot]
			var kind: int = examples[name]
			var body := Models.create(kind,kind,"",kind % 4,true)
			body.position = Vector3((slot % 4 - 1.5) * 1.8,0,(slot / 4 - 1) * 1.8)
			gallery.add_child(body)
			actors.append(body)
			var floor := Voxels.cube(Vector3(1.5,.08,1.4),Color("394654"))
			floor.position = body.position + Vector3(0,-.04,0)
			gallery.add_child(floor)
			gallery.add_child(_label(name.replace("_"," "),body.position + Vector3(0,-.12,.75),28))
		for view in range(2):
			title.position.z = -2.8 if view == 0 else 2.8
			camera.position = Vector3(5,6,11) if view == 0 else Vector3(-5,6,-11)
			camera.look_at(Vector3(0,.5,0))
			await _save("voxel-monsters-%s-%s" % [page,view])
		for slot in actors.size():
			Models.animate(actors[slot],"attack" if slot % 2 == 0 else "walk")
			var player: AnimationPlayer = actors[slot].find_children("*","AnimationPlayer",true,false)[0]
			player.advance(.3)
			player.pause()
		camera.position = Vector3(5,6,11)
		camera.look_at(Vector3(0,.5,0))
		title.text = "ATTACK / WALK / WINGS / SLIME MOTION"
		title.position.z = -2.8
		await _save("voxel-monsters-%s-motion" % page)
		gallery.queue_free()
		await process_frame
	stage.queue_free()
	await process_frame
	var Game = load("res://scripts/game.gd")
	var game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/voxel-monster-preview-saves"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	game.enter_dungeon(game.world.nearest_site(game.player_point,"dungeon"))
	assert(game.enemies.all(func(enemy): return enemy.model.get_meta("representation") == "generated_voxel"))
	var subject := {}
	for enemy in game.enemies:
		for offset in [Vector2(0,.7),Vector2(.7,0),Vector2(0,-.7),Vector2(-.7,0)]:
			var point: Vector2 = enemy.point + offset
			if game.dungeon.walkable(point) and game.dungeon.line_clear(point,enemy.point):
				subject = enemy
				game.player_point = point
				break
		if not subject.is_empty():
			break
	assert(not subject.is_empty(), "The actual encounter needs an accessible visible approach")
	game.dungeon_zoom = 12
	game.camera.size = 12
	game._snap_camera()
	game.simulate(.01)
	assert(subject.node.visible)
	game.select_target(subject)
	await _save("voxel-monsters-dungeon")
	game.queue_free()
	await process_frame
	print("PASS: all %s monster body templates from opposing views and animation poses, plus actual generated dungeon encounters" % names.size())
	quit()

func _label(text: String, point: Vector3, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = size
	label.pixel_size = .0035 if size < 40 else .006
	label.modulate = Color("ded3ba")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label

func _save(filename: String) -> void:
	for frame in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % filename) == OK)
