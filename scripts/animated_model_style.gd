extends RefCounted

const Voxelizer = preload("res://scripts/town_model_voxelizer.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var meshes := {}
var error := ""
const CACHE_LIMIT := 192

func convert(source: Node3D, family: String, resolution: int = 14, allow_flat: bool = false) -> bool:
	error = ""
	if family not in ["block_voxel", "flat_lowpoly"] or source == null:
		error = "Unknown animated visual family"
		return false
	var replacements := []
	var parts := source.find_children("*", "MeshInstance3D", true, false)
	if source is MeshInstance3D:
		parts.push_front(source)
	for node in parts:
		if node.mesh == null:
			continue
		var original: Mesh = node.mesh
		var materials := []
		for surface in range(original.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			materials.append(material.get_instance_id() if material != null else 0)
		var key := str([original.get_instance_id(), materials, family, resolution, allow_flat])
		if not meshes.has(key):
			var holder := Node3D.new()
			var part := MeshInstance3D.new()
			part.mesh = original
			for surface in range(original.get_surface_count()):
				part.set_surface_override_material(surface, node.get_active_material(surface))
			holder.add_child(part)
			var converted: Node3D = Voxelizer.voxelize(holder, resolution, true, allow_flat)
			holder.free()
			if converted == null:
				error = "Animated model exceeds style conversion limits"
				return false
			var mesh: ArrayMesh = converted.get_child(0).mesh
			if family == "flat_lowpoly":
				mesh = faceted(mesh)
			converted.free()
			if mesh == null:
				error = "Animated model has a collapsed faceted surface"
				return false
			if meshes.size() >= CACHE_LIMIT:
				meshes.erase(meshes.keys()[0])
			meshes[key] = mesh
		replacements.append({"node": node, "mesh": meshes[key]})
	if replacements.is_empty():
		error = "Animated model has no convertible geometry"
		return false
	for replacement in replacements:
		var node: MeshInstance3D = replacement.node
		node.mesh = replacement.mesh
		node.material_override = null
		for surface in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(surface, null)
		node.set_meta("visual_family", family)
	source.set_meta("visual_family", family)
	source.set_meta("representation", "voxelized" if family == "block_voxel" else "faceted_surface")
	return true

static func faceted(mesh: ArrayMesh) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var original: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var box := mesh.get_aabb()
	var quantum := maxf(box.size.x, maxf(box.size.y, box.size.z)) * .00001
	var lookup := {}
	var points: Array[Vector3] = []
	var ids: Array[int] = []
	var neighbors: Array[Dictionary] = []
	for vertex in original:
		var key := Vector3i(roundi(vertex.x / quantum), roundi(vertex.y / quantum), roundi(vertex.z / quantum))
		if not lookup.has(key):
			lookup[key] = points.size()
			points.append(vertex)
			neighbors.append({})
		ids.append(lookup[key])
	for index in range(0, ids.size(), 3):
		for edge in [[ids[index], ids[index + 1]], [ids[index + 1], ids[index + 2]], [ids[index + 2], ids[index]]]:
			neighbors[edge[0]][edge[1]] = true
			neighbors[edge[1]][edge[0]] = true
	for iteration in range(8):
		for factor in [.5, -.1]:
			var next: Array[Vector3] = points.duplicate()
			for index in range(points.size()):
				var average := Vector3.ZERO
				for neighbor in neighbors[index]:
					average += points[neighbor]
				if not neighbors[index].is_empty():
					next[index] = points[index].lerp(average / neighbors[index].size(), factor)
			points = next
	var fitted := AABB(points[0], Vector3.ZERO)
	for point in points:
		fitted = fitted.expand(point)
	if fitted.size.x <= 0 or fitted.size.y <= 0 or fitted.size.z <= 0:
		return null
	var scale := box.size / fitted.size
	for index in range(points.size()):
		points[index] = (points[index] - fitted.position) * scale + box.position
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(0, ids.size(), 3):
		var a := points[ids[index]]
		var b := points[ids[index + 1]]
		var c := points[ids[index + 2]]
		var normal := (c - a).cross(b - a).normalized()
		for offset in range(3):
			var vertex := index + offset
			surface.set_color(colors[vertex])
			surface.set_normal(normal)
			if not bones.is_empty():
				surface.set_bones(bones.slice(vertex * 4, vertex * 4 + 4))
				surface.set_weights(weights.slice(vertex * 4, vertex * 4 + 4))
			surface.add_vertex(points[ids[vertex]])
	surface.set_material(Voxels.material())
	return surface.commit()
