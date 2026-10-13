extends RefCounted

const Planner = preload("res://scripts/site_planner.gd")

static func dungeons(world, region: Dictionary) -> Array[Dictionary]:
	if world.generator_version < 5:
		return region.dungeons
	var point: Vector2 = Vector2(region.city.cell) if not region.city.is_empty() else Vector2(region.coordinate * world.REGION_SIZE) + Vector2.ONE * (world.REGION_SIZE / 2)
	var result: Array[Dictionary] = []
	for site in world.nearby_sites(point):
		if site.type == "dungeon":
			result.append(site)
	result.sort_custom(func(a, b):
		var first := point.distance_squared_to(a.cell)
		var second := point.distance_squared_to(b.cell)
		return a.id < b.id if first == second else first < second)
	return result

static func valid_city(seed_value: int, id: String, cell: Array = []) -> bool:
	var fields := id.split(":")
	if fields.size() != 3 or fields[0] != "city" or not fields[1].is_valid_int() or not fields[2].is_valid_int():
		return false
	var coordinate := Vector2i(fields[1].to_int(), fields[2].to_int())
	if id != "city:%s:%s" % [coordinate.x, coordinate.y]:
		return false
	var site: Dictionary = Planner.new(seed_value).settlement(coordinate)
	return not site.is_empty() and (cell.is_empty() or (cell.size() == 2 and site.cell == Vector2i(cell[0], cell[1])))

static func valid_dungeon(seed_value: int, id: String, cell: Array, origin: Vector2i) -> bool:
	if cell.size() != 2:
		return false
	var point := Vector2i(cell[0], cell[1])
	var coordinate := Planner.coordinate(point)
	if maxi(absi(coordinate.x - origin.x), absi(coordinate.y - origin.y)) > 1:
		return false
	return Planner.new(seed_value).slots(coordinate).dungeons.any(func(site): return site.id == id and site.cell == point)
