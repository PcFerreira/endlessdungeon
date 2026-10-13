extends Control

var game
var world_map_mode := false
var chart_signature := ""
var chart: Array[Dictionary] = []
var road_cells: Array[Vector2i] = []
var map_bounds := Rect2i()
var map_scale := 1.0
var map_offset := Vector2.ZERO
var refresh := 0.0
var previous_layer := ""

func map_sites() -> Array[Dictionary]:
	if game.online.session:
		var received: Array[Dictionary] = []
		for site in game.world.nearby_sites(game.player_point):
			if game.world.cells.has(Vector2i(site.cell)):
				var entry: Dictionary = site.duplicate()
				entry.knowledge = "downloaded"
				received.append(entry)
		return received
	return game.exploration.known_sites()

func chart_key(center: Vector2i, span: int) -> String:
	var signature := "%s:%s:%s:%s:%s" % [game.world.get_instance_id(), game.run_seed, center.x, center.y, span]
	return signature + ":%s:%s" % [game.online.map_revision, game.world.cells.size()] if game.online.session else signature

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
	if game.layer == "interior":
		var area = game.dungeon
		var scale_factor: float = minf(size.x / area.bounds.size.x, size.y / area.bounds.size.y)
		var offset := (size - Vector2(area.bounds.size) * scale_factor) * .5
		for cell in area.tiles:
			draw_rect(Rect2(Vector2(cell) * scale_factor + offset, Vector2.ONE * (scale_factor - .5)), Color("65717d"))
		for obstacle in area.obstacles:
			draw_rect(Rect2(obstacle.position * scale_factor + offset, obstacle.size * scale_factor), Color("a89774"))
		draw_circle(Vector2(area.exit) * scale_factor + offset, 3.5, Color("ebcf95"))
		draw_circle(game.player_point * scale_factor + offset, 3.0, Color("f5f0dc"))
		return
	if game.layer == "sanctum":
		var scale_factor: float = minf(size.x, size.y) / (game.dungeon.size + 2)
		var offset: Vector2 = (size - Vector2.ONE * game.dungeon.size * scale_factor) * .5
		for cell in game.dungeon.tiles:
			draw_rect(Rect2(Vector2(cell) * scale_factor + offset, Vector2.ONE * (scale_factor - .5)), Color("62647b"))
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
	var span: int = (game.world.CHUNK_SIZE * (game.world.CHUNK_RADIUS * 2 + 1) if game.online.session else game.world.REGION_SIZE * 3) if world_map_mode else 48
	map_bounds = Rect2i(center - Vector2i.ONE * (span / 2), Vector2i.ONE * span)
	map_scale = minf(size.x, size.y) / span
	map_offset = (size - Vector2.ONE * span * map_scale) * .5
	var signature := chart_key(center, span)
	if signature != chart_signature:
		chart_signature = signature
		chart.clear()
		var step: int = maxi(2,ceili(span / 80.0)) if world_map_mode else 1
		for x in range(map_bounds.position.x, map_bounds.end.x, step):
			for y in range(map_bounds.position.y, map_bounds.end.y, step):
				var cell := Vector2i(x, y)
				if game.online.session and not game.world.cells.has(cell):
					continue
				var info: Dictionary = game.world.cell_info(cell)
				var color: Color = game.world.Biomes.color_for(info) if info.has("biome_id") else game.world.MAP_COLORS[info.biome]
				color = color.lightened(info.height * .025)
				if info.terrain == "sky":
					color = Color("18172e")
				elif info.terrain == "water":
					color = Color("466f85")
				elif info.terrain in ["road", "bridge"]:
					color = Color("c4b895")
				elif info.terrain == "paving":
					color = Color("939a8b")
				if not info.walkable and info.terrain != "water":
					color = color.darkened(.2)
				chart.append({"cell": cell, "color": color, "step": step})
		var roads := {}
		for region in game.world.regions.values():
			for cell in region.get("roads", {}):
				if map_bounds.has_point(cell) and (not game.online.session or game.world.cells.has(cell)):
					roads[cell] = true
		road_cells.assign(roads.keys())
	for pixel in chart:
		var location := _map_point(Vector2(pixel.cell))
		draw_rect(Rect2(location, Vector2.ONE * (map_scale * pixel.step + .1)), pixel.color)
	if world_map_mode:
		_draw_atlas_roads()
	for site in map_sites():
		if not map_bounds.has_point(site.cell):
			continue
		var point := _map_point(Vector2(site.cell))
		var color := Color("ecd092") if site.type == "city" else Color("d5afe8")
		var radius := 5.0 if world_map_mode else 3.5
		var reported: bool = site.knowledge == "rumor"
		draw_rect(Rect2(point - Vector2.ONE * (radius + 1.5), Vector2.ONE * (radius + 1.5) * 2), Color("152330"))
		if site.type == "city":
			var marker := Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2)
			if reported:
				draw_rect(marker, color, false, 1.5)
			else:
				draw_rect(marker, color)
		else:
			var vertices := PackedVector2Array([point + Vector2(0, -radius), point + Vector2(radius, 0), point + Vector2(0, radius), point + Vector2(-radius, 0)])
			if reported:
				vertices.append(vertices[0])
				draw_polyline(vertices, color, 1.5)
			else:
				draw_colored_polygon(vertices, color)
		if site.knowledge == "visited":
			draw_circle(point, 1.5, Color("fff5cc"))
		if not game.waypoint.is_empty() and game.waypoint.id == site.id:
			draw_circle(point, radius + 4, Color("7be4d3"), false, 1.5)
		if world_map_mode:
			draw_string(ThemeDB.fallback_font, point + Vector2(8, -7), site.name + (" (reported)" if reported else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5efe0"))
	if not world_map_mode:
		var grounds := {}
		for chunk in game.world.chunks.values():
			for spawn in chunk.spawns:
				if spawn.has("area_id"):
					grounds[spawn.area_id] = spawn
		for area in grounds.values():
			if map_bounds.has_point(Vector2i(area.home)):
				draw_arc(_map_point(area.home), area.radius * map_scale, 0, TAU, 32, Color("c2846277"), 1)
		for actor in game.life.residents():
			if map_bounds.has_point(Vector2i(actor.point.round())):
				var color := Color("8dc6df") if actor.role == "guard" else (Color("efd078") if actor.role == "merchant" else Color("ccd2bd"))
				draw_circle(_map_point(actor.point), 2.3, color)
		for enemy in game.enemies:
			if enemy.node.visible:
				draw_circle(_map_point(enemy.point), 2, Color("e88f94"))
	var player_point := _map_point(game.player_point)
	draw_circle(player_point, 4.0, Color("112330"))
	draw_circle(player_point, 2.7, Color("fff5cc"))

func _draw_atlas_roads() -> void:
	for cell in road_cells:
		draw_rect(Rect2(_map_point(Vector2(cell)), Vector2.ONE * maxf(1, map_scale)), Color("c4b895"))

func _map_point(point: Vector2) -> Vector2:
	return (point - Vector2(map_bounds.position)) * map_scale + map_offset

func _gui_input(event: InputEvent) -> void:
	if not world_map_mode or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for site in map_sites():
		if map_bounds.has_point(site.cell) and _map_point(Vector2(site.cell)).distance_to(event.position) < 12:
			game.waypoint = site
			game.state = "playing"
			game.notify("Route set for %s." % site.name)
			accept_event()
			return
