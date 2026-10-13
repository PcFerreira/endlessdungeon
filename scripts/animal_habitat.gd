extends RefCounted

static func usable(world, point: Vector2, medium: String = "land") -> bool:
	if medium != "water":
		return world.walkable(point)
	var cell := Vector2i(point.round())
	return world.bounds.has_point(cell) and world.cell_info(cell).terrain == "water"

static func origin(world, point: Vector2, medium: String = "land") -> Vector2:
	if medium != "water":
		return world.safe_position(point, 2)
	for radius in range(4):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := Vector2(point.round()) + Vector2(x, y)
				if usable(world, candidate, medium) and [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN].all(func(offset): return usable(world, candidate + offset, medium)):
					return candidate
	return Vector2.INF

static func can_step(world, from: Vector2, to: Vector2, medium: String = "land") -> bool:
	return usable(world, from, medium) and usable(world, to, medium) if medium == "water" else world.can_step(from, to)

static func height(world, point: Vector2, medium: String = "land") -> float:
	return .03 if medium == "water" else world.ground_height(point) + (1.1 if medium == "air" else 0.0)
