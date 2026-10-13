extends RefCounted

var task := -1
var ready := false
var arrays: Array = []

func start(pieces: Array) -> void:
	task = WorkerThreadPool.add_task(_build.bind(pieces), false, "Chunk terrain buffers")

func finish() -> void:
	if task >= 0:
		WorkerThreadPool.wait_for_task_completion(task)
		task = -1
	ready = true

func _build(pieces: Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for piece in pieces:
		var source: Array = piece.arrays
		var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var source_colors: PackedColorArray = source[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX] if source[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for transform in piece.placements:
			assert(transform.basis == Basis.IDENTITY)
			if indices.is_empty():
				for point in positions:
					vertices.append(point + transform.origin)
				normals.append_array(source_normals)
				colors.append_array(source_colors)
			else:
				for index in indices:
					vertices.append(positions[index] + transform.origin)
					normals.append(source_normals[index])
					colors.append(source_colors[index])
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
