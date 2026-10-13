extends SceneTree

const World = preload("res://scripts/world.gd")
const Areas = preload("res://scripts/area_catalog.gd")

func _init() -> void:
	assert(Areas.valid(Areas.DATA))
	var invalid: Dictionary = Areas.DATA.duplicate(true)
	invalid.cities[invalid.start_city].layouts[0].plots[0] = [0,0]
	assert(not Areas.valid(invalid), "Layout definitions must reserve the main streets")
	invalid = Areas.DATA.duplicate(true)
	invalid.cities[invalid.start_city].weight = 0
	assert(not Areas.valid(invalid))
	invalid = Areas.DATA.duplicate(true)
	invalid.geography.town_spacing = 64
	assert(not Areas.valid(invalid))
	invalid = Areas.DATA.duplicate(true)
	invalid.cities[invalid.start_city].outdoor_lots[0].position = [-8,-8]
	assert(not Areas.valid(invalid), "Outdoor lots must not overlap buildings")
	invalid = Areas.DATA.duplicate(true)
	invalid.cities[invalid.start_city].required_buildings[0] = "unknown"
	assert(not Areas.valid(invalid))
	var changes := 0
	var edges := 0
	for seed_value in range(8):
		var world := World.new()
		world.generate(seed_value)
		for x in range(-256,257,8):
			for y in range(-256,257,8):
				var cell := Vector2i(x,y)
				for step in [Vector2i(8,0),Vector2i(0,8)]:
					edges += 1
					if world._biome_at(cell) != world._biome_at(cell + step):
						changes += 1
	var boundary_ratio := float(changes) / edges
	print("Biome boundary ratio at eight-cell spacing: %.4f" % boundary_ratio)
	assert(boundary_ratio < .055, "Broad climate areas must avoid frequent small biome pockets")
	var bridges := 0
	var openings := 0
	assert(World.REGION_SIZE >= 128, "Towns need at least 102 cells of wilderness between their plateaus")
	for seed_value in range(16):
		var world := World.new()
		world.generate(seed_value)
		var city: Dictionary = world.region_at(world.start).city
		var uses := {}
		for house in city.houses:
			assert(house.has("interior_type") and house.has("use_id"))
			uses[house.interior_type] = true
		assert(uses.has("home") and uses.has("shop") and uses.has("inn") and uses.has("workshop"))
		assert(city.outdoor_lots.size() >= 2)
		for direction in World.DIRECTIONS:
			var other: Dictionary = world.region_at(city.cell + direction * World.REGION_SIZE).city
			assert(Vector2(city.cell).distance_to(other.cell) >= 128)
			for lot in other.outdoor_lots:
				assert(other.streets.has(Vector2i(lot.approach)))
				assert(world.cell_info(Vector2i(lot.approach)).walkable)
		world.load_around(Vector2(world.start))
		for cell in city.streets:
			assert(is_equal_approx(world.ground_height(Vector2(cell)),city.height), "Town streets must stay on the level plateau")
		var seen := {world.start: true}
		var queue := [world.start]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			for direction in world.DIRECTIONS:
				var next: Vector2i = cell + direction
				if world.tiles.has(next) and world.can_step(Vector2(cell),Vector2(next)) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		for house in city.houses:
			assert(house.id.begins_with(city.id + ":house:") and house.door == house.approach)
			assert(house.has("door") and seen.has(Vector2i(house.door)), "Every front door must have a connected street")
			assert(city.streets.has(Vector2i(house.door)))
			assert(not house.footprint.has_point(Vector2i(house.door)))
		for book in city.books:
			assert(seen.has(Vector2i(book.approach)))
		for resident in city.residents:
			assert(seen.has(Vector2i(resident.approach)))
		for lot in city.outdoor_lots:
			assert(seen.has(Vector2i(lot.approach)), "Markets and farms need reachable paths")
			assert(not city.streets.has(lot.footprint.get_center()))
			for house in city.houses:
				assert(not house.footprint.intersects(lot.footprint))
			for cell in lot.solid_cells:
				assert(not world.walkable(Vector2(cell)))
		var region: Dictionary = world.region_at(city.cell)
		for site in region.dungeons:
			var junction := Vector2i(site.cell.x,city.cell.y)
			for x in range(-2,3):
				for y in range(-2,3):
					var cell := junction + Vector2i(x,y)
					var record: Dictionary = region.roads.get(cell,{})
					if record.is_empty() or record.edge == 0:
						continue
					var side := Vector2i.DOWN if record.axis.x != 0 else Vector2i.RIGHT
					var info: Dictionary = world.cell_info(cell)
					if info.terrain == "bridge" and region.roads.has(cell + side * record.edge):
						openings += 1
						assert(info.bridge_edge == 0, "Bridge railings must leave openings at side roads")
		for chunk in world.chunks.values():
			assert(chunk.spawns.size() <= 2)
			for spawn in chunk.spawns:
				assert(World.city_distance(Vector2(spawn.cell),world.region_at(spawn.cell).city.cell) >= 16)
		for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
			var side := Vector2i.DOWN if axis == Vector2i.RIGHT else Vector2i.RIGHT
			var point := Vector2(city.cell + side)
			for index in range(World.REGION_SIZE):
				world.load_around(point)
				var next := point + Vector2(axis)
				assert(world.can_step(point,next), "Town links must join across region boundaries")
				assert(world.move_actor(point,Vector2(axis)).is_equal_approx(next))
				point = next
				var info: Dictionary = world.cell_info(Vector2i(point))
				if info.terrain == "bridge":
					bridges += 1
					assert(info.height >= .5 and info.base_height < info.height)
	assert(bridges > 0)
	assert(openings > 0)
	print("PASS: broad biome coverage; connected front doors, residents and books; bank-to-bank bridges; streamed town links across region seams")
	quit()
