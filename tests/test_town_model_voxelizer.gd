extends SceneTree

const Converter = preload("res://scripts/town_model_voxelizer.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Registry = preload("res://scripts/asset_registry.gd")

func _init() -> void:
	var source := Node3D.new()
	var part := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(2, 3, 1)
	part.mesh = cube
	part.position = Vector3(1, 2, -1)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c07b39")
	part.material_override = material
	source.add_child(part)
	var original_arrays := cube.surface_get_arrays(0)
	var converted := Converter.voxelize(source, 18)
	assert(_check_bounds(source, converted))
	assert(_check_blocks(converted))
	var colors: PackedColorArray = converted.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert(_color_near(colors[0], material.albedo_color.srgb_to_linear()), "Material color must survive conversion")
	assert(cube.surface_get_arrays(0) == original_arrays and part.material_override == material)
	assert(part.position == Vector3(1, 2, -1), "Source transform must remain unchanged")
	converted.free()
	for requested in [-10, 99]:
		converted = Converter.voxelize(source, requested)
		assert(converted.get_meta("voxel_resolution") == (8 if requested < 8 else 24))
		assert(_check_bounds(source, converted))
		converted.free()
	var colored := ArrayMesh.new()
	var colored_arrays := cube.surface_get_arrays(0)
	var vertex_colors := PackedColorArray()
	vertex_colors.resize(colored_arrays[Mesh.ARRAY_VERTEX].size())
	vertex_colors.fill(Color("81cf95").srgb_to_linear())
	colored_arrays[Mesh.ARRAY_COLOR] = vertex_colors
	colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, colored_arrays)
	part.mesh = colored
	material.vertex_color_use_as_albedo = true
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color("c9d8ec"))
	material.albedo_texture = ImageTexture.create_from_image(image)
	converted = Converter.voxelize(source)
	colors = converted.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var expected := (material.albedo_color * Color("81cf95") * image.get_pixel(0, 0)).srgb_to_linear()
	assert(_color_near(colors[0], expected), "Material, vertex and texture colors must combine")
	assert(material.vertex_color_use_as_albedo and material.albedo_texture != null)
	converted.free()
	source.free()
	var wall := Node3D.new()
	for box in [[Vector3(-1, 1.5, 0), Vector3(1, 3, .3)], [Vector3(1, 1.5, 0), Vector3(1, 3, .3)], [Vector3(0, 2.75, 0), Vector3(1, .5, .3)]]:
		var mesh := BoxMesh.new()
		mesh.size = box[1]
		var block := MeshInstance3D.new()
		block.mesh = mesh
		block.position = box[0]
		wall.add_child(block)
	converted = Converter.voxelize(wall, 24)
	assert(_check_bounds(wall, converted))
	assert(_check_blocks(converted))
	var vertices: PackedVector3Array = converted.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		assert(not (absf(vertex.x) < .3 and vertex.y < 2.3), "Open doorway must remain open")
	converted.free()
	wall.free()
	var unindexed := Node3D.new()
	var triangle := ArrayMesh.new()
	var triangle_arrays: Array = []
	triangle_arrays.resize(Mesh.ARRAY_MAX)
	triangle_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ONE, Vector3(1, 0, 0)])
	triangle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, triangle_arrays)
	assert(triangle.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == null, "Regression must exercise a missing index array")
	var triangle_part := MeshInstance3D.new()
	triangle_part.mesh = triangle
	unindexed.add_child(triangle_part)
	converted = Converter.voxelize(unindexed)
	assert(_check_bounds(unindexed, converted))
	assert(_check_blocks(converted))
	converted.free()
	unindexed.free()
	var oversized := Node3D.new()
	var many := ArrayMesh.new()
	var many_arrays: Array = []
	many_arrays.resize(Mesh.ARRAY_MAX)
	many_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ONE, Vector3(1, 0, 0)])
	var many_indices := PackedInt32Array()
	for index in range(Converter.MAX_TRIANGLES + 1):
		many_indices.append_array(PackedInt32Array([0, 1, 2]))
	many_arrays[Mesh.ARRAY_INDEX] = many_indices
	many.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, many_arrays)
	var many_part := MeshInstance3D.new()
	many_part.mesh = many
	oversized.add_child(many_part)
	assert(Converter.voxelize(oversized) == null, "Budget exhaustion must reject rather than return a partial model")
	oversized.free()
	var registry := Registry.new()
	var entries := registry.find("model", [], "kaykit_medieval_hexagon")
	var key := ""
	for entry in entries:
		if entry.id.ends_with("building_home_A_blue.gltf"):
			key = entry.id
	assert(not key.is_empty(), "Existing imported complete home is required")
	var scenery := Scenery.new()
	source = scenery.fitted_model(key, Vector2(3.1, 2.7), 3.4, PI * .5)
	assert(source != null)
	var snapshots: Array = []
	for child in source.get_children():
		var mesh_snapshots: Array = []
		for surface in range(child.mesh.get_surface_count()):
			mesh_snapshots.append(child.mesh.surface_get_arrays(surface))
		snapshots.append([child.mesh, child.transform, mesh_snapshots])
	var started := Time.get_ticks_usec()
	converted = Converter.voxelize(source)
	var conversion_msec := (Time.get_ticks_usec() - started) / 1000.0
	assert(_check_bounds(source, converted))
	assert(_check_blocks(converted))
	var palette: Dictionary = {}
	colors = converted.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for color in colors:
		palette[color] = true
	assert(palette.size() > 3, "Imported texture/material palette must survive")
	for index in range(source.get_child_count()):
		var child := source.get_child(index)
		assert(child.mesh == snapshots[index][0] and child.transform == snapshots[index][1])
		for surface in range(child.mesh.get_surface_count()):
			assert(child.mesh.surface_get_arrays(surface) == snapshots[index][2][surface], "Imported mesh arrays must remain unchanged")
	print("Imported home: %d voxels, %d vertices, %d colors, %.1f ms conversion" % [converted.get_meta("voxel_count"), colors.size(), palette.size(), conversion_msec])
	converted.free()
	source.free()
	print("PASS: bounded axis-aligned imported-building voxels, colors, fitted bounds, source immutability, open doorway")
	quit()

func _check_bounds(source: Node3D, converted: Node3D) -> bool:
	assert(converted != null and converted.get_child_count() == 1)
	var scenery := Scenery.new()
	var before := scenery.bounds(source)
	var after := scenery.bounds(converted)
	assert(before.position.is_equal_approx(after.position), "Fitted origin/ground must remain unchanged")
	assert(before.size.is_equal_approx(after.size), "Fitted footprint/height must remain unchanged")
	assert(converted.get_meta("voxel_count") <= Converter.MAX_VOXELS)
	var vertices: PackedVector3Array = converted.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices.size() <= converted.get_meta("voxel_count") * 36)
	for vertex in vertices:
		assert(vertex.x >= before.position.x - .00001 and vertex.x <= before.end.x + .00001)
		assert(vertex.y >= before.position.y - .00001 and vertex.y <= before.end.y + .00001)
		assert(vertex.z >= before.position.z - .00001 and vertex.z <= before.end.z + .00001)
	return true

func _check_blocks(model: Node3D) -> bool:
	var arrays: Array = model.get_child(0).mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(not normals.is_empty())
	for normal in normals:
		assert(normal.distance_to(normal.round()) < .001 and is_equal_approx(normal.length(), 1), "Voxel faces must have axis-aligned unit normals")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box: AABB = model.get_meta("voxel_source_bounds")
	var pitch: float = model.get_meta("voxel_pitch")
	for vertex in vertices:
		for axis in range(3):
			var coordinate := (vertex[axis] - box.position[axis]) / pitch
			assert(absf(coordinate - roundf(coordinate)) < .001 or absf(vertex[axis] - box.end[axis]) < .0001, "Block vertices must lie on the voxel grid or clipped bounds")
	return true

func _color_near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < .005 and absf(a.g - b.g) < .005 and absf(a.b - b.b) < .005
