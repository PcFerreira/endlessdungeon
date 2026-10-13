extends SceneTree

const Geometry = preload("res://tools/town_voxel_geometry.gd")
const Facets = preload("res://scripts/animated_model_style.gd")
const Scenery = preload("res://scripts/scenery.gd")
const OUTPUT := "res://assets/town_voxels/runtime"
var records := {}

func _init() -> void:
	assert(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_voxels/catalog.json"))
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/town_voxel_assets.json"))
	for entry in catalog.assets:
		assert(FileAccess.get_sha256(entry.scene) == entry.scene_sha256)
		var source: Node3D = (load(entry.scene) as PackedScene).instantiate()
		publish(source,entry,entry.id.replace("/","_"),entry.scene)
		source.free()
		if entry.kind == "market":
			var geometry := Geometry.new()
			var original := geometry.generate(entry.theme,"market",0,definition.themes[entry.theme])
			original.free()
			for cell in geometry.cells.keys():
				var post: bool = absi(cell.x) in [11,12,13] and absi(cell.z) in [7,8,9]
				if cell.y < 16 and not post:
					geometry.cells.erase(cell)
			var shelter := Node3D.new()
			var mesh := MeshInstance3D.new()
			mesh.mesh = geometry.mesh()
			shelter.add_child(mesh)
			var id: String = entry.theme + "_shelter"
			var block_path := OUTPUT + "/" + id + "_block.scn"
			save_scene(shelter,block_path)
			publish(shelter,entry,id,block_path)
			shelter.free()
		print("BAKED: " + entry.id)
	assert(records.size() == 52)
	var document := {"version":1,"catalog_sha256":FileAccess.get_sha256("res://assets/town_voxels/catalog.json"),"builder_sha256":FileAccess.get_sha256("res://tools/build_town_voxel_runtime.gd"),"faceter_sha256":FileAccess.get_sha256("res://scripts/animated_model_style.gd"),"templates":records}
	var file := FileAccess.open("res://config/town_voxel_runtime.json",FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(document,"  ") + "\n")
	file.close()
	print("PASS: 44 town models and eight goods-free shelters have immutable block/faceted runtime scenes")
	quit()

func publish(source: Node3D, entry: Dictionary, id: String, block_path: String) -> void:
	var model: Node3D = source.duplicate()
	for node in model.get_children():
		var surface := SurfaceTool.new()
		surface.create_from(node.mesh,0)
		surface.deindex()
		node.mesh = Facets.faceted(surface.commit())
		assert(node.mesh != null)
	var flat_path := OUTPUT + "/" + id + "_flat.scn"
	save_scene(model,flat_path)
	model.free()
	records[id] = {"source_id":entry.id,"theme":entry.theme,"kind":"shelter" if id.ends_with("_shelter") else entry.kind,"name":entry.name,"source_assets":entry.source_assets,"block_voxel":{"scene":block_path,"sha256":FileAccess.get_sha256(block_path)},"flat_lowpoly":{"scene":flat_path,"sha256":FileAccess.get_sha256(flat_path)}}
	if entry.has("door"):
		records[id].door = entry.door

func save_scene(model: Node3D, path: String) -> void:
	for node in model.get_children():
		node.owner = model
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS) == OK)
