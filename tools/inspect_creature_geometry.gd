extends SceneTree
const Registry = preload("res://scripts/asset_registry.gd")
func _initialize() -> void:
	var registry := Registry.new()
	for asset in registry.find("model", [], "bundle_animal_samples"):
		var source := registry.instantiate(asset.id)
		var area := 0.0
		var axis_area := 0.0
		for part in source.find_children("*", "MeshInstance3D", true, false):
			for surface in range(part.mesh.get_surface_count()):
				var arrays: Array = part.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var length: int = vertices.size() if indices.is_empty() else indices.size()
				for triangle in range(0, length, 3):
					var a := vertices[triangle if indices.is_empty() else indices[triangle]]
					var b := vertices[triangle + 1 if indices.is_empty() else indices[triangle + 1]]
					var c := vertices[triangle + 2 if indices.is_empty() else indices[triangle + 2]]
					var cross := (b - a).cross(c - a)
					area += cross.length()
					var normal := cross.normalized().abs()
					if maxf(normal.x, maxf(normal.y, normal.z)) > .9999:
						axis_area += cross.length()
		print(asset.id, " / axis face area ", axis_area / maxf(area, .001))
		source.free()
	quit()
