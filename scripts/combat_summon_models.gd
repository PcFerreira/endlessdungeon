extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const COLORS := {"lantern_familiar": Color("ffd17a"), "ancestral_warden": Color("91e6cf"), "runic_blade": Color("b7abff")}

static func create(spell: String) -> Node3D:
	var model := Node3D.new()
	model.name = "Summon_" + spell
	model.set_meta("spell", spell)
	match spell:
		"lantern_familiar":
			_lantern(model)
		"ancestral_warden":
			_warden(model)
		"runic_blade":
			_blade(model)
	return model

static func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var cube := Voxels.cube(size, color, glow)
	cube.position = position
	parent.add_child(cube)
	return cube

static func _rune_ring(parent: Node3D, height: float, radius: float, color: Color) -> void:
	var ring := Node3D.new()
	ring.name = "RuneRing"
	ring.position.y = height
	parent.add_child(ring)
	for index in range(12):
		var angle := index * TAU / 12.0
		var tick := _box(ring, Vector3(cos(angle) * radius, 0, sin(angle) * radius), Vector3(.065, .035, .10), color, true)
		tick.rotation.y = -angle

static func _lantern(model: Node3D) -> void:
	var brass := Color("967348")
	_box(model, Vector3(0, .43, 0), Vector3(.37, .07, .37), brass)
	_box(model, Vector3(0, .84, 0), Vector3(.43, .10, .43), brass.lightened(.2))
	_box(model, Vector3(0, .64, 0), Vector3(.23, .32, .23), COLORS.lantern_familiar, true)
	for x in [-1, 1]:
		for z in [-1, 1]:
			_box(model, Vector3(x * .15, .64, z * .15), Vector3(.04, .39, .04), brass)
	for side in [-1, 1]:
		_box(model, Vector3(side * .12, .97, 0), Vector3(.04, .20, .04), brass)
	_box(model, Vector3(0, 1.06, 0), Vector3(.25, .04, .04), brass)
	_rune_ring(model, .37, .31, COLORS.lantern_familiar)

static func _warden(model: Node3D) -> void:
	var stone := Color("748689")
	_box(model, Vector3(0, .77, 0), Vector3(.48, .53, .32), stone)
	_box(model, Vector3(0, 1.20, 0), Vector3(.36, .28, .32), stone.lightened(.18))
	_box(model, Vector3(0, .49, 0), Vector3(.46, .12, .35), Color("52666b"))
	_box(model, Vector3(0, .79, .17), Vector3(.065, .30, .035), COLORS.ancestral_warden, true)
	_box(model, Vector3(0, .79, .17), Vector3(.25, .055, .035), COLORS.ancestral_warden, true)
	for side in [-1, 1]:
		_box(model, Vector3(side * .085, 1.23, .17), Vector3(.045, .045, .03), COLORS.ancestral_warden, true)
		var arm := Node3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.position = Vector3(side * .34, .97, 0)
		model.add_child(arm)
		_box(arm, Vector3(0, -.15, 0), Vector3(.20, .42, .25), stone.darkened(.08))
		_box(arm, Vector3(0, -.40, .02), Vector3(.22, .19, .26), stone.lightened(.1))
		var leg := Node3D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.position = Vector3(side * .14, .41, 0)
		model.add_child(leg)
		_box(leg, Vector3(0, -.16, 0), Vector3(.20, .32, .25), stone.darkened(.15))
		_box(leg, Vector3(0, -.35, .035), Vector3(.23, .12, .34), stone)

static func _blade(model: Node3D) -> void:
	var steel := Color("cbd8e4")
	_box(model, Vector3(0, .70, 0), Vector3(.12, .62, .075), steel)
	_box(model, Vector3(0, 1.04, 0), Vector3(.07, .12, .075), steel.lightened(.2))
	_box(model, Vector3(0, .68, .043), Vector3(.035, .39, .02), COLORS.runic_blade, true)
	_box(model, Vector3(0, .38, 0), Vector3(.39, .07, .10), Color("b99b64"))
	_box(model, Vector3(0, .26, 0), Vector3(.075, .20, .085), Color("695281"))
	_box(model, Vector3(0, .14, 0), Vector3(.10, .065, .10), COLORS.runic_blade, true)
	_rune_ring(model, .04, .28, COLORS.runic_blade)

static func animate(model: Node3D, spell: String, time: float, moving: bool, attacking: bool) -> void:
	if spell == "ancestral_warden":
		var swing := sin(time * 8) * .35 if moving else 0.0
		model.get_node("LeftLeg").rotation.x = swing
		model.get_node("RightLeg").rotation.x = -swing
		model.get_node("LeftArm").rotation.x = -swing
		model.get_node("RightArm").rotation.x = -1.15 if attacking else swing
	else:
		model.position.y = .22 + sin(time * 3.5) * .055
		model.rotation.z = sin(time * 2) * .07 + (.35 if attacking and spell == "runic_blade" else 0.0)
		model.get_node("RuneRing").rotation.y = time * .8
