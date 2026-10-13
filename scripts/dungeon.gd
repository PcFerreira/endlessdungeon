extends "res://scripts/grid_area.gd"
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Placement = preload("res://scripts/contextual_placement.gd")
const Dressing = preload("res://scripts/dungeon_dressing.gd")
var family := "dungeon_ashen_crypt"
var biome := 0
var room_roles: Array[String] = []
var readables: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var torch_mounts: Array[Dictionary] = []
var rooms: Array[Rect2i] = []
var spawns: Array[Dictionary] = []
var start := Vector2i.ZERO
var exit := Vector2i.ZERO
var size := 38
var rng := RandomNumberGenerator.new()

func generate(run_seed: int, depth: int, family_id: String = "dungeon_ashen_crypt", owning_biome: int = 0) -> void:
	assert(owning_biome in range(4), "Dungeon climate must come from its actual entrance")
	biome = owning_biome
	family = family_id if Areas.DUNGEONS.has(family_id) else "dungeon_ashen_crypt"
	rng.seed = hash("%s:%s:%s" % [run_seed, depth, family])
	tiles.clear()
	rooms.clear()
	spawns.clear()
	obstacles.clear()
	room_roles.clear()
	readables.clear()
	decorations.clear()
	torch_mounts.clear()
	size = 38 + mini(depth / 3, 10)
	bounds = Rect2i(0, 0, size + 2, size + 2)
	_add_room(Rect2i(3, 3, 7, 7))
	var count := 5 + mini(depth / 3, 3)
	var layouts := {
		"dungeon_ashen_crypt": [Vector2i(3,3), Vector2i(16,3), Vector2i(3,16), Vector2i(16,16), Vector2i(3,29), Vector2i(16,29), Vector2i(29,3), Vector2i(29,16)],
		"dungeon_violet_sanctum": [Vector2i(3,3), Vector2i(16,16), Vector2i(16,3), Vector2i(3,16), Vector2i(29,16), Vector2i(16,29), Vector2i(29,3), Vector2i(3,29)],
		"dungeon_verdant_tomb": [Vector2i(3,3), Vector2i(16,3), Vector2i(29,3), Vector2i(29,16), Vector2i(29,29), Vector2i(16,29), Vector2i(3,29), Vector2i(3,16)],
		"dungeon_quarry_depths": [Vector2i(3,3), Vector2i(16,3), Vector2i(29,3), Vector2i(3,16), Vector2i(16,16), Vector2i(29,16), Vector2i(3,29), Vector2i(29,29)],
		"dungeon_fungal_cistern": [Vector2i(3,3), Vector2i(3,16), Vector2i(3,29), Vector2i(16,29), Vector2i(29,29), Vector2i(29,16), Vector2i(29,3), Vector2i(16,3)],
		"dungeon_unclosed_office": [Vector2i(3,3), Vector2i(3,16), Vector2i(3,29), Vector2i(16,3), Vector2i(16,16), Vector2i(16,29), Vector2i(29,16), Vector2i(29,29)]
	}
	for index in range(1, count):
		var width := rng.randi_range(5, 8)
		var height := rng.randi_range(5, 8)
		if family == "dungeon_unclosed_office":
			width = 5
			height = 8
		elif family == "dungeon_fungal_cistern":
			width = 8
			height = 8
		elif family == "dungeon_quarry_depths":
			height = 5
		_add_room(Rect2i(layouts[family][index], Vector2i(width, height)))
		var link := index - 1
		if family == "dungeon_violet_sanctum":
			link = 0 if index == 1 else 1
		elif family == "dungeon_quarry_depths" and index >= 3:
			link = index - 3 if index < 6 else (3 if index == 6 else 5)
		elif family == "dungeon_unclosed_office" and index >= 3:
			link = index - 3
		elif family == "dungeon_ashen_crypt" and index >= 2:
			link = index - 2
		_connect(rooms[index].get_center(), rooms[link].get_center())
	if family in ["dungeon_verdant_tomb", "dungeon_fungal_cistern"]:
		_connect(rooms[-1].get_center(), rooms[0].get_center())
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
	var profile: Dictionary = Areas.DUNGEONS[family]
	var book_cell := rooms[0].position + Vector2i(1,4)
	readables.append({"kind": "book", "book_id": profile.book, "point": Vector2(book_cell), "approach": Vector2(book_cell + Vector2i.LEFT)})
	obstacles.append(Rect2(Vector2(book_cell) - Vector2.ONE * .35, Vector2.ONE * .7))
	for index in range(rooms.size()):
		room_roles.append(profile.roles[index % profile.roles.size()])
	Dressing.new().decorate(self, run_seed, depth)
	for room in rooms:
		var mounts := Placement.wall_slots(self, room, Vector2(.22, .18))
		for index in range(2):
			if mounts.is_empty():
				break
			var mount: Dictionary = mounts[0] if index == 0 else mounts[-1]
			torch_mounts.append(mount)
			mounts = mounts.filter(func(candidate): return candidate.point.distance_to(mount.point) > 2)
	var occupied := {start: true, exit: true, book_cell: true}
	for room in rooms.slice(1):
		for index in range(2 + mini(depth / 5, 1)):
			for attempt in range(30):
				var cell := Vector2i(rng.randi_range(room.position.x + 1, room.end.x - 2), rng.randi_range(room.position.y + 1, room.end.y - 2))
				if occupied.has(cell) or not walkable(Vector2(cell)) or Vector2(cell).distance_to(start) <= 5.0:
					continue
				occupied[cell] = true
				var pool: Array = Enemies.dungeon_pool(family)
				spawns.append({"cell": cell, "kind": pool[posmod(index + rooms.find(room) + depth, pool.size())]})
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

