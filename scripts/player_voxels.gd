extends RefCounted

const NPC = preload("res://scripts/voxel_character_generator.gd")
const Wardrobe = preload("res://scripts/player_wardrobe.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const CACHE_LIMIT := 128
static var mesh_cache: Dictionary = {}
static var animation_library: AnimationLibrary

static func create(class_id: String, profile) -> Node3D:
	var appearance: Dictionary = profile.snapshot()
	appearance.erase("name")
	appearance.erase("model")
	appearance.class_id = class_id
	var key := "procedural:voxel-player:v2:" + JSON.stringify(appearance).sha256_text().substr(0, 24)
	if not mesh_cache.has(key):
		while mesh_cache.size() >= CACHE_LIMIT:
			mesh_cache.erase(mesh_cache.keys()[0])
		mesh_cache[key] = geometry(class_id, profile)
	var compiled: Dictionary = mesh_cache[key]
	var body := Node3D.new()
	body.name = "VoxelBody"
	var height: float = {"human": 1.1, "elf": 1.14, "dwarf": .95, "orc": 1.14, "halfling": .86}[profile.ancestry]
	body.scale = Vector3.ONE * height / 28.0
	body.set_meta("generator_version", 2)
	body.set_meta("asset_id", key)
	body.set_meta("geometry", "voxel")
	body.set_meta("visual_family", "block_voxel")
	for bone in NPC.Catalog.BONES:
		var joint := Node3D.new()
		joint.name = bone
		joint.position = compiled.pivots[bone]
		var mesh := Voxels.instance(compiled.meshes[bone])
		mesh.name = "Geometry"
		mesh.set_meta("geometry", "voxel")
		joint.add_child(mesh)
		body.add_child(joint)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", animations())
	body.add_child(player)
	return body

static func geometry(class_id: String, profile) -> Dictionary:
	var build: Dictionary = Wardrobe.data.body_types[profile.body_type]
	var colors := {
		"skin": Color(Wardrobe.data.skins[profile.skin].color), "hair": Color(Wardrobe.data.hair_colors[profile.hair].color),
		"cloth": cloth(profile.outfit), "trim": cloth(profile.trim), "pants": cloth(profile.trousers),
		"leather": cloth(profile.boots_color), "boots": cloth(profile.boots_color), "belt": cloth(profile.boots_color),
		"bag": Color("80593e"), "gloves": cloth(profile.boots_color), "hat": cloth(profile.headwear_color),
		"outer": cloth(profile.outer_color), "eye": Color(Wardrobe.data.eye_colors[profile.eye_color].color), "metal": Color("a5bac0")
	}
	if profile.boots == "bare":
		colors.leather = colors.skin
	var hair_id: String = "short" if profile.head in ["hood", "beard"] else profile.head
	var hat_id: String = "hood" if profile.head == "hood" and profile.headwear == "none" else profile.headwear
	var beard_id: String = "full" if profile.head == "beard" and profile.beard == "none" else profile.beard
	var hair: Array = [] if hat_id in ["hood", "helm", "plumed_helm", "turban"] else pieces("head", hair_id, build.head)
	var extra: Array = []
	for kind in ["outerwear", "gloves", "boots", "belt", "accessory"]:
		extra.append_array(pieces(kind, profile.get(kind), build.head))
	if profile.ancestry == "elf":
		for side in [-1, 1]:
			extra.append(part("Head", Vector3(side * (build.head * .5 + 1), 5, 0), Vector3(2, .75, 2), "skin"))
	elif profile.ancestry == "orc":
		for side in [-1, 1]:
			extra.append(part("Head", Vector3(side, 2.5, 4.25), Vector3(.5, 1.25, .5), "paper"))
	var style := {"skin": 0, "hair_color": 0, "palette_id": "river", "build": "regular", "hair": "short", "beard": "none", "outfit": "tunic", "hat": "none", "accessory": "staff" if class_id == "mage" else "blade", "eyes": profile.eye_shape}
	return NPC._geometry(style, {"build": build, "colors": colors, "hair": hair, "beards": pieces("beard", beard_id, build.head), "outfits": clothing(profile.costume, class_id, build.head), "hats": pieces("headwear", hat_id, build.head), "extra": extra})

static func cloth(index: int) -> Color:
	return Color(Wardrobe.data.cloth_colors[index].color)

static func pieces(kind: String, id: String, head_size: float = 8) -> Array:
	var result := Wardrobe.pieces(kind, id)
	var recolor := {"headwear": {"cloth": "hat", "leather": "hat"}, "outerwear": {"cloth": "outer"}, "gloves": {"leather": "gloves"}, "accessory": {"leather": "bag"}, "belt": {"leather": "bag"}}
	for piece in result:
		piece.color = recolor.get(kind, {}).get(piece.color, piece.color)
		if kind in ["head", "headwear"]:
			piece.point[0] = roundf(piece.point[0] * head_size / 8 * 4) / 4
			piece.size[0] = maxf(.25, roundf(piece.size[0] * head_size / 8 * 4) / 4)
	return result

static func clothing(costume: String, class_id: String, head_size: float) -> Array:
	if Wardrobe.data.collections.costume.has(costume):
		return pieces("costume", costume, head_size)
	var base: String = {"mage": "robe", "sword": "mail", "spellsword": "coat"}[class_id]
	var result: Array = NPC.catalog.data.outfits[base].duplicate(true)
	match costume:
		"mage_scholar":
			result.append(part("Torso", Vector3(0, 6.5, 3.5), Vector3(6, 3, .5), "paper"))
			result.append(part("Torso", Vector3(0, 4, -3.5), Vector3(10, 9, 1), "cloth"))
		"mage_battlemage", "spellsword_spellblade", "sword_sentinel":
			result.append_array(NPC.catalog.data.outfits.mail.duplicate(true))
			result.append(part("Torso", Vector3(0, 4, -3.5), Vector3(10, 9, 1), "outer"))
			if costume == "sword_sentinel":
				result.append(part("LeftArm", Vector3(0, -5, 3), Vector3(7, 9, 1), "metal"))
		"sword_duelist":
			result = pieces("costume", "court_coat", head_size)
			result.append(part("Torso", Vector3(3, 6, 3.75), Vector3(2, 3, .5), "paper"))
		"spellsword_cloak":
			result.append_array(pieces("outerwear", "long_cloak", head_size))
		_:
			result.append(part("Torso", Vector3(0, 6.5, 3.75), Vector3(2, 2, .5), "trim"))
	return result

static func part(bone: String, point: Vector3, size: Vector3, color: String) -> Dictionary:
	return {"bone": bone, "point": [point.x, point.y, point.z], "size": [size.x, size.y, size.z], "color": color}

static func animations() -> AnimationLibrary:
	if animation_library != null:
		return animation_library
	animation_library = NPC._animations().duplicate(true)
	var walk: Animation = animation_library.get_animation("Walk")
	for track in range(walk.get_track_count()):
		if String(walk.track_get_path(track)) not in ["LeftLeg:position", "RightLeg:position"]:
			continue
		for key in range(walk.track_get_key_count(track)):
			var position: Vector3 = walk.track_get_key_value(track, key)
			var phase := walk.track_get_key_time(track, key) / walk.length
			position.y += absf(sin(phase * TAU)) * 1.4
			walk.track_set_key_value(track, key, position)
	var jump := Animation.new()
	jump.length = .6
	jump.loop_mode = Animation.LOOP_LINEAR
	for bone in ["LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		var track := jump.add_track(Animation.TYPE_VALUE)
		jump.track_set_path(track, NodePath(bone + ":rotation"))
		jump.track_insert_key(track, 0, Vector3(-.3 if bone.ends_with("Arm") else .25, 0, 0))
		jump.track_insert_key(track, .6, Vector3(-.3 if bone.ends_with("Arm") else .25, 0, 0))
	animation_library.add_animation("Jump_Idle", jump)
	return animation_library
