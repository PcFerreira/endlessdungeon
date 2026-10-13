extends RefCounted

const WALLS := {"north": Vector2.UP, "south": Vector2.DOWN, "west": Vector2.LEFT, "east": Vector2.RIGHT}
const GAP := .16

static func footprint(spec: Dictionary) -> Rect2:
	var size := Vector2(spec.footprint[0], spec.footprint[1])
	return Rect2(Vector2(spec.point[0], spec.point[1]) - size * .5, size)

static func facing(spec: Dictionary) -> Vector2:
	if spec.has("face"):
		return (Vector2(spec.face[0], spec.face[1]) - Vector2(spec.point[0], spec.point[1])).normalized()
	var direction: Array = spec.get("facing", [0, 1])
	return Vector2(direction[0], direction[1])

static func yaw(spec: Dictionary) -> float:
	var direction := facing(spec)
	return atan2(direction.x, direction.y)

static func room_valid(definition: Dictionary, defaults: Dictionary, layout: Dictionary) -> bool:
	var dimensions := Vector2(definition.size[0], definition.size[1])
	var floor := Rect2(Vector2(.57, .57), dimensions - Vector2(2.14, 2.14))
	var obstacles: Array[Rect2] = []
	for spec in defaults.props + layout.props:
		var box := footprint(spec)
		if not floor.encloses(box):
			return false
		for previous in obstacles:
			if previous.grow(.05).intersects(box):
				return false
		obstacles.append(box)
		if spec.has("face"):
			var target := Vector2(spec.face[0], spec.face[1])
			if not (defaults.props + layout.props).any(func(other): return other.fallback in ["table", "workbench"] and footprint(other).has_point(target)):
				return false
		if spec.fallback in ["bookcase", "wall_shelf"] and not spec.has("wall"):
			return false
		if spec.fallback == "wall_shelf" and spec.get("elevation", 0) < .5:
			return false
		if spec.has("wall") and spec.height + spec.get("elevation", 0) > 1.6:
			return false
		if spec.has("wall"):
			var wall: Vector2 = WALLS[spec.wall]
			var gap: float
			match spec.wall:
				"north": gap = box.position.y - .5
				"south": gap = dimensions.y - 1.5 - box.end.y
				"west": gap = box.position.x - .5
				"east": gap = dimensions.x - 1.5 - box.end.x
			if gap < .07 or gap > .16 or facing(spec).dot(-wall) < .99:
				return false
	var start := Vector2i(dimensions.x / 2, dimensions.y - 4)
	var exit := Vector2i(start.x, dimensions.y - 2)
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var cursor := 0
	var targets := [Vector2(exit), Vector2(defaults.readable.approach[0], defaults.readable.approach[1])]
	if definition.get("rest") is Array:
		targets.append(Vector2(definition.rest[0], definition.rest[1]))
	for target in [Vector2(start)] + targets:
		if not _clear(target, floor, obstacles):
			return false
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in WALLS.values():
			var next := cell + Vector2i(direction)
			if not seen.has(next) and _clear(Vector2(next), floor, obstacles):
				seen[next] = true
				queue.append(next)
	for target in targets:
		if not seen.has(Vector2i(target.round())):
			return false
	var book_point := Vector2(defaults.readable.point[0], defaults.readable.point[1])
	if not (defaults.props + layout.props).any(func(spec): return spec.fallback in ["bookstand", "table", "workbench"] and footprint(spec).has_point(book_point)):
		return false
	for box in obstacles:
		var accessible := false
		for cell in seen:
			if box.grow(.85).has_point(Vector2(cell)):
				accessible = true
				break
		if not accessible:
			return false
	return true

static func _clear(point: Vector2, floor: Rect2, obstacles: Array[Rect2]) -> bool:
	if not floor.encloses(Rect2(point - Vector2.ONE * .20, Vector2.ONE * .40)):
		return false
	return not obstacles.any(func(box): return box.grow(.20).has_point(point))

static func wall_slots(area, room: Rect2i, size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var cell := Vector2i(x, y)
			for direction in area.DIRECTIONS:
				if area.tiles.has(cell + direction):
					continue
				var normal := Vector2(direction)
				var footprint_size := Vector2(size.y, size.x) if direction.x != 0 else size
				var depth := size.y
				var point := Vector2(cell) + normal * (.5 - depth * .5 - GAP)
				var approach := Vector2(cell) - normal
				var box := Rect2(point - footprint_size * .5, footprint_size)
				if not _supported(area, cell, direction, box):
					continue
				if not area.walkable(approach) or point.distance_to(area.start) < 1.5 or point.distance_to(area.exit) < 1.5:
					continue
				if area.obstacles.any(func(previous): return previous.grow(.10).intersects(box)):
					continue
				result.append({"cell": cell, "point": point, "wall": direction, "yaw": atan2(-normal.x, -normal.y), "footprint": footprint_size})
	return result

static func _supported(area, cell: Vector2i, direction: Vector2i, box: Rect2) -> bool:
	var clear := box.grow(.14)
	for x in range(floori(clear.position.x + .5), ceili(clear.end.x + .5)):
		for y in range(floori(clear.position.y + .5), ceili(clear.end.y + .5)):
			if not area.tiles.has(Vector2i(x, y)):
				return false
	var from := floori((box.position.y if direction.x != 0 else box.position.x) + .5)
	var to := ceili((box.end.y if direction.x != 0 else box.end.x) + .5)
	for coordinate in range(from, to):
		var support := Vector2i(cell.x, coordinate) if direction.x != 0 else Vector2i(coordinate, cell.y)
		if not area.tiles.has(support) or area.tiles.has(support + direction):
			return false
	return true
