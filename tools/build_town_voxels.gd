extends SceneTree

const Geometry = preload("res://tools/town_voxel_geometry.gd")
const Converter = preload("res://scripts/town_model_voxelizer.gd")
const Scenery = preload("res://scripts/scenery.gd")
const CONFIG := "res://config/town_voxel_assets.json"
const OUTPUT := "res://assets/town_voxels"
var records: Array[Dictionary] = []
var scenery := Scenery.new()

func _init() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	assert(config.version == 1 and config.pitch == .125)
	assert(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK)
	var kinds := ["house","workshop","gate","market","landmark"]
	for theme in config.themes:
		var palette: Dictionary = config.themes[theme]
		for index in range(kinds.size()):
			var geometry := Geometry.new()
			var model := geometry.generate(theme,kinds[index],1 if index == 1 else 0,palette)
			var id: String = theme + "/" + kinds[index]
			var record := {"id":id,"name":palette.names[index],"theme":theme,"kind":kinds[index],"origin":"project-original","author":"Endless World project","pitch":geometry.pitch,"voxel_count":geometry.cells.size(),"exposed_faces":geometry.faces,"source_assets":[]}
			if geometry.has_door:
				record.door = {"point":[geometry.door.x,geometry.door.y,geometry.door.z],"clearance":[.75,1.5],"front":[0,0,1]}
			publish(model,record)
			model.free()
		print("BUILT: " + theme + " / five original assets")
	for derivative in config.derivatives:
		var source: Dictionary = scenery.registry.get_asset(derivative.source_asset)
		assert(not source.is_empty() and source.license == "CC0-1.0")
		var raw: Node3D = scenery.fitted_model(source.id,Vector2.ONE * derivative.width,derivative.height)
		assert(raw != null)
		var model: Node3D = Converter.voxelize(raw,24)
		assert(model != null)
		raw.free()
		var record := {"id":derivative.id,"name":derivative.name,"theme":derivative.theme,"kind":"prop","origin":"voxel-derivative","author":source.author,"source_assets":[source.id],"source_file":source.source_file,"source_url":source.source,"source_sha256":FileAccess.get_sha256("res://" + source.source_file),"license":source.license,"license_url":source.license_url,"attribution":source.attribution_text,"pitch":model.get_meta("voxel_pitch"),"voxel_count":model.get_meta("voxel_count")}
		publish(model,record)
		model.free()
	assert(records.size() == config.themes.size() * 5 + config.derivatives.size(),"Every scene and GLB must be exported before publishing the catalogue")
	var catalog := {"version":1,"generator":"tools/build_town_voxels.gd","definition_sha256":FileAccess.get_sha256(CONFIG),"geometry_sha256":FileAccess.get_sha256("res://tools/town_voxel_geometry.gd"),"axes":{"up":"+Y","front":"+Z","origin":"bottom-centered"},"assets":records}
	var file := FileAccess.open(OUTPUT + "/catalog.json",FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(catalog,"  ") + "\n")
	file.close()
	print("PASS: 40 original themed voxel assets and four attributed source derivatives exported to packed scenes and GLBs")
	quit()

func publish(model: Node3D, record: Dictionary) -> void:
	var directory: String = OUTPUT + "/" + record.theme
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var basename: String = record.id.get_file()
	model.name = basename.to_pascal_case()
	model.set_meta("asset_id","town_voxels:" + record.id)
	model.set_meta("visual_family","block_voxel")
	model.set_meta("theme",record.theme)
	model.set_meta("kind",record.kind)
	model.set_meta("source_assets",record.source_assets)
	for node in model.get_children():
		node.owner = model
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	var scene_path := directory + "/" + basename + ".scn"
	assert(ResourceSaver.save(scene,scene_path,ResourceSaver.FLAG_COMPRESS) == OK)
	var glb_path := directory + "/" + basename + ".glb"
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(model,state) == OK)
	assert(document.write_to_filesystem(state,glb_path) == OK)
	var box := scenery.bounds(model)
	record.scene = scene_path
	record.glb = glb_path
	record.bounds = {"position":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z]}
	record.scene_sha256 = FileAccess.get_sha256(scene_path)
	record.glb_sha256 = FileAccess.get_sha256(glb_path)
	record.visual_family = "block_voxel"
	record.triangles = 0
	for mesh in model.get_children():
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			record.triangles += arrays[Mesh.ARRAY_INDEX].size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size() / 3
	records.append(record)
