extends RefCounted

const Items = preload("res://scripts/item_models.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var items := Items.new()
var data: Dictionary = {}
var templates := {}
var tinted_materials := {}
var error := ""
const CACHE_LIMIT := 96
const NATIVE_ROLES := ["forest_understory", "jungle_understory", "reeds", "basalt", "lava_crack", "giant_mushroom"]

func _init(path: String = "res://config/biome_art.json") -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(document):
		error = "Invalid biome art catalogue"
		return
	data = document
	for profile in data.roles.values():
		for sources in profile.get("sources", {}).values():
			for source in sources:
				if items.registry.get_asset(source).get("kind") != "model" or not items.styles.item_sources.has(source):
					error = "Unknown biome source: " + source
					return

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("roles") is Dictionary or document.roles.is_empty():
		return false
	for role in document.roles:
		var profile = document.roles[role]
		if not role is String or role.is_empty() or ":" in role or not profile is Dictionary:
			return false
		for dimension in ["width", "height"]:
			if not (profile.get(dimension) is int or profile.get(dimension) is float) or not is_finite(profile[dimension]) or profile[dimension] <= 0:
				return false
		if profile.width > .95 or profile.height > 3.5:
			return false
		if profile.get("native", false):
			if role not in NATIVE_ROLES or not profile.get("colors") is Array or profile.colors.size() != 3 or not profile.colors.all(func(value): return value is String and Color.html_is_valid(value)):
				return false
		else:
			if not profile.get("sources") is Dictionary or not profile.get("tint") is String or not Color.html_is_valid(profile.tint):
				return false
			for family in ["block_voxel", "flat_lowpoly"]:
				var sources = profile.sources.get(family)
				if not sources is Array or sources.is_empty() or not sources.all(func(source): return source is String and not source.is_empty()):
					return false
	return true

func supports(role: String) -> bool:
	return data.roles.has(role) if data.has("roles") else false

func create(role: String, biome: int, seed_value: int) -> Node3D:
	if not error.is_empty() or not supports(role):
		return null
	var family: String = items.styles.family_for(biome)
	if family.is_empty():
		error = "Unknown biome visual family"
		return null
	var profile: Dictionary = data.roles[role]
	var source: String = "biome_geometry:%s:%s" % [family, role]
	var variant := posmod(seed_value, 3)
	if not profile.get("native", false):
		var choices: Array = profile.sources[family]
		source = choices[posmod(seed_value, choices.size())]
		variant = 0
	var key := "%s:%s:%s:%s" % [role, family, source, variant]
	if not templates.has(key):
		var body: Node3D
		if profile.get("native", false):
			body = _native(role, family, profile.colors, variant)
			body.set_meta("source_asset", source)
			body.set_meta("render_asset", source)
			body.set_meta("visual_family", family)
			body.set_meta("representation", "native_biome")
		else:
			body = items.source_model(source, family)
			if body == null:
				error = items.error
				return null
			_tint(body, Color(profile.tint))
		var fitted := items.fitted(body, Vector2.ONE * float(profile.width), float(profile.height))
		if fitted == null:
			error = items.error
			return null
		fitted.set_meta("biome_role", role)
		if templates.size() >= CACHE_LIMIT:
			var oldest: String = templates.keys()[0]
			templates[oldest].free()
			templates.erase(oldest)
		templates[key] = fitted
	return templates[key].duplicate()

func _native(role: String, family: String, palette: Array, variant: int) -> Node3D:
	var root := Node3D.new()
	var colors := palette.map(func(value): return Color(value))
	match role:
		"forest_understory":
			_piece(root, family, Vector3(.08, .38, .08), Vector3(0, .19, 0), colors[0])
			for tier in range(3):
				var reach := .48 - tier * .12
				for side in [-1, 1]:
					for axis in range(2):
						var point := Vector3(side * reach * .40, .14 + tier * .13, 0) if axis == 0 else Vector3(0, .14 + tier * .13, side * reach * .40)
						var leaf := _piece(root, family, Vector3(reach, .045, .14), point, colors[(tier + variant) % 3], family == "flat_lowpoly")
						leaf.rotation.z = side * .22
						if axis == 1:
							leaf.rotation.y = PI / 2
		"jungle_understory":
			_piece(root, family, Vector3(.075, .62, .075), Vector3(0, .31, 0), colors[0])
			for index in range(7):
				var angle := index * TAU / 7 + variant * .15
				var leaf := _piece(root, family, Vector3(.25, .045, .48), Vector3(sin(angle) * .20, .20 + index % 3 * .13, cos(angle) * .20), colors[1 + index % 2], true)
				leaf.rotation.y = angle
				leaf.rotation.x = .25 if index % 2 == 0 else -.20
		"reeds":
			for index in range(7):
				var angle := index * TAU / 7
				var x := cos(angle) * .22
				var z := sin(angle) * .22
				var height := .60 + .12 * ((index + variant) % 3)
				_piece(root, family, Vector3(.025, height, .025), Vector3(x, height * .5, z), colors[0])
				var blade := _piece(root, family, Vector3(.035, .35, .045), Vector3(x + cos(angle) * .06, .32, z + sin(angle) * .06), colors[1])
				blade.rotation.z = cos(angle) * -.25
				blade.rotation.x = sin(angle) * .25
				if index % 2 == 0:
					_piece(root, family, Vector3(.075, .15, .075), Vector3(x, height + .06, z), colors[2], true)
		"basalt":
			for index in range(5):
				var angle := index * TAU / 5
				var height := .70 + .20 * ((index + variant) % 3)
				_piece(root, family, Vector3(.30, height, .30), Vector3(cos(angle) * .23, height * .5, sin(angle) * .23), colors[index % 3], true)
			_piece(root, family, Vector3(.34, 1.30, .34), Vector3(0, .65, 0), colors[1], true)
		"giant_mushroom":
			_piece(root, family, Vector3(.16, 1.05, .16), Vector3(0, .525, 0), colors[0], true).set_meta("biome_part", "stem")
			for tier in range(3):
				var width: float = [1.0,.77,.42][tier]
				var cap := _piece(root, family, Vector3(width, .17, width), Vector3(0, 1.025 + tier * .17, 0), colors[1 + variant % 2].lightened(tier * .05), true)
				cap.set_meta("biome_part", "cap")
			for index in range(4):
				var angle := index * PI / 2 + variant * .2
				_piece(root, family, Vector3(.09,.035,.09), Vector3(cos(angle) * .15,1.468,sin(angle) * .15), colors[0], true)
		"lava_crack":
			_piece(root, family, Vector3(.8, .025, .8), Vector3(0, .0125, 0), colors[0])
			for index in range(4):
				var angle := -.28 if (index + variant) % 2 == 0 else .34
				var crack := _piece(root, family, Vector3(.06, .025, .23), Vector3((index % 2) * .045, .029, -.3 + index * .19), colors[1])
				crack.rotation.y = angle
				var material: StandardMaterial3D = crack.get_active_material(0).duplicate()
				material.emission_enabled = true
				material.emission = colors[2]
				material.emission_energy_multiplier = .7
				crack.material_override = material
	return root

func _piece(parent: Node3D, family: String, size: Vector3, point: Vector3, color: Color, round_form: bool = false) -> MeshInstance3D:
	var part := Voxels.cube(size, color)
	if family == "flat_lowpoly":
		if round_form:
			var shape := CylinderMesh.new()
			shape.radial_segments = 6
			shape.height = size.y
			shape.top_radius = size.x * .45
			shape.bottom_radius = size.x * .5
			part.mesh = shape
			part.scale.z = size.z / size.x
		else:
			var shape := BoxMesh.new()
			shape.size = size
			part.mesh = shape
		var material := StandardMaterial3D.new()
		material.albedo_color = color.srgb_to_linear()
		material.roughness = .95
		part.material_override = material
	part.position = point
	parent.add_child(part)
	return part

func _tint(body: Node3D, tint: Color) -> void:
	if tint == Color.WHITE:
		return
	for part in body.find_children("*", "MeshInstance3D", true, false):
		for surface in range(part.mesh.get_surface_count()):
			var original: StandardMaterial3D = part.get_active_material(surface)
			if original == null:
				continue
			var key := str([original.get_instance_id(), tint])
			if not tinted_materials.has(key):
				var material: StandardMaterial3D = original.duplicate()
				material.albedo_color *= tint
				tinted_materials[key] = material
			part.set_surface_override_material(surface, tinted_materials[key])

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for template in templates.values():
			template.free()
