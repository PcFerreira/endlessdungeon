extends Control

var game

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game.state != "playing":
		return
	var point := get_local_mouse_position()
	if game.enemy_at_screen(get_viewport().get_mouse_position()).is_empty():
		return
	var color := Color("ebc77d")
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(point + direction * 6, point + direction * 10, Color("101a26"), 4.0)
		draw_line(point + direction * 6, point + direction * 10, color, 1.5)
	draw_circle(point, 1.5, color)
