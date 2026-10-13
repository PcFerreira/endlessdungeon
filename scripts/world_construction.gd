extends RefCounted

const Catalog = preload("res://scripts/world_dressing_catalog.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var catalog := Catalog.new()
var scenery := Scenery.new()
var error := ""

func build(plan: Dictionary) -> Node3D:
	if plan.is_empty():
		return null
	var root := Node3D.new()
	var placed := {}
	var metadata: Array[Dictionary] = []
	for part in plan.parts:
		var point := Vector3(part.point[0],0,part.point[1])
		if part.support != "ground":
			var support: AABB = placed[part.support]
			point.y = support.end.y
			if not part.has("span"):
				point.x += support.get_center().x
				point.z += support.get_center().z
		var model: Node3D
		if part.has("native_role"):
			model = catalog.styles.native_model(part.native_role, part.visual_family, Vector2(part.footprint[0], part.footprint[1]), part.height)
		elif part.has("primitive"):
			model = Node3D.new()
			var mesh := Voxels.cube(Vector3(part.footprint[0],part.height,part.footprint[1]), Color("765b40") if part.primitive == "wood" else Color("8d9297"))
			mesh.position.y = part.height * .5
			model.add_child(mesh)
		else:
			if catalog.registry.resource(part.asset) == null and part.has("environment_role"):
				model = catalog.styles.native_model(part.environment_role, part.visual_family, Vector2(part.footprint[0], part.footprint[1]), part.height)
				part = part.duplicate()
				part.asset = catalog.styles.native_id(part.visual_family, part.environment_role)
			elif catalog.registry.resource(part.asset) == null:
				error = "World construction asset is not imported: " + part.asset
				root.free()
				return null
			else:
				model = scenery.fitted_model(part.asset, Vector2(part.footprint[0],part.footprint[1]), part.height)
		model.position = point
		root.add_child(model)
		var box := scenery.bounds(model)
		box.position += point
		placed[part.id] = box
		metadata.append({"id": part.id, "asset": part.get("asset", ""), "support": part.support, "bounds": box, "pool": part.get("pool", "primitive"), "visual_family": part.get("visual_family", "")})
	var flat := Node3D.new()
	scenery._collect(root, Transform3D.IDENTITY, flat)
	root.free()
	flat.set_meta("parts", metadata)
	flat.set_meta("recipe_id", plan.recipe_id)
	flat.set_meta("visual_family", plan.get("visual_family", ""))
	return flat
