extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")

static func terrain(kind: String, biome: int, tone: int, height: float = 0) -> ArrayMesh:
	var color: Color = [Color("70965d"), Color("a2ad74"), Color("d1b37a"), Color("c5d8d5")][biome]
	if kind == "water":
		color = Color("518eaa")
	elif kind == "road":
		color = Color("bcaa89")
	elif kind == "paving":
		color = Color("9a9a86")
	elif kind == "bridge":
		var boxes: Array = [[Vector3(0, -.13, 0), Vector3(1.01, .12, 1.01), Color("5086a0")]]
		for index in range(5):
			boxes.append([Vector3(0, -.025, -.4 + index * .2), Vector3(1.0, .12, .185), Color("998367")])
		return Voxels.mesh(boxes)
	color = color.lightened(tone * .025)
	if kind == "water":
		return Voxels.mesh([[Vector3(0, -.145, 0), Vector3(1.01, .27, 1.01), color]])
	var rock := Color("827d70") if biome != 3 else Color("8b9695")
	var earth := Color("917957") if biome != 3 else Color("9aaba6")
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

static func house(data: Dictionary, biome: int) -> ArrayMesh:
	var width: float = data.footprint.size.x - .07
	var length: float = data.footprint.size.y - .07
	var height: float = data.height
	var plaster: Color = [Color("d0c3a0"), Color("c6c2ab"), Color("d9bc8b"), Color("bccac8")][biome]
	var roof: Color = [Color("7b5450"), Color("637b7a"), Color("5b6e92"), Color("806d89")][data.style]
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
	boxes.append([Vector3(0, height + .15, length * .5), Vector3(width, .13, .11), wood])
	for index in range(4):
		boxes.append([Vector3(0, height + .30 + index * .18, 0), Vector3(width + .32 - index * width * .20, .21, length + .30), roof.lightened(index * .035)])
	boxes.append([Vector3(width * .25, height + .75, -length * .20), Vector3(.25, .95, .26), Color("89877d")])
	return Voxels.mesh(boxes)

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

static func tower(style: int) -> ArrayMesh:
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
	return Voxels.mesh(boxes)

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
