extends Control

var game
var world_map_mode := false
var chart_signature := ""
var chart: Array[Dictionary] = []
var chart_colors := {}
var chart_context := ""
var chart_texture: ImageTexture
var chart_image: Image
var road_cells: Array[Vector2i] = []
var road_paths: Array[Dictionary] = []
var label_boxes: Array[Rect2] = []
var map_bounds := Rect2i()
var map_scale := 1.0
var map_offset := Vector2.ZERO
var refresh := 0.0
var previous_layer := ""
var hovered_site_id := ""
var hover_context := ""

func _ready() -> void:
	mouse_exited.connect(_clear_hover)

func _clear_hover() -> void:
	_set_hover("")

func _set_hover(id: String) -> void:
	if hovered_site_id == id:
		return
	hovered_site_id = id
	queue_redraw()

func _sync_hover_context() -> void:
	var context := "%s:%s:%s:%s:%s" % [game.world.get_instance_id(), game.run_seed, game.world.get("generator_version"), world_map_mode, game.online.session]
	if hover_context != context:
		hover_context = context
		_clear_hover()

func destination_label_visible(site: Dictionary) -> bool:
	return not finite_world() or site.id == hovered_site_id or site.id == game.waypoint.get("id", "")

func finite_world() -> bool:
	return game != null and not game.online.session and game.world.has_method("dimension_record") and game.world.has_method("area_at")

func chart_bounds(center: Vector2i, span: int) -> Rect2i:
	var bounds := Rect2i(center - Vector2i.ONE * (span / 2), Vector2i.ONE * span)
	if finite_world():
		return game.world.map_extent if world_map_mode else bounds.intersection(game.world.map_extent)
	return bounds

func realm_title() -> String:
	if not finite_world():
		return ""
	return game.world.definition.get("name", game.world.dimension_id.capitalize())

func current_area() -> Dictionary:
	return game.world.area_at(Vector2i(game.player_point.round())) if finite_world() else {}

func area_labels() -> Array[Dictionary]:
	var labels: Array[Dictionary] = []
	if finite_world() and game.world.has_method("authored_areas"):
		labels.assign(game.world.authored_areas())
	return labels

func map_sites() -> Array[Dictionary]:
	if game.online.session:
		var received: Array[Dictionary] = []
		for site in game.world.nearby_sites(game.player_point):
			if game.world.cells.has(Vector2i(site.cell)):
				var entry: Dictionary = site.duplicate()
				entry.knowledge = "downloaded"
				received.append(entry)
		return received
	if finite_world() and game.world.has_method("authored_sites"):
		return game.exploration.knowledge.visible_sites(game.world.authored_sites())
	return game.exploration.known_sites()

func chart_key(center: Vector2i, span: int) -> String:
	if finite_world() and world_map_mode:
		center = game.world.map_extent.position
		span = maxi(game.world.map_extent.size.x, game.world.map_extent.size.y)
	var signature := "%s:%s:%s:%s:%s:%s:%s:%s" % [game.world.get_instance_id(), game.run_seed, game.world.get("generator_version"), center.x, center.y, span, world_map_mode, map_bounds]
	return signature + ":%s:%s" % [game.online.map_revision, game.world.cells.size()] if game.online.session else signature

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
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

func prepare_chart(center: Vector2i, span: int) -> void:
	_sync_hover_context()
	map_bounds = chart_bounds(center, span)
	if not map_bounds.has_area():
		chart_signature = ""
		chart.clear()
		chart_colors.clear()
		chart_texture = null
		chart_image = null
		road_cells.clear()
		road_paths.clear()
		return
	map_scale = minf(size.x / map_bounds.size.x, size.y / map_bounds.size.y)
	map_offset = (size - Vector2(map_bounds.size) * map_scale) * .5
	var signature := chart_key(center, span)
	if signature != chart_signature:
		chart_signature = signature
		chart.clear()
		var context := "%s:%s:%s:%s:%s" % [game.world.get_instance_id(), game.run_seed, game.world.get("generator_version"), world_map_mode, game.online.session]
		if game.online.session:
			context += ":%s:%s" % [game.online.map_revision, game.world.cells.size()]
		if context != chart_context:
			chart_context = context
			chart_colors.clear()
		var retained_colors := {}
		var width := maxi(map_bounds.size.x, map_bounds.size.y)
		var step: int = maxi(2,ceili(width / 80.0)) if world_map_mode else 1
		var raster := Image.create(ceili(float(map_bounds.size.x) / step), ceili(float(map_bounds.size.y) / step), false, Image.FORMAT_RGBA8)
		for x in range(map_bounds.position.x, map_bounds.end.x, step):
			for y in range(map_bounds.position.y, map_bounds.end.y, step):
				var cell := Vector2i(x, y)
				if game.online.session and not game.world.cells.has(cell):
					continue
				if not chart_colors.has(cell):
					chart_colors[cell] = _terrain_color(game.world.cell_info(cell))
				var color: Color = chart_colors[cell]
				retained_colors[cell] = color
				chart.append({"cell": cell, "color": color, "step": step})
				raster.set_pixel((x - map_bounds.position.x) / step, (y - map_bounds.position.y) / step, color)
		chart_colors = retained_colors
		chart_image = raster
		if chart_texture != null and chart_texture.get_width() == raster.get_width() and chart_texture.get_height() == raster.get_height():
			chart_texture.update(raster)
		else:
			chart_texture = ImageTexture.create_from_image(raster)
		var roads := {}
		if world_map_mode:
			for region in game.world.regions.values():
				for cell in region.get("roads", {}):
					if map_bounds.has_point(cell) and (not game.online.session or game.world.cells.has(cell)):
						roads[cell] = true
		road_cells.assign(roads.keys())
		road_paths.clear()
		if finite_world() and world_map_mode:
			for route in game.world.definition.get("routes", []):
				var points := PackedVector2Array()
				for point in route.path:
					points.append(Vector2(point[0], point[1]))
				road_paths.append({"points": points, "width": route.width})

func _terrain_color(info: Dictionary) -> Color:
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
	return color.darkened(.2) if not info.walkable and info.terrain != "water" else color

func _draw_world() -> void:
	var center := Vector2i(game.player_point.round())
	var span: int = (game.world.CHUNK_SIZE * (game.world.CHUNK_RADIUS * 2 + 1) if game.online.session else game.world.REGION_SIZE * 3) if world_map_mode else 48
	prepare_chart(center, span)
	if not map_bounds.has_area():
		return
	if chart_texture != null:
		var step: int = chart[0].step if not chart.is_empty() else 1
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect_region(chart_texture, Rect2(map_offset, Vector2(map_bounds.size) * map_scale), Rect2(Vector2.ZERO, Vector2(map_bounds.size) / step), Color.WHITE, false, true)
	if world_map_mode:
		label_boxes.clear()
		_draw_atlas_roads()
		if finite_world():
			label_boxes.assign(marker_rects())
		else:
			_draw_area_labels()
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
		if world_map_mode and destination_label_visible(site):
			_draw_site_label(point, site.name + (" (reported)" if reported else ""))
	if world_map_mode and finite_world():
		_draw_area_labels()
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
	for path in road_paths:
		var points := PackedVector2Array()
		for point in path.points:
			points.append(_map_point(point))
		draw_polyline(points, Color("c4b895"), maxf(1, path.width * map_scale))
	for cell in road_cells:
		draw_rect(Rect2(_map_point(Vector2(cell)), Vector2.ONE * maxf(1, map_scale)), Color("c4b895"))

func _draw_area_labels() -> void:
	for area in area_labels():
		var cell := Vector2i(area.label_cell)
		if not map_bounds.has_point(cell):
			continue
		var label: String = area.name
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var bounds := area_label_rect(_map_point(Vector2(cell)), width)
		var point := bounds.position + Vector2(5, 14)
		label_boxes.append(bounds)
		draw_rect(bounds, Color("152330dd"))
		draw_line(point + Vector2(-3, 4), point + Vector2(width + 3, 4), area.get("map_color", Color("ecd092")), 2)
		draw_string(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f5efe0"))

func marker_rects() -> Array[Rect2]:
	var markers: Array[Rect2] = []
	for site in map_sites():
		if map_bounds.has_point(site.cell):
			var radius := 10.5 if not game.waypoint.is_empty() and game.waypoint.id == site.id else 6.5
			markers.append(Rect2(_map_point(Vector2(site.cell)) - Vector2.ONE * radius, Vector2.ONE * radius * 2))
	markers.append(Rect2(_map_point(game.player_point) - Vector2(5, 5), Vector2(10, 10)))
	return markers

func label_fits(bounds: Rect2) -> bool:
	var chart_bounds := Rect2(map_offset, Vector2(map_bounds.size) * map_scale) if finite_world() else Rect2(Vector2.ZERO, size)
	return chart_bounds.encloses(bounds) and not label_boxes.any(func(previous): return previous.grow(2).intersects(bounds))

func area_label_rect(point: Vector2, width: float) -> Rect2:
	var origin := point - Vector2(width * .5 + 5, 36)
	var extent := Vector2(width + 10, 20)
	var bounds := Rect2(origin, extent)
	if label_fits(bounds):
		return bounds
	for distance in range(12, 241, 12):
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			bounds = Rect2(origin + direction * distance, extent)
			if label_fits(bounds):
				return bounds
	var chart_bounds := Rect2(map_offset, Vector2(map_bounds.size) * map_scale)
	for y in range(0, int(chart_bounds.size.y - extent.y) + 1, 6):
		for x in range(0, int(chart_bounds.size.x - extent.x) + 1, 6):
			bounds = Rect2(chart_bounds.position + Vector2(x, y), extent)
			if label_fits(bounds):
				return bounds
	return Rect2(origin, extent)

func site_label_rect(point: Vector2, width: float) -> Rect2:
	var offsets: Array[Vector2] = [Vector2(8, -7), Vector2(8, 14), Vector2(-width - 8, -7), Vector2(-width - 8, 14)]
	for distance in range(30, 151, 20):
		offsets.append_array([Vector2(8, distance), Vector2(-width - 8, distance), Vector2(8, -distance), Vector2(-width - 8, -distance)])
	for offset in offsets:
		var bounds := Rect2(point + offset - Vector2(3, 13), Vector2(width + 6, 18))
		if label_fits(bounds):
			return bounds
	return Rect2(point + Vector2(5, -20), Vector2(width + 6, 18))

func _draw_site_label(point: Vector2, label: String) -> void:
	var font := ThemeDB.fallback_font
	if not finite_world():
		draw_string(font, point + Vector2(8, -7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5efe0"))
		return
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var bounds := site_label_rect(point, width)
	var nearest := point.clamp(bounds.position, bounds.end)
	if point.distance_to(nearest) > 14:
		draw_line(point + point.direction_to(nearest) * 7, nearest, Color("ecd092aa"), 1)
	draw_rect(bounds, Color("152330dd"))
	draw_string(font, bounds.position + Vector2(3, 13), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5efe0"))
	label_boxes.append(bounds)

func _map_point(point: Vector2) -> Vector2:
	return (point - Vector2(map_bounds.position)) * map_scale + map_offset

func _gui_input(event: InputEvent) -> void:
	if not world_map_mode:
		return
	if event is InputEventMouseMotion:
		if finite_world():
			_sync_hover_context()
			var id := ""
			for site in map_sites():
				if map_bounds.has_point(site.cell) and _map_point(Vector2(site.cell)).distance_to(event.position) < 12:
					id = site.id
					break
			_set_hover(id)
		return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for site in map_sites():
		if map_bounds.has_point(site.cell) and _map_point(Vector2(site.cell)).distance_to(event.position) < 12:
			game.waypoint = site
			game.state = "playing"
			game.notify("Route set for %s." % site.name)
			accept_event()
			return
