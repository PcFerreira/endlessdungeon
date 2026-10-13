extends RefCounted

const Planner = preload("res://scripts/site_planner.gd")
const IntegerText = preload("res://scripts/integer_text.gd")

static func identity(from_id: String, to_id: String, slot: int) -> String:
	return "road5:%s:%s:%s:%s:%s" % [from_id.split(":")[1], from_id.split(":")[2], to_id.split(":")[1], to_id.split(":")[2], slot]

static func fields(id: String) -> Dictionary:
	var values := id.split(":")
	if values.size() != 6 or values[0] != "road5":
		return {}
	for value in values.slice(1, 5):
		if not IntegerText.bounded(value, 9600000.0 / Planner.DATA.region_size):
			return {}
	for value in values.slice(1):
		if not IntegerText.valid(value) or str(value.to_int()) != value:
			return {}
	var first := Vector2i(values[1].to_int(), values[2].to_int())
	var last := Vector2i(values[3].to_int(), values[4].to_int())
	var slot := values[5].to_int()
	var from_id := "city:%s:%s" % [first.x, first.y]
	var to_id := "city:%s:%s" % [last.x, last.y]
	if slot not in [0, 1, 2] or from_id >= to_id or [first.x, first.y, last.x, last.y].any(func(value): return absi(value * int(Planner.DATA.region_size)) > 9600000):
		return {}
	return {"first": first, "last": last, "from_id": from_id, "to_id": to_id, "slot": slot}

static func lane(path: Array, slot: int, towns: Array = []) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var width := .55 if slot % 2 == 0 else -.55
	for index in range(path.size()):
		var incoming := Vector2(path[index] - path[index - 1]).normalized() if index > 0 else Vector2(path[1] - path[0]).normalized()
		var outgoing := Vector2(path[index + 1] - path[index]).normalized() if index + 1 < path.size() else incoming
		var offset := Vector2(-incoming.y, incoming.x)
		if incoming != outgoing:
			offset += Vector2(-outgoing.y, outgoing.x)
		if towns.any(func(town): return maxf(absf(path[index].x - town.cell.x), absf(path[index].y - town.cell.y)) <= town.radius + 1):
			offset = Vector2.ZERO
		result.append(Vector2(path[index]) + offset * width)
	return result

static func resolve(planner, id: String) -> Dictionary:
	var parsed := fields(id)
	if parsed.is_empty():
		return {}
	var first: Dictionary = planner.settlement(parsed.first)
	var last: Dictionary = planner.settlement(parsed.last)
	if first.is_empty() or last.is_empty():
		return {}
	var edge: Dictionary = planner.edge(first, last)
	var candidates: Array = planner.connections(parsed.first) + planner.connections(parsed.last) + planner.backbone(Planner.macro_at(parsed.first)) + planner.backbone(Planner.macro_at(parsed.last))
	if not candidates.any(func(record): return record.id == edge.id):
		return {}
	var path: Array = planner.path(first, last)
	if path.size() < 2 or path.size() > 1024:
		return {}
	return {"from": first, "to": last, "points": lane(path, parsed.slot, [first, last]), "slot": parsed.slot}

static func length(points: Array) -> float:
	var result := 0.0
	for index in range(1, points.size()):
		result += points[index - 1].distance_to(points[index])
	return result

static func projected_distance(points: Array, point: Vector2) -> float:
	var closest := INF
	var distance := 0.0
	var traveled := 0.0
	for index in range(1,points.size()):
		var from: Vector2 = points[index - 1]
		var to: Vector2 = points[index]
		var projected := Geometry2D.get_closest_point_to_segment(point,from,to)
		var delta := point.distance_squared_to(projected)
		if delta < closest:
			closest = delta
			distance = traveled + from.distance_to(projected)
		traveled += from.distance_to(to)
	return distance

static func at_distance(points: Array, distance: float, reverse: bool) -> Dictionary:
	var total := length(points)
	var remaining := clampf(total - distance if reverse else distance, 0, total)
	for index in range(1, points.size()):
		var segment: float = points[index - 1].distance_to(points[index])
		if remaining <= segment or index == points.size() - 1:
			var fraction := clampf(remaining / maxf(segment, .001), 0, 1)
			return {"point": points[index - 1].lerp(points[index], fraction), "waypoint": index - 1 if reverse else index}
		remaining -= segment
	return {}

static func near_path(point: Vector2, points: Array, margin: float = 1.2) -> bool:
	for index in range(1, points.size()):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index - 1], points[index])) <= margin:
			return true
	return false
