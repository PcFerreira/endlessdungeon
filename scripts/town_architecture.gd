extends RefCounted

const Catalog = preload("res://scripts/town_architecture_catalog.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Voxelizer = preload("res://scripts/town_model_voxelizer.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var catalog := Catalog.new()
var scenery := Scenery.new()
var styles := Styles.new(catalog.registry)
var templates: Dictionary = {}
var error := ""
const CACHE_LIMIT := 48

func build(house: Dictionary, city: Dictionary) -> Node3D:
	var recipe := catalog.choose(house,city)
	if recipe.is_empty():
		return null
	var footprint := Vector2(house.footprint.size) - Vector2.ONE * .10
	if house.facing.x != 0:
		footprint = Vector2(footprint.y,footprint.x)
	var model := build_template(recipe,footprint,house.height + 1.0,styles.family_for(city.biome))
	if model != null:
		model.set_meta("house_id", house.id)
	return model

func civic(city: Dictionary) -> Node3D:
	var recipe := catalog.choose({"id":city.id + ":civic", "kind":"civic"},city)
	if recipe.is_empty():
		return null
	var model := build_template(recipe,Vector2(2.7,2.7),3.8,styles.family_for(city.biome))
	if model != null:
		model.set_meta("house_id",city.id + ":civic")
	return model

func build_template(recipe: Dictionary, footprint: Vector2, height: float, family: String) -> Node3D:
	error = ""
	if footprint.x <= 0 or footprint.y <= 0 or height <= 0 or family not in ["block_voxel", "flat_lowpoly"]:
		return null
	var key := JSON.stringify([recipe,footprint.x,footprint.y,height,family])
	if templates.has(key):
		return templates[key].duplicate()
	var model := Node3D.new()
	var sources: Array[String] = []
	for part in recipe.parts:
		var component: Node3D
		if part.has("asset"):
			if styles.family_of(part.asset) != "flat_lowpoly":
				error = "Town building source is not classified as faceted architecture: " + part.asset
				model.free()
				return null
			if catalog.registry.resource(part.asset) == null:
				error = "Town building source is unavailable: " + part.asset
				model.free()
				return null
			component = scenery.fitted_model(part.asset,Vector2(part.size[0],part.size[2]),part.size[1])
			if part.asset not in sources:
				sources.append(part.asset)
		else:
			component = Node3D.new()
			var mesh := Voxels.cube(Vector3(part.size[0],part.size[1],part.size[2]),Color("8c938c") if part.primitive == "stone" else Color("795d42"))
			mesh.position.y = part.size[1] * .5
			component.add_child(mesh)
		var rotation := Transform3D(Basis(Vector3.UP,part.get("yaw",0)),Vector3.ZERO)
		for mesh in component.get_children():
			mesh.transform = rotation * mesh.transform
		component.position = Vector3(part.point[0],part.point[1],part.point[2])
		model.add_child(component)
	var flat := Node3D.new()
	scenery._collect(model,Transform3D(Basis(Vector3.UP,recipe.get("front_yaw",0)),Vector3.ZERO),flat)
	model.free()
	var box := scenery.bounds(flat)
	if box.size.x <= 0 or box.size.y <= 0 or box.size.z <= 0:
		flat.free()
		return null
	var fit := Transform3D(Basis.from_scale(Vector3(footprint.x / box.size.x,height / box.size.y,footprint.y / box.size.z)),Vector3.ZERO)
	for mesh in flat.get_children():
		mesh.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)
		mesh.transform = fit * mesh.transform
	if family == "block_voxel":
		var converted: Node3D = Voxelizer.voxelize(flat)
		flat.free()
		if converted == null:
			error = "Town building exceeds the voxel conversion budget: " + recipe.id
			return null
		flat = converted
	flat.set_meta("template_id",recipe.id)
	flat.set_meta("construction_name",recipe.name)
	flat.set_meta("source_assets",sources)
	flat.set_meta("visual_family",family)
	flat.set_meta("render_asset","town_architecture:%s:%s" % [family,recipe.id])
	if styles.family_of(flat.get_meta("render_asset")) != family:
		error = "Unknown rendered town construction identity: " + flat.get_meta("render_asset")
		flat.free()
		return null
	flat.set_meta("representation","voxelized" if family == "block_voxel" else "source")
	flat.set_meta("render_height",scenery.bounds(flat).end.y)
	flat.set_meta("theme",recipe.get("theme","generic"))
	if templates.size() >= CACHE_LIMIT:
		var oldest = templates.keys()[0]
		templates[oldest].free()
		templates.erase(oldest)
	templates[key] = flat
	return flat.duplicate()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for model in templates.values():
			model.free()
