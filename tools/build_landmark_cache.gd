extends SceneTree

const Architecture = preload("res://scripts/town_architecture.gd")
const Cache = preload("res://scripts/landmark_cache.gd")
const RenderCache = preload("res://scripts/render_cache.gd")
const Locations = preload("res://scripts/surface_locations.gd")

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	assert(DirAccess.make_dir_recursive_absolute("res://assets/landmark_cache") == OK)
	var architecture := Architecture.new()
	var scenes := {}
	var hashes := {}
	for definition in Locations.DATA.locations.values():
		for part in definition.structures:
			if not part.has("template"):
				continue
			for family in ["block_voxel", "flat_lowpoly"]:
				var key := Cache.key(part, family)
				if scenes.has(key):
					continue
				var recipe: Dictionary = architecture.catalog.data.templates[part.template].duplicate(true)
				recipe.id = part.template
				recipe.theme = "generic"
				var size := Vector2(part.size[0], part.size[1]) - (Vector2.ONE * .10 if part.get("solid", true) else Vector2.ZERO)
				var model := architecture.build_template(recipe, size, part.height, family)
				assert(model != null, architecture.error)
				model.scene_file_path = ""
				RenderCache._owners(model, model)
				var packed := PackedScene.new()
				assert(packed.pack(model) == OK)
				var path := "res://assets/landmark_cache/%s.scn" % key
				assert(ResourceSaver.save(packed, path) == OK)
				model.free()
				scenes[key] = path
				hashes[path] = FileAccess.get_sha256(path)
				await process_frame
	var runtime_inputs := {}
	for path in ["res://assets/imported/catalog.json", "res://config/town_architecture.json", "res://config/environment_styles.json"]:
		runtime_inputs[path] = FileAccess.get_sha256(path)
	var build_inputs := runtime_inputs.duplicate()
	for path in ["res://config/surface_locations.json", "res://scripts/landmark_cache.gd", "res://scripts/surface_location_view.gd", "res://scripts/town_architecture.gd", "res://scripts/town_model_voxelizer.gd", "res://scripts/scenery.gd", "res://scripts/environment_styles.gd", "res://scripts/asset_registry.gd", "res://scripts/voxel_kit.gd", "res://tools/build_landmark_cache.gd"]:
		build_inputs[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open(Cache.PATH + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1, "runtime_inputs":runtime_inputs, "build_inputs":build_inputs, "scenes":scenes, "scene_hashes":hashes}, "\t"))
	file.close()
	assert(DirAccess.rename_absolute(Cache.PATH + ".tmp", Cache.PATH) == OK)
	print("PASS: baked %s fixed landmark components with exact geometry and provenance" % scenes.size())
	quit()
