extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const MIN_RESOLUTION := 8
const MAX_RESOLUTION := 24
const MAX_VOXELS := MAX_RESOLUTION * MAX_RESOLUTION * MAX_RESOLUTION
const MAX_TRIANGLES := 40000
const MAX_SAMPLES := 2000000

static func voxelize(source: Node3D, resolution: int = 18, preserve_skin: bool = false, allow_flat: bool = false) -> Node3D:
	if source == null:
		return null
	var box := AABB()
	var first := true
	for part in source.get_children():
		if part is MeshInstance3D and part.mesh != null:
			var bounds: AABB = part.transform * part.mesh.get_aabb()
			box = bounds if first else box.merge(bounds)
			first = false
	if first or box.size == Vector3.ZERO:
		return null
	resolution = clampi(resolution, MIN_RESOLUTION, MAX_RESOLUTION)
	if allow_flat:
		var thickness := maxf(box.size.x, maxf(box.size.y, box.size.z)) / resolution
		for axis in range(3):
			if box.size[axis] < thickness:
				box.position[axis] -= (thickness - box.size[axis]) * .5
				box.size[axis] = thickness
	if box.size.x <= 0 or box.size.y <= 0 or box.size.z <= 0:
		return null
	var pitch := maxf(box.size.x, maxf(box.size.y, box.size.z)) / resolution
	var counts := Vector3i(mini(resolution, ceili(box.size.x / pitch)), mini(resolution, ceili(box.size.y / pitch)), mini(resolution, ceili(box.size.z / pitch)))
	var cells: Dictionary = {}
	var skin: Dictionary = {}
	var images: Dictionary = {}
	var triangles := 0
	var samples := 0
	for part in source.get_children():
		if not part is MeshInstance3D or part.mesh == null:
			continue
		for surface in range(part.mesh.get_surface_count()):
			if part.mesh is ArrayMesh and part.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var indexed := not indices.is_empty()
			var length := indices.size() if indexed else vertices.size()
			triangles += length / 3
			if triangles > MAX_TRIANGLES:
				return null
			var material: Material = part.get_active_material(surface)
			var image: Image
			if material is BaseMaterial3D and material.albedo_texture != null:
				var texture: Texture2D = material.albedo_texture
				var key := texture.get_instance_id()
				if not images.has(key):
					var decoded := texture.get_image()
					if decoded != null and decoded.is_compressed():
						decoded.decompress()
					images[key] = decoded
				image = images[key]
			for index in range(0, length - 2, 3):
				var ids := Vector3i(indices[index], indices[index + 1], indices[index + 2]) if indexed else Vector3i(index, index + 1, index + 2)
				var a: Vector3 = part.transform * vertices[ids.x]
				var b: Vector3 = part.transform * vertices[ids.y]
				var c: Vector3 = part.transform * vertices[ids.z]
				var normal := (b - a).cross(c - a).abs()
				if normal.length_squared() < 1e-18:
					continue
				var axis := normal.max_axis_index()
				var u := (axis + 1) % 3
				var v := (axis + 2) % 3
				var pa := Vector2((a[u] - box.position[u]) / pitch, (a[v] - box.position[v]) / pitch)
				var pb := Vector2((b[u] - box.position[u]) / pitch, (b[v] - box.position[v]) / pitch)
				var pc := Vector2((c[u] - box.position[u]) / pitch, (c[v] - box.position[v]) / pitch)
				var low := Vector2i(maxi(0, floori(minf(pa.x, minf(pb.x, pc.x)))), maxi(0, floori(minf(pa.y, minf(pb.y, pc.y)))))
				var high := Vector2i(mini(counts[u] - 1, floori(maxf(pa.x, maxf(pb.x, pc.x)))), mini(counts[v] - 1, floori(maxf(pa.y, maxf(pb.y, pc.y)))))
				samples += (high.x - low.x + 1) * (high.y - low.y + 1) + 3
				if samples > MAX_SAMPLES:
					return null
				for corner in range(3):
					var weights := Vector3.ZERO
					weights[corner] = 1
					_store(cells, a * weights.x + b * weights.y + c * weights.z, _color(arrays, ids, weights, material, image, preserve_skin), box, pitch, counts, skin, _influences(arrays, ids, weights) if preserve_skin else {}, allow_flat)
				for x in range(low.x, high.x + 1):
					for y in range(low.y, high.y + 1):
						var point := Vector2(x + .5, y + .5)
						if not _overlaps(pa, pb, pc, point):
							continue
						var weights := _weights(pa, pb, pc, point)
						_store(cells, a * weights.x + b * weights.y + c * weights.z, _color(arrays, ids, weights, material, image, preserve_skin), box, pitch, counts, skin, _influences(arrays, ids, weights) if preserve_skin else {}, allow_flat)
	if cells.is_empty():
		return null
	var result := Node3D.new()
	var part := MeshInstance3D.new()
	part.mesh = _mesh(cells, box, pitch, skin, preserve_skin)
	result.add_child(part)
	result.set_meta("voxel_count", cells.size())
	result.set_meta("voxel_resolution", resolution)
	result.set_meta("voxel_pitch", pitch)
	result.set_meta("voxel_source_bounds", box)
	result.set_meta("voxel_triangle_count", triangles)
	result.set_meta("voxel_sample_count", samples)
	result.set_meta("voxel_skinned", not skin.is_empty())
	return result

static func _store(cells: Dictionary, point: Vector3, color: Color, box: AABB, pitch: float, counts: Vector3i, skin: Dictionary = {}, influences: Dictionary = {}, clip_alpha: bool = false) -> void:
	if clip_alpha and color.a <= .15:
		return
	var local := (point - box.position) / pitch
	var cell := Vector3i(clampi(floori(local.x), 0, counts.x - 1), clampi(floori(local.y), 0, counts.y - 1), clampi(floori(local.z), 0, counts.z - 1))
	cells[cell] = color
	if not influences.is_empty():
		skin[cell] = influences

static func _influences(arrays: Array, ids: Vector3i, barycentric: Vector3) -> Dictionary:
	if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
		return {}
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if bones.is_empty() or weights.is_empty() or vertices.is_empty():
		return {}
	var lanes: int = weights.size() / vertices.size()
	var combined := {}
	for corner in range(3):
		for lane in range(lanes):
			var index := ids[corner] * lanes + lane
			var value: float = weights[index] * barycentric[corner]
			if is_finite(value) and value > 0:
				combined[bones[index]] = combined.get(bones[index], 0.0) + value
	var ranked: Array = combined.keys()
	ranked.sort_custom(func(a, b): return combined[a] > combined[b])
	var total := 0.0
	for bone in ranked.slice(0, 4):
		total += combined[bone]
	if not is_finite(total) or total <= 0:
		return {}
	var result := {}
	for bone in ranked.slice(0, 4):
		result[bone] = clampf(combined[bone] / total, 0, 1)
	return result

static func _overlaps(a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> bool:
	for edge in [b - a, c - b, a - c]:
		var axis := Vector2(-edge.y, edge.x)
		var center := point.dot(axis)
		var radius: float = (absf(axis.x) + absf(axis.y)) * .5
		var low := minf(a.dot(axis), minf(b.dot(axis), c.dot(axis)))
		var high := maxf(a.dot(axis), maxf(b.dot(axis), c.dot(axis)))
		if center + radius < low or center - radius > high:
			return false
	return true

static func _weights(a: Vector2, b: Vector2, c: Vector2, point: Vector2) -> Vector3:
	var denominator := (b - a).cross(c - a)
	if absf(denominator) < 1e-12:
		var distances := Vector3(point.distance_squared_to(a), point.distance_squared_to(b), point.distance_squared_to(c))
		var nearest := Vector3.ZERO
		nearest[distances.min_axis_index()] = 1
		return nearest
	var wb := (point - a).cross(c - a) / denominator
	var wc := (b - a).cross(point - a) / denominator
	var wa := 1 - wb - wc
	if minf(wa, minf(wb, wc)) < 0:
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		for edge in [[b, c], [c, a]]:
			var candidate := Geometry2D.get_closest_point_to_segment(point, edge[0], edge[1])
			if point.distance_squared_to(candidate) < point.distance_squared_to(closest):
				closest = candidate
		wb = (closest - a).cross(c - a) / denominator
		wc = (b - a).cross(closest - a) / denominator
		wa = 1 - wb - wc
	return Vector3(wa, wb, wc)

static func _color(arrays: Array, ids: Vector3i, weights: Vector3, material: Material, image: Image, linear_albedo: bool = false) -> Color:
	var result := Color.WHITE
	if material is BaseMaterial3D:
		result = material.albedo_color.linear_to_srgb() if linear_albedo else material.albedo_color
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if material.vertex_color_use_as_albedo and not colors.is_empty():
			result *= (colors[ids.x] * weights.x + colors[ids.y] * weights.y + colors[ids.z] * weights.z).linear_to_srgb()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		if image != null and not image.is_empty() and not uvs.is_empty():
			var uv := uvs[ids.x] * weights.x + uvs[ids.y] * weights.y + uvs[ids.z] * weights.z
			uv = uv * Vector2(material.uv1_scale.x, material.uv1_scale.y) + Vector2(material.uv1_offset.x, material.uv1_offset.y)
			uv = Vector2(fposmod(uv.x, 1), fposmod(uv.y, 1)) if material.texture_repeat else uv.clamp(Vector2.ZERO, Vector2.ONE)
			result *= image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1), clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1))
	return result

static func _mesh(cells: Dictionary, box: AABB, pitch: float, skin: Dictionary = {}, preserve_color: bool = false) -> ArrayMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var arrays := cube.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector3i in cells:
		var low := box.position + Vector3(cell) * pitch
		var high := (low + Vector3.ONE * pitch).min(box.end)
		var size := high - low
		var center := (low + high) * .5
		surface.set_color(cells[cell] if preserve_color else cells[cell].srgb_to_linear())
		var bones := PackedInt32Array([0, 0, 0, 0])
		var weights := PackedFloat32Array([1, 0, 0, 0])
		if skin.has(cell):
			var lane := 0
			weights.fill(0)
			for bone in skin[cell]:
				bones[lane] = bone
				weights[lane] = skin[cell][bone]
				lane += 1
		for index in indices:
			var normal := normals[index]
			if cells.has(cell + Vector3i(normal)):
				continue
			surface.set_normal(normal)
			if not skin.is_empty():
				surface.set_bones(bones)
				surface.set_weights(weights)
			surface.add_vertex(center + vertices[index] * size)
	surface.set_material(Voxels.material())
	return surface.commit()
