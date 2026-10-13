extends RefCounted

const Activity = preload("res://scripts/world_activity.gd")
static var config: Dictionary = Activity.new().data.monster_areas

static func plans(world, region: Dictionary) -> Array[Dictionary]:
	var city: Dictionary = region.get("city", {})
	var center: Vector2i = city.cell if not city.is_empty() else region.coordinate * world.REGION_SIZE + Vector2i.ONE * (world.REGION_SIZE / 2)
	var reach: int = maxi(22, world.REGION_SIZE / 4)
	var positions := [center + Vector2i(-reach,-reach), center + Vector2i(reach,reach)]
	if not region.dungeons.is_empty():
		positions.append(region.dungeons[0].cell + Vector2i(0,-6))
	var result: Array[Dictionary] = []
	for index in range(positions.size()):
		var point: Vector2i = positions[index]
		var biome: int = world.cell_info(point).biome
		var labels: Array = config.get("biome_labels", {}).get(str(biome), config.labels)
		result.append({"id":"grounds:%s:%s:%s" % [region.coordinate.x,region.coordinate.y,index], "cell":point, "radius":int(config.radius), "label":labels[index]})
	return result

static func spawns(world, coordinate: Vector2i, data: Dictionary, enemies) -> Array[Dictionary]:
	var regions := {}
	for cell in [coordinate * world.CHUNK_SIZE, (coordinate + Vector2i.ONE) * world.CHUNK_SIZE - Vector2i.ONE]:
		var region: Dictionary = world.region_at(cell)
		regions[region.coordinate] = region
	var candidates: Array[Dictionary] = []
	for region in regions.values():
		for area in plans(world,region):
			if not Rect2i(coordinate * world.CHUNK_SIZE,Vector2i.ONE * world.CHUNK_SIZE).grow(area.radius).has_point(area.cell):
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = world._hash(area.id)
			var home: Dictionary = world.cell_info(area.cell)
			var home_pool: Array = enemies.surface_pool(home.biome,home.facet)
			var leader: int = -1 if home_pool.is_empty() else home_pool[world._hash("species:" + area.id) % home_pool.size()]
			var occupied := {}
			for member in range(int(config.members)):
				for attempt in range(24):
					var cell: Vector2i = area.cell + Vector2i(rng.randi_range(-area.radius,area.radius),rng.randi_range(-area.radius,area.radius))
					var info: Dictionary = world.cell_info(cell)
					if occupied.has(cell) or not info.walkable or info.terrain != "land" or Vector2(cell).distance_to(area.cell) > area.radius or not world.city_at(Vector2(cell), float(config.clearance) - 13).is_empty():
						continue
					var pool: Array = enemies.surface_pool(info.biome,info.facet)
					if pool.is_empty():
						break
					var kind: int = leader if leader in pool else pool[world._hash("species:" + area.id) % pool.size()]
					occupied[cell] = true
					if data.has(cell):
						candidates.append({"id":"%s:%s" % [area.id,member], "cell":cell, "kind":kind, "area_id":area.id, "home":Vector2(area.cell), "radius":area.radius, "label":area.label})
					break
	candidates.sort_custom(func(a,b): return a.id < b.id)
	return candidates.slice(0,2)
