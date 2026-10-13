extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const Cultural = preload("res://scripts/native_cultural_models.gd")
const DungeonSurfaces = preload("res://scripts/dungeon_surfaces.gd")
const Decor = preload("res://scripts/decor_geometry.gd")
const Rewards = preload("res://scripts/native_reward_models.gd")
var data: Dictionary = {}
var classified: Dictionary = {}
var creature_sources: Dictionary = {}
var item_sources: Dictionary = {}
var derived: Dictionary = {}
var error := ""
var materials: Dictionary = {}
static var biome_art: Dictionary = {}

func _init(registry = null, path: String = "res://config/environment_styles.json") -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(document):
		error = "Invalid environment style catalogue"
		return
	data = document
	if registry == null:
		registry = Registry.new()
	var queries := {}
	for family in data.families:
		queries[family] = data.families[family].queries.duplicate(true)
	for catalogue in data.get("source_catalogues", []):
		var source = JSON.parse_string(FileAccess.get_file_as_string(catalogue))
		if not source is Dictionary or not source.get("families") is Dictionary:
			error = "Invalid style source catalogue: " + catalogue
			return
		if source.get("scope", "") == "items":
			if not source.get("native_sources") is Array or not source.native_sources.all(func(id): return id is String and id.begins_with("res://assets/") and ".." not in id.split("/")) or not source.get("procedural_sources") is Dictionary or not source.get("scenery_sources", []) is Array or not source.get("scenery_sources", []).all(func(id): return id is String and not id.is_empty() and ":" not in id):
				error = "Invalid native item sources in " + catalogue
				return
			for asset in registry.find():
				if asset.kind in ["model", "texture"]:
					item_sources[asset.id] = true
			for id in source.native_sources:
				item_sources[id] = true
			for id in source.get("scenery_sources", []):
				item_sources[id] = true
			for id in source.procedural_sources:
				if not id is String or not id.begins_with("procedural:") or not data.families.has(source.procedural_sources[id]):
					error = "Invalid procedural item source"
					return
				item_sources[id] = true
				classified[id] = source.procedural_sources[id]
		for series in source.families.values():
			if not series is Dictionary or not data.families.has(series.get("environment_family", "")) or not series.get("queries") is Array or not series.queries.all(_valid_query):
				error = "Unclassified source series in " + catalogue
				return
			for source_query in series.queries:
				var query: Dictionary = source_query.duplicate(true)
				query.creature_source = source.get("scope", "") == "creatures"
				queries[series.environment_family].append(query)
	for definition in data.get("derived_catalogues", []):
		var source = JSON.parse_string(FileAccess.get_file_as_string(definition.path))
		if not source is Dictionary or not source.get("templates") is Dictionary or source.templates.is_empty() or not source.templates.keys().all(func(id): return id is String and not id.is_empty() and ":" not in id):
			error = "Invalid derived style catalogue: " + definition.path
			return
		for family in definition.families:
			for id in source.templates:
				var key := "%s:%s:%s" % [definition.prefix, family, id]
				if derived.has(key):
					error = "Duplicate derived style identity: " + key
					return
				derived[key] = family
	for family in queries:
		for query in queries[family]:
			for asset in registry.find("model", query.get("tags", []), query.pack):
				if not query.patterns.any(func(pattern): return asset.id.matchn(pattern)):
					continue
				if classified.has(asset.id) and classified[asset.id] != family:
					error = "Ambiguous environment style: " + asset.id
					return
				classified[asset.id] = family
				if query.get("creature_source", false):
					creature_sources[asset.id] = family

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("families") is Dictionary or document.families.is_empty() or not document.get("biomes") is Dictionary or not document.get("roles") is Array or document.roles.is_empty() or not document.roles.all(func(value): return value is String) or not document.get("anchors") is Dictionary or not document.get("sizes") is Dictionary or not document.get("colors") is Dictionary:
		return false
	for family in document.families.values():
		if not family is Dictionary or not family.get("name") is String or family.get("geometry") not in ["voxel", "lowpoly"] or not family.get("queries") is Array or family.queries.is_empty():
			return false
		for query in family.queries:
			if not _valid_query(query):
				return false
	if not document.get("source_catalogues", []) is Array or not document.get("source_catalogues", []).all(func(path): return path is String and path.begins_with("res://config/") and path.ends_with(".json") and ".." not in path.split("/")):
		return false
	if not document.get("derived_catalogues", []) is Array:
		return false
	for definition in document.get("derived_catalogues", []):
		if not definition is Dictionary or not definition.get("path") is String or not definition.path.begins_with("res://config/") or not definition.path.ends_with(".json") or ".." in definition.path.split("/") or not definition.get("prefix") is String or definition.prefix.is_empty() or ":" in definition.prefix or not definition.get("families") is Array or definition.families.is_empty() or not definition.families.all(func(family): return family is String and document.families.has(family)):
			return false
	for biome in range(4):
		if not document.families.has(document.biomes.get(str(biome), "")):
			return false
	for role in document.roles:
		var size = document.sizes.get(role)
		if not size is Array or size.size() != 2 or not size.all(func(value): return (value is int or value is float) and is_finite(value) and value > 0):
			return false
	if not document.get("cultural_roles", []) is Array or not document.get("cultural_roles", []).all(func(role): return role is String and role in Cultural.ROLES):
		return false
	if not document.get("native_dungeon_roles", []) is Array or not document.get("native_dungeon_roles", []).all(func(role): return role is String and role in DungeonSurfaces.ROLES):
		return false
	if not document.get("native_creature_fallbacks", []) is Array or not document.get("native_creature_fallbacks", []).all(func(role): return role is String and role in range(10).map(func(index): return "fallback_%s" % index)):
		return false
	if not document.get("native_decor_roles", []) is Array or not document.get("native_decor_roles", []).all(func(role): return role is String and role in Decor.ROLES):
		return false
	if not document.get("native_reward_roles", []) is Array or not document.get("native_reward_roles", []).all(func(role): return role is String and role in Rewards.ROLES):
		return false
	if not document.get("native_town_roles", []) is Array or not document.get("native_town_roles", []).all(func(role): return role is String and role in ["house", "civic_tower", "market_lot", "farm_lot"]):
		return false
	for role in document.anchors.values():
		if role not in document.roles:
			return false
	for color in ["wood", "leaf", "stone", "fungus", "flower"]:
		if not document.colors.get(color) is String or not Color.html_is_valid(document.colors[color]):
			return false
	return true

static func _valid_query(query) -> bool:
	return query is Dictionary and query.get("pack") is String and query.get("patterns") is Array and not query.patterns.is_empty() and query.patterns.all(func(value): return value is String) and query.get("tags", []) is Array and query.get("tags", []).all(func(value): return value is String)

func family_for(biome: int) -> String:
	return data.biomes.get(str(biome), "")

func family_of(asset_id: String) -> String:
	if asset_id.begins_with("biome_geometry:"):
		if biome_art.is_empty():
			biome_art = JSON.parse_string(FileAccess.get_file_as_string("res://config/biome_art.json"))
		var fields := asset_id.split(":")
		return fields[1] if fields.size() == 3 and data.families.has(fields[1]) and biome_art.get("roles", {}).get(fields[2], {}).get("native", false) else ""
	if asset_id.begins_with("native_town:"):
		var fields := asset_id.split(":")
		return fields[1] if fields.size() == 3 and data.families.has(fields[1]) and fields[2] in data.get("native_town_roles", []) else ""
	if asset_id.begins_with("native_reward:"):
		var fields := asset_id.split(":")
		return fields[1] if fields.size() == 3 and data.families.has(fields[1]) and fields[2] in data.get("native_reward_roles", []) else ""
	if asset_id.begins_with("native_item:"):
		var fields := asset_id.split(":", true, 2)
		return fields[1] if fields.size() == 3 and data.families.has(fields[1]) and item_sources.has(fields[2]) else ""
	if asset_id.begins_with("native_decor:"):
		var fields := asset_id.split(":")
		return fields[1] if fields.size() == 3 and data.families.has(fields[1]) and fields[2] in data.get("native_decor_roles", []) else ""
	if asset_id.begins_with("native_creature:"):
		var fields := asset_id.split(":", true, 2)
		if fields.size() == 3 and data.families.has(fields[1]) and (creature_sources.has(fields[2]) or fields[2] in data.get("native_creature_fallbacks", [])):
			return fields[1]
		return ""
	if asset_id.begins_with("native_dungeon:"):
		var fields := asset_id.split(":")
		return fields[1] if fields.size() == 3 and data.families.has(fields[1]) and fields[2] in data.get("native_dungeon_roles", []) else ""
	if asset_id.begins_with("native_environment:"):
		var fields := asset_id.split(":")
		return fields[1] if fields.size() == 3 and data.families.has(fields[1]) and supports(fields[2]) else ""
	return derived.get(asset_id, classified.get(asset_id, ""))

func allows(asset_id: String, biome: int) -> bool:
	var required := family_for(biome)
	return not required.is_empty() and family_of(asset_id) == required

func native_id(family: String, role: String) -> String:
	return "native_environment:%s:%s" % [family, role]

func supports(role: String) -> bool:
	return role in data.roles or role in data.get("cultural_roles", [])

func native_model(role: String, family: String, footprint: Vector2, height: float) -> Node3D:
	assert(supports(role) and data.families.has(family))
	var root := Node3D.new()
	if role in data.get("cultural_roles", []):
		root.free()
		root = Cultural.new().model(role, family)
	var block: bool = data.families[family].geometry == "voxel"
	var wood := Color(data.colors.wood)
	var leaf := Color(data.colors.leaf)
	var stone := Color(data.colors.stone)
	match role:
		"canopy", "pine", "deadwood":
			_piece(root, Vector3(.16, .65, .16), Vector3(0, .325, 0), wood, block)
			if role == "deadwood":
				for side in [-1, 1]:
					_piece(root, Vector3(.45, .10, .10), Vector3(side * .22, .60, 0), wood, block)
				_piece(root, Vector3(.12, .28, .12), Vector3(0, .80, 0), wood, block)
			elif role == "pine":
				for index in range(3):
					var width := 1.0 - index * .24
					_piece(root, Vector3(width, .40, width), Vector3(0, .40 + index * .22, 0), leaf.lightened(index * .04), block, true)
			else:
				_piece(root, Vector3(.80, .45, .80), Vector3(0, .65, 0), leaf, block, true)
				_piece(root, Vector3(.55, .28, .55), Vector3(.20, .84, -.10), leaf.lightened(.1), block, true)
		"cactus":
			_piece(root, Vector3(.25, .90, .25), Vector3(0, .45, 0), leaf, block)
			for side in [-1, 1]:
				_piece(root, Vector3(.40, .12, .14), Vector3(side * .20, .40, 0), leaf, block)
				_piece(root, Vector3(.14, .38, .14), Vector3(side * .36, .55, 0), leaf, block)
		"stone":
			_piece(root, Vector3(.90, .40, .75), Vector3(0, .20, 0), stone, block, true)
			_piece(root, Vector3(.55, .25, .55), Vector3(-.10, .45, .10), stone.lightened(.12), block, true)
		"mushroom":
			_piece(root, Vector3(.16, .55, .16), Vector3(0, .275, 0), Color("ccbea1"), block)
			_piece(root, Vector3(.90, .25, .90), Vector3(0, .64, 0), Color(data.colors.fungus), block, true)
		"flowers", "understory", "bush":
			for index in range(3):
				var x := (index - 1) * .24
				_piece(root, Vector3(.08, .40, .08), Vector3(x, .20, 0), leaf, block)
				_piece(root, Vector3(.32, .22, .28), Vector3(x, .38, 0), Color(data.colors.flower) if role == "flowers" else leaf.lightened(index * .06), block, true)
	var bounds := AABB()
	var first := true
	for mesh in root.get_children():
		var box: AABB = mesh.transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var fit := Transform3D(Basis.from_scale(Vector3(footprint.x / bounds.size.x, height / bounds.size.y, footprint.y / bounds.size.z)), Vector3.ZERO)
	for mesh in root.get_children():
		mesh.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		mesh.transform = fit * mesh.transform
	root.set_meta("visual_family", family)
	root.set_meta("native_role", role)
	return root

func _piece(parent: Node3D, size: Vector3, point: Vector3, color: Color, block: bool, canopy: bool = false) -> void:
	var mesh: MeshInstance3D
	if block:
		mesh = Voxels.cube(size, color)
	else:
		mesh = MeshInstance3D.new()
		var form := CylinderMesh.new()
		form.radial_segments = 6
		form.height = size.y
		form.bottom_radius = size.x * .5
		form.top_radius = 0 if canopy else size.x * .5
		mesh.mesh = form
		mesh.scale.z = size.z / size.x
		if not canopy and size.x > size.y * 2:
			form.height = size.x
			form.bottom_radius = size.y * .5
			form.top_radius = size.y * .5
			mesh.scale.z = size.z / size.y
			mesh.rotation.z = PI / 2
		var key := color.to_html()
		if not materials.has(key):
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.roughness = .95
			materials[key] = material
		mesh.material_override = materials[key]
	mesh.position = point
	parent.add_child(mesh)
