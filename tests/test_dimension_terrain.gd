extends SceneTree

const Terrain = preload("res://scripts/dimension_terrain.gd")

func fixture() -> Dictionary:
	return {"id": "organic_test", "map_version": 2, "bounds": [0, 0, 2048, 2048], "areas": [{"id": "west", "label_cell": [600, 900]}, {"id": "east", "terrain_center": [1450, 1000], "label_cell": [1450, 1000], "terrain_scale": [1.0, .85]}], "terrain": {"version": 1, "coast": {"polygon": [[160, 160], [520, 96], [1152, 160], [1680, 288], [1872, 704], [1800, 1376], [1552, 1920], [896, 1840], [384, 1648], [128, 1024]], "warp_amplitude": 64, "frequency": .004}, "areas": {"warp_amplitude": 48, "frequency": .003, "blend_width": 64}, "elevation": {"base": 1.5, "amplitude": 2, "frequency": .002, "octaves": 3, "gain": .45, "lacunarity": 2, "step": .5}, "rivers": [{"id": "main", "path": [[1280, 250], [1260, 580], [1310, 960], [1240, 1540], [1500, 1880]], "width": 8, "bank_width": 32}], "lakes": [{"id": "still", "center": [800, 1200], "radii": [90, 60], "rotation": .2, "shore_warp": .06}], "ridges": [{"id": "north", "path": [[500, 400], [1150, 560]], "width": 180, "height": 5}], "hills": [{"id": "south", "center": [650, 1500], "radius": 220, "height": 3}]}}

func _initialize() -> void:
	var definition := fixture()
	assert(Terrain.valid(definition))
	var terrain := Terrain.new(definition)
	var other := Terrain.new(definition.duplicate(true))
	assert(not terrain.land_at(Vector2i(-1, 900)) and not terrain.land_at(Vector2i(2048, 900)))
	assert(terrain.sample(Vector2i(-1, 900)) == {"land": false, "height": 0.0, "water_feature": "ocean", "area_id": ""})
	assert(terrain.area_id(Vector2i(-1, 900)).is_empty() and terrain.height_at(Vector2i(-1, 900)) == 0 and terrain.raw_height_at(Vector2i(-1, 900)) == 0)
	assert(not terrain.land_at(Vector2i(10, 10)) and terrain.land_at(Vector2i(650, 900)))
	assert(terrain.sample(Vector2i(1310, 960)).water_feature == "river:main")
	assert(terrain.sample(Vector2i(800, 1200)).water_feature == "lake:still")
	assert(terrain.sample(Vector2i(800, 1200)).height == 0 and terrain.height_at(Vector2i(800, 1200)) >= 1)
	assert(terrain.sample(Vector2i(10, 10)).area_id.is_empty() and not terrain.area_id(Vector2i(10, 10)).is_empty())
	assert(terrain.area_id(Vector2i(600, 900)) == "west" and terrain.area_id(Vector2i(1450, 1000)) == "east")
	var explicit_center := definition.duplicate(true)
	explicit_center.areas[1].erase("label_cell")
	assert(Terrain.valid(explicit_center))
	var centered := Terrain.new(explicit_center)
	assert(centered.area_id(Vector2i(1450, 1000)) == "east", "An explicit terrain center needs no redundant label fallback")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1825
	var heights := {}
	var samples := {}
	var blended := false
	for index in range(1800):
		var cell := Vector2i(rng.randi_range(0, 2046), rng.randi_range(0, 2046))
		var sample := terrain.sample(cell)
		assert(sample == other.sample(cell), "Fresh samplers must agree independently of query order and cache state")
		assert(sample.land == terrain.land_at(cell))
		var height := terrain.height_at(cell)
		var raw_height := terrain.raw_height_at(cell)
		assert(raw_height >= 1 and raw_height <= 12 and height == snappedf(raw_height, .5))
		assert(height >= 1 and height <= 12 and is_equal_approx(fmod(height, .5), 0))
		for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(1, -1)]:
			var neighbour: Vector2i = cell + offset
			if terrain.extent.has_point(neighbour):
				assert(absf(height - terrain.height_at(neighbour)) <= .5, "Every neighbouring land/deck height must fit actor stepping")
				assert(absf(raw_height - terrain.raw_height_at(neighbour)) <= 22.0 / Terrain.HEIGHT_GRID + .00001, "Unrounded height interpolation must preserve its continuous grade bound")
		if sample.land:
			heights[sample.height] = true
			assert(not sample.area_id.is_empty() and sample.water_feature.is_empty())
		else:
			assert(sample.height == 0 and sample.area_id.is_empty() and not sample.water_feature.is_empty())
		var weights := terrain.area_weights(cell)
		var sum := 0.0
		for area in weights:
			sum += area.weight
		assert(is_equal_approx(sum, 1.0) and weights[0].id == terrain.area_id(cell))
		blended = blended or weights.size() == 2
		if index % 97 == 0:
			samples[cell] = sample
	assert(heights.size() >= 5 and blended, "The map must have actual elevation and soft biome-border variation")
	assert(terrain._height_nodes.size() <= Terrain.CACHE_LIMIT)
	for cell in samples:
		assert(terrain.sample(cell) == samples[cell], "Evicting height controls cannot change prior terrain")
	var changed := definition.duplicate(true)
	changed.map_version += 1
	var versioned := Terrain.new(changed)
	assert(samples.keys().any(func(cell): return terrain.sample(cell) != versioned.sample(cell)), "Map version participates in terrain identity")
	var bad := definition.duplicate(true)
	bad.terrain.coast.polygon = [[100, 100], [500, 500], [100, 500], [500, 100]]
	assert(not Terrain.valid(bad), "A crossing coastline cannot define a supported island")
	bad = definition.duplicate(true)
	bad.terrain.rivers[0].path[0][0] = INF
	assert(not Terrain.valid(bad))
	bad = definition.duplicate(true)
	bad.areas[0].terrain_scale = [0, 1]
	assert(not Terrain.valid(bad))
	bad = definition.duplicate(true)
	bad.terrain.elevation.step = 1
	assert(not Terrain.valid(bad), "The geometry contract requires half-cell elevation steps")
	bad = definition.duplicate(true)
	bad.terrain.coast.octaves = 999999
	assert(not Terrain.valid(bad), "Every consumed noise control needs a validated cost bound")
	var legacy := {"id": "edge_probe", "map_version": 1, "bounds": [0, 0, 64, 64], "areas": [{"id": "land", "bounds": [8, 8, 48, 48], "label_cell": [32, 32]}]}
	assert(Terrain.valid(legacy))
	var original := Terrain.new(legacy)
	assert(original.sample(Vector2i(16, 16)) == {"land": true, "height": 1.0, "water_feature": "", "area_id": "land"})
	assert(original.raw_height_at(Vector2i(16, 16)) == 1.0)
	assert(not original.land_at(Vector2i.ZERO) and original.area_id(Vector2i.ZERO).is_empty())
	check_authored_map()
	print("PASS: organic point-sampled coast/areas/rivers/lakes/ridges/hills, deterministic bounded cache, half-cell neighbour grades and legacy fixtures")
	quit()

func check_authored_map() -> void:
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/dimensions/morrowmere.json"))
	assert(Terrain.valid(definition))
	var terrain := Terrain.new(definition)
	var heights := {}
	var areas := {}
	var water := {}
	for x in range(16, 2048, 32):
		for y in range(16, 2048, 32):
			var cell := Vector2i(x, y)
			var sample := terrain.sample(cell)
			if sample.land:
				heights[sample.height] = true
				areas[sample.area_id] = true
			else:
				water[sample.water_feature] = true
			for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				assert(absf(terrain.height_at(cell) - terrain.height_at(cell + offset)) <= .5)
	assert(heights.size() >= 8 and areas.size() == definition.areas.size() and water.has("ocean"))
	for lake in definition.terrain.lakes:
		assert(terrain.sample(Vector2i(Terrain.point(lake.center))).water_feature == "lake:" + lake.id)
	for river in definition.terrain.rivers:
		assert(river.path.any(func(location): return terrain.sample(Vector2i(Terrain.point(location))).water_feature == "river:" + river.id))
	print("Authored Morrowmere: ", areas.size(), " geographic areas, ", heights.size(), " sampled land heights, ", water.size(), " sampled water features, ", terrain._height_nodes.size(), " cached controls")
