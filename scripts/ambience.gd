extends RefCounted

static func emitter(kind: String, color: Color, amount: int = 12) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 1.4 if kind == "fire" else 2.4
	particles.preprocess = .6
	particles.local_coords = true
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = .09 if kind == "fire" else .35
	particles.direction = Vector3.UP
	particles.spread = 22
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = .18
	particles.initial_velocity_max = .45
	particles.scale_amount_min = .10 if kind == "magic" else .17
	particles.scale_amount_max = .22 if kind == "magic" else .30
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, .15, 1])
	gradient.colors = PackedColorArray([Color(color, 0), Color(color, .65), Color(color, 0)])
	particles.color_ramp = gradient
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if kind != "smoke" else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = load("res://assets/particles/%s_01.png" % kind)
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
