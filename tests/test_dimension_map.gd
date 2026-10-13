extends SceneTree

const Minimap = preload("res://scripts/minimap.gd")
const Knowledge = preload("res://scripts/site_knowledge.gd")
const FiniteWorld = preload("res://scripts/finite_world.gd")

class FiniteProvider extends RefCounted:
	const MAP_COLORS = [Color("617e62")]
	var dimension_id := "test_realm"
	var definition := {"name": "Test Realm", "routes": [{"path": [[40,40], [400,40], [400,400]], "width": 5}]}
	var map_extent := Rect2i(0, 0, 512, 512)
	var regions := {}
	var calls: Array[Vector2i] = []
	func area_at(_cell: Vector2i) -> Dictionary:
		return {"name": "Authored area"}
	func dimension_record() -> Dictionary:
		return definition.duplicate(true)
	func authored_sites() -> Array[Dictionary]:
		return [{"id": "test_realm:known", "name": "Known temple", "type": "temple", "cell": Vector2i(400, 400)}, {"id": "test_realm:unknown", "name": "Unknown temple", "type": "temple", "cell": Vector2i(100, 100)}]
	func authored_areas() -> Array[Dictionary]:
		return [{"name": "Authored area", "label_cell": Vector2i(240, 260)}]
	func cell_info(cell: Vector2i) -> Dictionary:
		assert(map_extent.has_point(cell), "Finite chart must never request procedural fallback beyond its edge")
		calls.append(cell)
		return {"terrain": "grass", "biome": 0, "height": 0, "walkable": true}

class EndlessProvider extends RefCounted:
	var regions := {}

class Exploration extends RefCounted:
	var knowledge = Knowledge.new()
	func known_sites() -> Array[Dictionary]:
		return []

class Session extends RefCounted:
	var online := {"session": false}
	var run_seed := 17
	var world = FiniteProvider.new()
	var exploration := Exploration.new()
	var waypoint := {}
	var player_point := Vector2(960, 1040)
	var state := "map"
	func notify(_message: String) -> void:
		pass

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var session := Session.new()
	var map := Minimap.new()
	map.game = session
	map.size = Vector2(700, 440)
	map.world_map_mode = true
	root.add_child(map)
	map.set_process(false)
	map.hide()
	map.prepare_chart(Vector2i(240, 260), 192)
	assert(session.exploration.knowledge.remember(session.world.authored_sites()[0], "seen", "17"))
	var knowledge_before: Dictionary = session.exploration.knowledge.snapshot()
	assert(map.map_sites().size() == 1 and map.map_sites()[0].id == "test_realm:known", "A full realm atlas keeps distant observed sites and hides unobserved authored destinations")
	assert(session.exploration.knowledge.snapshot() == knowledge_before, "Charting authored terrain cannot upgrade discovery state")
	assert(map.realm_title() == "Test Realm" and map.area_labels().size() == 1)
	assert(map.road_paths.size() == 1 and map.road_paths[0].points.size() == 3, "Thin authored routes must remain visible in the complete topology independent of sampled terrain and loaded chunks")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = map._map_point(Vector2(100, 100))
	map._gui_input(click)
	assert(session.waypoint.is_empty() and session.state == "map", "Authored geography cannot make an unknown destination clickable")
	click.position = map._map_point(Vector2(400, 400))
	map._gui_input(click)
	assert(session.waypoint.id == "test_realm:known" and session.state == "playing")
	assert(map.map_bounds == session.world.map_extent)
	assert(map.chart.size() <= 80 * 80, "The atlas must sample the finite topology without loading the entire world")
	assert(map._map_point(Vector2.ZERO) == Vector2(130, 0))
	assert(map._map_point(Vector2(512, 512)) == Vector2(570, 440))
	var sampled: int = session.world.calls.size()
	map.prepare_chart(Vector2i(400, 20), 192)
	assert(session.world.calls.size() == sampled, "Moving inside a fixed atlas must not regenerate its chart")
	map.world_map_mode = false
	map.prepare_chart(Vector2i.ZERO, 48)
	assert(map.map_bounds == Rect2i(0, 0, 24, 24))
	map.prepare_chart(Vector2i(511, 511), 48)
	assert(map.map_bounds.end == Vector2i(512, 512))
	map.prepare_chart(Vector2i(-50, -50), 48)
	assert(map.chart.is_empty() and map.road_cells.is_empty())
	map.prepare_chart(Vector2i(511, 511), 48)
	assert(not map.chart.is_empty(), "Returning from an unsupported outside viewport must rebuild the prior chart")
	session.world.map_extent = Rect2i(0, 0, 2048, 2048)
	map.world_map_mode = true
	map.prepare_chart(Vector2i(960, 1040), 192)
	assert(map.map_bounds == session.world.map_extent and map.chart.size() <= 80 * 80, "Larger realm dimensions must come from metadata without multiplying atlas work")
	assert(map._map_point(Vector2(2048, 2048)) == Vector2(570, 440))
	session.world = EndlessProvider.new()
	map.world_map_mode = true
	assert(map.chart_bounds(Vector2i(-200, 45), 192) == Rect2i(-296, -51, 192, 192))
	session.world = FiniteProvider.new()
	session.online.session = true
	assert(not map.finite_world(), "Online downloaded-map handling must remain separate")
	assert(map.chart_bounds(Vector2i(240, 260), 80) == Rect2i(200, 220, 80, 80))
	session.online.session = false
	session.world = FiniteWorld.new()
	session.world.generate(17, 6)
	session.world.load_around(session.world.spawn_point())
	var chunk_count: int = session.world.chunks.size()
	map.world_map_mode = true
	map.prepare_chart(Vector2i(session.world.spawn_point()), session.world.REGION_SIZE * 3)
	assert(map.map_bounds == session.world.map_extent and map.chart.size() <= 80 * 80)
	assert(map.area_labels().size() == session.world.definition.areas.size() and map.realm_title() == session.world.definition.name)
	assert(session.world.chunks.size() == chunk_count and not map.road_paths.is_empty(), "A full real realm chart cannot expand streamed scene geometry")
	assert(map.map_sites().is_empty(), "Viewing all authored topology cannot discover the real realm's unknown sites")
	var site: Dictionary = session.world.authored_sites()[-1]
	assert(session.exploration.knowledge.remember(site, "rumor", "17"))
	assert(map.map_sites().size() == 1 and map.map_sites()[0].id == site.id)
	for kind in ["village", "graveyard", "woodland_house"]:
		var candidates: Array = session.world.authored_sites().filter(func(entry): return entry.type == kind and not session.exploration.knowledge.sites.has(entry.id))
		assert(not candidates.is_empty(), "Expanded realm content must supply the new authored " + kind + " kind")
		var destination: Dictionary = candidates[0]
		assert(not map.map_sites().any(func(entry): return entry.id == destination.id))
		assert(session.exploration.knowledge.remember(destination, "rumor", "17"))
		var before_chart: Dictionary = session.exploration.knowledge.snapshot()
		map.prepare_chart(destination.cell, 192)
		assert(map.map_sites().any(func(entry): return entry.id == destination.id and entry.knowledge == "rumor"))
		assert(session.exploration.knowledge.snapshot() == before_chart and session.world.chunks.size() == chunk_count)
		session.state = "map"
		click.position = map._map_point(Vector2(destination.cell))
		map._gui_input(click)
		assert(session.waypoint.id == destination.id and session.state == "playing", "Each new discovered site kind must remain selectable on the real finite atlas")
	session.waypoint.clear()
	var hover_site: Dictionary = map.map_sites()[-1]
	var other_site: Dictionary = map.map_sites()[0]
	var texture: ImageTexture = map.chart_texture
	var motion := InputEventMouseMotion.new()
	motion.position = map._map_point(Vector2(hover_site.cell))
	map._gui_input(motion)
	assert(map.get("hovered_site_id") == hover_site.id, "A finite marker must reveal its destination name on hover")
	assert(map.destination_label_visible(hover_site) and not map.destination_label_visible(other_site), "Dense finite maps keep only hovered and selected destination labels")
	map._gui_input(motion)
	assert(map.chart_texture == texture and session.world.chunks.size() == chunk_count, "Hover must reuse the existing terrain texture and streamed world")
	session.waypoint = other_site
	assert(map.destination_label_visible(other_site))
	map.mouse_exited.emit()
	assert(map.hovered_site_id.is_empty() and not map.destination_label_visible(hover_site) and map.destination_label_visible(other_site))
	map._gui_input(motion)
	var real_world = session.world
	session.world = FiniteProvider.new()
	map.prepare_chart(Vector2i.ZERO, 192)
	assert(map.hovered_site_id.is_empty(), "Switching dimensions must discard the previous hovered identity")
	session.world = EndlessProvider.new()
	assert(map.destination_label_visible(hover_site), "Ordinary endless destination labels remain visible")
	session.world = real_world
	session.online.session = true
	assert(map.destination_label_visible(hover_site), "Downloaded online destination labels retain their existing presentation")
	session.online.session = false
	map.label_boxes = [Rect2(map.map_offset + Vector2(50, 50), Vector2(100, 20))]
	var label := map.site_label_rect(map.map_offset + Vector2(70, 70), 100)
	assert(not label.intersects(map.label_boxes[0].grow(2)) and Rect2(Vector2.ZERO, map.size).encloses(label), "A discovered-site label must move clear of an authored area label while staying within the atlas")
	map.size = Vector2(392, 392)
	map.prepare_chart(Vector2i(session.world.spawn_point()), session.world.REGION_SIZE * 3)
	var label_texture := map.chart_texture
	for destination in session.world.authored_sites():
		assert(session.exploration.knowledge.remember(destination, "seen", "17"))
	var known := map.map_sites()
	assert(known.size() == session.world.authored_sites().size())
	session.waypoint = known[-1]
	var markers := map.marker_rects()
	assert(markers.size() == known.size() + 1, "Every known marker and the hero must remain protected from finite atlas labels")
	map.label_boxes.assign(markers)
	for destination in [known[0], known[-1]]:
		var width := ThemeDB.fallback_font.get_string_size(destination.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var destination_bounds := map.site_label_rect(map._map_point(Vector2(destination.cell)), width)
		assert(map.label_fits(destination_bounds), "Hovered and waypoint labels must avoid all known marker rectangles inside the chart")
		map.label_boxes.append(destination_bounds)
	var area_count := 0
	for area in map.area_labels():
		var width := ThemeDB.fallback_font.get_string_size(area.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var area_bounds := map.area_label_rect(map._map_point(Vector2(area.label_cell)), width)
		assert(map.label_fits(area_bounds), "Every authored area name must avoid all markers, destination names and other area names")
		map.label_boxes.append(area_bounds)
		area_count += 1
	assert(area_count == 8 and map.chart_texture == label_texture and session.world.chunks.size() == chunk_count)
	map.free()
	print("PASS: complete real finite atlas/area/route topology without chunk expansion or discovery promotion, stable cache, clipped edge minimap and unchanged endless/online bounds")
	quit()
