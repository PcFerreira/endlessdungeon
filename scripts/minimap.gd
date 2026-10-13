extends Control

var game
var world_map_mode := false
var chart_signature := ""
var chart: Array[Dictionary] = []
var map_bounds := Rect2i()
var map_scale := 1.0
var map_offset := Vector2.ZERO
var refresh := 0.0
var previous_layer := ""

func _process(delta: float) -> void:
	if game != null and previous_layer != game.layer:
		previous_layer = game.layer
		refresh = 0.0
	refresh -= delta
	if refresh <= 0:
		refresh = .15
		queue_redraw()

func _draw() -> void:
	if game == null or game.dungeon.tiles.is_empty():
		return
	if game.layer == "overworld":
		_draw_world()
		return
	if game.layer == "sanctum":
		var scale_factor: float = minf(size.x, size.y) / (game.dungeon.size + 2)
		var offset: Vector2 = (size - Vector2.ONE * game.dungeon.size * scale_factor) * .5
		for cell in game.dungeon.tiles:
			draw_rect(Rect2(Vector2(cell) * scale_factor + offset, Vector2.ONE * (scale_factor - .5)), Color("62647b"))
		for plot in game.dungeon.furnishing_plots:
			draw_rect(Rect2(Vector2(plot.position) * scale_factor + offset, Vector2(plot.size) * scale_factor), Color("c2ad76"), false)
		draw_circle(game.dungeon.hearth * scale_factor + offset, 3, Color("c1a2ff"))
		draw_circle(Vector2(game.dungeon.exit) * scale_factor + offset, 3, Color("83e1ce"))
		draw_circle(game.player_point * scale_factor + offset, 3, Color("fff5cc"))
		return
	var scale_factor: float = minf(size.x, size.y) / (game.dungeon.size + 4)
	var offset: Vector2 = Vector2(2, 2) * scale_factor
	for cell in game.dungeon_view.explored:
		var location: Vector2 = Vector2(cell) * scale_factor + offset
		draw_rect(Rect2(location, Vector2.ONE * (scale_factor - .5)), Color("53646b"))
	for enemy in game.enemies:
		if enemy.node.visible:
			draw_circle(enemy.point * scale_factor + offset, 2.0, Color("e18c94"))
			if enemy == game.selected_target:
				draw_circle(enemy.point * scale_factor + offset, 4.0, Color("ebc77d"), false, 1.0)
	if game.dungeon_view.explored.has(game.dungeon.exit):
		var exit_point: Vector2 = Vector2(game.dungeon.exit) * scale_factor + offset
		var color := Color("75ded0") if game.enemies.is_empty() else Color("b89dc8")
		draw_rect(Rect2(exit_point - Vector2.ONE * 3, Vector2.ONE * 6), color, false, 1.5)
	var player_point: Vector2 = game.player_point * scale_factor + offset
	var stairs: Vector2 = Vector2(game.dungeon.start) * scale_factor + offset
	draw_rect(Rect2(stairs - Vector2.ONE * 3, Vector2.ONE * 6), Color("d2c09a"), false, 1)
	draw_circle(player_point, 3.0, Color("f0deb7"))
	draw_circle(player_point, 5.5, Color("f0deb766"), false, 1.0)

func _draw_world() -> void:
	var center := Vector2i(game.player_point.round())
	var span := 160 if world_map_mode else 48
	map_bounds = Rect2i(center - Vector2i.ONE * (span / 2), Vector2i.ONE * span)
	map_scale = minf(size.x, size.y) / span
	map_offset = (size - Vector2.ONE * span * map_scale) * .5
	var signature := "%s:%s:%s:%s" % [game.run_seed, center.x, center.y, span]
	if signature != chart_signature:
		chart_signature = signature
		chart.clear()
		var step := 2 if world_map_mode else 1
		for x in range(map_bounds.position.x, map_bounds.end.x, step):
			for y in range(map_bounds.position.y, map_bounds.end.y, step):
				var cell := Vector2i(x, y)
				var info: Dictionary = game.world.cell_info(cell)
				var color: Color = game.world.MAP_COLORS[info.biome]
				color = color.lightened(info.height * .025)
				if info.terrain == "water":
					color = Color("466f85")
				elif info.terrain in ["road", "bridge"]:
					color = Color("c4b895")
				elif info.terrain == "paving":
					color = Color("939a8b")
				if not info.walkable and info.terrain != "water":
					color = color.darkened(.2)
				chart.append({"cell": cell, "color": color, "step": step})
	for pixel in chart:
		var location := _map_point(Vector2(pixel.cell))
		draw_rect(Rect2(location, Vector2.ONE * (map_scale * pixel.step + .1)), pixel.color)
	for site in game.world.nearby_sites(game.player_point):
		if not map_bounds.has_point(site.cell):
			continue
		var point := _map_point(Vector2(site.cell))
		var color := Color("ecd092") if site.type == "city" else Color("d5afe8")
		var radius := 5.0 if world_map_mode else 3.5
		draw_rect(Rect2(point - Vector2.ONE * (radius + 1.5), Vector2.ONE * (radius + 1.5) * 2), Color("152330"))
		if site.type == "city":
			draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2), color)
		else:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0)]), color)
		if not game.waypoint.is_empty() and game.waypoint.id == site.id:
			draw_circle(point, radius + 4, Color("7be4d3"), false, 1.5)
		if world_map_mode:
			draw_string(ThemeDB.fallback_font, point + Vector2(8, -7), site.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5efe0"))
	if not world_map_mode:
		for enemy in game.enemies:
			if enemy.node.visible:
				draw_circle(_map_point(enemy.point), 2, Color("e88f94"))
	var player_point := _map_point(game.player_point)
	draw_circle(player_point, 4.0, Color("112330"))
	draw_circle(player_point, 2.7, Color("fff5cc"))

func _map_point(point: Vector2) -> Vector2:
	return (point - Vector2(map_bounds.position)) * map_scale + map_offset

func _gui_input(event: InputEvent) -> void:
	if not world_map_mode or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for site in game.world.nearby_sites(game.player_point):
		if map_bounds.has_point(site.cell) and _map_point(Vector2(site.cell)).distance_to(event.position) < 12:
			game.waypoint = site
			game.state = "playing"
			game.notify("Route set for %s." % site.name)
			accept_event()
			return
