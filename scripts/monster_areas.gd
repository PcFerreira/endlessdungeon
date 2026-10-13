extends RefCounted

const Activity = preload("res://scripts/world_activity.gd")
static var config: Dictionary = Activity.new().data.monster_areas

static func plans(world, region: Dictionary) -> Array[Dictionary]:
	var city: Dictionary = region.get("city", {})
	var center: Vector2i = city.cell if not city.is_empty() else region.coordinate * world.REGION_SIZE + Vector2i.ONE * (world.REGION_SIZE / 2)
	var reach: int = maxi(22, world.REGION_SIZE / 4)
	var positions := [center + Vector2i(-reach,-reach), center + Vector2i(reach,reach)]
	var ruins: Array = region.get("dungeons", [])
	if not ruins.is_empty():
		positions.append(ruins[0].cell + Vector2i(0,-6))
	else:
		positions.append(null)
	var middle: Vector2i = region.coordinate * world.REGION_SIZE + Vector2i.ONE * (world.REGION_SIZE / 2)
	for offset in [Vector2i(-reach,reach), Vector2i(reach,-reach), Vector2i(0,-reach), Vector2i(0,reach), Vector2i(-reach,0), Vector2i(reach,0)]:
		positions.append(middle + offset)
	for ruin in ruins.slice(1):
		positions.append(ruin.cell + Vector2i(0,-6))
	var result: Array[Dictionary] = []
	for index in range(positions.size()):
		if positions[index] == null:
			continue
		var point: Vector2i = positions[index]
		if index >= 3 and index < 9:
			var jitter := RandomNumberGenerator.new()
			jitter.seed = world._hash("grounds-position:%s:%s:%s" % [region.coordinate.x,region.coordinate.y,index])
			point += Vector2i(jitter.randi_range(-5,5), jitter.randi_range(-5,5))
		var biome: int = world.cell_info(point).biome
		var labels: Array = config.get("biome_labels", {}).get(str(biome), config.labels)
		var radius: int = int(config.radius) if index < 3 or index >= 9 else clampi(int(config.radius) + index % 3 - 1, 3, 9)
		result.append({"id":"grounds:%s:%s:%s" % [region.coordinate.x,region.coordinate.y,index], "cell":point, "radius":radius, "label":labels[index if index < 9 else 2]})
	return result

static func spawns(world, coordinate: Vector2i, data: Dictionary, enemies) -> Array[Dictionary]:
	var regions := {}
	var chunk_bounds := Rect2i(coordinate * world.CHUNK_SIZE, Vector2i.ONE * world.CHUNK_SIZE)
	var search := chunk_bounds.grow(maxi(22, world.REGION_SIZE / 4) + 9)
	var first := Vector2i(floori(float(search.position.x) / world.REGION_SIZE), floori(float(search.position.y) / world.REGION_SIZE))
	var last := Vector2i(floori(float(search.end.x - 1) / world.REGION_SIZE), floori(float(search.end.y - 1) / world.REGION_SIZE))
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var region: Dictionary = world.region_at(Vector2i(x,y) * world.REGION_SIZE)
			regions[region.coordinate] = region
	var candidates: Array[Dictionary] = []
	for region in regions.values():
		for area in plans(world,region):
			if not chunk_bounds.grow(area.radius).has_point(area.cell):
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = world._hash(area.id)
			var home: Dictionary = world.cell_info(area.cell)
			var home_pool: Array = enemies.surface_pool(home.biome,home.facet,home.get("biome_id", "") if world.generator_version >= 6 else "")
			var leader: int = -1 if home_pool.is_empty() else home_pool[world._hash("species:" + area.id) % home_pool.size()]
			var occupied: Array[Vector2i] = []
			for member in range(int(config.members)):
				for attempt in range(24):
					var cell: Vector2i = area.cell + Vector2i(rng.randi_range(-area.radius,area.radius),rng.randi_range(-area.radius,area.radius))
					var info: Dictionary = world.cell_info(cell)
					if occupied.any(func(other): return Vector2(other).distance_squared_to(cell) < 4) or not info.walkable or info.terrain != "land" or Vector2(cell).distance_to(area.cell) > area.radius or not world.city_at(Vector2(cell), float(config.clearance) - 13).is_empty():
						continue
					var pool: Array = enemies.surface_pool(info.biome,info.facet,info.get("biome_id", "") if world.generator_version >= 6 else "")
					if pool.is_empty():
						break
					var kind: int = leader if leader in pool else pool[world._hash("species:" + area.id) % pool.size()]
					occupied.append(cell)
					if data.has(cell):
						candidates.append({"id":"%s:%s" % [area.id,member], "cell":cell, "kind":kind, "area_id":area.id, "home":Vector2(area.cell), "radius":area.radius, "label":area.label})
					break
	candidates.sort_custom(func(a,b): return a.id < b.id)
	return candidates.slice(0,2)
