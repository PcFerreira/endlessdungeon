extends SceneTree

const World = preload("res://scripts/world.gd")

func _init() -> void:
	var invalid: Dictionary = World.Biomes.DATA.duplicate(true)
	for profile in invalid.profiles.values():
		profile.weight = 0
	assert(not World.Biomes.valid(invalid), "Every climate needs a nonempty weighted biome pool")
	var legacy := World.new()
	legacy.generate(91, 5)
	var world := World.new()
	world.generate(91, 6)
	assert(is_equal_approx(world.temperature.frequency * 5, legacy.temperature.frequency))
	assert(is_equal_approx(world.moisture.frequency * 5, legacy.moisture.frequency))
	assert(world.REGION_SIZE == legacy.REGION_SIZE and world.site_planner.slots(Vector2i(2, -1)) == legacy.site_planner.slots(Vector2i(2, -1)))
	var found := {}
	var blended := 0
	for x in range(-24, 25):
		for y in range(-24, 25):
			var point := Vector2i(x, y) * 1024
			var first: Dictionary = world.biome_at(point)
			assert(first == world.biome_at(point))
			assert(world.Biomes.valid_cell(first))
			found[first.biome_id] = true
			blended += int(first.biome_blend > 0)
			assert(world._biome_at(point * 5) == legacy._biome_at(point), "Climate width is a coordinate scale change, independent of planning cells")
	assert(found.size() >= 13 and blended > 0, str(found.keys()))
	var previous := {}
	var boundaries := 0
	for x in range(-12000, 12001):
		var context := World.Biomes.sample(Vector2i(x, 1000), 0, 91, 0.0, .5)
		if not previous.is_empty():
			var first := World.Biomes.color_for(previous)
			var second := World.Biomes.color_for(context)
			assert(maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b))) < .05, "Ecology boundaries blend without a hard ground-color seam")
			if previous.biome_id != context.biome_id:
				boundaries += 1
				assert(previous.biome_blend >= .4 and context.biome_blend >= .4)
		previous = context
	assert(boundaries > 2)
	var start: Dictionary = world.region_at(world.start)
	assert(not start.city.is_empty() and start.dungeons.size() == 2)
	world.load_around(Vector2(world.start))
	assert(world.walkable(Vector2(world.start)))
	var profiles := {}
	for x in range(-2, 3):
		for y in range(-2, 3):
			var region: Dictionary = world.region_at(Vector2i(x, y) * world.REGION_SIZE)
			for site in World.sites_in(region):
				assert(world.Biomes.DATA.profiles.has(site.biome_id))
				assert(site.biome_id == world.biome_at(site.cell).biome_id)
			for route in region.routes:
				for point in world.SitePlanner.raster(route.path):
					if world.SitePlanner.coordinate(point) == region.coordinate:
						var info: Dictionary = world.cell_info(point)
						assert(info.walkable and info.terrain in ["road", "bridge", "paving"], "Biome density must preserve actual connected roads")
			profiles[region.facet] = true
	print("PASS: larger edition-6 climate fields, coherent ecology catalogue/transition sampling, actual site context and clear connected routes; ", found.keys())
	quit()
