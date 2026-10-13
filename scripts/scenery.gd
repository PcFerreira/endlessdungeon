extends RefCounted

const Profiles = preload("res://scripts/asset_profiles.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const Styles = preload("res://scripts/environment_styles.gd")
static var native_styles
var registry := Registry.new()

const MODELS := {
	"barrel": "res://assets/environment/kaykit/barrel_large.gltf",
	"crates": "res://assets/environment/kaykit/crates_stacked.gltf",
	"banner_blue": "res://assets/environment/kaykit/banner_blue.gltf",
	"banner_red": "res://assets/environment/kaykit/banner_patternA_red.gltf",
	"torch": "res://assets/environment/kaykit/torch_mounted.gltf",
	"floor": "res://assets/environment/kaykit/floor_tile_small.gltf",
	"floor_broken": "res://assets/environment/kaykit/floor_tile_small_broken_A.gltf",
	"arch": "res://assets/environment/quaternius/Arch_Gothic.fbx",
	"stag": "res://assets/environment/quaternius/Statue_Stag.fbx",
	"pot": "res://assets/environment/quaternius/Pot1.fbx"
}
var templates: Dictionary = {}
var tinted_materials: Dictionary = {}

static func is_native(key: String) -> bool:
	if not key.begins_with("native_environment:"):
		return false
	if native_styles == null:
		native_styles = Styles.new()
	return not native_styles.family_of(key).is_empty()

func model(key: String, width: float, height: float = 0.0, tint: Color = Color.WHITE) -> Node3D:
	if is_native(key):
		var fields := key.split(":")
		var extent: Vector2
		var natural_height: float
		if fields[2] in native_styles.data.roles:
			var size: Array = native_styles.data.sizes[fields[2]]
			extent = Vector2.ONE * width
			natural_height = float(size[1]) * width / float(size[0])
		else:
			if not templates.has(key):
				templates[key] = Styles.Cultural.new().model(fields[2], fields[1])
			var box := bounds(templates[key])
			var factor := width / maxf(box.size.x, box.size.z)
			extent = Vector2(box.size.x, box.size.z) * factor
			natural_height = box.size.y * factor
		return native_styles.native_model(fields[2], fields[1], extent, height if height > 0 else natural_height)
	if not templates.has(key):
		var source: Node3D
		if MODELS.has(key) or Profiles.MODELS.has(key):
			var path: String = MODELS[key] if MODELS.has(key) else Profiles.MODELS[key][0]
			if ResourceLoader.exists(path):
				var scene: PackedScene = load(path)
				source = scene.instantiate()
			else:
				source = registry.instantiate(path.trim_prefix("res://assets/expansion/"))
		else:
			source = registry.instantiate(key)
		if source == null:
			push_error("Unknown scenery model: " + key)
			return null
		var template := Node3D.new()
		_collect(source, Transform3D.IDENTITY, template)
		source.free()
		templates[key] = template
	var result: Node3D = templates[key].duplicate()
	var box := bounds(result)
	var scale_factor := width / maxf(box.size.x, box.size.z)
	var size := Vector3.ONE * scale_factor
	if height > 0:
		size.y = height / box.size.y
	var offset := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for child in result.get_children():
		child.position += offset
		child.transform = Transform3D(Basis.from_scale(size), Vector3.ZERO) * child.transform
		if tint != Color.WHITE:
			for surface in range(child.mesh.get_surface_count()):
				var original: StandardMaterial3D = child.get_active_material(surface)
				var material_key := "%s:%s" % [original.get_instance_id(), tint]
				if not tinted_materials.has(material_key):
					var material: StandardMaterial3D = original.duplicate()
					material.albedo_color *= tint
					tinted_materials[material_key] = material
				child.set_surface_override_material(surface, tinted_materials[material_key])
	return result

func profiled(key: String, tint: Color = Color.WHITE) -> Node3D:
	var profile: Array = Profiles.MODELS[key]
	return model(key, profile[1], profile[2], tint)

func fitted_model(key: String, footprint: Vector2, height: float, yaw: float = 0) -> Node3D:
	var result := model(key, 1.0, height)
	var rotation := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	for part in result.get_children():
		part.transform = rotation * part.transform
	var box := bounds(result)
	var fit := Transform3D(Basis.from_scale(Vector3(footprint.x / box.size.x, 1, footprint.y / box.size.z)), Vector3.ZERO)
	for part in result.get_children():
		part.transform = fit * part.transform
	return result

func _collect(node: Node, parent_transform: Transform3D, result: Node3D) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D:
		var part := MeshInstance3D.new()
		part.mesh = node.mesh
		part.transform = transform
		for surface in range(node.mesh.get_surface_count()):
			var original = node.get_active_material(surface)
			if original == null:
				original = StandardMaterial3D.new()
				var colors = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				original.vertex_color_use_as_albedo = colors != null and not colors.is_empty()
				node.set_surface_override_material(surface, original)
			if original is StandardMaterial3D:
				var material: StandardMaterial3D = original.duplicate()
				material.roughness = .95
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				part.set_surface_override_material(surface, material)
		result.add_child(part)
	for child in node.get_children():
		_collect(child, transform, result)

func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D:
			var box: AABB = child.transform * child.mesh.get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result

func valid_materials(node: Node3D) -> bool:
	for child in node.get_children():
		if not child is MeshInstance3D:
			continue
		for surface in range(child.mesh.get_surface_count()):
			var material = child.get_active_material(surface)
			if not material is StandardMaterial3D:
				return false
			var texture = material.albedo_texture
			if texture != null and (texture.get_width() == 0 or not texture.resource_path.begins_with("res://assets/")):
				return false
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for template in templates.values():
			template.free()
