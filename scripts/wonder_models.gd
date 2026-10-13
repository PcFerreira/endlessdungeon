extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const IDS := ["clay_herbalist", "moss_listener", "lantern_peddler", "scrap_fencer", "dew_jiggler", "rime_rooker", "bog_mossback", "choir_husk"]
const JOINTS := ["Body", "Head", "LeftArm", "RightArm", "LeftFoot", "RightFoot"]
const CACHE_LIMIT := 64
static var compiled := {}

static func create(id: String, family: String = "block_voxel", seed_value: int = 0) -> Node3D:
	if id not in IDS or family not in ["block_voxel", "flat_lowpoly"]:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wonder-art:1:%s:%s" % [id, seed_value])
	var variant := rng.randi_range(0, 7)
	var key := "%s:%s:%s" % [id, family, variant]
	if not compiled.has(key):
		if compiled.size() >= CACHE_LIMIT:
			compiled.erase(compiled.keys()[0])
		compiled[key] = _compile(id, family, variant)
	var recipe: Dictionary = compiled[key]
	var body := Node3D.new()
	body.name = "Wonder_" + id
	body.set_meta("wonder_id", id)
	body.set_meta("visual_family", family)
	body.set_meta("representation", "original_wonder_voxel")
	body.set_meta("appearance_variant", variant)
	for joint in JOINTS:
		var part := Node3D.new()
		part.name = joint
		part.position = recipe.pivots[joint]
		body.add_child(part)
		var mesh := Voxels.instance(recipe.meshes[joint])
		mesh.name = "Geometry"
		part.add_child(mesh)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	body.add_child(player)
	player.add_animation_library("", recipe.animations)
	player.animation_finished.connect(func(action):
		if str(action).to_lower() in ["wave", "attack"]:
			player.play("Idle"))
	player.play("Idle")
	return body

static func _compile(id: String, family: String, variant: int) -> Dictionary:
	var pieces := {}
	for joint in JOINTS:
		pieces[joint] = []
	var earth := Color("b97557").lightened(variant * .008)
	var moss := Color("568066").lightened(variant * .009)
	var light := Color("ffe3a0")
	var dark := Color("27323e")
	var metal := Color("729399").lightened(variant * .01)
	var bone := Color("beb9a6")
	var pivots := {"Body": Vector3(0,.5,0), "Head": Vector3(0,.85,0), "LeftArm": Vector3(-.27,.69,0), "RightArm": Vector3(.27,.69,0), "LeftFoot": Vector3(-.13,.18,0), "RightFoot": Vector3(.13,.18,0)}
	match id:
		"clay_herbalist":
			_box(pieces,"Body",0,.38,0,.48,.38,.43,earth)
			_box(pieces,"Body",0,.61,0,.55,.12,.48,earth.lightened(.15))
			_box(pieces,"Body",0,.26,0,.36,.09,.32,earth.darkened(.2))
			_box(pieces,"Body",0,.43,.235,.32,.28,.045,moss)
			for side in [-1,1]:
				_box(pieces,"Body",side*.07,.55,.266,.045,.18,.025,moss.lightened(.15))
			_box(pieces,"Head",0,.82,0,.35,.27,.32,earth)
			_box(pieces,"Head",0,.98,0,.42,.08,.38,earth.lightened(.2))
			_box(pieces,"Head",.04,1.07,0,.07,.1,.07,moss)
			_box(pieces,"Head",.13,1.08,0,.13,.045,.08,moss.lightened(.1))
			_eyes(pieces,.84,.17,.08,dark)
			_limbs(pieces,pivots,earth,moss,.18,.28)
		"moss_listener":
			_box(pieces,"Body",0,.49,0,.29,.52,.27,moss.darkened(.12))
			_box(pieces,"Body",0,.30,-.1,.43,.2,.35,moss)
			_box(pieces,"Body",-.18,.42,.20,.18,.22,.13,Color("c4a569"))
			_box(pieces,"Head",0,.87,0,.31,.3,.31,moss)
			_box(pieces,"Head",0,.88,.17,.19,.18,.025,dark)
			for side in [-1,1]:
				_box(pieces,"Head",side*.13,1.045,-.03,.07,.2,.07,Color("74604b"))
				_box(pieces,"Head",side*.20,1.11,-.03,.18,.055,.07,Color("74604b"))
				_box(pieces,"Head",side*.24,1.15,-.03,.06,.09,.08,moss.lightened(.15))
			_eyes(pieces,.89,.19,.055,light)
			_limbs(pieces,pivots,moss,Color("5e4838"),.12,.32)
		"lantern_peddler":
			_box(pieces,"Body",0,.46,0,.36,.4,.35,Color("775b86"))
			_box(pieces,"Body",0,.70,-.08,.75,.06,.08,Color("7b5e44"))
			_box(pieces,"Body",0,.73,-.15,.30,.35,.18,Color("927555"))
			_box(pieces,"Head",0,.83,0,.12,.36,.14,Color("b8d4b4"))
			_box(pieces,"Head",0,1.02,0,.27,.19,.26,Color("b8d4b4"))
			_box(pieces,"Head",0,1.01,.20,.14,.08,.2,Color("e8bb6d"))
			_box(pieces,"Head",0,1.15,-.03,.31,.055,.30,Color("775b86"))
			_eyes(pieces,1.055,.137,.085,dark)
			for side in [-1,1]:
				var arm: String = "LeftArm" if side == -1 else "RightArm"
				_box(pieces,arm,side*.30,.58,0,.12,.23,.25,Color("91b5a5"))
				_box(pieces,arm,side*.38,.54,-.04,.04,.19,.04,Color("775a37"))
				_box(pieces,arm,side*.38,.39,-.04,.14,.16,.14,light)
				for height in [.29,.49]:
					_box(pieces,arm,side*.38,height,-.04,.18,.04,.18,Color("775a37"))
			_feet(pieces,pivots,Color("e8bb6d"),.21,.3)
		"scrap_fencer":
			_box(pieces,"Body",0,.47,0,.34,.44,.29,metal)
			_box(pieces,"Body",0,.49,.17,.21,.24,.06,Color("a2b49e"))
			_box(pieces,"Body",-.16,.26,-.17,.075,.43,.09,Color("725442"))
			_box(pieces,"Body",-.16,.49,-.17,.19,.05,.1,Color("cba56c"))
			_box(pieces,"Head",0,.86,0,.26,.32,.24,metal)
			_box(pieces,"Head",-.075,1.04,0,.06,.14,.05,metal.darkened(.3))
			_box(pieces,"Head",0,.86,.14,.25,.07,.035,dark)
			_box(pieces,"Head",-.06,.86,.166,.06,.045,.018,light)
			_box(pieces,"RightArm",.30,.60,0,.23,.19,.31,Color("b0935e"))
			_box(pieces,"RightArm",.31,.38,.04,.13,.32,.14,metal)
			_box(pieces,"LeftArm",-.27,.46,.03,.09,.41,.10,metal.darkened(.25))
			_box(pieces,"LeftArm",-.27,.25,.07,.15,.08,.18,metal)
			_feet(pieces,pivots,metal.darkened(.2),.16,.31)
		"dew_jiggler":
			pivots = {"Body": Vector3(0,.24,0), "Head": Vector3(0,.41,0), "LeftArm": Vector3(-.24,.3,0), "RightArm": Vector3(.24,.3,0), "LeftFoot": Vector3(-.14,.04,0), "RightFoot": Vector3(.14,.04,0)}
			var jelly := Color("74cabc").lightened(variant*.01)
			_box(pieces,"Body",0,.17,0,.57,.3,.46,jelly)
			_box(pieces,"Body",0,.33,-.04,.40,.17,.35,jelly.lightened(.1))
			for side in [-1,1]:
				_box(pieces,"Head",side*.12,.48,0,.055,.22,.055,jelly.darkened(.14))
				_box(pieces,"Head",side*.12,.59,0,.105,.09,.11,light)
				_box(pieces,"Head",side*.12,.60,.057,.04,.04,.018,dark)
			_box(pieces,"Head",0,.34,.28,.055,.16,.055,jelly.darkened(.2))
			_box(pieces,"Head",0,.24,.29,.12,.10,.11,Color("b5f1e8"))
			_box(pieces,"LeftArm",-.3,.24,0,.11,.1,.16,jelly)
			_box(pieces,"RightArm",.3,.24,0,.11,.1,.16,jelly)
			_feet(pieces,pivots,jelly.darkened(.1),.20,.08)
		"rime_rooker":
			pivots = {"Body": Vector3(0,.34,0), "Head": Vector3(0,.54,0), "LeftArm": Vector3(-.23,.39,0), "RightArm": Vector3(.23,.39,0), "LeftFoot": Vector3(-.14,.07,0), "RightFoot": Vector3(.14,.07,0)}
			var ice := Color("92bfda").lightened(variant*.01)
			_box(pieces,"Body",0,.31,0,.43,.44,.4,Color("405d78"))
			_box(pieces,"Body",0,.31,.21,.31,.30,.055,ice)
			_box(pieces,"Body",0,.23,-.28,.24,.10,.22,Color("405d78"))
			_box(pieces,"Head",0,.59,.02,.35,.25,.32,ice)
			for i in range(3):
				_box(pieces,"Head",0,.76+i*.045,-.1+i*.08,.085,.14-i*.025,.07,Color("c6e9ef"))
			_box(pieces,"Head",0,.56,.245,.20,.09,.16,Color("d9b379"))
			_eyes(pieces,.64,.186,.10,dark)
			for side in [-1,1]:
				_box(pieces,"LeftArm" if side==-1 else "RightArm",side*.24,.34,-.02,.12,.30,.32,Color("668eaf"))
			_feet(pieces,pivots,Color("b0d6e0"),.25,.14)
		"bog_mossback":
			pivots = {"Body": Vector3(0,.6,0), "Head": Vector3(0,.99,0), "LeftArm": Vector3(-.39,.78,0), "RightArm": Vector3(.39,.78,0), "LeftFoot": Vector3(-.24,.19,0)}
			pivots.RightFoot = Vector3(.24,.19,0)
			_box(pieces,"Body",0,.64,0,.67,.65,.46,Color("586752"))
			_box(pieces,"Body",0,.88,0,1.02,.16,.65,moss)
			for side in [-1,1]:
				_box(pieces,"Body",side*.32,1.015,-.13,.16,.13,.19,moss.lightened(.15))
				_box(pieces,"LeftArm" if side==-1 else "RightArm",side*.44,.52,.04,.24,.60,.27,Color("788363"))
			_box(pieces,"Head",0,1.045,.07,.37,.26,.34,Color("87917a"))
			for i in range(5):
				_box(pieces,"Head",(i-2)*.066,.83-absf(i-2)*.025,.25,.044,.28-absf(i-2)*.035,.055,Color("aaad73"))
			_eyes(pieces,1.08,.25,.10,dark)
			_feet(pieces,pivots,Color("555c46"),.35,.38)
		"choir_husk":
			pivots.LeftArm = Vector3(-.23,.75,0)
			pivots.RightArm = Vector3(.23,.75,0)
			_box(pieces,"Body",0,.56,-.12,.09,.47,.10,bone)
			_box(pieces,"Body",0,.29,0,.31,.10,.24,bone.darkened(.25))
			for side in [-1,1]:
				_box(pieces,"Body",side*.17,.56,0,.055,.39,.22,bone)
			for height in [.40,.73]:
				_box(pieces,"Body",0,height,0,.39,.045,.29,bone)
			_box(pieces,"Body",0,.60,0,.14,.18,.14,Color("bf9b5f"))
			_box(pieces,"Body",0,.49,0,.22,.055,.22,Color("ddbd79"))
			_box(pieces,"Body",0,.44,0,.045,.07,.045,dark)
			_box(pieces,"Head",0,.98,0,.20,.38,.23,bone)
			_box(pieces,"Head",0,1.18,-.025,.25,.045,.26,bone.darkened(.2))
			_eyes(pieces,1.05,.13,.052,Color("b596c8"))
			for side in [-1,1]:
				var arm: String = "LeftArm" if side==-1 else "RightArm"
				_box(pieces,arm,side*.25,.54,0,.07,.42,.08,bone)
				_box(pieces,arm,side*.26,.28,.04,.13,.14,.15,bone)
				for finger in range(3):
					_box(pieces,arm,side*.26+(finger-1)*.043,.20,.10,.025,.14,.04,bone)
			_feet(pieces,pivots,bone.darkened(.18),.12,.36)
	var highest := 0.0
	for joint in JOINTS:
		for piece in pieces[joint]:
			highest = maxf(highest,piece[0].y+piece[1].y*.5)
	var scale := 1.15 / highest if IDS.find(id) < 4 else 1.0
	var meshes := {}
	for joint in JOINTS:
		for piece in pieces[joint]:
			piece[0] = (piece[0]-pivots[joint])*scale
			piece[1] *= scale
		pivots[joint] *= scale
		meshes[joint] = Voxels.mesh(pieces[joint]) if family=="block_voxel" else _chamfered(pieces[joint])
	return {"pivots":pivots,"meshes":meshes,"animations":_animations(pivots,meshes)}

static func _box(parts: Dictionary, joint: String, x: float, y: float, z: float, w: float, h: float, d: float, color: Color) -> void:
	parts[joint].append([Vector3(x,y,z),Vector3(w,h,d),color])

static func _eyes(parts: Dictionary, y: float, z: float, gap: float, color: Color) -> void:
	for side in [-1,1]:
		_box(parts,"Head",side*gap,y,z,.045,.045,.025,color)

static func _limbs(parts: Dictionary, pivots: Dictionary, skin: Color, boots: Color, width: float, leg_height: float) -> void:
	for side in [-1,1]:
		_box(parts,"LeftArm" if side==-1 else "RightArm",side*.29,.48,.015,.12,.30,.15,skin)
	_feet(parts,pivots,boots,width,leg_height)

static func _feet(parts: Dictionary, pivots: Dictionary, color: Color, width: float, height: float) -> void:
	for joint in ["LeftFoot","RightFoot"]:
		_box(parts,joint,pivots[joint].x,height*.5,0,width,height,.23,color)
		_box(parts,joint,pivots[joint].x,.04,.095,width+.03,.08,.32,color.darkened(.1))

static func _chamfered(pieces: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces:
		var half: Vector3 = piece[1]*.5
		var bevel := minf(half.x,half.z)*.32
		var ring := [Vector2(-half.x+bevel,-half.z),Vector2(half.x-bevel,-half.z),Vector2(half.x,-half.z+bevel),Vector2(half.x,half.z-bevel),Vector2(half.x-bevel,half.z),Vector2(-half.x+bevel,half.z),Vector2(-half.x,half.z-bevel),Vector2(-half.x,-half.z+bevel)]
		for i in range(8):
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i+1)%8]
			var low_a: Vector3 = Vector3(a.x,-half.y,a.y)+piece[0]
			var low_b: Vector3 = Vector3(b.x,-half.y,b.y)+piece[0]
			var high_a: Vector3 = Vector3(a.x,half.y,a.y)+piece[0]
			var high_b: Vector3 = Vector3(b.x,half.y,b.y)+piece[0]
			_triangle(surface,[low_a,high_a,high_b],piece[2])
			_triangle(surface,[low_a,high_b,low_b],piece[2])
			if i in range(1,7):
				var origin: Vector2 = ring[0]
				_triangle(surface,[Vector3(origin.x,half.y,origin.y)+piece[0],high_b,high_a],piece[2])
				_triangle(surface,[Vector3(origin.x,-half.y,origin.y)+piece[0],low_a,low_b],piece[2])
	surface.set_material(Voxels.material())
	return surface.commit()

static func _triangle(surface: SurfaceTool, points: Array, color: Color) -> void:
	var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
	for index in [0,2,1]:
		surface.set_normal(normal)
		surface.set_color(color.srgb_to_linear())
		surface.add_vertex(points[index])

static func _animations(pivots: Dictionary, meshes: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for action in ["Idle","Walk","Wave","Attack"]:
		var animation := Animation.new()
		animation.length = {"Idle":2.8,"Walk":.8,"Wave":1.3,"Attack":.7}[action]
		animation.loop_mode = Animation.LOOP_LINEAR if action in ["Idle","Walk"] else Animation.LOOP_NONE
		for joint in JOINTS:
			var rotation_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(rotation_track,NodePath(joint+":rotation"))
			var position_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(position_track,NodePath(joint+":position"))
			for step in range(17):
				var phase := step/16.0
				var wave := sin(phase*TAU)
				var rotation := Vector3.ZERO
				var position: Vector3 = pivots[joint]
				if action=="Idle":
					if joint=="Head": rotation.y = wave*.045
					if joint=="Body": position.y += (wave+1)*.006
				if action=="Walk":
					var sign_value := -1.0 if joint.begins_with("Left") else 1.0
					if joint.ends_with("Foot"):
						position.y += maxf(0,wave*sign_value)*.045
						position.z += wave*sign_value*.055
					if joint.ends_with("Arm"): rotation.x = wave*sign_value*.24
				if action=="Wave" and joint=="RightArm":
					rotation.z = sin(phase*PI)*1.8
					rotation.x = sin(phase*TAU*2)*.18
				if action=="Attack":
					if joint=="RightArm": rotation.x = -sin(phase*PI)*1.1
					if joint=="LeftArm": rotation.x = -sin(phase*PI)*.3
					if joint=="Head": rotation.x = sin(phase*PI)*.08
				var basis := Basis.from_euler(rotation)
				var lowest := INF
				for vertex in meshes[joint].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					lowest = minf(lowest,(basis*vertex).y+position.y)
				position.y += maxf(0,-lowest)
				animation.track_insert_key(rotation_track,phase*animation.length,rotation)
				animation.track_insert_key(position_track,phase*animation.length,position)
		library.add_animation(action,animation)
		library.add_animation(action.to_lower(),animation)
	return library
