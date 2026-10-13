extends Node

var enabled := true
var viewport: SubViewport
var samples: Node3D
var busy := false
var rendered_variants := 0
var rendered_draw_calls := 0
var materials: Array[Material] = []
var seen := {}
var cursor := 0
var phase := 0
var pending_frame := false
var directional: DirectionalLight3D
var point_light: OmniLight3D
var held_materials: Array[Material] = []
var sprites: Array[SpriteBase3D] = []
var mesh_variants := []
var main_camera: Camera3D
var probe_camera: Camera3D
var shadow_before := true
var scene_pending := false
var scene_frames := 0
var camera_size_before := 0.0
const PROBE_LAYER := 1 << 19

func material_key(material: Material) -> String:
	if material is ShaderMaterial:
		return "shader:%s" % material.shader.get_instance_id()
	var settings := []
	for property in material.get_property_list():
		var name: String = property.name
		if name.ends_with("_enabled") or name.ends_with("_texture") or name.ends_with("_channel") or name in ["shading_mode", "transparency", "blend_mode", "cull_mode", "depth_draw_mode", "billboard_mode", "billboard_keep_scale", "vertex_color_use_as_albedo", "vertex_color_is_srgb", "disable_receive_shadows", "disable_fog", "no_depth_test", "texture_filter", "texture_repeat", "grow", "proximity_fade_enabled", "distance_fade_mode", "use_point_size", "albedo_texture_force_srgb", "diffuse_mode", "specular_mode"]:
			var value = material.get(name)
			settings.append([name, value != null if name.ends_with("_texture") else value])
	return JSON.stringify(settings)

func collect(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			add_material(node.get_active_material(surface))
			add_mesh(node.mesh, surface, node.get_active_material(surface), false)
	elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		for surface in range(node.multimesh.mesh.get_surface_count()):
			add_material(node.material_override if node.material_override != null else node.multimesh.mesh.surface_get_material(surface))
			add_mesh(node.multimesh.mesh, surface, node.material_override if node.material_override != null else node.multimesh.mesh.surface_get_material(surface), true)
	elif node is SpriteBase3D:
		var key := "%s:%s:%s:%s:%s:%s" % [node.get_class(), node.billboard, node.alpha_cut, node.shaded, node.double_sided, node.no_depth_test]
		if not seen.has(key):
			seen[key] = true
			sprites.append(node.duplicate())
	for child in node.get_children():
		collect(child)

func add_mesh(mesh: Mesh, surface: int, material: Material, instanced: bool) -> void:
	if material == null:
		return
	var format: int = mesh.surface_get_format(surface) if mesh is ArrayMesh else 0
	var key := "%s:%s:%s" % [material_key(material), format, instanced]
	if not seen.has(key):
		seen[key] = true
		mesh_variants.append({"mesh":mesh, "material":material, "instanced":instanced})

func add_material(material: Material) -> void:
	if material == null:
		return
	var key := material_key(material)
	if not seen.has(key):
		seen[key] = true
		materials.append(material)
	if material.next_pass != null:
		add_material(material.next_pass)

func configure(roots: Array, environment: Environment, camera_source: Camera3D = null, sunlight: DirectionalLight3D = null) -> void:
	if not enabled or DisplayServer.get_name() == "headless":
		return
	for node in roots:
		collect(node)
	for shader in [preload("res://assets/world_cutaway.gdshader"), preload("res://assets/biome_cutaway.gdshader")]:
		var material := ShaderMaterial.new()
		material.shader = shader
		add_material(material)
	viewport = SubViewport.new()
	viewport.size = Vector2i(96, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	samples = Node3D.new()
	main_camera = camera_source
	if main_camera == null:
		viewport.add_child(samples)
	else:
		add_child(samples)
		samples.position = Vector3(10000, 0, 10000)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5
	camera.position = samples.position + Vector3(0, 1, 5)
	camera.current = true
	if main_camera == null:
		viewport.add_child(camera)
	else:
		camera.cull_mask = PROBE_LAYER
		add_child(camera)
	probe_camera = camera
	var sky := WorldEnvironment.new()
	sky.environment = environment.duplicate() if environment != null else Environment.new()
	sky.environment.background_mode = Environment.BG_COLOR
	sky.environment.background_color = Color("14202a")
	viewport.add_child(sky)
	if sunlight == null:
		directional = DirectionalLight3D.new()
		directional.rotation_degrees = Vector3(-55, -30, 0)
		directional.shadow_enabled = true
		directional.directional_shadow_max_distance = 65
		viewport.add_child(directional)
	else:
		directional = sunlight
	shadow_before = directional.shadow_enabled
	point_light = OmniLight3D.new()
	point_light.position = samples.position + Vector3(0, 2, 2)
	point_light.omni_range = 8
	if main_camera == null:
		viewport.add_child(point_light)
	else:
		point_light.light_cull_mask = PROBE_LAYER
		add_child(point_light)
	busy = not materials.is_empty()
	RenderingServer.frame_post_draw.connect(_after_draw)

func _process(_delta: float) -> void:
	if scene_pending:
		main_camera.size = maxf(camera_size_before, 160)
		return
	if not busy or pending_frame:
		return
	for child in samples.get_children():
		child.free()
	if cursor >= materials.size():
		directional.shadow_enabled = shadow_before
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if main_camera != null:
			main_camera.make_current()
			probe_camera.queue_free()
			point_light.queue_free()
			_begin_scene()
		else:
			busy = false
		held_materials.assign(materials)
		materials.clear()
		return
	_build_probes(materials[cursor])
	point_light.visible = phase in [0, 3]
	directional.shadow_enabled = phase < 2
	if main_camera == null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	pending_frame = true

func warm_scene() -> void:
	if main_camera == null or busy:
		return
	_begin_scene()

func _begin_scene() -> void:
	camera_size_before = main_camera.size
	main_camera.size = maxf(camera_size_before, 160)
	scene_frames = 0
	scene_pending = true
	busy = true

func _build_probes(material: Material) -> void:
	for variant in mesh_variants:
		if material_key(variant.material) != material_key(material):
			continue
		var node: GeometryInstance3D
		if variant.instanced:
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.mesh = variant.mesh
			batch.instance_count = 1
			batch.set_instance_transform(0, Transform3D.IDENTITY)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = batch
			node = instance
		else:
			var instance := MeshInstance3D.new()
			instance.mesh = variant.mesh
			if variant.mesh is ArrayMesh and variant.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES:
				var bone_indices: PackedInt32Array = variant.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
				var count := 1
				for bone in bone_indices:
					count = maxi(count, bone + 1)
				var skeleton := Skeleton3D.new()
				skeleton.name = "ActualBones%s" % samples.get_child_count()
				var skin := Skin.new()
				for index in range(count):
					skeleton.add_bone("bone%s" % index)
					skin.add_bind(index, Transform3D.IDENTITY)
					skeleton.set_bone_pose_position(index, Vector3(0, .001 * (phase + 1), 0))
				samples.add_child(skeleton)
				instance.skin = skin
				instance.skeleton = NodePath("../" + skeleton.name)
			node = instance
		var bounds: AABB = variant.mesh.get_aabb()
		var factor := 1 / maxf(.1, bounds.size.length())
		node.material_override = variant.material
		node.scale = Vector3.ONE * factor
		node.position = Vector3(0, .5, 0) - bounds.get_center() * factor
		node.layers = PROBE_LAYER if main_camera != null else 1
		samples.add_child(node)
	for mode in range(4):
		var arrays: Array = BoxMesh.new().get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		colors.fill(Color.WHITE)
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags := 0
		if mode >= 2:
			var weights_count := 8 if mode == 3 else 4
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			bones.resize(vertices.size() * weights_count)
			weights.resize(bones.size())
			for index in range(vertices.size()):
				weights[index * weights_count] = 1
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if mode == 3 else 0
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		mesh.surface_set_material(0, material)
		var node: GeometryInstance3D
		if mode == 1:
			var instance := MultiMeshInstance3D.new()
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.mesh = mesh
			batch.instance_count = 1
			batch.set_instance_transform(0, Transform3D.IDENTITY)
			instance.multimesh = batch
			node = instance
		else:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			if mode >= 2:
				var skeleton := Skeleton3D.new()
				skeleton.name = "WarmSkeleton%s" % mode
				skeleton.add_bone("root")
				samples.add_child(skeleton)
				var skin := Skin.new()
				skin.add_bind(0, Transform3D.IDENTITY)
				instance.skin = skin
				instance.skeleton = NodePath("../" + skeleton.name)
			node = instance
		node.position = Vector3(mode - 1.5, .5, 0)
		node.scale = Vector3.ONE * .6
		node.layers = PROBE_LAYER if main_camera != null else 1
		samples.add_child(node)
	var label := Label3D.new()
	label.text = "Wandering traveler 0123456789"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 42
	label.outline_size = 7
	label.pixel_size = .007
	label.position = Vector3(0, 1.4, 0)
	label.layers = PROBE_LAYER if main_camera != null else 1
	samples.add_child(label)
	for template in sprites:
		var sprite: SpriteBase3D = template.duplicate()
		sprite.visible = true
		sprite.position = Vector3(0, .6, .8)
		sprite.rotation = Vector3.ZERO
		sprite.scale = Vector3.ONE
		sprite.pixel_size = .002
		sprite.process_mode = Node.PROCESS_MODE_DISABLED
		sprite.layers = PROBE_LAYER if main_camera != null else 1
		samples.add_child(sprite)

func _after_draw() -> void:
	if scene_pending:
		scene_frames += 1
		if scene_frames >= 2:
			main_camera.size = camera_size_before
			scene_pending = false
			busy = false
		return
	if not pending_frame:
		return
	rendered_variants += 4
	var rid := get_viewport().get_viewport_rid() if main_camera != null else viewport.get_viewport_rid()
	rendered_draw_calls += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	pending_frame = false
	phase += 1
	if phase == 4:
		phase = 0
		cursor += 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for sprite in sprites:
			sprite.free()
