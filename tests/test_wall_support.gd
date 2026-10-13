extends SceneTree

const Placement = preload("res://scripts/contextual_placement.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")

class Fixture:
	extends "res://scripts/grid_area.gd"
	var start := Vector2i(3, 3)
	var exit := Vector2i(4, 4)

func _initialize() -> void:
	var area := Fixture.new()
	var room := Rect2i(0, 0, 7, 7)
	for x in range(7):
		for y in range(7):
			area.tiles[Vector2i(x, y)] = true
	area.tiles[Vector2i(3, -1)] = true
	var slots := Placement.wall_slots(area, room, Vector2(1.4, .55))
	assert(not slots.is_empty())
	var overlaps := 0
	for slot in slots:
		var box := Rect2(slot.point - slot.footprint * .5, slot.footprint)
		for cell in area.tiles:
			for direction in area.DIRECTIONS:
				if area.tiles.has(cell + direction):
					continue
				var wall: AABB = Voxels.wall(true, direction.y != 0, 0).get_aabb()
				wall.position += Vector3(cell.x + direction.x * .51, 0, cell.y + direction.y * .51)
				var projection := Rect2(Vector2(wall.position.x, wall.position.z), Vector2(wall.size.x, wall.size.z))
				if box.intersects(projection):
					overlaps += 1
	if overlaps > 0:
		print("FAIL: wall-mounted footprints intersect %s actual wall mesh projections" % overlaps)
	else:
		print("PASS: wide wall fixtures clear actual wall mesh caps, corners and corridor openings")
	quit(0 if overlaps == 0 else 1)
