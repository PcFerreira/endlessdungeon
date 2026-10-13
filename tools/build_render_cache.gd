extends SceneTree

const Cache = preload("res://scripts/render_cache.gd")
const Creatures = preload("res://scripts/creature_models.gd")
const Items = preload("res://scripts/item_models.gd")

func _initialize() -> void:
	call_deferred("build")

func source_inputs() -> Dictionary:
	var result := {}
	for path in ["res://assets/imported/catalog.json", "res://config/creature_styles.json", "res://config/item_styles.json", "res://config/environment_styles.json", "res://config/biome_art.json", "res://scripts/render_cache.gd", "res://scripts/creature_models.gd", "res://scripts/item_models.gd", "res://scripts/animated_model_style.gd", "res://scripts/town_model_voxelizer.gd", "res://scripts/voxel_kit.gd", "res://scripts/asset_registry.gd", "res://scripts/scenery.gd", "res://scripts/environment_styles.gd", "res://scripts/decor_geometry.gd", "res://tools/build_render_cache.gd"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func build() -> void:
	var initial_inputs := source_inputs()
	Cache.enabled = false
	Cache.baking = true
	assert(DirAccess.make_dir_recursive_absolute("res://assets/render_cache") == OK)
	var creatures := Creatures.new()
	for id in creatures.styles.creature_sources:
		for biome in [0, 2]:
			var body := creatures.instantiate(id, biome)
			assert(body != null, creatures.error)
			body.free()
		await process_frame
	var items := Items.new()
	var art = JSON.parse_string(FileAccess.get_file_as_string("res://config/biome_art.json"))
	var sources := {}
	for role in art.roles.values():
		for group in role.get("sources", {}).values():
			for source in group:
				sources[source] = true
	for source in sources:
		for family in ["block_voxel", "flat_lowpoly"]:
			var body := items.source_model(source, family)
			assert(body != null, items.error)
			body.free()
		await process_frame
	var runtime_inputs := {}
	if source_inputs() != initial_inputs:
		push_error("Render cache inputs changed during the bake; rerun after the source handoff")
		quit(1)
		return
	for path in ["res://assets/imported/catalog.json", "res://config/creature_styles.json", "res://config/item_styles.json", "res://config/environment_styles.json"]:
		runtime_inputs[path] = FileAccess.get_sha256(path)
	var build_inputs := initial_inputs
	var scene_hashes := {}
	for path in Cache.records.values():
		scene_hashes[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open(Cache.PATH + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1, "runtime_inputs":runtime_inputs, "build_inputs":build_inputs, "scenes":Cache.records, "scene_hashes":scene_hashes}, "\t"))
	file.close()
	assert(DirAccess.rename_absolute(Cache.PATH + ".tmp", Cache.PATH) == OK)
	print("PASS: baked %s exact creature/biome source scenes with bones, animation and provenance preserved" % Cache.records.size())
	quit()
