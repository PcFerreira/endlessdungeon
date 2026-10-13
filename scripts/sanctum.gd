extends "res://scripts/grid_area.gd"

const SIZE := 21
var size := SIZE
var start := Vector2i(10, 15)
var exit := Vector2i(10, 17)
var hearth := Vector2(10, 6)
var furnishing_plots := [Rect2i(3, 9, 4, 4), Rect2i(14, 9, 4, 4)]

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
