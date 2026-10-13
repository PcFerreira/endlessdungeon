extends SceneTree

const World = preload("res://scripts/world.gd")
const Planner = preload("res://scripts/site_planner.gd")

func _init() -> void:
	var counts := {"towns": 0, "townless": 0, "quiet": 0, "routes": 0, "steps": 0, "bridges": 0}
	var kinds := {}
	for seed_value in [0, 91]:
		var world = World.new()
		world.generate(seed_value, 5)
		assert(world.generator_version == 5 and World.GENERATOR_VERSION == 4, "Edition 5 is staged; new journeys stay on the accepted edition")
		for x in range(-2, 3):
			for y in range(-2, 3):
				var coordinate := Vector2i(x, y)
				var region: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
				var raw: Dictionary = world.site_planner.slots(coordinate)
				assert(region.coordinate == raw.coordinate)
				assert(region.city.is_empty() == raw.city.is_empty(), "World must materialize actual absent settlements")
				counts.townless += int(region.city.is_empty())
				counts.towns += int(not region.city.is_empty())
				counts.quiet += int(World.sites_in(region).is_empty())
				assert(region.dungeons.size() == raw.dungeons.size() and region.locations.size() == raw.locations.size())
				for site in World.sites_in(region):
					assert(world.site_by_id(site.id, site.cell) == site)
					assert(site.biome == world._biome_at(site.cell), "Owning context comes from the actual irregular site")
					assert(not site.name.is_empty() and site.height == world.ground_height(Vector2(site.approach)))
					if site.type == "city":
						assert(site.houses.size() >= 6 and world.city_at(Vector2(site.approach)).id == site.id)
					elif site.type == "dungeon":
						assert(site.floors >= 1 and site.floors <= 20 and world.city_at(Vector2(site.cell)).is_empty())
					else:
						kinds[site.type] = true
				counts.routes += region.routes.size()
				var limits := Rect2i(coordinate * World.REGION_SIZE, Vector2i.ONE * World.REGION_SIZE)
				for route in region.routes:
					for point in Planner.raster(route.path):
						if limits.has_point(point):
							if not world.cell_info(point).walkable:
								print("BLOCKED ROUTE: ", {"seed": seed_value, "coordinate": coordinate, "route": route, "point": point, "city": region.city.get("cell"), "locations": region.locations.map(func(site): return {"id": site.id, "cell": site.cell, "facing": site.facing, "contains": point in site.solid_cells})})
							assert(region.roads.has(point) and region.roads[point].centerline and world.cell_info(point).walkable, "The actual declared route path must be clear: " + str(point))
				for cell in region.roads:
					var road: Dictionary = region.roads[cell]
					var info: Dictionary = world.cell_info(cell)
					assert(road.height == world._travel_height(cell), "Route crossings share one deterministic surface")
					counts.bridges += int(road.bridge)
					# Road shoulders can touch fixed entrance posts; centerlines must remain clear.
					if road.centerline:
						assert(info.walkable, "Actual generated centerline is blocked at " + str(cell))
						for step in World.DIRECTIONS:
							var next: Vector2i = cell + step
							if region.roads.has(next) and region.roads[next].centerline:
								assert(absf(info.height - world.cell_info(next).height) <= .5, "Adjacent route ownership must preserve traversable grades")
			# Follow real connector paths through actual streamed chunks, including turns.
			for connection in world.site_planner.connections(Vector2i.ZERO):
				var path := Planner.raster(world.site_planner.path(connection.from, connection.to))
				assert(not path.is_empty())
				world.load_around(Vector2(path[0]))
				for index in range(1, path.size()):
					var previous: Vector2i = path[index - 1]
					var cell: Vector2i = path[index]
					world.load_around(Vector2(cell))
					assert(world.can_step(Vector2(previous), Vector2(cell)), "Actual route must be traversable at %s -> %s" % [previous, cell])
					counts.steps += 1
					assert(world.chunks.size() == 25 and world.cells.size() == 6400)
		var initial: Dictionary = world.region_at(world.start).duplicate(true)
		var anchor: Dictionary = world.nearest_site(Vector2(64000, -51200), "city")
		assert(not anchor.is_empty() and world.site_by_id(anchor.id, anchor.cell) == anchor, "Sparse lookup returns an actual guaranteed town")
		world.load_around(Vector2(64000, -51200))
		world.load_around(Vector2(world.start))
		assert(world.walkable(Vector2(world.start)) and world.region_at(world.start) == initial)
		var replay = World.new()
		replay.generate(seed_value, 5)
		replay.load_around(Vector2(replay.start))
		assert(replay.cells == world.cells and replay.region_at(replay.start) == initial)
	assert(counts.townless > counts.towns and counts.quiet > 0 and counts.routes > 0 and counts.steps > 0)
	assert(["ruin", "castle", "church", "temple"].all(func(kind): return kinds.has(kind)))
	print("PASS: staged edition-5 World; actual sparse materialization, real-site biome/height/IDs, streamed physical connectors, bounded far reload/replay; ", JSON.stringify(counts))
	quit()
