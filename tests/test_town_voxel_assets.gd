extends SceneTree

const Geometry = preload("res://tools/town_voxel_geometry.gd")
const Scenery = preload("res://scripts/scenery.gd")

func _init() -> void:
	assert(FileAccess.file_exists("res://assets/town_voxels/catalog.json"),"The themed voxel assets must exist as reusable exported resources")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_voxels/catalog.json"))
	assert(catalog.assets.size() == 44)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/town_voxel_assets.json"))
	assert(catalog.definition_sha256 == FileAccess.get_sha256("res://config/town_voxel_assets.json"))
	assert(catalog.geometry_sha256 == FileAccess.get_sha256("res://tools/town_voxel_geometry.gd"))
	var scenery := Scenery.new()
	var shapes := {}
	var kinds := {}
	var derivative_count := 0
	for record in catalog.assets:
		assert(record.visual_family == "block_voxel")
		assert(FileAccess.get_sha256(record.scene) == record.scene_sha256 and FileAccess.get_sha256(record.glb) == record.glb_sha256)
		var packed: PackedScene = load(record.scene)
		assert(packed != null)
		var model: Node3D = packed.instantiate()
		var box := scenery.bounds(model)
		assert(box.position.y >= -.00001 and box.size.x > 0 and box.size.y > 0 and box.size.z > 0)
		assert(model.get_meta("asset_id") == "town_voxels:" + record.id)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(record.glb,state) == OK,"Exported GLB must reload independently")
		var exported: Node3D = document.generate_scene(state)
		assert(exported != null)
		var roundtrip := Node3D.new()
		scenery._collect(exported,Transform3D.IDENTITY,roundtrip)
		exported.free()
		var other := scenery.bounds(roundtrip)
		assert(box.position.is_equal_approx(other.position) and box.size.is_equal_approx(other.size),"GLB export must retain geometry bounds")
		assert(not roundtrip.get_children().is_empty())
		for part in model.get_children():
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			assert(not vertices.is_empty() and vertices.size() == normals.size() and colors.size() == vertices.size())
			for index in range(vertices.size()):
				assert(is_finite(vertices[index].x) and is_finite(vertices[index].y) and is_finite(vertices[index].z))
				var normal := normals[index].abs()
				var axis := Vector3.ZERO
				axis[normal.max_axis_index()] = 1.0
				assert(normal.distance_to(axis) < .0001,"Voxel face normals must survive packed-resource normal quantization")
			if record.origin == "project-original":
				var fingerprint := HashingContext.new()
				fingerprint.start(HashingContext.HASH_SHA256)
				fingerprint.update(vertices.to_byte_array())
				var signature := fingerprint.finish().hex_encode()
				if not shapes.has(signature):
					shapes[signature] = []
				shapes[signature].append(record.id)
		if record.origin == "project-original":
			if not kinds.has(record.theme):
				kinds[record.theme] = []
			kinds[record.theme].append(record.kind)
			var geometry := Geometry.new()
			var generated := geometry.generate(record.theme,record.kind,1 if record.kind == "workshop" else 0,config.themes[record.theme])
			assert(geometry.cells.size() == int(record.voxel_count) and geometry.faces == int(record.exposed_faces))
			assert(geometry.faces < geometry.cells.size() * 6,"Hidden internal voxel faces must be removed")
			if record.has("door"):
				assert(record.door.front == [0.0,0.0,1.0])
				for x in range(-3,3):
					for y in range(2,14):
						var z: int = roundi(record.door.point[2] / geometry.pitch) - 1
						assert(not geometry.cells.has(Vector3i(x,y,z)),"Door sockets need a real open aperture: " + record.id)
			generated.free()
		else:
			derivative_count += 1
			assert(record.license == "CC0-1.0" and not record.source_assets.is_empty() and not record.attribution.is_empty())
			assert(FileAccess.get_sha256("res://" + record.source_file) == record.source_sha256,"Imported source bytes must remain unchanged")
		model.free()
		roundtrip.free()
	assert(kinds.size() == 8 and kinds.values().all(func(value): return value.size() == 5))
	for identities in shapes.values():
		if identities.size() > 1:
			print("DUPLICATE GEOMETRY: " + str(identities))
	assert(shapes.size() == 40,"The forty original assets need distinct geometry, beyond palette changes")
	assert(derivative_count == 4)
	print("PASS: 44 reusable voxel assets, 40 distinct original shapes, eight complete theme sets, open doorway sockets, hidden-face removal, finite block geometry, GLB round-trip bounds and preserved attributed sources")
	quit()
