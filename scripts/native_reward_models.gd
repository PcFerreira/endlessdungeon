extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
const ROLES := ["coin", "health", "mana", "ember"]

static func model(role: String, family: String) -> Node3D:
	assert(role in ROLES and family in ["block_voxel", "flat_lowpoly"])
	var root := Node3D.new()
	var boxes := []
	if role == "coin":
		var gold := Color("e5b65b")
		if family == "block_voxel":
			boxes = [[Vector3(0, .15, 0), Vector3(.22, .30, .045), gold], [Vector3(0, .15, 0), Vector3(.30, .22, .045), gold]]
		else:
			var coin := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.radial_segments = 8
			disc.top_radius = .15
			disc.bottom_radius = .15
			disc.height = .045
			coin.mesh = disc
			coin.rotation.x = PI / 2
			coin.position.y = .15
			var material := StandardMaterial3D.new()
			material.albedo_color = gold
			material.metallic = .5
			material.roughness = .6
			coin.material_override = material
			root.add_child(coin)
		boxes.append_array([[Vector3(0, .15, .029), Vector3(.035, .15, .018), Color("fff0c5")], [Vector3(0, .15, .029), Vector3(.11, .035, .018), Color("fff0c5")]])
	elif role in ["health", "mana"]:
		var color := Color("e78181") if role == "health" else Color("80cee5")
		boxes = [[Vector3(0, .025, 0), Vector3(.18, .05, .18), Color("c5a67b")], [Vector3(0, .12, 0), Vector3(.18, .16, .18), color.darkened(.2)], [Vector3(0, .13, .094), Vector3(.11, .09, .02), color], [Vector3(0, .23, 0), Vector3(.07, .07, .07), color], [Vector3(0, .275, 0), Vector3(.09, .03, .09), Color("c5a67b")]]
		if role == "health":
			boxes.append_array([[Vector3(0, .13, .107), Vector3(.018, .06, .008), Color("f0d8bd")], [Vector3(0, .13, .107), Vector3(.06, .018, .008), Color("f0d8bd")]])
	else:
		boxes = [[Vector3(0, .07, 0), Vector3(.18, .14, .14), Color("a96643")], [Vector3(-.03, .17, 0), Vector3(.12, .12, .12), Color("cf8050")], [Vector3(-.03, .25, 0), Vector3(.06, .06, .06), Color("edaa63")]]
	root.add_child(Voxels.instance(Surfaces.mesh_boxes(boxes, family)))
	var id := "native_reward:%s:%s" % [family, role]
	root.set_meta("asset_id", id)
	root.set_meta("visual_family", family)
	root.set_meta("native_role", role)
	for part in root.find_children("*", "MeshInstance3D", true, false):
		part.set_meta("asset_id", id)
		part.set_meta("visual_family", family)
	return root
