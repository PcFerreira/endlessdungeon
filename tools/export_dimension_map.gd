extends SceneTree

const FiniteWorld = preload("res://scripts/finite_world.gd")
const Catalog = preload("res://scripts/dimension_catalog.gd")

func source_hashes() -> Dictionary:
	var paths := ["res://scripts/finite_world.gd", "res://scripts/dimension_terrain.gd", "res://scripts/dimension_catalog.gd", "res://scripts/dimension_constructions.gd", "res://scripts/dimension_population.gd", "res://config/dimension_constructions.json", "res://scripts/biome_catalog.gd", "res://config/biomes.json", "res://tools/export_dimension_map.gd"]
	for filename in DirAccess.get_files_at(Catalog.DIRECTORY):
		if filename.get_extension() == "json":
			paths.append(Catalog.DIRECTORY.path_join(filename))
	var hashes := {}
	for path in paths:
		hashes[path] = FileAccess.get_sha256(path)
	return hashes

func map_color(world, info: Dictionary) -> Color:
	var color: Color = world.Biomes.color_for(info) if info.has("biome_id") else world.MAP_COLORS[info.biome]
	color = color.lightened(info.height * .025)
	if info.terrain == "sky":
		color = Color("18172e")
	elif info.terrain == "water":
		color = Color("466f85")
	elif info.terrain in ["road", "bridge"]:
		color = Color("c4b895")
	elif info.terrain == "paving":
		color = Color("939a8b")
	if not info.walkable and info.terrain != "water":
		color = color.darkened(.2)
	return color

func _initialize() -> void:
	var id := Catalog.default_id()
	var resolution := 256
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dimension="):
			id = argument.trim_prefix("--dimension=")
		elif argument.begins_with("--resolution="):
			var value := argument.trim_prefix("--resolution=")
			assert(value.is_valid_int())
			resolution = value.to_int()
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		else:
			assert(false, "Unknown dimension-map argument: " + argument)
	assert(resolution >= 32 and resolution <= 512)
	var hashes := source_hashes()
	var world := FiniteWorld.new(id)
	world.generate(0)
	assert(world.chunks.is_empty())
	if output.is_empty():
		output = "res://artifacts/dimension-maps/%s-v%s" % [id, world.map_version]
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) == OK)
	var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat64Array()
	var areas := PackedStringArray()
	var terrains := PackedStringArray()
	var biomes := PackedStringArray()
	var colors := PackedStringArray()
	var water: Array[bool] = []
	var extent: Rect2i = world.map_extent
	var stride := Vector2(extent.size) / resolution
	for y in range(resolution):
		for x in range(resolution):
			var cell := extent.position + Vector2i((Vector2(x, y) + Vector2.ONE * .5) * stride)
			assert(extent.has_point(cell))
			var info: Dictionary = world.cell_info(cell)
			var area: Dictionary = world.area_at(cell)
			var color := map_color(world, info)
			image.set_pixel(x, y, color)
			heights.append(info.height)
			areas.append(area.get("id", ""))
			terrains.append(info.terrain)
			biomes.append(info.get("biome_id", ""))
			colors.append(color.to_html(false))
			water.append(info.terrain == "water")
	assert(world.chunks.is_empty(), "Map raster export must not generate or load any world chunks")
	assert(source_hashes() == hashes, "Terrain or catalogue changed during raster export; repeat after source release")
	var data := {"version": 1, "dimension_id": id, "map_version": world.map_version, "name": world.definition.name, "extent": [extent.position.x, extent.position.y, extent.size.x, extent.size.y], "raster_size": [resolution, resolution], "sample_stride": [stride.x, stride.y], "sample_offset": [.5, .5], "row_order": "y_then_x", "height": heights, "area_id": areas, "terrain": terrains, "biome_id": biomes, "color_rgb": colors, "water": water, "definition": world.dimension_record(), "generated_chunks": world.chunks.size(), "source_sha256": hashes}
	var file := FileAccess.open(output.path_join("terrain.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()
	assert(image.save_png(output.path_join("terrain.png")) == OK)
	print("PASS: %s v%s actual terrain raster %sx%s (%s samples), zero generated chunks; %s" % [id, world.map_version, resolution, resolution, heights.size(), output])
	quit()
