extends RefCounted

const Scenery = preload("res://scripts/scenery.gd")
const Portables = preload("res://scripts/surface_portables.gd")
const Layout = preload("res://scripts/town_voxel_layout.gd")
const CACHE_LIMIT := 96
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/town_voxel_runtime.json"))
var templates := {}
var sources := {}
var scenery := Scenery.new()
var error := ""

func build(house: Dictionary, city: Dictionary, family: String) -> Node3D:
	var theme: String = city.get("theme_id", "")
	if theme not in Layout.THEMES:
		return null
	var kind := "house" if house.get("use_id","home") in ["home","farmhouse","inn"] else "workshop"
	var size := Vector2(house.footprint.size) - Vector2.ONE * .10
	if house.facing.x != 0:
		size = Vector2(size.y,size.x)
	var center := Vector2(house.footprint.position) + (Vector2(house.footprint.size) - Vector2.ONE) * .5
	var delta := Vector2(house.get("door",center + Vector2(house.facing) * (size.y * .5 + .5))) - center
	var local := Basis(Vector3.UP,atan2(house.facing.x,house.facing.y)).inverse() * Vector3(delta.x,0,delta.y)
	var model := fitted(theme + "_" + kind,size,house.height + 1.0,family,local.x)
	if model != null:
		model.set_meta("house_id",house.id)
		for mesh in model.get_children():
			mesh.set_meta("house_id",house.id)
	return model

func civic(city: Dictionary, family: String) -> Node3D:
	var theme: String = city.get("theme_id", "")
	if theme not in Layout.THEMES:
		return null
	var choices := [theme + "_landmark"]
	if theme == "halloween":
		choices.append_array(["halloween_kaykit_pumpkin","halloween_kaykit_jackolantern"])
	elif theme == "christmas":
		choices.append_array(["christmas_kenney_tree","christmas_kenney_present"])
	var id: String = choices[posmod(hash(city.id + ":voxel-civic"),choices.size())]
	var model := fitted(id,Vector2.ONE * 2.7,3.8,family,0,true)
	if model != null:
		model.set_meta("house_id",city.id + ":civic")
	return model

func gate(city: Dictionary, family: String) -> Node3D:
	if city.get("gateway",{}).is_empty():
		return null
	return fitted(city.theme_id + "_gate",Vector2(7,.6),3.3,family)

func market(model: Node3D, city: Dictionary, family: String) -> Node3D:
	var theme: String = city.get("theme_id", "")
	if theme not in Layout.THEMES or not model.has_meta("parts"):
		return null
	var shelter := fitted(theme + "_shelter",Vector2(.98,.98),1.9,family)
	if shelter == null:
		return null
	var wrappers := Portables.wrappers(model)
	for part in model.get_meta("parts"):
		if part.id in ["post_left","post_right","canopy"]:
			wrappers[part.id].visible = false
	model.add_child(shelter)
	model.set_meta("town_voxel_shelter",shelter.get_meta("town_voxel_id"))
	return shelter

func fitted(id: String, footprint: Vector2, height: float, family: String, door_offset: float = 0, uniform: bool = false) -> Node3D:
	error = ""
	if not data.get("templates",{}).has(id) or family not in ["block_voxel","flat_lowpoly"] or footprint.x <= 0 or footprint.y <= 0 or height <= 0:
		return null
	var record: Dictionary = data.templates[id]
	if record.kind in ["house","workshop"] and (height < 1.9 or footprint.x < .86 + absf(door_offset) * 2):
		return null
	var key := str([id,footprint,height,family,door_offset,uniform])
	if templates.has(key):
		return templates[key].duplicate()
	var scene: Dictionary = record[family]
	if not sources.has(scene.scene):
		if not FileAccess.file_exists(scene.scene) or FileAccess.get_sha256(scene.scene) != scene.sha256:
			error = "Town voxel scene is missing or stale: " + scene.scene
			return null
		sources[scene.scene] = load(scene.scene)
		if not sources[scene.scene] is PackedScene:
			return null
	var model: Node3D = sources[scene.scene].instantiate()
	var box := scenery.bounds(model)
	var scale := Vector3(footprint.x / box.size.x,height / box.size.y,footprint.y / box.size.z)
	if uniform:
		scale = Vector3.ONE * minf(scale.x,minf(scale.y,scale.z))
	var entrance: bool = record.kind in ["house","workshop"]
	var gateway: bool = record.kind == "gate"
	var half_opening := .42 if entrance else minf(2.75,footprint.x * .4)
	for node in model.get_children():
		if not entrance and not gateway:
			node.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)
			node.transform = Transform3D(Basis.from_scale(scale),Vector3.ZERO) * node.transform
			continue
		var tool := SurfaceTool.new()
		tool.create_from(node.mesh,0)
		tool.deindex()
		var arrays := tool.commit().surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in range(points.size()):
			var point := points[index]
			point.x = _stretch(point.x,box.position.x,box.end.x,.375 if entrance else .75,door_offset,half_opening,footprint.x)
			if entrance:
				point.y = _vertical(point.y,record.door.point[1],record.door.point[1] + 1.5,box.end.y,height)
			else:
				point.y *= scale.y
			point.z = (point.z - box.get_center().z) * scale.z
			points[index] = point
		for index in range(0,points.size(),3):
			var normal := (points[index + 2] - points[index]).cross(points[index + 1] - points[index]).normalized()
			for offset in range(3):
				normals[index + offset] = normal
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,node.mesh.surface_get_material(0))
		node.mesh = mesh
	model.set_meta("town_voxel_id",record.source_id)
	model.set_meta("template_id","voxel_" + id)
	model.set_meta("asset_id","town_voxel:%s:%s" % [family,id])
	model.set_meta("render_asset",model.get_meta("asset_id"))
	model.set_meta("construction_name",record.name)
	model.set_meta("source_assets",record.source_assets)
	model.set_meta("visual_family",family)
	model.set_meta("representation","native_voxel" if family == "block_voxel" else "faceted_surface")
	model.set_meta("theme",record.theme)
	model.set_meta("render_height",scenery.bounds(model).end.y)
	if entrance:
		model.set_meta("door_socket",Vector3(door_offset,.12,(record.door.point[2] - box.get_center().z) * scale.z))
		model.set_meta("door_clearance",Vector2(.84,1.6))
	if gateway:
		model.set_meta("door_clearance",Vector2(half_opening * 2,20.0 * .125 * scale.y))
	if templates.size() >= CACHE_LIMIT:
		var oldest = templates.keys()[0]
		templates[oldest].free()
		templates.erase(oldest)
	templates[key] = model
	return model.duplicate()

func _stretch(value: float, low: float, high: float, inner: float, offset: float, opening: float, width: float) -> float:
	if value < -inner:
		return remap(value,low,-inner,-width * .5,offset - opening)
	if value > inner:
		return remap(value,inner,high,offset + opening,width * .5)
	return remap(value,-inner,inner,offset - opening,offset + opening)

func _vertical(value: float, floor_height: float, lintel: float, top: float, height: float) -> float:
	if value < floor_height:
		return remap(value,0,floor_height,0,.12)
	if value <= lintel:
		return remap(value,floor_height,lintel,.12,1.72)
	return remap(value,lintel,top,1.72,height)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for model in templates.values():
			model.free()
