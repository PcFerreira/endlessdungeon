extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const ROLES = ["floor", "wall_high", "wall_low", "stairs", "portal", "chest", "mote"]

static func id(family: String, role: String) -> String:
	return "native_dungeon:%s:%s" % [family, role]

static func mesh(role: String, family: String, palette: int, tone: int = 0, along_x: bool = true, opened: bool = false) -> ArrayMesh:
	assert(role in ROLES and family in ["block_voxel", "flat_lowpoly"] and palette in range(3))
	if family == "block_voxel":
		match role:
			"floor": return Voxels.tile(tone, palette)
			"wall_high", "wall_low": return Voxels.wall(role == "wall_high", along_x, palette)
			"portal": return Voxels.portal()
			"chest": return Voxels.reward_chest(opened)
	var stone: Color = [Color("49565c"), Color("504d61"), Color("455c55")][palette]
	var boxes: Array = []
	match role:
		"floor":
			boxes = [[Vector3(0, -.05, 0), Vector3(.985, .12, .985), stone.lightened(.12 + tone * .025)]]
		"wall_high", "wall_low":
			var height := 1.30 if role == "wall_high" else .26
			var body := Vector3(.96, height, .22) if along_x else Vector3(.22, height, .96)
			var cap := Vector3(.99, .09, .29) if along_x else Vector3(.29, .09, .99)
			boxes = [[Vector3(0, height * .5, 0), body, stone], [Vector3(0, height + .01, 0), cap, stone.lightened(.14)]]
		"stairs":
			boxes = [[Vector3(0, .05, 0), Vector3(1.1, .1, 1.1), Color("9c9077")], [Vector3(0, .12, -.2), Vector3(1.1, .1, .7), Color("b3a487")], [Vector3(0, .22, -.4), Vector3(1.1, .1, .3), Color("c5b79b")]]
		"portal":
			boxes = [[Vector3(0, .04, 0), Vector3(1.35, .08, 1.35), Color("282d3b")], [Vector3(0, .11, 0), Vector3(1.12, .06, 1.12), Color("716886")]]
			for side in [-1, 1]:
				boxes.append([Vector3(side * .62, .75, 0), Vector3(.22, 1.5, .32), Color("827a86")])
			boxes.append([Vector3(0, 1.66, 0), Vector3(1.46, .22, .34), Color("9c8c9b")])
		"chest":
			var wood := Color("82603e")
			var gold := Color("dfba68")
			boxes = [[Vector3(0, .22, 0), Vector3(.90, .44, .62), wood], [Vector3(-.32, .24, 0), Vector3(.07, .48, .66), gold], [Vector3(.32, .24, 0), Vector3(.07, .48, .66), gold], [Vector3(0, .27, .33), Vector3(.15, .16, .06), gold], [Vector3(0, .55 if not opened else .69, 0 if not opened else -.27), Vector3(.94, .20 if not opened else .47, .66 if not opened else .13), wood.lightened(.13)]]
		"mote":
			boxes = [[Vector3.ZERO, Vector3.ONE * .1, Color("6ddeca")]]
	return mesh_boxes(boxes, family)

static func mesh_boxes(boxes: Array, family: String) -> ArrayMesh:
	assert(family in ["block_voxel", "flat_lowpoly"])
	if family == "block_voxel":
		return Voxels.mesh(boxes)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box in boxes:
		_prism(surface, box[0], box[1], box[2])
	surface.set_material(Voxels.material())
	return surface.commit()

static func node(role: String, family: String, palette: int, opened: bool = false) -> MeshInstance3D:
	var result := Voxels.instance(mesh(role, family, palette, 0, true, opened))
	result.set_meta("asset_id", id(family, role))
	result.set_meta("visual_family", family)
	result.set_meta("native_role", role)
	if role == "mote":
		result.material_override = Voxels.glow(Color("6ddeca"))
	return result

static func _prism(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var x := size.x * .5
	var z := size.z * .5
	var bevel := minf(.035, minf(size.x, size.z) * .2)
	var outline := [Vector2(-x + bevel, -z), Vector2(x - bevel, -z), Vector2(x, -z + bevel), Vector2(x, z - bevel), Vector2(x - bevel, z), Vector2(-x + bevel, z), Vector2(-x, z - bevel), Vector2(-x, -z + bevel)]
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for point in outline:
		bottom.append(center + Vector3(point.x, -size.y * .5, point.y))
		top.append(center + Vector3(point.x, size.y * .5, point.y))
	for index in range(1, outline.size() - 1):
		_triangle(surface, top[0], top[index + 1], top[index], color)
		_triangle(surface, bottom[0], bottom[index], bottom[index + 1], color)
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		_triangle(surface, bottom[index], top[index], top[next], color.darkened(.04))
		_triangle(surface, bottom[index], top[next], bottom[next], color.darkened(.04))

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, c, b]:
		surface.set_normal(normal)
		surface.set_color(color.srgb_to_linear())
		surface.add_vertex(point)
