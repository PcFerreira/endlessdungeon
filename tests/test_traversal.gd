extends SceneTree

class Ledge:
	extends "res://scripts/grid_area.gd"
	func ground_height(point: Vector2) -> float:
		return 1.0 if point.x >= 1.5 else 0.0

class Hill:
	extends "res://scripts/grid_area.gd"
	func ground_height(point: Vector2) -> float:
		return 3.0 if point.x > 1.5 and point.x < 2.5 else 0.0

func _init() -> void:
	var ledge := Ledge.new()
	for x in range(5):
		for y in range(3):
			ledge.tiles[Vector2i(x, y)] = true
	var start := Vector2(1, 1)
	assert(ledge.move_actor(start, Vector2.RIGHT).x < 1.5, "A full ledge must block grounded walking")
	assert(ledge.move_actor(start, Vector2.RIGHT, .4, true).x < 1.5, "Jumping must reach the ledge's height before crossing")
	assert(ledge.move_actor(start, Vector2.RIGHT, 1.1, true).x > 1.5, "A high enough jump must clear a ledge")
	var falling := Vector2(1.45, 1)
	assert(ledge.move_actor(falling, Vector2(-.3, 0), .4, true).x < 1.25, "Descending off a ledge must allow moving away from the overlapping edge")
	assert(not ledge.can_step(start, Vector2(2, 1)), "Ground enemies must not path through ledges")
	ledge.tiles.erase(Vector2i(2, 1))
	assert(ledge.move_actor(start, Vector2.RIGHT, 5, true).x < 1.5, "A jump must not pass through solid obstacles")
	var hill := Hill.new()
	hill.tiles = ledge.tiles.duplicate()
	hill.tiles[Vector2i(2, 1)] = true
	assert(not hill.line_clear(Vector2(0, 1), Vector2(4, 1)), "Tall terrain must block line of sight")
	print("PASS: ledge collision, airborne clearance, grounded navigation, solid obstacles, terrain occlusion")
	quit()
