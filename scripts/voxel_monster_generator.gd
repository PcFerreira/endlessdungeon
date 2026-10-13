extends RefCounted

const Catalog = preload("res://scripts/voxel_monster_catalog.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const CACHE_LIMIT = 128
static var catalog := Catalog.new()
static var mesh_cache: Dictionary = {}
static var animation_cache: Dictionary = {}

static func appearance(definition: Dictionary, seed_value: int, saved_id: String = "", biome: int = 0) -> Dictionary:
	assert(catalog.error.is_empty(),catalog.error)
	var profile := catalog.profile(definition)
	var template: String = profile.template
	var palettes: Array = profile.get("palettes",catalog.data.templates[template].palettes)
	var saved := decode(saved_id,template,palettes)
	if not saved.is_empty():
		return saved
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("voxel-monster-v1:%s:%s" % [definition.id,seed_value])
	var climate := clampi(biome,0,3)
	var style := {"version":1,"template":template,"palette":_pick(palettes,rng),"biome":climate,
		"accent":rng.randi_range(0,catalog.data.biomes[str(climate)].size() - 1),"build":_pick(catalog.data.builds.keys(),rng),
		"ornament":_pick(catalog.data.templates[template].ornaments.keys(),rng),"tone":rng.randi_range(0,catalog.data.tones.size() - 1)}
	style.asset = encode(style)
	return style

static func _pick(values: Array, rng: RandomNumberGenerator):
	return values[rng.randi_range(0,values.size() - 1)]

static func encode(style: Dictionary) -> String:
	return "voxel-monster:1:%s:%s:%s:%s:%s:%s:%s" % [style.template,style.palette,style.biome,style.accent,style.build,style.ornament,style.tone]

static func decode(id: String, template: String, palettes: Array) -> Dictionary:
	var fields := id.split(":")
	if fields.size() != 9 or fields[0] != "voxel-monster" or fields[1] != "1" or fields[2] != template or fields[3] not in palettes or not catalog.data.builds.has(fields[6]) or not catalog.data.templates[template].ornaments.has(fields[7]):
		return {}
	for index in [4,5,8]:
		if not fields[index].is_valid_int():
			return {}
	var biome := int(fields[4])
	var accent := int(fields[5])
	var tone := int(fields[8])
	if biome not in range(4) or accent < 0 or accent >= catalog.data.biomes[str(biome)].size() or tone < 0 or tone >= catalog.data.tones.size():
		return {}
	var result := {"version":1,"template":template,"palette":fields[3],"biome":biome,"accent":accent,"build":fields[6],"ornament":fields[7],"tone":tone}
	result.asset = encode(result)
	return result

static func create(style: Dictionary) -> Node3D:
	var template: Dictionary = catalog.data.templates[style.template]
	if not mesh_cache.has(style.asset):
		if mesh_cache.size() >= CACHE_LIMIT:
			mesh_cache.erase(mesh_cache.keys()[0])
		mesh_cache[style.asset] = _meshes(style,template)
	var body := Node3D.new()
	body.name = "VoxelMonster"
	var width: float = catalog.data.builds[style.build]
	body.scale = Vector3(width,1,width)
	var motion := Node3D.new()
	motion.name = "Motion"
	body.add_child(motion)
	for name in template.parts:
		var joint := Node3D.new()
		joint.name = name
		joint.position = _vector(template.parts[name].pivot)
		motion.add_child(joint)
		var mesh := Voxels.instance(mesh_cache[style.asset][name])
		mesh.name = "Geometry"
		mesh.set_meta("asset_id",style.asset)
		mesh.set_meta("visual_family","block_voxel")
		joint.add_child(mesh)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("",_animations(style.template,template))
	body.add_child(player)
	return body

static func _vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

static func _meshes(style: Dictionary, template: Dictionary) -> Dictionary:
	var colors := {}
	var tone: float = catalog.data.tones[style.tone]
	for key in catalog.data.palettes[style.palette]:
		var color := Color(catalog.data.palettes[style.palette][key])
		colors[key] = color.lightened(tone) if tone >= 0 else color.darkened(-tone)
	var accent: Array = catalog.data.biomes[str(style.biome)][style.accent]
	colors.accent = Color(accent[0])
	colors.eye = Color(accent[1])
	var pieces := {}
	for name in template.parts:
		pieces[name] = template.parts[name].pieces.duplicate()
	for ornament in template.ornaments[style.ornament]:
		pieces[ornament.part].append(ornament)
	var meshes := {}
	for name in pieces:
		var boxes: Array = []
		for piece in pieces[name]:
			boxes.append([_vector(piece.point),_vector(piece.size),colors[piece.color]])
		meshes[name] = Voxels.mesh(boxes)
	return meshes

static func _animations(id: String, template: Dictionary) -> AnimationLibrary:
	if animation_cache.has(id):
		return animation_cache[id]
	var library := AnimationLibrary.new()
	for mode in ["idle","walk","attack"]:
		var animation := Animation.new()
		animation.length = {"idle":2.2,"walk":.75,"attack":.65}[mode]
		animation.loop_mode = Animation.LOOP_LINEAR
		for name in template.parts:
			var part: Dictionary = template.parts[name]
			var rotations: Array = []
			var positions: Array = []
			for step in range(9):
				var phase := float(step) / 8
				var swing: float = sin(phase * TAU) * part.phase
				var pulse := sin(phase * PI)
				var rotation := Vector3.ZERO
				var position := _vector(part.pivot)
				match part.motion:
					"head":
						rotation.y = swing * .055 if mode != "attack" else 0.0
						rotation.x = -pulse * .22 if mode == "attack" else 0.0
					"arm":
						rotation.x = swing * .4 if mode == "walk" else (-pulse * 1.3 if mode == "attack" else swing * .025)
					"leg":
						if mode == "walk":
							rotation.x = swing * .45
							position.y += maxf(0,swing) * 2
					"crawler_leg":
						rotation.y = swing * .25 if mode == "walk" else 0.0
					"wing":
						rotation.z = swing * (.45 if template.locomotion == "fly" else .18)
					"tail":
						rotation.y = swing * (.2 if mode == "walk" else .08)
					"turret":
						rotation.y = swing * .045
						position.z -= pulse * 1.5 if mode == "attack" else 0.0
					"core":
						rotation.y = swing * .025 if mode == "idle" else 0.0
				rotations.append(rotation)
				positions.append(position)
			_track(animation,"Motion/%s:rotation" % name,rotations)
			_track(animation,"Motion/%s:position" % name,positions)
		var translations: Array = []
		var scales: Array = []
		for step in range(9):
			var phase := float(step) / 8
			var swing := sin(phase * TAU)
			var position := Vector3.ZERO
			var scale := Vector3.ONE
			if template.locomotion in ["float","fly"]:
				position.y = 1.5 + swing * .45
			elif template.locomotion == "slime":
				position.y = maxf(0,swing) * (1.4 if mode == "walk" else .3)
				scale = Vector3(1 + swing * .07,1 - swing * .08,1 + swing * .07)
				if mode == "attack":
					var pulse := sin(phase * PI)
					scale = Vector3(1 - pulse * .1,1 + pulse * .15,1 + pulse * .2)
			translations.append(position)
			scales.append(scale)
		_track(animation,"Motion:position",translations)
		_track(animation,"Motion:scale",scales)
		library.add_animation(mode,animation)
	animation_cache[id] = library
	return library

static func _track(animation: Animation, path: String, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track,NodePath(path))
	for step in values.size():
		animation.track_insert_key(track,float(step) / (values.size() - 1) * animation.length,values[step])
