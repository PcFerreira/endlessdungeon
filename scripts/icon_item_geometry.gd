extends RefCounted

const Style = preload("res://scripts/animated_model_style.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const MAX_SIZE := 32

func mesh(source: Image, family: String) -> ArrayMesh:
	if source == null or source.is_empty() or family not in ["block_voxel", "flat_lowpoly"]:
		return null
	var image: Image = source.duplicate()
	if image.is_compressed():
		image.decompress()
	var size := Vector2i(image.get_width(), image.get_height())
	var factor := minf(1, float(MAX_SIZE) / maxi(size.x, size.y))
	if factor < 1:
		image.resize(maxi(1, roundi(size.x * factor)), maxi(1, roundi(size.y * factor)), Image.INTERPOLATE_NEAREST)
	var cells := {}
	var pitch := 1.0 / maxi(image.get_width(), image.get_height())
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			var color := image.get_pixel(x, y)
			if color.a > .25:
				cells[Vector3i(x, image.get_height() - y - 1, 0)] = color
	if cells.is_empty():
		return null
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var arrays := cube.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector3i in cells:
		var center := Vector3((cell.x + .5 - image.get_width() * .5) * pitch, (cell.y + .5) * pitch, 0)
		surface.set_color(cells[cell])
		for index in indices:
			var normal := normals[index]
			if cells.has(cell + Vector3i(normal)):
				continue
			surface.set_normal(normal)
			surface.add_vertex(center + vertices[index] * Vector3(pitch, pitch, .14))
	surface.set_material(Voxels.material())
	var result := surface.commit()
	return result if family == "block_voxel" else Style.faceted(result)
