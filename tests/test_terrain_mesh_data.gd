extends SceneTree

const Models = preload("res://scripts/world_voxels.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	if not ResourceLoader.exists("res://scripts/terrain_mesh_data.gd"):
		push_error("Terrain palettes must share a chunk draw without changing triangle positions or colors")
		quit(1)
		return
	var Builder = load("res://scripts/terrain_mesh_data.gd")
	var pieces := []
	var expected := []
	for kind in ["land", "road", "water", "bridge", "indexed"]:
		var mesh: Mesh = Models.terrain(kind, 0, 2, 3, "", Vector2i.RIGHT, 1) if kind != "indexed" else BoxMesh.new()
		var arrays := mesh.surface_get_arrays(0)
		if kind == "indexed":
			var colors := PackedColorArray()
			colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
			colors.fill(Color("617e62"))
			arrays[Mesh.ARRAY_COLOR] = colors
		var placements := [Transform3D(Basis.IDENTITY, Vector3(-4, 2, 3)), Transform3D(Basis.IDENTITY, Vector3(7, 3.5, -2))]
		pieces.append({"arrays":arrays, "placements":placements})
		for transform in placements:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else range(vertices.size())
			for index in indices:
				expected.append([transform * vertices[index], normals[index], colors[index]])
	var data = Builder.new()
	data.start(pieces)
	data.finish()
	var actual: Array = data.arrays
	assert(actual[Mesh.ARRAY_VERTEX].size() == expected.size())
	for index in range(expected.size()):
		assert(actual[Mesh.ARRAY_VERTEX][index].is_equal_approx(expected[index][0]))
		assert(actual[Mesh.ARRAY_NORMAL][index].is_equal_approx(expected[index][1]))
		assert(actual[Mesh.ARRAY_COLOR][index] == expected[index][2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, actual)
	assert(mesh.get_surface_count() == 1, "Terrain color/height/bridge variants must draw in one surface")
	assert(data.ready and data.task == -1)
	print("PASS: worker-only packed terrain buffers preserve land/road/water/bridge vertices, normals and colors in one surface")
	quit()
