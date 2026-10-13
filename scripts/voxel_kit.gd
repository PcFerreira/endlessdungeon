extends RefCounted

static var stone_material: StandardMaterial3D
static var glow_materials: Dictionary = {}

static func material() -> StandardMaterial3D:
	if stone_material == null:
		stone_material = StandardMaterial3D.new()
		stone_material.vertex_color_use_as_albedo = true
		stone_material.roughness = 0.95
	return stone_material

static func glow(color: Color) -> StandardMaterial3D:
	if not glow_materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = .7
		glow_materials[color] = result
	return glow_materials[color]

static func mesh(boxes: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for box in boxes:
		var cube := BoxMesh.new()
		cube.size = box[1]
		var arrays := cube.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in indices:
			surface.set_normal(normals[index])
			var color: Color = box[2]
			surface.set_color(color.srgb_to_linear())
			surface.add_vertex(vertices[index] + box[0])
	surface.set_material(material())
	return surface.commit()

static func instance(asset: Mesh) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = asset
	return result

static func cube(size: Vector3, color: Color, luminous: bool = false) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	result.mesh = shape
	if luminous:
		result.material_override = glow(color)
	else:
		result.mesh = mesh([[Vector3.ZERO, size, color]])
	return result

static func character(class_id: String) -> ArrayMesh:
	if class_id == "mage":
		return mage()
	var armor := Color("66818e") if class_id == "sword" else Color("6e618d")
	var gold := Color("c9ab70")
	return mesh([
		[Vector3(0, .48, 0), Vector3(.43, .43, .34), armor],
		[Vector3(0, .76, 0), Vector3(.26, .23, .25), Color("d3b697")],
		[Vector3(0, .91, 0), Vector3(.30, .09, .28), armor.lightened(.2)],
		[Vector3(-.16, .58, 0), Vector3(.20, .15, .39), armor.lightened(.15)],
		[Vector3(.16, .58, 0), Vector3(.20, .15, .39), armor.lightened(.15)],
		[Vector3(0, .32, 0), Vector3(.44, .08, .35), gold],
		[Vector3(-.11, .15, 0), Vector3(.16, .30, .22), Color("3f4857")],
		[Vector3(.11, .15, 0), Vector3(.16, .30, .22), Color("3f4857")],
		[Vector3(.34, .45, .34), Vector3(.075, .075, .68), Color("d8e0e2")],
		[Vector3(.34, .45, .06), Vector3(.26, .06, .06), gold],
		[Vector3(.34, .45, -.06), Vector3(.08, .08, .20), Color("73573f")],
		[Vector3(-.31, .50, .03), Vector3(.09, .25, .12), Color("628bb1") if class_id == "spellsword" else armor]
	])

static func reward_chest(open: bool) -> ArrayMesh:
	var wood := Color("82603e")
	var gold := Color("dfba68")
	var boxes: Array = [
		[Vector3(0, .22, 0), Vector3(.90, .44, .62), wood],
		[Vector3(-.32, .24, 0), Vector3(.07, .48, .66), gold],
		[Vector3(.32, .24, 0), Vector3(.07, .48, .66), gold],
		[Vector3(0, .27, .33), Vector3(.15, .16, .06), gold],
		[Vector3(0, .55 if not open else .69, 0 if not open else -.27), Vector3(.94, .20 if not open else .47, .66 if not open else .13), wood.lightened(.13)]
	]
	return mesh(boxes)

static func mage() -> ArrayMesh:
	var robe := Color("304e76")
	var blue := Color("427aac")
	var gold := Color("c5a96c")
	var skin := Color("d3b697")
	var dark := Color("1c2a3c")
	return mesh([
		[Vector3(0, .31, 0), Vector3(.46, .38, .38), robe],
		[Vector3(0, .61, 0), Vector3(.36, .29, .30), blue],
		[Vector3(0, .40, -.19), Vector3(.49, .52, .12), dark],
		[Vector3(0, .79, 0), Vector3(.34, .26, .32), dark],
		[Vector3(0, .81, .13), Vector3(.23, .16, .07), skin],
		[Vector3(0, .95, -.02), Vector3(.26, .09, .27), robe],
		[Vector3(0, .49, .17), Vector3(.38, .055, .035), gold],
		[Vector3(0, .28, .20), Vector3(.055, .31, .04), gold],
		[Vector3(-.25, .56, .06), Vector3(.15, .25, .17), robe],
		[Vector3(.25, .56, .08), Vector3(.15, .25, .17), robe],
		[Vector3(.29, .43, .13), Vector3(.11, .10, .11), skin],
		[Vector3(-.12, .09, .04), Vector3(.15, .16, .23), dark],
		[Vector3(.12, .09, .04), Vector3(.15, .16, .23), dark],
		[Vector3(.38, .54, .16), Vector3(.06, 1.08, .06), Color("785b40")],
		[Vector3(.38, 1.02, .16), Vector3(.20, .08, .14), gold],
		[Vector3(.38, 1.15, .16), Vector3(.14, .18, .14), Color("75eee0")]
	])

static func enemy(kind: int) -> ArrayMesh:
	var boxes: Array = []
	if kind == 0:
		var bone := Color("c8c4af")
		var shadow := Color("686d6a")
		boxes = [
			[Vector3(0, .72, 0), Vector3(.31, .29, .28), bone],
			[Vector3(0, .54, 0), Vector3(.12, .10, .13), shadow],
			[Vector3(0, .39, 0), Vector3(.12, .26, .14), bone],
			[Vector3(0, .29, 0), Vector3(.28, .10, .19), shadow]
		]
		for side in [-1, 1]:
			boxes.append([Vector3(side * .23, .44, .02), Vector3(.10, .31, .12), bone])
			boxes.append([Vector3(side * .10, .15, .02), Vector3(.09, .25, .10), bone])
			boxes.append([Vector3(side * .075, .76, .145), Vector3(.055, .055, .015), Color("eb9b69")])
		for height in [.40, .48, .56]:
			boxes.append([Vector3(0, height, .08), Vector3(.31, .045, .12), bone])
		boxes.append([Vector3(.32, .34, .12), Vector3(.05, .52, .07), Color("949fa4")])
	else:
		var cloth := Color("5a386e") if kind == 1 else Color("324f47")
		var trim := Color("a07199") if kind == 1 else Color("8d9b66")
		boxes = [
			[Vector3(0, .29, 0), Vector3(.42, .42, .37), cloth],
			[Vector3(0, .56, 0), Vector3(.32, .25, .28), cloth],
			[Vector3(0, .78, 0), Vector3(.33, .29, .32), cloth.darkened(.25)],
			[Vector3(0, .78, .15), Vector3(.22, .17, .04), Color("15282b")],
			[Vector3(0, .47, .20), Vector3(.055, .32, .04), trim],
			[Vector3(-.23, .53, .05), Vector3(.15, .26, .17), cloth],
			[Vector3(.23, .53, .05), Vector3(.15, .26, .17), cloth],
			[Vector3(-.07, .80, .18), Vector3(.04, .04, .02), Color("bcf4b7")],
			[Vector3(.07, .80, .18), Vector3(.04, .04, .02), Color("bcf4b7")]
		]
		if kind == 1:
			boxes.append([Vector3(.31, .52, .1), Vector3(.055, 1.0, .055), Color("62546c")])
			boxes.append([Vector3(.31, 1.04, .1), Vector3(.16, .16, .16), Color("d388bf")])
		else:
			boxes.append([Vector3(0, .20, -.14), Vector3(.52, .16, .21), cloth.darkened(.2)])
	return mesh(boxes)

static func tile(tone: int, biome: int) -> ArrayMesh:
	var base: Color = [Color("49565c"), Color("504d61"), Color("455c55")][biome]
	base = base.lightened(.12 + float(tone) * .025)
	var boxes: Array = [[Vector3(0, -.11, 0), Vector3(.985, .20, .985), base.darkened(.25)]]
	for x in [-.245, .245]:
		for z in [-.245, .245]:
			boxes.append([Vector3(x, -.012, z), Vector3(.477, .08, .477), base.lightened(.035 if x == z else 0.0)])
	return mesh(boxes)

static func wall(high: bool, along_x: bool, biome: int) -> ArrayMesh:
	var base: Color = [Color("414d56"), Color("484252"), Color("3f5049")][biome]
	base = base.lightened(.08)
	var boxes: Array = []
	var rows := 5 if high else 1
	for row in range(rows):
		for part in range(2):
			var center := Vector3(-.24 + part * .48, .13 + row * .26, 0)
			var extent := Vector3(.465, .245, .22)
			if not along_x:
				center = Vector3(0, center.y, center.x)
				extent = Vector3(.22, .245, .465)
			boxes.append([center, extent, base.lightened(.03 * ((row + part) % 3))])
	var top := Vector3(.99, .09, .29) if along_x else Vector3(.29, .09, .99)
	boxes.append([Vector3(0, rows * .26 + .01, 0), top, base.lightened(.14)])
	return mesh(boxes)

static func brazier() -> ArrayMesh:
	return mesh([
		[Vector3(0, .06, 0), Vector3(.34, .12, .34), Color("272e35")],
		[Vector3(0, .27, 0), Vector3(.16, .33, .16), Color("414449")],
		[Vector3(0, .44, 0), Vector3(.36, .10, .36), Color("a48455")],
		[Vector3(0, .53, 0), Vector3(.20, .12, .20), Color("e4a65c")],
		[Vector3(-.035, .65, .02), Vector3(.10, .17, .10), Color("ffdc8f")]
	])

static func portal() -> ArrayMesh:
	var boxes: Array = [
		[Vector3(0, .03, 0), Vector3(1.35, .10, 1.35), Color("282d3b")],
		[Vector3(0, .10, 0), Vector3(1.12, .08, 1.12), Color("716886")]
	]
	for side in [-1, 1]:
		boxes.append([Vector3(side * .62, .75, 0), Vector3(.22, 1.5, .32), Color("827a86")])
		boxes.append([Vector3(side * .62, .22, 0), Vector3(.36, .32, .45), Color("534e66")])
		boxes.append([Vector3(side * .49, 1.59, 0), Vector3(.30, .23, .32), Color("827a86")])
	boxes.append([Vector3(0, 1.70, 0), Vector3(.79, .22, .32), Color("9c8c9b")])
	return mesh(boxes)
