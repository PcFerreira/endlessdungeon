extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
const Biomes = preload("res://scripts/biome_catalog.gd")

static func terrain(kind: String, biome: int, tone: int, height: float = 0, facet: String = "", bridge_axis: Vector2i = Vector2i.RIGHT, bridge_edge: int = 0, ecology: Dictionary = {}) -> ArrayMesh:
	var color := Color(Areas.DATA.biomes[str(biome)].color)
	if not facet.is_empty():
		color = Color(Areas.DATA.facets[facet].color)
	if not ecology.is_empty():
		color = Biomes.color_for(ecology)
	if kind == "water":
		color = Color("518eaa")
	elif kind == "road":
		color = Color("bcaa89")
	elif kind == "paving":
		color = Color("9a9a86")
	elif kind == "farmland":
		color = Color("756047")
	elif kind == "bridge":
		var boxes: Array = [[Vector3(0, -.14, 0), Vector3(1.03, .15, 1.03), Color("685744")]]
		for index in range(5):
			var point := Vector3(-.4 + index * .2,-.025,0) if bridge_axis.x != 0 else Vector3(0,-.025,-.4 + index * .2)
			var size := Vector3(.185,.12,1.03) if bridge_axis.x != 0 else Vector3(1.03,.12,.185)
			boxes.append([point,size,Color("998367")])
		if bridge_edge != 0:
			var point := Vector3(0, .65, bridge_edge * .46) if bridge_axis.x != 0 else Vector3(bridge_edge * .46,.65,0)
			var rail := Vector3(1.04,.09,.09) if bridge_axis.x != 0 else Vector3(.09,.09,1.04)
			boxes.append([point,rail,Color("7c6249")])
			boxes.append([Vector3(point.x,.30,point.z),Vector3(.10,.65,.10),Color("7c6249")])
		return Voxels.mesh(boxes)
	color = color.lightened(tone * .025)
	if kind == "water":
		return Voxels.mesh([[Vector3(0, -.145, 0), Vector3(1.01, .27, 1.01), color]])
	var rock := Color("827d70") if biome != 3 else Color("8b9695")
	var earth := Color("917957") if biome != 3 else Color("9aaba6")
	if not ecology.is_empty():
		rock = Biomes.color_for(ecology, "rock")
		earth = Biomes.color_for(ecology, "earth")
	return Voxels.mesh([
		[Vector3(0, -(height + 2) * .5, 0), Vector3(1.0, height + 2, 1.0), rock],
		[Vector3(0, -.18, 0), Vector3(1.005, .36, 1.005), earth],
		[Vector3(0, -.045, 0), Vector3(1.01, .10, 1.01), color]
	])

static func prop(kind: String) -> ArrayMesh:
	var boxes: Array = []
	match kind:
		"oak":
			boxes = [
				[Vector3(0, .60, 0), Vector3(.23, 1.20, .23), Color("795d42")],
				[Vector3(0, 1.60, 0), Vector3(.95, .65, .95), Color("487343")],
				[Vector3(-.28, 1.35, .10), Vector3(.60, .50, .65), Color("5e874d")],
				[Vector3(.25, 1.38, -.20), Vector3(.60, .55, .65), Color("739652")],
				[Vector3(0, 1.98, 0), Vector3(.60, .25, .60), Color("7b9c59")]
			]
		"pine":
			boxes.append([Vector3(0, .45, 0), Vector3(.20, .90, .20), Color("695342")])
			for index in range(4):
				var width := 1.15 - index * .24
				boxes.append([Vector3(0, .8 + index * .35, 0), Vector3(width, .42, width), Color("597c70")])
				boxes.append([Vector3(0, 1.025 + index * .35, 0), Vector3(width * .95, .055, width * .95), Color("d2e1de")])
		"cactus":
			boxes = [
				[Vector3(0, .6, 0), Vector3(.23, 1.2, .23), Color("769460")],
				[Vector3(.22, .65, 0), Vector3(.35, .15, .16), Color("648853")],
				[Vector3(.34, .82, 0), Vector3(.14, .42, .16), Color("82a065")],
				[Vector3(-.20, .38, 0), Vector3(.35, .15, .16), Color("648853")],
				[Vector3(-.33, .56, 0), Vector3(.14, .45, .16), Color("82a065")]
			]
		"rock":
			boxes = [
				[Vector3(0, .22, 0), Vector3(.80, .44, .68), Color("8c958b")],
				[Vector3(-.10, .49, .05), Vector3(.52, .16, .48), Color("a5aca0")],
				[Vector3(.28, .15, -.20), Vector3(.38, .30, .34), Color("778676")]
			]
	return Voxels.mesh(boxes)

static func house(data: Dictionary, biome: int, family: String = "block_voxel") -> ArrayMesh:
	var width: float = data.footprint.size.x - .07
	var length: float = data.footprint.size.y - .07
	if data.get("facing",Vector2i.DOWN).x != 0:
		var old_width := width
		width = length
		length = old_width
	var height: float = data.height
	var plaster: Color = [Color("d0c3a0"), Color("c6c2ab"), Color("d9bc8b"), Color("bccac8")][biome]
	var roof: Color = [Color("7b5450"), Color("637b7a"), Color("5b6e92"), Color("806d89")][data.style]
	var architecture: Dictionary = data.get("architecture",{})
	if architecture.has("wall_color"):
		plaster = Color(architecture.wall_color)
	if architecture.has("roof_colors"):
		roof = Color(architecture.roof_colors[data.style % architecture.roof_colors.size()])
	var wood := Color("68513f")
	var boxes: Array = [
		[Vector3(0, .12, 0), Vector3(width, .24, length), Color("777e74")],
		[Vector3(0, height * .5 + .20, 0), Vector3(width - .08, height, length - .08), plaster],
		[Vector3(0, .67, length * .5), Vector3(.52, .94, .06), wood],
		[Vector3(.13, .62, length * .5 + .04), Vector3(.05, .05, .035), Color("d4b77a")]
	]
	for side in [-1, 1]:
		boxes.append([Vector3(side * (width * .5 - .10), height * .5 + .2, length * .5), Vector3(.12, height, .10), wood])
		boxes.append([Vector3(side * width * .23, height * .65 + .2, length * .5), Vector3(.40, .44, .04), Color("617e84")])
		boxes.append([Vector3(side * width * .23, height * .65 + .2, length * .5 + .025), Vector3(.05, .44, .03), wood])
		boxes.append([Vector3(side * width * .5, height * .65 + .2, 0), Vector3(.03, .45, .52), Color("617e84")])
		if data.get("floors",1) > 1:
			boxes.append([Vector3(side * width * .25,.84,length * .5),Vector3(.32,.36,.04),Color("617e84")])
			boxes.append([Vector3(side * width * .25,.84,length * .5 + .025),Vector3(.035,.36,.03),wood])
	boxes.append([Vector3(0, height + .15, length * .5), Vector3(width, .13, .11), wood])
	var flat: bool = architecture.get("roof_shape","gable") == "flat"
	for index in range(2 if flat else 4):
		var roof_length := length + .30
		if architecture.get("roof_shape","gable") == "hip":
			roof_length -= index * length * .20
		if family == "block_voxel" or flat:
			boxes.append([Vector3(0, height + .30 + index * .18, 0), Vector3(width + .32 - (0 if flat else index * width * .20), .21, roof_length), roof.lightened(index * .035)])
	boxes.append([Vector3(width * .25, height + .75, -length * .20), Vector3(.25, .95, .26), Color("89877d")])
	if architecture.has("awning_color"):
		var fabric := Color(architecture.awning_color)
		boxes.append([Vector3(0,1.28,length * .5 + .17),Vector3(width - .3,.12,.42),fabric])
		for index in range(4):
			boxes.append([Vector3((index - 1.5) * (width - .3) / 4,1.25,length * .5 + .34),Vector3((width - .3) / 4,.18,.045),fabric.lightened(.12 if index % 2 == 0 else 0)])
	var result := Surfaces.mesh_boxes(boxes, family)
	if family == "flat_lowpoly" and not flat:
		var slope := _roof(width + .32, length + .30, height + .195, height + .945, architecture.get("roof_shape", "gable"), roof)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, slope.surface_get_arrays(0))
		result.surface_set_material(result.get_surface_count() - 1, Voxels.material())
	return result

static func _roof(width: float, length: float, bottom: float, top: float, shape: String, color: Color) -> ArrayMesh:
	var a := Vector3(-width * .5, bottom, -length * .5)
	var b := Vector3(width * .5, bottom, -length * .5)
	var c := Vector3(width * .5, bottom, length * .5)
	var d := Vector3(-width * .5, bottom, length * .5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if shape == "hip":
		var x := (width * .4 + .192) * .5
		var z := (length * .4 + .18) * .5
		var upper := [Vector3(-x, top, -z), Vector3(x, top, -z), Vector3(x, top, z), Vector3(-x, top, z)]
		for face in [[a,d,upper[3],upper[0]], [b,upper[1],upper[2],c], [a,upper[0],upper[1],b], [d,c,upper[2],upper[3]], [upper[0],upper[3],upper[2],upper[1]]]:
			Surfaces._triangle(surface, face[0], face[1], face[2], color)
			Surfaces._triangle(surface, face[0], face[2], face[3], color)
	else:
		var rear := Vector3(0, top, -length * .5)
		var front := Vector3(0, top, length * .5)
		for triangle in [[a,d,front], [a,front,rear], [b,rear,front], [b,front,c], [d,c,front], [a,rear,b]]:
			Surfaces._triangle(surface, triangle[0], triangle[1], triangle[2], color)
	Surfaces._triangle(surface, a, b, c, color.darkened(.1))
	Surfaces._triangle(surface, a, c, d, color.darkened(.1))
	surface.set_material(Voxels.material())
	return surface.commit()

static func outdoor_lot(data: Dictionary, family: String = "block_voxel") -> ArrayMesh:
	var boxes: Array = []
	var color := Color(data.recipe.color)
	if data.kind == "farm":
		for x in range(-1,2):
			for y in range(-1,2):
				boxes.append([Vector3(x,.07,y),Vector3(.70,.12,.80),Color("66523c")])
				for offset in [-.23,0,.23]:
					var point := Vector3(x + offset,0,y)
					match data.recipe.crop_shape:
						"grain":
							boxes.append([point + Vector3(0,.30,0),Vector3(.07,.46,.08),Color("7d9059")])
							boxes.append([point + Vector3(0,.51,0),Vector3(.16,.22,.13),color])
						"mushroom":
							boxes.append([point + Vector3(0,.22,0),Vector3(.08,.28,.08),Color("ccbea1")])
							boxes.append([point + Vector3(0,.37,0),Vector3(.22,.14,.24),color])
						"root":
							boxes.append([point + Vector3(0,.16,0),Vector3(.14,.18,.15),color])
							boxes.append([point + Vector3(0,.29,0),Vector3(.23,.10,.19),Color("7d9059")])
						"leaf":
							boxes.append([point + Vector3(0,.23,0),Vector3(.20,.28,.24),color])
							boxes.append([point + Vector3(0,.38,0),Vector3(.15,.12,.17),color.lightened(.16)])
	else:
		var wood := Color("765b40")
		boxes.append([Vector3(0,.60,0),Vector3(.85,.14,.78),wood])
		boxes.append([Vector3(0,.92,0),Vector3(1.30,.13,1.10),color])
		for x in [-.48,.48]:
			boxes.append([Vector3(x,.49,-.40),Vector3(.09,.98,.09),wood])
			boxes.append([Vector3(x * .58,.27,.25),Vector3(.07,.54,.07),wood])
		for x in [-.26,0,.26]:
			boxes.append([Vector3(x,.72,.10),Vector3(.20,.10,.26),Color("b6a47a")])
	return Surfaces.mesh_boxes(boxes, family)

static func fountain() -> ArrayMesh:
	var stone := Color("b3baa6")
	return Voxels.mesh([
		[Vector3(0, .10, 0), Vector3(1.7, .20, 1.7), stone.darkened(.2)],
		[Vector3(0, .25, 0), Vector3(1.45, .22, 1.45), stone],
		[Vector3(0, .38, 0), Vector3(1.15, .055, 1.15), Color("70bac7")],
		[Vector3(0, .70, 0), Vector3(.23, .70, .23), Color("959e8e")],
		[Vector3(0, 1.02, 0), Vector3(.55, .10, .55), stone],
		[Vector3(0, 1.18, 0), Vector3(.15, .20, .15), Color("94dedb")]
	])

static func tower(style: int, family: String = "block_voxel") -> ArrayMesh:
	var color := Color("8c938c")
	var boxes: Array = [
		[Vector3(0, .15, 0), Vector3(1.70, .30, 1.70), color.darkened(.2)],
		[Vector3(0, 1.35, 0), Vector3(1.32, 2.40, 1.32), color],
		[Vector3(0, 2.62, 0), Vector3(1.65, .22, 1.65), color.lightened(.1)],
		[Vector3(0, 1.9, .68), Vector3(.25, .45, .035), Color("394850")]
	]
	for x in [-.62, .62]:
		for z in [-.62, .62]:
			boxes.append([Vector3(x, 2.90, z), Vector3(.35, .40, .35), color])
	var flag: Color = [Color("9f555e"), Color("5a7d9e"), Color("839154")][style]
	boxes.append([Vector3(.15, 3.48, 0), Vector3(.05, 1.30, .05), Color("a39068")])
	boxes.append([Vector3(.44, 3.72, 0), Vector3(.60, .32, .045), flag])
	return Surfaces.mesh_boxes(boxes, family)

static func citizen(color: Color) -> ArrayMesh:
	return Voxels.mesh([
		[Vector3(0, .38, 0), Vector3(.28, .46, .24), color],
		[Vector3(0, .72, 0), Vector3(.25, .22, .24), Color("cdb292")],
		[Vector3(0, .85, 0), Vector3(.29, .075, .28), Color("795e49")],
		[Vector3(-.075, .09, 0), Vector3(.10, .19, .14), Color("53535b")],
		[Vector3(.075, .09, 0), Vector3(.10, .19, .14), Color("53535b")]
	])

static func cave() -> ArrayMesh:
	var boxes: Array = [
		[Vector3(0, -.015, 0), Vector3(2.7, .13, 2.0), Color("807d7b")],
		[Vector3(0, .86, -.3), Vector3(1.15, 1.6, .05), Color("1e2633")]
	]
	for side in [-1, 1]:
		boxes.append([Vector3(side * .88, .66, -.15), Vector3(.64, 1.3, 1.1), Color("85838b")])
		boxes.append([Vector3(side * .80, 1.40, -.15), Vector3(.80, .28, 1.1), Color("a09aa3")])
	boxes.append([Vector3(0, 1.68, -.15), Vector3(1.25, .30, 1.1), Color("a09aa3")])
	boxes.append([Vector3(0, 1.70, .42), Vector3(.15, .18, .08), Color("b398d4")])
	return Voxels.mesh(boxes)
