extends RefCounted

const DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var tiles: Dictionary = {}
var bounds := Rect2i()
var obstacles: Array[Rect2] = []

func walkable(point: Vector2, radius: float = .20) -> bool:
	for obstacle in obstacles:
		if obstacle.grow(radius).has_point(point):
			return false
	for offset in [Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(-radius, radius), Vector2(radius, radius)]:
		if not tiles.has(Vector2i((point + offset).round())):
			return false
	return true

func ground_height(_point: Vector2) -> float:
	return 0.0

func can_step(from: Vector2, to: Vector2) -> bool:
	return walkable(to) and absf(ground_height(to) - ground_height(from)) <= .51

func clearance_height(point: Vector2) -> float:
	var height := ground_height(point)
	for offset in [Vector2(-.20, -.20), Vector2(.20, -.20), Vector2(-.20, .20), Vector2(.20, .20)]:
		height = maxf(height, ground_height(point + offset))
	return height

func move_actor(from: Vector2, displacement: Vector2, altitude: float = NAN, airborne: bool = false) -> Vector2:
	var result := from
	var steps := maxi(1, ceili(displacement.length() / .15))
	var step := displacement / steps
	for index in range(steps):
		for axis in [Vector2(step.x, 0), Vector2(0, step.y)]:
			var candidate: Vector2 = result + axis
			var support := ground_height(result) if is_nan(altitude) else maxf(altitude, ground_height(result))
			var ceiling := altitude + .05 if airborne else support + .51
			var clearance := clearance_height(candidate)
			var retreat := clearance <= clearance_height(result) and ground_height(candidate) <= ground_height(result)
			if walkable(candidate) and (clearance <= ceiling or retreat):
				result = candidate
	return result

func safe_position(point: Vector2, search_radius: int = 12) -> Vector2:
	if walkable(point) and clearance_height(point) <= ground_height(point) + .51:
		return point
	var center := Vector2i(point.round())
	var closest := point
	var distance := INF
	for x in range(center.x - search_radius, center.x + search_radius + 1):
		for y in range(center.y - search_radius, center.y + search_radius + 1):
			var candidate := Vector2(x, y)
			if not walkable(candidate) or clearance_height(candidate) > ground_height(candidate) + .51:
				continue
			var neighbor := false
			for direction in DIRECTIONS:
				if walkable(candidate + Vector2(direction)):
					neighbor = true
			var delta := candidate.distance_squared_to(point)
			if neighbor and delta < distance:
				closest = candidate
				distance = delta
	return closest

func line_clear(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / .2))
	var start_y := ground_height(from) + .8
	var end_y := ground_height(to) + .8
	for index in range(steps + 1):
		var fraction := float(index) / steps
		var point := from.lerp(to, fraction)
		if not tiles.has(Vector2i(point.round())) or ground_height(point) > lerpf(start_y, end_y, fraction):
			return false
	return true
