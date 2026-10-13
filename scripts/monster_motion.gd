extends RefCounted

const SPACE := 1.25
const MIN_GAP := .8
const BUCKET_SIZE := 2.0

static func bucket(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / BUCKET_SIZE), floori(point.y / BUCKET_SIZE))

static func identity(enemy: Dictionary) -> String:
	return enemy.id if not enemy.id.is_empty() else str(enemy.node.get_instance_id())

static func snapshot(enemies: Array) -> Dictionary:
	var result := {}
	for enemy in enemies:
		var cell := bucket(enemy.point)
		if not result.has(cell):
			result[cell] = []
		result[cell].append({"id": identity(enemy), "point": enemy.point, "radius": enemy.get("spacing_radius", MIN_GAP / 2)})
	return result

static func neighbors(enemy: Dictionary, crowd: Dictionary) -> Array:
	var result := []
	var center := bucket(enemy.point)
	var id := identity(enemy)
	for x in range(-1, 2):
		for y in range(-1, 2):
			for other in crowd.get(center + Vector2i(x,y), []):
				if other.id != id:
					result.append(other)
	return result

static func separation(enemy: Dictionary, nearby: Array) -> Vector2:
	var force := Vector2.ZERO
	var id := identity(enemy)
	for other in nearby:
		var offset: Vector2 = enemy.point - other.point
		var distance := offset.length()
		var space := maxf(SPACE, enemy.get("spacing_radius", MIN_GAP / 2) + other.radius + .3)
		if distance >= space:
			continue
		if distance < .001:
			var pair: String = id + ":" + other.id if id < other.id else other.id + ":" + id
			offset = Vector2.from_angle(posmod(hash(pair), 6283) * .001) * (1 if id < other.id else -1)
		force += offset.normalized() * (1 - distance / space) * 3
	return force.limit_length(3)

static func keeps_gap(from: Vector2, to: Vector2, nearby: Array, radius: float) -> bool:
	for other in nearby:
		var distance := to.distance_squared_to(other.point)
		var gap: float = radius + other.radius
		if distance < gap * gap and distance + .000001 < from.distance_squared_to(other.point):
			return false
	return true

static func move(area, enemy: Dictionary, velocity: Vector2, speed: float, delta: float, crowd: Dictionary) -> Vector2:
	var nearby := neighbors(enemy, crowd)
	var push := separation(enemy, nearby) * speed
	var movement := (velocity + push).limit_length(speed) * delta
	var next: Vector2 = area.move_actor(enemy.point, movement)
	var radius: float = enemy.get("spacing_radius", MIN_GAP / 2)
	if keeps_gap(enemy.point, next, nearby, radius):
		return next
	next = area.move_actor(enemy.point, push.limit_length(speed) * delta)
	return next if keeps_gap(enemy.point, next, nearby, radius) else enemy.point
