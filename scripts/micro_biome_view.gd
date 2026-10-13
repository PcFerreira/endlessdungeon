extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
const Biomes = preload("res://scripts/biome_catalog.gd")
const CACHE_LIMIT := 24
const RECIPES := ["fairy_ring", "ancient_grove", "wildflowers", "cactus_shade", "oasis_bank", "frozen_pond", "haunted_memorial", "firefly_fen", "bamboo_hollow", "harvest_glade", "mycelial_nursery", "basalt_vent", "windward_outcrop", "tide_garden", "crystal_pocket"]
var templates := {}

func build(profile: Dictionary, family: String, claimed: bool) -> Node3D:
	var recipe: String = profile.get("recipe", "")
	if recipe not in RECIPES or family not in ["block_voxel", "flat_lowpoly"]:
		return null
	var biome = profile.get("biome_id", profile.get("biome", "greenwood"))
	var ecology: Dictionary = Biomes.DATA.profiles.get(biome, Biomes.DATA.profiles.greenwood) if biome is String else Biomes.DATA.profiles.greenwood
	var ground := Color(profile.get("color", ecology.color))
	var earth := Color(profile.get("earth", ecology.earth))
	var rock := Color(profile.get("rock", ecology.rock))
	var key := str([recipe, family, claimed, ground, earth, rock])
	if not templates.has(key):
		var stone: bool = recipe in ["frozen_pond", "haunted_memorial", "basalt_vent", "windward_outcrop", "tide_garden", "crystal_pocket"]
		var body_color: Color = rock if stone else earth.lightened(.10)
		var trim := ground.lightened(.25)
		if claimed:
			trim = trim.darkened(.25)
		var boxes: Array = [
			[Vector3(0, .025, 0), Vector3(.52, .05, .40), body_color.darkened(.3)],
			[Vector3(-.23, .155, 0), Vector3(.06, .26, .40), body_color],
			[Vector3(.23, .155, 0), Vector3(.06, .26, .40), body_color],
			[Vector3(0, .155, -.17), Vector3(.40, .26, .06), body_color],
			[Vector3(0, .155, .17), Vector3(.40, .26, .06), body_color],
			[Vector3(-.16, .17, .205), Vector3(.035, .27, .025), trim],
			[Vector3(.16, .17, .205), Vector3(.035, .27, .025), trim],
			[Vector3(0, .20, .21), Vector3(.07, .07, .035), trim]
		]
		if claimed:
			boxes.append([Vector3(0, .36, -.195), Vector3(.54, .18, .05), body_color.lightened(.12)])
		else:
			boxes.append([Vector3(0, .305, 0), Vector3(.54, .07, .42), body_color.lightened(.12)])
		_flourish(boxes, recipe, trim, ground, claimed)
		if templates.size() >= CACHE_LIMIT:
			templates.erase(templates.keys()[0])
		templates[key] = Surfaces.mesh_boxes(boxes, family)
	var result := Voxels.instance(templates[key])
	var identity := "native_micro_biome:%s:%s" % [family, recipe]
	result.set_meta("source_asset", identity)
	result.set_meta("render_asset", identity)
	result.set_meta("asset_id", identity)
	result.set_meta("visual_family", family)
	result.set_meta("representation", "original_micro_biome_geometry")
	result.set_meta("recipe", recipe)
	result.set_meta("claimed", claimed)
	result.set_meta("nonblocking", true)
	return result

func _box(boxes: Array, point: Vector3, size: Vector3, color: Color) -> void:
	boxes.append([point, size, color])

func _flourish(boxes: Array, recipe: String, trim: Color, ground: Color, claimed: bool) -> void:
	var accent := ground.lightened(.30)
	if claimed:
		accent = accent.darkened(.30)
	match recipe:
		"fairy_ring":
			for index in range(4):
				var angle := index * TAU / 4
				var point := Vector3(cos(angle) * .105, .375, sin(angle) * .105)
				_box(boxes, point, Vector3(.025, .08, .025), trim)
				_box(boxes, point + Vector3.UP * .05, Vector3(.085, .025, .085), accent)
		"ancient_grove":
			_box(boxes, Vector3(0, .405, 0), Vector3(.035, .16, .035), trim)
			_box(boxes, Vector3(-.045, .42, 0), Vector3(.13, .035, .09), ground)
			_box(boxes, Vector3(.04, .465, 0), Vector3(.12, .035, .075), accent)
		"wildflowers":
			_box(boxes, Vector3(0, .395, 0), Vector3(.025, .11, .025), ground)
			for index in range(5):
				var angle := index * TAU / 5
				_box(boxes, Vector3(cos(angle) * .055, .455, sin(angle) * .055), Vector3(.065, .025, .065), accent)
			_box(boxes, Vector3(0, .47, 0), Vector3(.04, .03, .04), Color("d9b362"))
		"cactus_shade":
			_box(boxes, Vector3(0, .415, 0), Vector3(.055, .15, .055), ground)
			_box(boxes, Vector3(-.055, .415, 0), Vector3(.08, .04, .045), accent)
			_box(boxes, Vector3(-.08, .45, 0), Vector3(.03, .065, .035), ground)
			_box(boxes, Vector3(.055, .385, 0), Vector3(.08, .04, .045), accent)
		"oasis_bank":
			_box(boxes, Vector3(0, .365, 0), Vector3(.22, .035, .14), Color("548f99"))
			for side in [-1, 1]:
				_box(boxes, Vector3(side * .075, .415, -.04), Vector3(.035, .11, .035), ground)
			_box(boxes, Vector3(0, .48, -.04), Vector3(.20, .025, .055), accent)
		"frozen_pond":
			_box(boxes, Vector3(0, .36, 0), Vector3(.24, .025, .17), Color("8bb7c5"))
			for index in range(3):
				_box(boxes, Vector3(-.07 + index * .065, .40 + index * .015, 0), Vector3(.04, .06 + index * .03, .04), accent)
		"haunted_memorial":
			_box(boxes, Vector3(0, .42, 0), Vector3(.055, .18, .055), trim)
			_box(boxes, Vector3(0, .465, 0), Vector3(.18, .045, .06), accent)
			_box(boxes, Vector3(0, .355, 0), Vector3(.19, .035, .12), ground)
		"firefly_fen":
			for index in range(3):
				var height := .10 + index * .025
				_box(boxes, Vector3(-.07 + index * .07, .335 + height * .5, 0), Vector3(.018, height, .018), ground)
				_box(boxes, Vector3(-.07 + index * .07, .35 + height, 0), Vector3(.045, .035, .045), Color("c5ce76").darkened(.3 if claimed else 0.0))
		"bamboo_hollow":
			for index in range(3):
				_box(boxes, Vector3(-.07 + index * .07, .425, index % 2 * .03), Vector3(.028, .17 - index * .02, .028), ground)
				_box(boxes, Vector3(-.07 + index * .07, .415, index % 2 * .03), Vector3(.04, .018, .04), accent)
		"harvest_glade":
			_box(boxes, Vector3(0, .40, 0), Vector3(.17, .12, .15), Color("b7763d").darkened(.3 if claimed else 0.0))
			_box(boxes, Vector3(0, .48, 0), Vector3(.025, .055, .025), ground)
		"mycelial_nursery":
			_box(boxes, Vector3(0, .40, 0), Vector3(.035, .12, .035), trim)
			_box(boxes, Vector3(0, .465, 0), Vector3(.22, .045, .20), accent)
			_box(boxes, Vector3(.035, .49, .025), Vector3(.035, .025, .035), trim)
		"basalt_vent":
			for index in range(3):
				_box(boxes, Vector3(-.07 + index * .07, .395 + index * .02, 0), Vector3(.06, .10 + index * .04, .075), trim.darkened(.2))
			_box(boxes, Vector3(0, .35, .055), Vector3(.22, .025, .02), Color("ce7a43").darkened(.3 if claimed else 0.0))
		"windward_outcrop":
			_box(boxes, Vector3(0, .38, 0), Vector3(.23, .075, .12), trim)
			_box(boxes, Vector3(-.04, .435, 0), Vector3(.10, .065, .08), accent)
			_box(boxes, Vector3(.105, .41, .035), Vector3(.045, .05, .025), ground)
		"tide_garden":
			for index in range(3):
				_box(boxes, Vector3(-.05 + index * .05, .355 + index * .035, 0), Vector3(.20 - index * .04, .025, .12 - index * .025), Color("639b9f").lightened(index * .07))
			_box(boxes, Vector3(-.1, .45, 0), Vector3(.035, .06, .035), accent)
		"crystal_pocket":
			for index in range(3):
				var height := .12 + (1 - absi(index - 1)) * .07
				_box(boxes, Vector3(-.065 + index * .065, .34 + height * .5, 0), Vector3(.045, height, .045), accent.lightened(index * .05))
