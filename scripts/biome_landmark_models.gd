extends RefCounted

const Catalog = preload("res://scripts/biome_landmark_catalog.gd")
const Biomes = preload("res://scripts/biome_catalog.gd")
const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const CACHE_LIMIT := 32
var templates := {}
var error := ""

func create(profile: Dictionary, family: String, claimed: bool = false) -> Node3D:
	error = ""
	var kind: String = profile.get("kind", "")
	var blueprint := Catalog.by_id(kind)
	if blueprint.is_empty() or family not in ["block_voxel", "flat_lowpoly"]:
		error = "Unknown landmark kind/family"
		return null
	for field in ["size", "body_size", "body_center", "body_height", "foundation_depth", "door_local", "solid_local"]:
		if profile.get(field) != blueprint[field]:
			error = "Landmark render blueprint differs from physical catalogue: " + field
			return null
	var biome: String = profile.get("biome_id", "greenwood")
	var palette: Dictionary = Biomes.DATA.profiles.get(biome, Biomes.DATA.profiles.greenwood)
	var key := str([kind, family, claimed, palette.color, palette.earth, palette.rock])
	if not templates.has(key):
		var root := _body(blueprint, family, palette, claimed)
		var identity := "native_biome_landmark:%s:%s" % [family, kind]
		for node in [root] + root.find_children("*", "MeshInstance3D", true, false):
			node.set_meta("source_asset", identity)
			node.set_meta("render_asset", identity)
			node.set_meta("asset_id", identity)
			node.set_meta("visual_family", family)
		root.set_meta("representation", "original_landmark_geometry")
		root.set_meta("original_landmark_geometry", true)
		root.set_meta("kind", kind)
		root.set_meta("claimed", claimed)
		root.set_meta("door_local", blueprint.door_local)
		root.set_meta("foundation_depth", blueprint.foundation_depth)
		if templates.size() >= CACHE_LIMIT:
			var oldest: String = templates.keys()[0]
			templates[oldest].free()
			templates.erase(oldest)
		templates[key] = root
	return templates[key].duplicate()

func _part(root: Node3D, name: String, boxes: Array, family: String, obstructing: bool = false) -> MeshInstance3D:
	var part := Voxels.instance(Surfaces.mesh_boxes(boxes, family))
	part.name = name
	part.set_meta("obstructing", obstructing)
	root.add_child(part)
	return part

func _block(boxes: Array, point: Vector3, size: Vector3, color: Color) -> void:
	boxes.append([point, size, color])

func _body(profile: Dictionary, family: String, palette: Dictionary, claimed: bool) -> Node3D:
	var root := Node3D.new()
	var stone := Color(palette.rock)
	var earth := Color(palette.earth)
	var accent := Color(palette.color).lightened(.25)
	var base_color := earth.lightened(.08) if profile.kind == "ruined_cottage" else stone
	var foundation: Array = [[Vector3(0, -profile.foundation_depth * .5, 0), Vector3(profile.size.x, profile.foundation_depth, profile.size.y), stone.darkened(.28)]]
	_part(root, "Foundation", foundation, family)
	var boxes: Array = []
	var body_height: float = profile.body_height
	var kind: String = profile.kind
	for cell in profile.solid_local:
		var height := .65 if kind in ["monolith", "well"] else body_height
		if kind == "watchtower":
			height = 5.8
		elif kind == "mage_tower":
			height = 6.3
		elif kind == "tomb":
			height = 2.2
		elif kind == "ruined_cottage":
			height = 1.5 + posmod(cell.x * 3 + cell.y, 4) * .35
		elif kind == "shrine":
			height = 2.2
		elif kind == "ruined_arch":
			height = 2.6
		var width := .78 if kind in ["shrine", "ruined_arch"] else .98
		_block(boxes, Vector3(cell.x, height * .5, cell.y), Vector3(width, height, width), base_color.lightened(posmod(cell.x + cell.y, 3) * .025))
	match kind:
		"monolith":
			_block(boxes, Vector3(0, 2.55, -1), Vector3(.94, 3.8, .86), stone.lightened(.10))
			_block(boxes, Vector3(0, 4.25, -1), Vector3(.74, .50, .66), accent)
		"well":
			for side in [-1, 1]:
				_block(boxes, Vector3(side, 1.13, -1.65), Vector3(.15, 1.14, .15), earth)
			_block(boxes, Vector3(0, 1.48, -1.65), Vector3(2.2, .16, .16), earth.lightened(.12))
			for cell in profile.solid_local:
				if cell != profile.body_center:
					_block(boxes, Vector3(cell.x, .78, cell.y), Vector3(.96, .26, .96), stone.lightened(.08))
			_part(root, "WaterBowl", [[Vector3(0, .70, -1), Vector3(.88, .06, .88), Color("428aa5")]], family)
			_part(root, "Rope", [[Vector3(0, 1.12, -1.65), Vector3(.045, .60, .045), Color("c4af7c")]], family)
			_part(root, "Bucket", [[Vector3(0, .84, -1.65), Vector3(.28, .30, .28), earth.darkened(.18)], [Vector3(0, .985, -1.65), Vector3(.31, .04, .31), stone.darkened(.12)]], family)
		"watchtower":
			_block(boxes, Vector3(0, 6.0, 0), Vector3(5, .40, 5), stone.darkened(.12))
			for x in [-2, 0, 2]:
				for z in [-2, 2]:
					_block(boxes, Vector3(x, 6.5, z), Vector3(.88, .60, .88), stone.lightened(.10))
			for z in [0]:
				for x in [-2, 2]:
					_block(boxes, Vector3(x, 6.5, z), Vector3(.88, .60, .88), stone.lightened(.10))
			_block(boxes, Vector3(0, 4.0, 2), Vector3(.98, 3.6, .98), stone)
		"mage_tower":
			_block(boxes, Vector3(0, 4.25, 2), Vector3(.98, 4.1, .98), stone)
			for tier in range(4):
				var width: float = [5.0, 3.6, 2.4, 1.2][tier]
				var height: float = [.35, .35, .35, .25][tier]
				var elevation: float = [6.475, 6.825, 7.175, 7.625][tier]
				_block(boxes, Vector3(0, elevation, 0), Vector3(width, height, width), accent.darkened(.2 + tier * .035))
			for side in [-1, 1]:
				_glow(root, "UpperWindow" + str(side), Vector3(side * 1.2, 4.5, 2.51), Vector3(.4, .65, .045), Color("b8a5de"), family, true)
		"tomb":
			for tier in range(3):
				var width := 5.0 - tier * 1.2
				_block(boxes, Vector3(0, 2.4 + tier * .3, 0), Vector3(width, .4, width), stone.lightened(tier * .04))
		"ruined_cottage":
			_block(boxes, Vector3(-1.15, 2.95, 0), Vector3(2.2, .35, 5), earth.darkened(.12))
			_block(boxes, Vector3(-.95, 3.4, -.6), Vector3(1.75, .4, 3.8), earth.lightened(.06))
		"shrine":
			_block(boxes, Vector3(0, 2.4, -1), Vector3(3, .4, 2.4), stone)
			_block(boxes, Vector3(0, 2.8, -1), Vector3(2.1, .4, 1.7), accent)
		"ruined_arch":
			_block(boxes, Vector3(0, 2.8, -1), Vector3(3, .4, .9), stone.lightened(.08))
			_block(boxes, Vector3(-.65, 3.15, -1), Vector3(.7, .3, .82), stone)
	_part(root, "Structure", boxes, family, true)
	if kind in Catalog.CACHE_KINDS:
		_cache(root, profile.door_local, family, earth, accent, claimed)
	elif kind in ["monolith", "shrine", "ruined_arch"]:
		var height := 2.35 if kind == "monolith" else 1.35
		_glow(root, "InscribedRune", Vector3(0, height, -.53), Vector3(.35, .55, .045), accent, family, claimed)
	return root

func _glow(root: Node3D, name: String, point: Vector3, size: Vector3, color: Color, family: String, active: bool) -> void:
	var part := _part(root, name, [[point, size, color]], family)
	var material := StandardMaterial3D.new()
	material.albedo_color = color.srgb_to_linear().lightened(.12 if active else 0.0)
	material.roughness = .9
	material.emission_enabled = active
	material.emission = color.srgb_to_linear()
	material.emission_energy_multiplier = .55
	part.material_override = material

func _cache(root: Node3D, door: Vector2i, family: String, earth: Color, accent: Color, claimed: bool) -> void:
	var origin := Vector3(door.x, 0, door.y)
	var boxes: Array = []
	_block(boxes, origin + Vector3(0, .03, 0), Vector3(.44, .06, .34), earth.darkened(.25))
	for side in [-1, 1]:
		_block(boxes, origin + Vector3(side * .195, .15, 0), Vector3(.05, .24, .34), earth)
		_block(boxes, origin + Vector3(0, .15, side * .145), Vector3(.34, .24, .05), earth)
	_block(boxes, origin + Vector3(0, .20, .18), Vector3(.055, .055, .025), accent)
	_block(boxes, origin + (Vector3(0, .36, -.155) if claimed else Vector3(0, .30, 0)), Vector3(.46, .18, .045) if claimed else Vector3(.46, .065, .36), earth.lightened(.12))
	var cache := _part(root, "Cache", boxes, family)
	cache.set_meta("nonblocking", true)
	cache.set_meta("claimed", claimed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for template in templates.values():
			template.free()
