extends RefCounted

static func find(world) -> Dictionary:
	var result := {}
	for x in range(-24, 25):
		for y in range(-24, 25):
			var point := Vector2i(x, y) * 1024
			var profile: Dictionary = world.biome_at(point)
			if result.has(profile.biome_id) or (profile.biome_mix.size() > 1 and profile.biome_id != "coast") or world._natural_water(point):
				continue
			var slots: Dictionary = world.site_planner.slots(world.SitePlanner.coordinate(point))
			if world.sites_in(slots).any(func(site): return site.footprint.grow(4).has_point(point)):
				continue
			profile.cell = point
			result[profile.biome_id] = profile
			if result.size() == world.Biomes.DATA.profiles.size():
				return result
	assert(result.size() == world.Biomes.DATA.profiles.size(), "Find real land examples for every biome: " + str(result.keys()))
	return result
