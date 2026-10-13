extends "res://scripts/grid_area.gd"

const SIZE := 21
var size := SIZE
var start := Vector2i(10, 15)
var exit := Vector2i(10, 17)
var hearth := Vector2(10, 6)
var placements: Array[Dictionary] = []
var furnishing_walls := [
	{"point": Vector2(4.5, 8.5), "normal": Vector2.UP, "length": 4.0},
	{"point": Vector2(2.5, 10.5), "normal": Vector2.LEFT, "length": 4.0},
	{"point": Vector2(15.5, 8.5), "normal": Vector2.UP, "length": 4.0},
	{"point": Vector2(17.5, 10.5), "normal": Vector2.RIGHT, "length": 4.0}
]

func _init() -> void:
	bounds = Rect2i(0, 0, SIZE, SIZE)
	for x in range(SIZE):
		for y in range(SIZE):
			if Vector2(x - 10, (y - 10) * .9).length() <= 9.5:
				tiles[Vector2i(x, y)] = true
	obstacles = [Rect2(9.4, 5.4, 1.2, 1.2), Rect2(4.2, 5.4, 1.6, .8)]
	for cell in [Vector2(7, 3), Vector2(13, 3), Vector2(7, 7), Vector2(13, 7)]:
		obstacles.append(Rect2(cell - Vector2.ONE * .25, Vector2.ONE * .5))
	for cell in [Vector2(3, 5), Vector2(17, 5), Vector2(3, 16), Vector2(17, 16)]:
		obstacles.append(Rect2(cell - Vector2.ONE * .3, Vector2.ONE * .6))
	for wall in furnishing_walls:
		var extent := Vector2(wall.length, .12) if wall.normal.y != 0 else Vector2(.12, wall.length)
		obstacles.append(Rect2(wall.point - extent * .5, extent))
