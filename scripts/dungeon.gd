extends "res://scripts/grid_area.gd"
var rooms: Array[Rect2i] = []
var spawns: Array[Dictionary] = []
var start := Vector2i.ZERO
var exit := Vector2i.ZERO
var size := 38
var rng := RandomNumberGenerator.new()

func generate(run_seed: int, depth: int) -> void:
	rng.seed = hash("%s:%s" % [run_seed, depth])
	tiles.clear()
	rooms.clear()
	spawns.clear()
	size = 38 + mini(depth / 3, 10)
	bounds = Rect2i(0, 0, size + 2, size + 2)
	_add_room(Rect2i(3, 3, 7, 7))
	var count := 5 + mini(depth / 3, 3)
	for attempt in range(240):
		if rooms.size() >= count:
			break
		var width := rng.randi_range(5, 8)
		var height := rng.randi_range(5, 8)
		var room := Rect2i(rng.randi_range(3, size - width - 3), rng.randi_range(3, size - height - 3), width, height)
		var overlaps := false
		for existing in rooms:
			if existing.grow(2).intersects(room):
				overlaps = true
				break
		if overlaps:
			continue
		var center := room.get_center()
		var nearest := rooms[0].get_center()
		for existing in rooms:
			if Vector2(center).distance_squared_to(existing.get_center()) < Vector2(center).distance_squared_to(nearest):
				nearest = existing.get_center()
		_add_room(room)
		_connect(center, nearest)
	start = rooms[0].get_center()
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for step in DIRECTIONS:
			var neighbor: Vector2i = cell + step
			if tiles.has(neighbor) and not distances.has(neighbor):
				distances[neighbor] = distances[cell] + 1
				queue.append(neighbor)
	exit = rooms[1].get_center()
	for room in rooms.slice(1):
		if distances[room.get_center()] > distances[exit]:
			exit = room.get_center()
	var occupied := {start: true, exit: true}
	for room in rooms.slice(1):
		for index in range(2 + mini(depth / 5, 1)):
			for attempt in range(30):
				var cell := Vector2i(rng.randi_range(room.position.x + 1, room.end.x - 2), rng.randi_range(room.position.y + 1, room.end.y - 2))
				if occupied.has(cell) or Vector2(cell).distance_to(start) <= 5.0:
					continue
				occupied[cell] = true
				spawns.append({"cell": cell, "kind": (index + rooms.find(room) + depth) % 3})
				break

func _add_room(room: Rect2i) -> void:
	rooms.append(room)
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			tiles[Vector2i(x, y)] = true

func _connect(from: Vector2i, to: Vector2i) -> void:
	var cell := from
	var horizontal_first := rng.randf() > 0.5
	while cell != to:
		tiles[cell] = true
		tiles[cell + Vector2i.RIGHT] = true
		if (horizontal_first and cell.x != to.x) or cell.y == to.y:
			cell.x += signi(to.x - cell.x)
		else:
			cell.y += signi(to.y - cell.y)
	tiles[to] = true

