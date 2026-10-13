extends RefCounted

const Catalog = preload("res://scripts/voxel_character_catalog.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const CACHE_LIMIT = 128
static var catalog := Catalog.new()
static var mesh_cache: Dictionary = {}
static var animations: AnimationLibrary

static func appearance(index: int, context: Dictionary = {}) -> Dictionary:
	assert(catalog.error.is_empty(), catalog.error)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("voxel-npc-v1:%s:%s" % [context.get("id", "resident"), index])
	var role: String = context.get("role", "retired_delver")
	var recipe: Dictionary = catalog.data.roles.get(role, catalog.data.roles.villager)
	var biome := clampi(int(context.get("biome", 0)), 0, 3)
	var palette_rng := RandomNumberGenerator.new()
	palette_rng.seed = hash("voxel-clothes-v1:%s" % context.get("city_id", context.get("id", "resident")))
	var palette_id: String = _pick(catalog.data.biomes[str(biome)], palette_rng)
	var result := {
		"generator_version": 1, "family": "generated_voxel", "visual_family": "block_voxel", "geometry": "voxel",
		"role": role, "biome": biome, "palette_id": palette_id,
		"build": _pick(catalog.data.builds.keys(), rng), "skin": rng.randi_range(0, catalog.data.skins.size() - 1),
		"hair_color": rng.randi_range(0, catalog.data.hair_colors.size() - 1), "hair": _pick(catalog.data.hair.keys(), rng),
		"beard": _pick(catalog.data.beards.keys(), rng), "outfit": _pick(recipe.outfits, rng),
		"hat": _pick(recipe.hats, rng), "accessory": _pick(recipe.accessories, rng), "eyes": rng.randi_range(0, 2)
	}
	result.asset = "procedural:voxel-npc:v1:" + JSON.stringify(result).sha256_text().substr(0, 24)
	return result

static func _pick(values: Array, rng: RandomNumberGenerator):
	return values[rng.randi_range(0, values.size() - 1)]

static func create(style: Dictionary) -> Node3D:
	var key: String = style.asset
	if not mesh_cache.has(key):
		if mesh_cache.size() >= CACHE_LIMIT:
			mesh_cache.erase(mesh_cache.keys()[0])
		mesh_cache[key] = _geometry(style)
	var compiled: Dictionary = mesh_cache[key]
	var body := Node3D.new()
	body.name = "VoxelBody"
	body.scale = Vector3.ONE * catalog.data.height / compiled.height
	body.set_meta("generator_version", 1)
	body.set_meta("asset_id", key)
	body.set_meta("geometry", "voxel")
	for bone in Catalog.BONES:
		var joint := Node3D.new()
		joint.name = bone
		joint.position = compiled.pivots[bone]
		body.add_child(joint)
		var visual := Voxels.instance(compiled.meshes[bone])
		visual.name = "Geometry"
		visual.set_meta("asset_id", key)
		visual.set_meta("visual_family", "block_voxel")
		joint.add_child(visual)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", _animations())
	player.animation_finished.connect(func(action):
		if action in ["Wave", "Attack"]:
			player.play("Idle"))
	body.add_child(player)
	player.play("Idle")
	return body

static func _geometry(style: Dictionary) -> Dictionary:
	var colors := {"skin": Color(catalog.data.skins[style.skin]), "hair": Color(catalog.data.hair_colors[style.hair_color]), "paper": Color("f2e3c1"), "eye": Color("292c35")}
	for name in catalog.data.palettes[style.palette_id]:
		colors[name] = Color(catalog.data.palettes[style.palette_id][name])
	var build: Dictionary = catalog.data.builds[style.build]
	var shoulder: float = build.width / 2.0 + 1.5
	var pivots := {"Torso":Vector3(0,11,0), "Head":Vector3(0,20,0), "LeftArm":Vector3(-shoulder,19,0), "RightArm":Vector3(shoulder,19,0), "LeftLeg":Vector3(-2.5,11,0), "RightLeg":Vector3(2.5,11,0)}
	var boxes := {}
	for bone in Catalog.BONES:
		boxes[bone] = []
	_add(boxes, "Torso", Vector3(0,4.5,0), Vector3(build.width,9,5), colors.cloth)
	_add(boxes, "Torso", Vector3(0,.5,0), Vector3(build.width + .5,1,5.5), colors.leather)
	_add(boxes, "Torso", Vector3(0,.5,3), Vector3(2,1.5,.5), colors.trim)
	_add(boxes, "Torso", Vector3(0,8.5,2.75), Vector3(5,1,.5), colors.trim)
	var head_size: float = build.head
	_add(boxes, "Head", Vector3(0,4,0), Vector3(head_size,8,7), colors.skin)
	_add(boxes, "Head", Vector3(0,-.5,0), Vector3(3,1,3), colors.skin)
	for side in [-1,1]:
		_add(boxes, "Head", Vector3(side * (head_size / 2 + .5),4,0), Vector3(1,2,2), colors.skin)
		_add(boxes, "Head", Vector3(side * 2,4.5,3.75), Vector3(1.5,1.5,.5), colors.paper)
		_add(boxes, "Head", Vector3(side * 2,4.5 + style.eyes * .25,4.125), Vector3(.75,1,.25), colors.eye)
		_add(boxes, "Head", Vector3(side * 2,6,3.75), Vector3(2,.5,.5), colors.hair)
	_add(boxes, "Head", Vector3(0,3.5,4), Vector3(1,1,1), colors.skin.darkened(.08))
	_add(boxes, "Head", Vector3(0,1.75,3.75), Vector3(2,.5,.5), colors.skin.darkened(.3))
	for bone in ["LeftArm", "RightArm"]:
		_add(boxes, bone, Vector3(0,-4,0), Vector3(3,8,4), colors.cloth)
		_add(boxes, bone, Vector3(0,-7,0), Vector3(3.5,1,4.5), colors.trim)
		_add(boxes, bone, Vector3(0,-8.5,.5), Vector3(3,2,3), colors.skin)
	for bone in ["LeftLeg", "RightLeg"]:
		_add(boxes, bone, Vector3(0,-3.5,0), Vector3(3,7,4), colors.pants)
		_add(boxes, bone, Vector3(0,-9,1), Vector3(3.5,4,6), colors.leather)
		_add(boxes, bone, Vector3(0,-10.5,1), Vector3(3.5,1,6), colors.leather.darkened(.25))
	for kind in ["hair", "beards", "outfits", "hats", "accessories"]:
		var choice: String = style[{"beards":"beard", "outfits":"outfit", "hats":"hat", "accessories":"accessory"}.get(kind, kind)]
		for piece in catalog.data[kind][choice]:
			_add(boxes, piece.bone, Vector3(piece.point[0],piece.point[1],piece.point[2]), Vector3(piece.size[0],piece.size[1],piece.size[2]), colors[piece.color])
	var height := 0.0
	var meshes := {}
	for bone in boxes:
		meshes[bone] = Voxels.mesh(boxes[bone])
		var bound: AABB = meshes[bone].get_aabb()
		height = maxf(height, bound.end.y + pivots[bone].y)
	return {"meshes":meshes, "pivots":pivots, "height":height}

static func _add(boxes: Dictionary, bone: String, point: Vector3, size: Vector3, color: Color) -> void:
	boxes[bone].append([point,size,color])

static func _animations() -> AnimationLibrary:
	if animations != null:
		return animations
	animations = AnimationLibrary.new()
	for action in ["Idle", "Walk", "Wave", "Attack"]:
		var animation := Animation.new()
		animation.length = {"Idle":2.4, "Walk":.7, "Wave":1.3, "Attack":.6}[action]
		animation.loop_mode = Animation.LOOP_LINEAR if action in ["Idle", "Walk"] else Animation.LOOP_NONE
		for bone in Catalog.BONES:
			var track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track, NodePath(bone + ":rotation"))
			for step in range(9):
				var phase := float(step) / 8
				var rotation := Vector3.ZERO
				var swing := sin(phase * TAU)
				if action == "Walk":
					if bone in ["LeftLeg", "RightArm"]:
						rotation.x = swing * .48
					elif bone in ["RightLeg", "LeftArm"]:
						rotation.x = -swing * .48
				elif action == "Wave" and bone == "RightArm":
					rotation.z = sin(phase * PI) * 2.8
					rotation.x = sin(phase * TAU * 2) * .25
				elif action == "Attack" and bone == "RightArm":
					rotation.x = -sin(phase * PI) * 1.5
				elif action == "Idle" and bone == "Head":
					rotation.y = swing * .045
				animation.track_insert_key(track, phase * animation.length, rotation)
		for side in [-1,1]:
			var leg_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(leg_track, "LeftLeg:position" if side == -1 else "RightLeg:position")
			for step in range(9):
				var phase := float(step) / 8
				var lift := maxf(0, sin(phase * TAU) * -side) * 2 if action == "Walk" else 0.0
				animation.track_insert_key(leg_track, phase * animation.length, Vector3(side * 2.5,11 + lift,0))
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, "Torso:position")
		for step in range(9):
			var phase := float(step) / 8
			animation.track_insert_key(track, phase * animation.length, Vector3(0,11 + (sin(phase * TAU) * .12 if action == "Idle" else 0),0))
		animations.add_animation(action, animation)
	return animations
