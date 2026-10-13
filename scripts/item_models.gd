extends RefCounted

const Styles = preload("res://scripts/environment_styles.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const Catalog = preload("res://scripts/item_catalog.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Conversion = preload("res://scripts/animated_model_style.gd")
const Icons = preload("res://scripts/icon_item_geometry.gd")
const Rewards = preload("res://scripts/native_reward_models.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
var registry := Registry.new()
var styles := Styles.new(registry)
var renderer := Conversion.new()
var icons := Icons.new()
var meshes := {}
var error := ""
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_styles.json"))
const CACHE_LIMIT := 192

func create(item: Dictionary, family: String) -> Node3D:
	error = ""
	if not styles.data.families.has(family):
		error = "Unknown item visual family"
		return null
	var role: String = data.reward_icons.get(item.get("icon", ""), "")
	if not role.is_empty() and ((not item.has("asset_id") and not item.has("scenery_key")) or item.get("currency", "") == "gold"):
		var body := Rewards.model(role, family)
		body.set_meta("source_asset", item.get("asset_id", item.icon))
		body.set_meta("render_asset", body.get_meta("asset_id"))
		body.set_meta("representation", "native_reward")
		tag(body)
		return body
	if item.has("asset_id"):
		return source_model(item.asset_id, family)
	if item.has("scenery_key"):
		return source_model(item.scenery_key, family)
	var source: String = item.get("source_asset", item.get("icon", ""))
	if not styles.item_sources.has(source):
		error = "Unknown item icon source: " + source
		return null
	var key: String = str([item.icon, item.get("icon_region", []), family])
	if not meshes.has(key):
		var texture := Catalog.icon(item)
		var mesh := icons.mesh(texture.get_image(), family)
		if mesh == null:
			error = "Item icon has no visible silhouette: " + source
			return null
		if meshes.size() >= CACHE_LIMIT:
			meshes.erase(meshes.keys()[0])
		meshes[key] = mesh
	var body := MeshInstance3D.new()
	body.mesh = meshes[key]
	body.set_meta("source_asset", source)
	body.set_meta("render_asset", "native_item:%s:%s" % [family, source])
	body.set_meta("visual_family", family)
	body.set_meta("representation", "icon_extrusion")
	body.set_meta("icon_region", item.get("icon_region", []).duplicate())
	tag(body)
	return body

func source_model(source: String, family: String) -> Node3D:
	if not styles.data.families.has(family):
		error = "Unknown item visual family"
		return null
	if Scenery.is_native(source):
		var fields := source.split(":")
		var target := styles.native_id(family, fields[2])
		var body := Scenery.new().model(target, 1)
		body.set_meta("source_asset", source)
		body.set_meta("render_asset", target)
		body.set_meta("visual_family", family)
		body.set_meta("representation", "native_role")
		tag(body)
		return body
	var body: Node3D
	if registry.get_asset(source).get("kind") == "model":
		body = registry.instantiate(source)
	elif source in data.scenery_sources:
		body = Scenery.new().model(source, 1)
	if body == null:
		error = "Unavailable item model: " + source
		return null
	if not adapt(body, source, family):
		body.free()
		return null
	return body

func fitted(body: Node3D, footprint: Vector2, height: float, yaw: float = 0) -> Node3D:
	if body == null:
		return null
	var root := Node3D.new()
	root.add_child(body)
	body.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * body.transform
	var box := Bounds.bounds(root)
	if box.size.x <= 0 or box.size.y <= 0 or box.size.z <= 0:
		error = "Item body cannot fit a positive placement volume"
		root.free()
		return null
	var fit := Transform3D(Basis.from_scale(Vector3(footprint.x / box.size.x, height / box.size.y, footprint.y / box.size.z)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	body.transform = fit * body.transform
	for key in ["source_asset", "render_asset", "visual_family", "representation"]:
		root.set_meta(key, body.get_meta(key))
	tag(root)
	return root

func adapt(body: Node3D, source: String, family: String) -> bool:
	if not styles.data.families.has(family) or not styles.item_sources.has(source):
		error = "Unregistered item derivative source: " + source
		return false
	var box := Bounds.bounds(body)
	var minimum := maxf(box.size.x, maxf(box.size.y, box.size.z)) * .0001
	var direct := styles.family_of(source) == family and box.size.x > minimum and box.size.y > minimum and box.size.z > minimum
	if not direct and not renderer.convert(body, family, 18, true):
		error = renderer.error + ": " + source
		return false
	body.set_meta("source_asset", source)
	body.set_meta("render_asset", "native_item:%s:%s" % [family, source])
	body.set_meta("visual_family", family)
	body.set_meta("representation", "direct" if direct else body.get_meta("representation"))
	tag(body)
	return true

static func tag(body: Node3D) -> void:
	body.set_meta("asset_id", body.get_meta("render_asset"))
	for part in body.find_children("*", "MeshInstance3D", true, false):
		for key in ["source_asset", "render_asset", "visual_family"]:
			part.set_meta(key, body.get_meta(key))
		part.set_meta("asset_id", body.get_meta("render_asset"))
