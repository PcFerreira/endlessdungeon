extends SceneTree

const Planner = preload("res://scripts/site_planner.gd")

func _initialize() -> void:
	assert(Planner.valid(Planner.DATA))
	var kinds := {}
	var counts := {"towns": 0, "townless": 0, "quiet": 0, "townless_dungeons": 0}
	var dungeon_counts := {}
	var offsets := {}
	var region_size := int(Planner.DATA.region_size)
	for seed_value in [0, 1, 91, 12345]:
		var planner := Planner.new(seed_value)
		var replay := Planner.new(seed_value)
		for x in range(-4, 5):
			for y in range(-4, 5):
				var coordinate := Vector2i(x, y)
				var first: Dictionary = planner.slots(coordinate)
				assert(first == replay.slots(coordinate), "Placement cannot depend on load order")
				var bounds := Rect2i(coordinate * region_size, Vector2i.ONE * region_size)
				var occupied: Array = first.locations + first.dungeons
				if first.city.is_empty():
					counts.townless += 1
					counts.townless_dungeons += int(not first.dungeons.is_empty())
					counts.quiet += int(occupied.is_empty())
				else:
					counts.towns += 1
					occupied.append(first.city)
					offsets[first.city.cell - coordinate * region_size] = true
				dungeon_counts[first.dungeons.size()] = true
				var seen := {}
				for site in occupied:
					assert(not seen.has(site.id))
					seen[site.id] = true
					assert(bounds.encloses(site.footprint.grow(Planner.DATA.clearance)))
					assert(site.approach == site.cell + site.facing * site.approach_distance)
					for other in occupied:
						if site.id != other.id:
							assert(not site.footprint.grow(Planner.DATA.clearance).intersects(other.footprint), "Actual site footprints need clearance")
					if site.type != "city" and site.type != "dungeon":
						kinds[site.type] = true
				var neighbors := planner.nearby_settlements(coordinate)
				for town in neighbors:
					assert(planner.settlement(town.coordinate) == town, "Neighbor queries cannot invent towns")
				for connection in planner.connections(coordinate):
					assert(not connection.from.is_empty() and not connection.to.is_empty())
					assert(connection.from.type == "city" or connection.to.type == "city", "Local sites must connect to an actual settlement")
					assert(not planner.path(connection.from, connection.to).is_empty(), "Every declared local-site connection needs a planned path: " + connection.id)
		assert(not planner.slots(Vector2i.ZERO).city.is_empty(), "A real starting settlement remains guaranteed")
		for macro in [Vector2i.ZERO, Vector2i(-1, -2), Vector2i(3, 2), Vector2i(1200, -850)]:
			var anchor: Dictionary = planner.macro_anchor(macro)
			assert(anchor == planner.settlement(anchor.coordinate))
			for edge in planner.backbone(macro):
				assert(not edge.from.is_empty() and not edge.to.is_empty())
				assert(edge.id == planner.edge(edge.to, edge.from).id)
				var path: Array = planner.path(edge.from, edge.to)
				assert(not path.is_empty(), "A real-town backbone needs a usable planned route")
				assert(path == planner.path(edge.to, edge.from), "Cross-region route ownership must be canonical")
				var canonical: Dictionary = planner.edge(edge.from, edge.to)
				assert(path[0] == canonical.from.approach and path[-1] == canonical.to.approach)
				for index in range(1, path.size()):
					assert(path[index].x == path[index - 1].x or path[index].y == path[index - 1].y)
				var obstacles := planner.obstacles(path, [canonical.from.id, canonical.to.id])
				for point in Planner.raster(path):
					assert(not obstacles.any(func(box): return box.has_point(point)), "Planned routes must bypass other site footprints")
		var distant: Dictionary = planner.slots(Vector2i(25000, -21000)).duplicate(true)
		var road_records := planner.roads_for(Vector2i.ZERO)
		assert(not road_records.is_empty())
		var reverse_records := replay.roads_for(Vector2i.ZERO)
		assert(road_records == reverse_records, "Road aggregation must replay after different planning/cache histories")
		for index in range(180):
			planner.slots(Vector2i(index, -index))
		assert(planner.plans.size() <= 128)
		assert(planner.slots(Vector2i(25000, -21000)) == distant, "Evicted far plans must reconstruct identically")
	assert(counts.towns > 0 and counts.townless > 100 and counts.quiet > 0 and counts.townless_dungeons > 0)
	assert(offsets.size() > 20 and dungeon_counts.has(0) and dungeon_counts.has(1) and dungeon_counts.has(2))
	assert(["ruin", "castle", "church", "temple"].all(func(kind): return kinds.has(kind)))
	print("PASS: 324 seeded irregular plans; true town-free/quiet areas, independent variable dungeons, four destination kinds, footprint clearance, canonical real-town routes, negative/far replay; ", JSON.stringify(counts))
	quit()
