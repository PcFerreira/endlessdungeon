extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const ROLES = ["table", "workbench", "bench", "cart", "crate", "crates", "barrel", "anvil", "tools", "pickaxe", "farm_tool", "bookstand", "book", "scroll", "bookcase", "bottle", "plate", "fruit", "bread", "tea", "camp", "bedroll", "campfire", "statue", "grave", "gravestone", "coffin", "altar", "lantern", "wall_lantern", "candle", "banner", "column", "portal", "soil", "crop_carrot", "crop_corn", "crop_tomato", "crop_daikon", "crop_wheat", "harvest", "market_roof", "standing_fire", "banner_wall", "rug_floor", "wood", "stone_block", "chair", "pot", "sack", "chest", "training_dummy", "fence", "signpost", "wall_shelf", "bed", "log", "fountain"]
var materials := {}
var root: Node3D
var block := true
const WOOD = Color("795d42")
const STONE = Color("8c958b")
const LEAF = Color("5b7c54")
const PAPER = Color("e6d4ac")
const IRON = Color("546272")

func model(role: String, family: String) -> Node3D:
	assert(role in ROLES)
	root = Node3D.new()
	block = family == "block_voxel"
	match role:
		"table", "workbench", "bench", "chair":
			var top := .55 if role in ["bench", "chair"] else .88
			box(Vector3(.95, .12, .75), Vector3(0, top, 0), WOOD)
			for x in [-.35, .35]:
				for z in [-.25, .25]:
					box(Vector3(.10, top, .10), Vector3(x, top * .5, z), WOOD.darkened(.12))
			if role in ["bench", "chair"]:
				box(Vector3(.95, .3, .08), Vector3(0, .83, -.30), WOOD)
		"crate", "crates", "cart", "chest":
			box(Vector3(.8, .6, .7), Vector3(0, .4, 0), WOOD)
			for x in [-.33, .33]:
				box(Vector3(.08, .64, .74), Vector3(x, .4, 0), WOOD.lightened(.18))
			if role == "crates":
				box(Vector3(.6, .4, .6), Vector3(.1, .9, 0), WOOD.lightened(.1))
			if role == "chest":
				box(Vector3(.82, .1, .72), Vector3(0, .75, 0), WOOD.lightened(.15))
				box(Vector3(.10, .17, .03), Vector3(0, .65, .37), IRON)
			if role == "cart":
				for x in [-.48, .48]:
					for z in [-.23, .23]:
						var wheel := round_form(Vector3(.28, .09, .28), Vector3(x, .15, z), IRON)
						wheel.rotation.z = PI / 2
				box(Vector3(.10, .10, .75), Vector3(0, .35, .65), WOOD)
		"barrel", "bottle", "tea", "pot", "sack", "log":
			var color := WOOD if role in ["barrel", "log"] else (PAPER if role == "sack" else Color("718e98"))
			round_form(Vector3(.65, .65, .65), Vector3(0, .325, 0), color)
			if role == "log":
				round_form(Vector3(.68, .06, .68), Vector3(0, .68, 0), PAPER)
			elif role == "barrel":
				for y in [.15, .53]:
					round_form(Vector3(.69, .065, .69), Vector3(0, y, 0), IRON)
			else:
				round_form(Vector3(.25, .24, .25), Vector3(0, .74, 0), PAPER)
				if role == "tea":
					box(Vector3(.15, .15, .13), Vector3(.4, .5, 0), PAPER)
		"plate", "rug_floor", "soil", "market_roof", "wood", "stone_block":
			var color: Color = {"plate": PAPER, "rug_floor": Color("826ba6"), "soil": Color("4d382b"), "market_roof": Color("a77652"), "wood": WOOD, "stone_block": STONE}[role]
			if role == "plate":
				round_form(Vector3(.95, .10, .95), Vector3(0, .05, 0), color)
			else:
				box(Vector3(1, .15, 1), Vector3(0, .075, 0), color)
		"fruit", "bread", "harvest":
			for index in range(3):
				var color := Color("bc7045") if role == "bread" else Color("aa674d").lightened(index * .07)
				round_form(Vector3(.32, .25, .4), Vector3((index - 1) * .3, .13, .08 if index == 1 else -.08), color)
				if role != "bread":
					box(Vector3(.03, .10, .03), Vector3((index - 1) * .3, .30, .08 if index == 1 else -.08), LEAF)
		"crop_carrot", "crop_daikon", "crop_corn", "crop_tomato", "crop_wheat":
			for index in range(3):
				var x := (index - 1) * .3
				box(Vector3(.04, .65, .04), Vector3(x, .325, 0), LEAF)
				var crop: Color = {"crop_carrot": Color("d18843"), "crop_daikon": PAPER, "crop_corn": Color("cead61"), "crop_tomato": Color("b9584f"), "crop_wheat": Color("c6ad6b")}[role]
				var y := .20 if role in ["crop_carrot", "crop_daikon"] else .6
				round_form(Vector3(.18, .30, .18), Vector3(x, y, 0), crop)
				for side in [-1, 1]:
					box(Vector3(.20, .06, .13), Vector3(x + side * .08, .40, 0), LEAF)
		"tools", "pickaxe", "farm_tool":
			box(Vector3(.06, .85, .07), Vector3(0, .425, 0), WOOD)
			box(Vector3(.65, .10, .14), Vector3(0, .80, 0), IRON)
			if role == "farm_tool":
				for x in [-.24, 0, .24]:
					box(Vector3(.07, .17, .07), Vector3(x, .72, .10), IRON)
		"anvil":
			box(Vector3(.65, .18, .6), Vector3(0, .09, 0), WOOD)
			box(Vector3(.3, .42, .3), Vector3(0, .38, 0), IRON)
			box(Vector3(.85, .18, .4), Vector3(0, .64, 0), IRON.lightened(.2))
		"book", "scroll":
			box(Vector3(.75, .16, .55), Vector3(0, .09, 0), PAPER)
			if role == "book":
				for y in [.01, .18]:
					box(Vector3(.8, .025, .60), Vector3(0, y, 0), Color("576c86"))
				box(Vector3(.04, .18, .6), Vector3(-.38, .09, 0), Color("576c86"))
			else:
				for x in [-.4, .4]:
					round_form(Vector3(.16, .6, .16), Vector3(x, .09, 0), PAPER).rotation.x = PI / 2
		"bookstand", "altar":
			box(Vector3(.7, .12, .7), Vector3(0, .06, 0), WOOD if role == "bookstand" else STONE)
			box(Vector3(.3, .60, .3), Vector3(0, .4, 0), WOOD if role == "bookstand" else STONE)
			box(Vector3(.85, .15, .65), Vector3(0, .78, 0), WOOD if role == "bookstand" else STONE.lightened(.12))
			if role == "bookstand":
				for side in [-1, 1]:
					var page := box(Vector3(.28, .035, .40), Vector3(side * .14, .9, 0), PAPER)
					page.rotation.z = side * -.1
		"bookcase", "wall_shelf":
			for x in [-.43, .43]:
				box(Vector3(.12, 1, .45), Vector3(x, .5, 0), WOOD)
			for y in [.05, .50, .95]:
				box(Vector3(.9, .1, .45), Vector3(0, y, 0), WOOD)
			for x in [-.28, -.07, .14, .30]:
				box(Vector3(.13, .28, .3), Vector3(x, .72, -.04), Color("576c86").lightened((x + .3) * .3))
		"coffin", "bedroll", "bed":
			box(Vector3(.55, .30, 1), Vector3(0, .15, 0), WOOD if role == "coffin" else Color("788979"))
			box(Vector3(.6, .08, .95), Vector3(0, .34, 0), WOOD.lightened(.15) if role == "coffin" else PAPER)
			if role == "coffin":
				box(Vector3(.05, .025, .40), Vector3(0, .393, 0), PAPER)
				box(Vector3(.25, .025, .05), Vector3(0, .393, -.08), PAPER)
			elif role == "bed":
				box(Vector3(.6, .35, .08), Vector3(0, .4, -.47), WOOD)
		"grave", "gravestone", "statue", "column":
			box(Vector3(.7, .15, .6), Vector3(0, .075, 0), STONE)
			if role == "column":
				round_form(Vector3(.35, .7, .35), Vector3(0, .5, 0), STONE)
				box(Vector3(.65, .15, .6), Vector3(0, .925, 0), STONE)
			elif role == "statue":
				box(Vector3(.25, .45, .22), Vector3(0, .46, 0), STONE.lightened(.12))
				round_form(Vector3(.22, .22, .22), Vector3(0, .81, 0), STONE.lightened(.12))
				for side in [-1, 1]:
					box(Vector3(.10, .34, .12), Vector3(side * .18, .47, 0), STONE)
			else:
				box(Vector3(.48, .65, .22), Vector3(0, .48, 0), STONE.lightened(.12))
				box(Vector3(.22, .035, .02), Vector3(0, .5, .12), STONE.darkened(.25))
		"lantern", "wall_lantern", "candle", "standing_fire", "campfire":
			box(Vector3(.55, .12, .5), Vector3(0, .06, 0), IRON)
			if role in ["standing_fire", "wall_lantern"]:
				box(Vector3(.12, .6, .12), Vector3(0, .36, 0), WOOD)
			var base := .65 if role in ["standing_fire", "wall_lantern"] else .18
			if role == "candle":
				round_form(Vector3(.22, .4, .22), Vector3(0, base + .2, 0), PAPER)
				base += .40
			var flame := round_form(Vector3(.32, .3, .32), Vector3(0, base + .15, 0), Color("eab965"))
			if not block:
				flame.mesh.top_radius = 0
			flame.set_meta("light_source", true)
			if role == "campfire":
				for side in [-1, 1]:
					var log := box(Vector3(.55, .10, .10), Vector3(0, .14, 0), WOOD)
					log.rotation.y = side * PI / 4
			if role in ["lantern", "wall_lantern"]:
				for x in [-.22, .22]:
					box(Vector3(.04, .45, .04), Vector3(x, base + .15, 0), IRON)
				box(Vector3(.5, .08, .45), Vector3(0, base + .4, 0), IRON)
		"banner", "banner_wall":
			box(Vector3(.06, 1, .06), Vector3(-.37, .5, 0), WOOD)
			box(Vector3(.7, .6, .035), Vector3(0, .63, 0), Color("826ba6"))
			box(Vector3(.18, .18, .02), Vector3(0, .66, .03), PAPER)
		"portal":
			for x in [-.4, .4]:
				box(Vector3(.15, .85, .25), Vector3(x, .425, 0), STONE)
			box(Vector3(.95, .18, .3), Vector3(0, .92, 0), STONE)
		"camp":
			for side in [-1, 1]:
				var roof := box(Vector3(.70, .06, 1), Vector3(side * .22, .30, 0), Color("a77652"))
				roof.rotation.z = side * PI / 4
			box(Vector3(.05, .62, .05), Vector3(0, .31, .3), WOOD)
		"signpost", "fence", "training_dummy":
			box(Vector3(.08, .95, .08), Vector3(0, .475, 0), WOOD)
			box(Vector3(.85, .13, .10), Vector3(0, .78, 0), WOOD.lightened(.15))
			if role == "fence":
				box(Vector3(.85, .13, .10), Vector3(0, .38, 0), WOOD)
				for side in [-1, 1]:
					box(Vector3(.08, .95, .08), Vector3(side * .38, .475, 0), WOOD)
			elif role == "training_dummy":
				box(Vector3(.36, .4, .20), Vector3(0, .65, 0), PAPER)
				round_form(Vector3(.24, .22, .24), Vector3(0, .97, 0), PAPER)
		"fountain":
			round_form(Vector3(1, .25, 1), Vector3(0, .125, 0), STONE)
			round_form(Vector3(.82, .03, .82), Vector3(0, .26, 0), Color("79b4c3"))
			round_form(Vector3(.16, .48, .16), Vector3(0, .48, 0), STONE.lightened(.12))
			round_form(Vector3(.5, .12, .5), Vector3(0, .76, 0), STONE.lightened(.12))
	return root

func box(size: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	var mesh := Voxels.cube(size, color)
	if not block:
		var shape := BoxMesh.new()
		shape.size = size
		mesh.mesh = shape
		mesh.material_override = material(color)
	mesh.position = point
	root.add_child(mesh)
	return mesh

func round_form(size: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	if block:
		return box(size, point, color)
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.radial_segments = 6
	shape.height = size.y
	shape.top_radius = size.x * .5
	shape.bottom_radius = size.x * .5
	mesh.mesh = shape
	mesh.scale.z = size.z / size.x
	mesh.material_override = material(color)
	mesh.position = point
	root.add_child(mesh)
	return mesh

func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = .95
		materials[color] = result
	return materials[color]
