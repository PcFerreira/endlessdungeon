extends SceneTree

const Minimap = preload("res://scripts/minimap.gd")

class Provider extends RefCounted:
	const MAP_COLORS = [Color("617e62")]
	var regions := {}
	var cells := {}
	var generator_version := 6
	var calls := 0
	func cell_info(cell: Vector2i) -> Dictionary:
		calls += 1
		return {"terrain":"water" if cell.x % 3 == 0 else "road", "biome":0, "height":0, "walkable":true}

class Session extends RefCounted:
	var online := {"session":false, "map_revision":0}
	var run_seed := 17
	var world := Provider.new()

func require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var session := Session.new()
	var map := Minimap.new()
	map.game = session
	map.size = Vector2(162, 146)
	map.prepare_chart(Vector2i(-12, 10), 48)
	var sampled: int = session.world.calls
	map.prepare_chart(Vector2i(-11, 10), 48)
	if not require(session.world.calls - sampled <= 48, "Moving one cell must sample only the entering map column, not all 2304 cells"):
		map.free()
		return
	for index in range(1, 80):
		map.prepare_chart(Vector2i(index, 10), 48)
	if not require(map.chart_colors.size() <= 48 * 48, "Terrain color retention must stay bounded to the visible chart"):
		map.free()
		return
	await process_frame
	await process_frame
	var texture: Image = map.chart_image if DisplayServer.get_name() == "headless" else map.chart_texture.get_image()
	for pixel in map.chart:
		var location: Vector2i = pixel.cell - map.map_bounds.position
		var actual := texture.get_pixelv(location)
		var expected: Color = pixel.color
		var error := maxf(absf(actual.r - expected.r), maxf(absf(actual.g - expected.g), absf(actual.b - expected.b)))
		if not require(error <= 1.0 / 255 + .000001 and actual.a == expected.a, "Raster colors must match terrain within one RGBA8 channel value: %s %s %s" % [location, actual, expected]):
			map.free()
			return
	sampled = session.world.calls
	map.size = Vector2(200, 100)
	map.prepare_chart(Vector2i(79, 10), 48)
	if not require(session.world.calls == sampled and is_equal_approx(map.map_scale, 100.0 / 48), "Resizing must update projection without resampling terrain"):
		map.free()
		return
	session.online.session = true
	session.world.cells[Vector2i(79, 10)] = {}
	map.prepare_chart(Vector2i(79, 10), 48)
	await process_frame
	await process_frame
	texture = map.chart_image if DisplayServer.get_name() == "headless" else map.chart_texture.get_image()
	if not require(map.chart.size() == 1 and texture.get_pixel(0, 0).a == 0, "Online maps must expose only downloaded cells and clear stale offline pixels"):
		map.free()
		return
	sampled = session.world.calls
	session.online.map_revision += 1
	map.prepare_chart(Vector2i(79, 10), 48)
	if not require(session.world.calls > sampled, "A remote revision must invalidate retained terrain"):
		map.free()
		return
	session.online.session = false
	session.run_seed += 1
	sampled = session.world.calls
	map.prepare_chart(Vector2i(79, 10), 48)
	if not require(session.world.calls - sampled == 48 * 48, "A new world context must discard all previous colors"):
		map.free()
		return
	sampled = session.world.calls
	session.world.generator_version = 4
	map.prepare_chart(Vector2i(79, 10), 48)
	if not require(session.world.calls - sampled == 48 * 48, "Loading a different generator edition on the same provider must invalidate colors"):
		map.free()
		return
	map.free()
	print("PASS: incremental bounded chart sampling, raster parity, resizing and downloaded-map invalidation")
	quit()
