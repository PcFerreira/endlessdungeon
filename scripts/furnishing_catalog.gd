extends RefCounted

const Inventory = preload("res://scripts/inventory.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const ItemModels = preload("res://scripts/item_models.gd")
static var families := ItemModels.new()
const PATH := "res://config/sanctum_furnishings.json"
static var data: Dictionary = _read()
static var registry := Registry.new()

static func _read() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(document), "Invalid Sanctum furnishing recipes")
	return document

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("items") is Dictionary or not document.get("profiles") is Dictionary or document.profiles.is_empty() or not document.get("rules") is Array:
		return false
	for spec in document.profiles.values():
		if not spec is Dictionary or not spec.get("footprint") is Array or spec.footprint.size() != 2 or not spec.footprint.all(func(value): return number(value) and value > 0 and value <= 4):
			return false
		if not number(spec.get("height")) or spec.height <= 0 or spec.height > 2.5 or spec.get("support") not in ["floor", "wall", "surface"] or not spec.get("solid") is bool:
			return false
		if not number(spec.get("elevation", 0)) or spec.get("elevation", 0) < 0 or not number(spec.get("source_yaw", 0)):
			return false
		for key in ["surface", "wall_back", "rug", "light"]:
			if spec.has(key) and not spec[key] is bool:
				return false
		if (spec.support == "wall" or spec.get("wall_back", false)) and spec.height + spec.get("elevation", 0) > 1.8:
			return false
		if spec.support != "wall" and spec.get("elevation", 0) != 0:
			return false
		if spec.support == "surface" and (spec.get("surface", false) or spec.solid):
			return false
	for entry in document.items.values():
		if not entry is Dictionary or not document.profiles.has(entry.get("profile")) or not entry.get("model") is String or entry.model.is_empty():
			return false
	for rule in document.rules:
		if not rule is Dictionary or not document.profiles.has(rule.get("profile")) or not rule.get("patterns") is Array or rule.patterns.is_empty() or not rule.patterns.all(func(pattern): return pattern is String and not pattern.is_empty()):
			return false
		if rule.has("surface") and not rule.surface is bool:
			return false
	return true

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func definition(id: String) -> Dictionary:
	var item: Dictionary = Inventory.ITEMS.get(id, {})
	if item.get("kind") != "furnishing":
		return {}
	var entry: Dictionary = data.items.get(id, {})
	var model: String = entry.get("model", item.get("asset_id", item.get("scenery_key", "")))
	var profile: String = entry.get("profile", item.get("furnishing_profile", ""))
	var selection := {}
	if profile.is_empty() and not model.is_empty():
		var name: String = item.get("native_role", model.get_file().get_basename())
		for rule in data.rules:
			if rule.patterns.any(func(pattern): return name.matchn(pattern)):
				profile = rule.profile
				selection = rule
				break
	if not data.profiles.has(profile) or (not model.begins_with("procedural:") and not Scenery.is_native(model) and registry.get_asset(model).get("kind", "") != "model"):
		return {}
	var result: Dictionary = data.profiles[profile].duplicate(true)
	result.profile = profile
	result.model = model
	result.name = item.name
	if selection.has("surface"):
		result.surface = selection.surface
	return result

static func footprint(spec: Dictionary, rotation: int) -> Vector2:
	var size := Vector2(spec.footprint[0], spec.footprint[1])
	return Vector2(size.y, size.x) if rotation % 2 == 1 else size

static func model(record: Dictionary, renderer = null, family: String = "") -> Node3D:
	var spec := definition(record.item)
	var size := footprint(spec, record.rotation)
	var result: Node3D
	if spec.model == "procedural:rug":
		result = Node3D.new()
		result.add_child(Voxels.instance(Voxels.mesh([
			[Vector3(0, .012, 0), Vector3(size.x, .024, size.y), Color("775b8e")],
			[Vector3(0, .029, 0), Vector3(size.x - .12, .011, size.y - .12), Color("bc9465")],
			[Vector3(0, .033, 0), Vector3(size.x - .30, .004, size.y - .30), Color("826ba6")]
		])))
	elif spec.model == "procedural:lantern":
		result = Node3D.new()
		result.add_child(Voxels.instance(Voxels.mesh([
			[Vector3(0, .06, 0), Vector3(.45, .12, .45), Color("806956")],
			[Vector3(0, .40, 0), Vector3(.22, .56, .22), Color("927791")],
			[Vector3(0, .40, 0), Vector3(.30, .34, .30), Color("92ded5")],
			[Vector3(0, .73, 0), Vector3(.38, .14, .38), Color("bea570")]
		])))
	else:
		if not family.is_empty():
			result = families.fitted(families.source_model(spec.model, family), size, spec.height, record.rotation * PI / 2 + deg_to_rad(spec.get("source_yaw", 0)))
		else:
			var scenery = Scenery.new() if renderer == null else renderer
			result = scenery.fitted_model(spec.model, size, spec.height, record.rotation * PI / 2 + deg_to_rad(spec.get("source_yaw", 0)))
	if spec.model.begins_with("procedural:") and not family.is_empty():
		if not families.adapt(result, spec.model, family):
			result.free()
			return null
		result = families.fitted(result, size, spec.height)
	if result == null:
		return null
	if spec.get("light", false):
		var light := OmniLight3D.new()
		light.position.y = spec.height * .65
		light.light_color = Color("9fe8dc")
		light.light_energy = .65
		light.omni_range = 3
		result.add_child(light)
	return result
