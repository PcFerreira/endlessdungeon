extends SceneTree

const World = preload("res://scripts/world.gd")

func _init() -> void:
	var seen_biomes := {}
	var seen_heights := {}
	var floor_counts := {}
	for run_seed in range(12):
		var world = World.new()
		world.generate(run_seed, 4)
		assert(world.load_around(Vector2(world.start)))
		assert(world.chunks.size() == 25 and world.cells.size() == 6400)
		assert(world.walkable(Vector2(world.start)))
		var region: Dictionary = world.region_at(world.start)
		assert(region.city.houses.size() >= 6 and region.dungeons.size() == 2)
		assert(world.generator_version == 4)
		assert(world.city_at(Vector2(world.start)).id == region.city.id)
		assert(world.city_at(Vector2(region.dungeons[0].cell)).is_empty(), "A nearby dungeon is not town sanctuary")
		for site in World.sites_in(region):
			assert(world.site_by_id(site.id, site.cell) == site)
			assert(world.site_by_id(site.id, site.cell + Vector2i.ONE).is_empty(), "Real-site resolution requires the actual cell")
		assert(World.sites_in({"coordinate": Vector2i.ZERO, "city": {}, "dungeons": [], "locations": []}).is_empty(), "A town-free plan cannot invent a fallback city")
		var visited := {world.start: true}
		var frontier := [world.start]
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for step in world.DIRECTIONS:
				var neighbor: Vector2i = cell + step
				if world.tiles.has(neighbor) and world.can_step(Vector2(cell), Vector2(neighbor)) and not visited.has(neighbor):
					visited[neighbor] = true
					frontier.append(neighbor)
		for site in region.dungeons:
			assert(site.floors >= 1 and site.floors <= 20, "Dungeon lengths must be finite")
			floor_counts[site.floors] = true
			assert(visited.has(site.cell), "Roads must connect dungeon entrances to the city")
		for house in region.city.houses:
			assert(not world.walkable(Vector2(house.footprint.get_center())), "Buildings need collision")
		assert(not region.city.decorations.is_empty(), "Cities need visible facade props")
		for decoration in region.city.decorations:
			assert(not world.walkable(Vector2(decoration.cell)), "Solid decorative props need collision")
			for house in region.city.houses:
				assert(not house.footprint.has_point(decoration.cell), "Facade props must sit outside buildings")
		for chunk in world.chunks.values():
			for spawn in chunk.spawns:
				assert(world.tiles.has(spawn.cell))
		var original: Dictionary = world.chunks[World.chunk_at(Vector2(world.start))].cells.duplicate(true)
		world.load_around(Vector2(-1024, 2048))
		assert(world.chunks.size() == 25 and world.cells.size() == 6400, "Streaming must remain bounded")
		assert(world.bounds.has_point(Vector2i(-1024, 2048)))
		world.load_around(Vector2(world.start))
		assert(world.chunks[World.chunk_at(Vector2(world.start))].cells == original, "Reloaded chunks must be identical")
		var replay = World.new()
		replay.generate(run_seed, 4)
		replay.load_around(Vector2(replay.start))
		assert(replay.cells == world.cells and replay.region_at(replay.start) == region)
		for x in range(-512, 513, 32):
			for y in range(-512, 513, 32):
				seen_biomes[world.cell_info(Vector2i(x, y)).biome] = true
				seen_heights[world.cell_info(Vector2i(x, y)).height] = true
	assert(seen_biomes.size() == 4, "The world must generate all four biomes")
	assert(seen_heights.size() > 8, "Terrain must have real vertical variation")
	assert(floor_counts.size() > 8, "Dungeon lengths must vary across seeds")
	print("PASS: 12 legacy edition-4 worlds; real site/empty-city queries, varied terrain heights, four biomes, finite dungeon lengths, reachable entrances, city/prop collision, deterministic reloads, bounded streaming at negative/far coordinates")
	quit()
