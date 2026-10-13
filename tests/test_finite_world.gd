extends SceneTree

const Catalog = preload("res://scripts/dimension_catalog.gd")
const FiniteWorld = preload("res://scripts/finite_world.gd")

func _initialize() -> void:
	var data := Catalog.definition()
	assert(Catalog.valid(data) and Catalog.box(data.bounds) == Rect2i(0, 0, 2048, 2048))
	var bad := data.duplicate(true)
	bad.sites[0].cell = [-1, 0]
	assert(not Catalog.valid(bad))
	bad = data.duplicate(true)
	bad.areas[0].biome_id = "unknown"
	assert(not Catalog.valid(bad))
	bad = data.duplicate(true)
	bad.routes[0].path[0] = [INF, 2]
	assert(not Catalog.valid(bad))
	bad = data.duplicate(true)
	bad.routes.append({"id": "disconnected", "width": 3, "path": [[2000, 20], [2020, 20]]})
	assert(not Catalog.valid(bad), "A future definition cannot add a disconnected road network")
	bad = data.duplicate(true)
	var overlapping: Dictionary = bad.sites[0].duplicate(true)
	overlapping.id = "overlapping_place"
	bad.sites.append(overlapping)
	assert(not Catalog.valid(bad), "Composed landmarks cannot overlap and disagree with their collision geometry")
	var world := FiniteWorld.new()
	world.generate(17, 6)
	assert(world.map_extent == Rect2i(0, 0, 2048, 2048) and world.cells.is_empty() and world.chunks.is_empty())
	assert(world.authored_areas().size() == 8 and world.authored_sites().size() == data.sites.size() and data.sites.size() >= 24)
	assert(world.area_at(Vector2i(767, 1100)).id == world.area_at(Vector2i(768, 1100)).id, "Organic area assignments must cross the old rectangular content envelopes")
	assert(not world.cell_info(Vector2i(1104, 1152)).walkable, "The new inland lake must replace the former flat meadow")
	var heights := {}
	for x in range(256, 1792, 128):
		for y in range(128, 1792, 128):
			var info := world.cell_info(Vector2i(x, y))
			if info.walkable:
				heights[info.height] = true
	assert(heights.size() >= 6, "Morrowmere must contain hills and valleys instead of one flat plateau")
	for site in world.authored_sites():
		for x in range(-128, 129, 16):
			for y in range(-128, 129, 16):
				var cell: Vector2i = site.cell + Vector2i(x, y)
				var info := world.cell_info(cell)
				if not info.walkable:
					continue
				for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
					var neighbour := world.cell_info(cell + direction)
					assert(not neighbour.walkable or absf(info.height - neighbour.height) <= .51, "Overlapping landmark plateaus must meet without impassable height jumps")
	world.load_around(world.spawn_point())
	assert(world.chunks.size() == 25 and world.cells.size() == 6400)
	assert(world.walkable(world.spawn_point()) and world.walkable(Vector2(world.return_portal)))
	var saved_point := world.spawn_point() + Vector2(.31, .17)
	assert(world.safe_position(saved_point) == saved_point, "Loading a valid fractional position cannot snap it onto the integer grid")
	var other := FiniteWorld.new()
	for edition in [4, 5, 6, 7]:
		other.generate(999, edition)
		for point in [Vector2i(960, 1040), Vector2i(400, 700), Vector2i(1600, 320)]:
			assert(world.cell_info(point) == other.cell_info(point), "The authored map and decoration remain identical between heroes and editions")
	for area in world.authored_areas():
		assert(world.area_at(area.label_cell).id == area.id)
		assert(world.Biomes.valid_cell(world.cell_info(area.label_cell)))
	for site in world.authored_sites():
		assert(world.site_by_id(site.id, site.cell).id == site.id)
		assert(world.map_extent.encloses(site.footprint))
		assert(world.cell_info(Vector2i(site.approach)).walkable, "Every authored site has a clear route approach")
		for book in site.books:
			assert(world.cell_info(Vector2i(book.approach)).walkable, "An authored reader must have a clear approach")
			assert(world.sites_in(world.region_at(Vector2i(book.approach))).any(func(visible): return visible.id == site.id), "A site's reader must remain addressable across region boundaries")
		if site.type == "city":
			for house in site.houses:
				assert(world.cell_info(Vector2i(house.approach)).walkable)
		else:
			assert(world.cell_info(Vector2i(site.rest_point)).walkable)
	for route in data.routes:
		for index in range(route.path.size() - 1):
			var from := Vector2i(route.path[index][0], route.path[index][1])
			var to := Vector2i(route.path[index + 1][0], route.path[index + 1][1])
			var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
			var previous := from
			for step in range(steps + 1):
				var cell := Vector2i(Vector2(from).lerp(Vector2(to), float(step) / steps).round())
				assert(world.cell_info(cell).walkable, "Authored routes must remain connected and unblocked")
				assert(absf(world.cell_info(cell).height - world.cell_info(previous).height) <= .51, "Road and bridge grades must remain traversable")
				previous = cell
	assert(not world.cell_info(Vector2i(-1, 700)).walkable and world.region_at(Vector2i(-1, 700)).city.is_empty())
	assert(world.nearest_site(Vector2(1000, 1000)).id.begins_with("dimension:"))
	world.load_around(Vector2(128, 576))
	assert(world.chunks.size() <= 25 and world.cells.size() <= 6400 and world.regions.size() <= 32)
	assert(not world.bounds.has_point(Vector2i(960, 1040)) and world.map_extent.has_point(Vector2i(960, 1040)))
	world.load_around(Vector2.ZERO)
	assert(world.chunks.size() == 9 and not world.walkable(Vector2(-1, 0)))
	assert(world.safe_position(Vector2(-999, -999)) == world.spawn_point())
	var area: Dictionary = data.areas[0].duplicate(true)
	area.bounds = [0, 0, 64, 64]
	area.label_cell = [32, 32]
	var edge := {"version": 1, "id": "edge_probe", "name": "Edge probe", "map_version": 1, "bounds": [0, 0, 64, 64], "spawn": [32, 32], "return_portal": [32, 32], "sanctum_portal": [5, 7], "areas": [area], "sites": [{"id": "edge_town", "name": "Edge town", "type": "city", "cell": [13, 32], "area_id": area.id, "archetype_id": "city_crossroads"}], "routes": [{"id": "entry", "width": 3, "path": [[32, 32], [32, 35], [13, 35]]}]}
	assert(Catalog.valid(edge))
	var separated := edge.duplicate(true)
	separated.bounds = [0, 0, 256, 256]
	separated.areas[0].bounds = [0, 0, 256, 256]
	separated.routes.append({"id": "diagonal", "width": 3, "path": [[32, 32], [192, 192]]})
	separated.routes.append({"id": "parallel_isolated", "width": 3, "path": [[32, 96], [144, 208]]})
	assert(not Catalog.valid(separated), "Overlapping diagonal bounding boxes do not connect separated roads")
	var shore := edge.duplicate(true)
	shore.id = "shore_probe"
	shore.areas[0].bounds = [8, 0, 56, 64]
	assert(not Catalog.valid(shore), "A land structure needs a complete dry foundation inside its named area")
	Catalog.records[edge.id] = edge
	var edge_world := FiniteWorld.new(edge.id)
	edge_world.generate(17, 6)
	assert(not edge_world.cell_info(Vector2i(-1, 32)).walkable, "An edge site's clearing cannot make outside cells walkable")
	var twin := edge.duplicate(true)
	twin.id = "twin_probe"
	twin.bounds = [0, 0, 256, 256]
	twin.areas[0].bounds = [0, 0, 256, 256]
	twin.sites[0].cell = [124, 32]
	twin.sites.append(twin.sites[0].duplicate(true))
	twin.sites[1].id = "second_town"
	twin.sites[1].cell = [160, 96]
	twin.routes[0].path = [[32, 32], [32, 35], [160, 35], [160, 99]]
	assert(not Catalog.valid(twin), "Two cities cannot overwrite the singular region city metadata at their shared doors")
	var future := data.duplicate(true)
	future.id = "another_dimension"
	future.name = "Another Place"
	future.default = false
	assert(Catalog.valid(future))
	Catalog.records[future.id] = future
	var expansion := FiniteWorld.new(future.id)
	expansion.generate(17, 6)
	assert(expansion.authored_sites()[0].id.begins_with("dimension:another_dimension:") and expansion.cell_info(Vector2i.ZERO).area_name == "Another Place Sea")
	print("PASS: fixed 2048-square dimension, seed-independent data, bounded chunks/edges, valid authored sites and connected routes")
	quit()
