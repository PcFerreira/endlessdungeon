extends SubViewportContainer

const Models = preload("res://scripts/enemy_models.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Visual = preload("res://scripts/item_visual.gd")
const Registry = preload("res://scripts/asset_registry.gd")
signal changed(description: String)
var viewport := SubViewport.new()
var stage := Node3D.new()
var actor := Node3D.new()
var camera := Camera3D.new()
var target := Node3D.new()
var registry := Registry.new()
var definition := {}
var body: Node3D
var mode := "Idle"
var running := true
var depth := 1
var angle := .6
var elevation := .45
var distance := 4.0
var time := 0.0
var cooldown := 0.0
var attack_timer := 0.0
var provoked := false
var texture_view := TextureRect.new()
var audio := AudioStreamPlayer.new()

func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(420, 360)
	viewport.size = Vector2i(800, 700)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(stage)
	stage.add_child(actor)
	stage.add_child(target)
	stage.add_child(camera)
	camera.current = true
	camera.fov = 45
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111a29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b7c8e3")
	environment.environment.ambient_light_energy = .7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.7
	stage.add_child(light)
	_box(stage, Vector3(0, -.07, 0), Vector3(14, .1, 14), Color("253044"))
	for index in range(-7, 8):
		_box(stage, Vector3(index, -.01, 0), Vector3(.015, .015, 14), Color("35445a"))
		_box(stage, Vector3(0, -.01, index), Vector3(14, .015, .015), Color("35445a"))
	_box(actor, Vector3(0, .035, .6), Vector3(.04, .04, 1.0), Color("51d5b1"))
	_box(actor, Vector3(-.12, .035, 1.05), Vector3(.3, .04, .04), Color("51d5b1")).rotation.y = -.7
	_box(actor, Vector3(.12, .035, 1.05), Vector3(.3, .04, .04), Color("51d5b1")).rotation.y = .7
	_label(actor, "FRONT +Z", Vector3(0, .15, 1.3), Color("51d5b1"))
	_label(actor, "BACK", Vector3(0, .15, -1.3), Color("ee927f"))
	_box(target, Vector3(0, .12, 0), Vector3(.25, .25, .25), Color("f4c46c"))
	target.position = Vector3(3, 0, 0)
	texture_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_view.hide()
	add_child(texture_view)
	add_child(audio)
	gui_input.connect(_input_preview)
	_update_camera()

func clear() -> void:
	if is_instance_valid(body):
		body.free()
	body = null
	audio.stop()
	texture_view.hide()
	actor.position = Vector3.ZERO
	actor.rotation = Vector3.ZERO
	definition = {}
	time = 0
	cooldown = 0
	attack_timer = 0
	provoked = false

func monster(entry: Dictionary, biome: int, dungeon: bool) -> void:
	clear()
	definition = entry.duplicate(true)
	var index := -1
	for candidate in range(Enemies.TYPES.size()):
		if Enemies.TYPES[candidate].id == entry.id:
			index = candidate
			break
	if index < 0:
		Enemies.TYPES.append(entry)
		index = Enemies.TYPES.size() - 1
	var original: Dictionary = Enemies.TYPES[index]
	Enemies.TYPES[index] = entry
	body = Models.create(index, 42, "", biome, dungeon)
	Enemies.TYPES[index] = original
	actor.add_child(body)
	_models_loaded()

func item(entry: Dictionary, biome: int) -> void:
	clear()
	body = Visual.model(entry, 1.5, "block_voxel" if biome < 2 else "flat_lowpoly", entry.id)
	if body != null:
		actor.add_child(body)
		_models_loaded()

func asset(entry: Dictionary) -> void:
	clear()
	if not entry.staged:
		if entry.kind == "texture":
			var image := Image.load_from_file(entry.path)
			if image != null:
				texture_view.texture = ImageTexture.create_from_image(image)
				texture_view.show()
		changed.emit("Stage this source file to preview its game model.")
		return
	if entry.kind == "model":
		body = registry.instantiate(entry.id)
		if body != null:
			var box := Models.bounds(body)
			body.scale *= 2.0 / maxf(.01, box.size.length())
			box = Models.bounds(body)
			body.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
			actor.add_child(body)
			_models_loaded()
	elif entry.kind == "texture":
		texture_view.texture = registry.resource(entry.id)
		texture_view.show()
		changed.emit("Texture preview")
	elif entry.kind == "audio":
		audio.stream = registry.resource(entry.id)
		audio.play()
		changed.emit("Playing source audio; select another asset to stop.")

func clips() -> Array[String]:
	var result: Array[String] = []
	if body == null:
		return result
	for player in body.find_children("*", "AnimationPlayer", true, false):
		for clip in player.get_animation_list():
			if clip not in result:
				result.append(clip)
	return result

func _models_loaded() -> void:
	var text: String = body.get_meta("representation", "source") + " | " + str(body.get_meta("render_asset", body.get_meta("asset_id", "")))
	changed.emit(text + " | " + str(clips().size()) + " animation clips")
	if definition.is_empty():
		Models.animate(body, "idle")

func _process(delta: float) -> void:
	if body == null:
		return
	body.process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED
	if not running:
		return
	time += delta
	var animation := "idle"
	if mode == "Walk loop":
		var speed: float = definition.get("speed", 1.3)
		var heading := Vector3(cos(time * speed / 2), 0, -sin(time * speed / 2))
		actor.position = Vector3(sin(time * speed / 2) * 2, 0, cos(time * speed / 2) * 2)
		actor.rotation.y = atan2(heading.x, heading.z)
		animation = "walk"
	elif mode == "Pursuit":
		target.position = Vector3(cos(time * .28) * 3, 0, sin(time * .28) * 3)
		var direction := target.position - actor.position
		if not Enemies.should_engage(definition, provoked, direction.length() < 7.5):
			Models.animate(body, "idle")
			return
		cooldown = maxf(0, cooldown - delta)
		attack_timer = maxf(0, attack_timer - delta)
		actor.rotation.y = atan2(direction.x, direction.z)
		if direction.length() > float(definition.get("reach", .9)):
			actor.position += direction.normalized() * minf(direction.length(), float(definition.get("speed", 1.3)) * delta)
			animation = "walk"
		elif cooldown <= 0:
			cooldown = float(definition.get("period", 1.5)) + float(definition.get("windup", .5))
			attack_timer = float(definition.get("windup", .5))
		if attack_timer > 0:
			animation = "attack"
	elif mode == "Attack":
		animation = "attack"
	Models.animate(body, animation)

func _input_preview(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		angle -= event.relative.x * .008
		elevation = clampf(elevation + event.relative.y * .006, .12, 1.3)
		_update_camera()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		distance = clampf(distance + (-.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else .5), 2.5, 15)
		_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(sin(angle) * cos(elevation), sin(elevation), cos(angle) * cos(elevation)) * distance + Vector3.UP * .7
	camera.look_at(Vector3.UP * .7)

func _box(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	node.mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	node.position = point
	parent.add_child(node)
	return node

func _label(parent: Node3D, text: String, point: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = 24
	label.pixel_size = .006
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
