extends RefCounted

# Twice the control height range divided by grid spacing stays below a half-cell step.
const HEIGHT_GRID := 64
const MIN_HEIGHT := 1.0
const MAX_HEIGHT := 12.0
const CACHE_LIMIT := 128
var extent := Rect2i()
var _identity := ""
var _organic := false
var _areas: Array[Dictionary] = []
var _polygon := PackedVector2Array()
var _rivers: Array[Dictionary] = []
var _lakes: Array[Dictionary] = []
var _ridges: Array[Dictionary] = []
var _hills: Array[Dictionary] = []
var _coast_x: FastNoiseLite
var _coast_y: FastNoiseLite
var _area_x: FastNoiseLite
var _area_y: FastNoiseLite
var _elevation: FastNoiseLite
var _lake_noise: FastNoiseLite
var _coast_amplitude := 0.0
var _area_amplitude := 0.0
var _blend_width := 64.0
var _base := 1.0
var _amplitude := 0.0
var _height_nodes: Dictionary = {}

static func number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func pair(value) -> bool:
	return value is Array and value.size() == 2 and value.all(func(item): return number(item, -65536, 65536))

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func points(value: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for item in value:
		result.append(point(item))
	return result

static func polygon(value: Array) -> PackedVector2Array:
	var result := points(value)
	if result.size() > 1 and result[0] == result[result.size() - 1]:
		result.resize(result.size() - 1)
	return result

static func path_valid(value, minimum: int = 2) -> bool:
	if not value is Array or value.size() < minimum or value.size() > 128 or not value.all(pair):
		return false
	for index in range(value.size() - 1):
		if point(value[index]) == point(value[index + 1]):
			return false
	return true

static func polygon_valid(value) -> bool:
	if not path_valid(value, 3):
		return false
	var shape := polygon(value)
	if shape.size() < 3:
		return false
	var area := 0.0
	for index in range(shape.size()):
		var next := (index + 1) % shape.size()
		area += shape[index].cross(shape[next])
		for other in range(index + 1, shape.size()):
			if other == next or (index == 0 and other == shape.size() - 1):
				continue
			if Geometry2D.segment_intersects_segment(shape[index], shape[next], shape[other], shape[(other + 1) % shape.size()]) != null:
				return false
	return absf(area) > .001

static func parameters(value, ranges: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for key in ranges:
		if value.has(key) and not number(value[key], ranges[key][0], ranges[key][1]):
			return false
	return true

static func valid(definition) -> bool:
	if not definition is Dictionary or not definition.get("id") is String or definition.id.is_empty() or not number(definition.get("map_version"), 1, 99999) or definition.map_version != int(definition.map_version):
		return false
	var bounds = definition.get("bounds")
	if not bounds is Array or bounds.size() != 4 or not bounds.all(func(item): return number(item, -65536, 65536) and item == int(item)) or bounds[2] <= 0 or bounds[3] <= 0:
		return false
	if not definition.get("areas") is Array or definition.areas.is_empty() or definition.areas.size() > 64:
		return false
	var ids := {}
	for area in definition.areas:
		if not area is Dictionary or not area.get("id") is String or area.id.is_empty() or ids.has(area.id) or not pair(area.get("terrain_center", area.get("label_cell"))):
			return false
		ids[area.id] = true
		if area.has("terrain_scale") and (not pair(area.terrain_scale) or not area.terrain_scale.all(func(item): return number(item, .2, 4))):
			return false
	if not definition.has("terrain"):
		return definition.areas.all(func(area): return area.get("bounds") is Array and area.bounds.size() == 4 and area.bounds.all(func(item): return number(item, -65536, 65536)) and area.bounds[2] > 0 and area.bounds[3] > 0)
	var terrain = definition.terrain
	if not terrain is Dictionary or terrain.get("version") != 1 or not terrain.get("coast") is Dictionary or not polygon_valid(terrain.coast.get("polygon")):
		return false
	if not parameters(terrain.coast, {"warp_amplitude": [0, 128], "frequency": [.0001, .02]}) or not parameters(terrain.get("areas", {}), {"warp_amplitude": [0, 160], "frequency": [.0001, .02], "blend_width": [1, 256]}):
		return false
	var elevation = terrain.get("elevation", {})
	if not parameters(elevation, {"base": [1, 8], "amplitude": [0, 8], "frequency": [.0001, .02], "octaves": [1, 4], "gain": [0, 1], "lacunarity": [1, 3]}) or elevation.get("step", .5) != .5 or elevation.get("octaves", 3) != int(elevation.get("octaves", 3)):
		return false
	for settings in [terrain.coast, terrain.get("areas", {})]:
		if not parameters(settings, {"octaves": [1, 4], "gain": [0, 1], "lacunarity": [1, 3]}) or settings.get("octaves", 3) != int(settings.get("octaves", 3)):
			return false
	for group in ["rivers", "lakes", "ridges", "hills"]:
		var features = terrain.get(group, [])
		if not features is Array or features.size() > 32:
			return false
		var names := {}
		for feature in features:
			if not feature is Dictionary or not feature.get("id") is String or feature.id.is_empty() or names.has(feature.id):
				return false
			names[feature.id] = true
			if group in ["rivers", "ridges"]:
				if not path_valid(feature.get("path")) or not number(feature.get("width"), 1, 512):
					return false
			else:
				if not pair(feature.get("center")):
					return false
			if group == "rivers" and not number(feature.get("bank_width", 32), 1, 256):
				return false
			if group == "lakes" and (not pair(feature.get("radii")) or not feature.radii.all(func(item): return number(item, 4, 512)) or not parameters(feature, {"rotation": [-TAU, TAU], "shore_warp": [0, .3], "bank_width": [1, 256]})):
				return false
			if group in ["hills", "ridges"] and not number(feature.get("height"), 0, 11):
				return false
			if group == "hills" and not number(feature.get("radius"), 16, 512):
				return false
	return true

func _init(definition: Dictionary) -> void:
	assert(valid(definition), "Invalid authored dimension terrain")
	extent = Rect2i(int(definition.bounds[0]), int(definition.bounds[1]), int(definition.bounds[2]), int(definition.bounds[3]))
	_identity = "%s:%s" % [definition.id, int(definition.map_version)]
	_organic = definition.has("terrain")
	for recipe in definition.areas:
		var area := {"id": recipe.id, "center": point(recipe.get("terrain_center", recipe.get("label_cell"))), "scale": point(recipe.get("terrain_scale", [1, 1]))}
		if not _organic:
			area.bounds = Rect2(float(recipe.bounds[0]), float(recipe.bounds[1]), float(recipe.bounds[2]), float(recipe.bounds[3]))
		_areas.append(area)
	if not _organic:
		return
	var terrain: Dictionary = definition.terrain
	_polygon = polygon(terrain.coast.polygon)
	_coast_amplitude = float(terrain.coast.get("warp_amplitude", 48))
	var area_settings: Dictionary = terrain.get("areas", {})
	_area_amplitude = float(area_settings.get("warp_amplitude", 48))
	_blend_width = float(area_settings.get("blend_width", 64))
	_coast_x = _noise(terrain.coast, "coast:x", .003)
	_coast_y = _noise(terrain.coast, "coast:y", .003)
	_area_x = _noise(area_settings, "areas:x", .003)
	_area_y = _noise(area_settings, "areas:y", .003)
	var elevation: Dictionary = terrain.get("elevation", {})
	_elevation = _noise(elevation, "elevation", .002)
	_lake_noise = _noise({}, "lake:shore", .012)
	_base = float(elevation.get("base", 1))
	_amplitude = float(elevation.get("amplitude", 2))
	for recipe in terrain.get("rivers", []):
		var path := points(recipe.path)
		var radius := float(recipe.width) * .5
		var bank := float(recipe.get("bank_width", 32))
		_rivers.append({"id": recipe.id, "path": path, "radius": radius, "bank_width": bank, "bounds": _bounds(path).grow(radius + bank)})
	for recipe in terrain.get("lakes", []):
		var radii := point(recipe.radii)
		var center := point(recipe.center)
		var bank := float(recipe.get("bank_width", 32))
		var warp := float(recipe.get("shore_warp", .06))
		var radius := maxf(radii.x, radii.y) * (1 + warp) + bank
		_lakes.append({"id": recipe.id, "center": center, "radii": radii, "rotation": float(recipe.get("rotation", 0)), "shore_warp": warp, "bank_width": bank, "bounds": Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)})
	for recipe in terrain.get("ridges", []):
		_ridges.append({"path": points(recipe.path), "width": float(recipe.width), "height": float(recipe.height)})
	for recipe in terrain.get("hills", []):
		_hills.append({"center": point(recipe.center), "radius": float(recipe.radius), "height": float(recipe.height)})

func _seed(salt: String) -> int:
	var value := 2166136261
	for byte in (_identity + ":" + salt).to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xffffffff
	return value & 0x7fffffff

func _noise(settings: Dictionary, salt: String, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = _seed(salt)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = float(settings.get("frequency", frequency))
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = int(settings.get("octaves", 3))
	noise.fractal_gain = float(settings.get("gain", .45))
	noise.fractal_lacunarity = float(settings.get("lacunarity", 2))
	noise.domain_warp_enabled = false
	return noise

func _warp(location: Vector2, x: FastNoiseLite, y: FastNoiseLite, amplitude: float) -> Vector2:
	return location + Vector2(x.get_noise_2dv(location), y.get_noise_2dv(location)) * amplitude

func _bounds(path: PackedVector2Array) -> Rect2:
	var limits := Rect2(path[0], Vector2.ZERO)
	for location in path:
		limits = limits.expand(location)
	return limits

func _distance(location: Vector2, path: PackedVector2Array, closed: bool = false) -> float:
	var distance := INF
	for index in range(path.size() if closed else path.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(location, path[index], path[(index + 1) % path.size()])
		distance = minf(distance, location.distance_to(closest))
	return distance

func _lake_distance(location: Vector2, lake: Dictionary) -> float:
	var local: Vector2 = (location - lake.center).rotated(-lake.rotation) / lake.radii
	var shore: float = 1 + lake.shore_warp * _lake_noise.get_noise_2dv(location)
	return (local.length() - shore) * minf(lake.radii.x, lake.radii.y)

func _water_feature(location: Vector2) -> String:
	if not _organic:
		return "ocean" if _legacy_area(location).is_empty() else ""
	var coast := _warp(location, _coast_x, _coast_y, _coast_amplitude)
	if not Geometry2D.is_point_in_polygon(coast, _polygon):
		return "ocean"
	for lake in _lakes:
		if lake.bounds.has_point(location) and _lake_distance(location, lake) <= 0:
			return "lake:" + lake.id
	for river in _rivers:
		if river.bounds.has_point(location) and _distance(location, river.path) <= river.radius:
			return "river:" + river.id
	return ""

func _legacy_area(location: Vector2) -> String:
	for area in _areas:
		if area.bounds.has_point(location):
			return area.id
	return ""

func land_at(cell: Vector2i) -> bool:
	return extent.has_point(cell) and _water_feature(Vector2(cell)).is_empty()

func _nearest_areas(location: Vector2) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var warped := _warp(location, _area_x, _area_y, _area_amplitude)
	for area in _areas:
		var delta: Vector2 = (warped - area.center) / area.scale
		candidates.append({"id": area.id, "distance": delta.length()})
	candidates.sort_custom(func(first, second): return first.id < second.id if first.distance == second.distance else first.distance < second.distance)
	return candidates

func area_id(cell: Vector2i) -> String:
	if not extent.has_point(cell):
		return ""
	return _nearest_areas(Vector2(cell))[0].id if _organic else _legacy_area(Vector2(cell))

func area_weights(cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not extent.has_point(cell):
		return result
	if not _organic:
		var id := _legacy_area(Vector2(cell))
		if not id.is_empty():
			result.append({"id": id, "weight": 1.0})
		return result
	var candidates := _nearest_areas(Vector2(cell))
	var weight := 0.0
	if candidates.size() > 1:
		weight = .5 * (1 - smoothstep(0, _blend_width, candidates[1].distance - candidates[0].distance))
	result.append({"id": candidates[0].id, "weight": 1 - weight})
	if weight > 0:
		result.append({"id": candidates[1].id, "weight": weight})
	return result

func _bank_ratio(location: Vector2) -> float:
	var coast := _warp(location, _coast_x, _coast_y, _coast_amplitude)
	if not Geometry2D.is_point_in_polygon(coast, _polygon):
		return 0.0
	var ratio := smoothstep(0, 96, _distance(coast, _polygon, true))
	for river in _rivers:
		if river.bounds.has_point(location):
			ratio = minf(ratio, smoothstep(0, river.bank_width, _distance(location, river.path) - river.radius))
	for lake in _lakes:
		if lake.bounds.has_point(location):
			ratio = minf(ratio, smoothstep(0, lake.bank_width, _lake_distance(location, lake)))
	return ratio

func _height_node(coordinate: Vector2i) -> float:
	if _height_nodes.has(coordinate):
		return _height_nodes[coordinate]
	var location := Vector2(extent.position + coordinate * HEIGHT_GRID)
	var height := _base + _amplitude * _elevation.get_noise_2dv(location)
	for ridge in _ridges:
		height += ridge.height * (1 - smoothstep(0, ridge.width, _distance(location, ridge.path)))
	for hill in _hills:
		height += hill.height * (1 - smoothstep(0, hill.radius, location.distance_to(hill.center)))
	height = lerpf(MIN_HEIGHT, clampf(height, MIN_HEIGHT, MAX_HEIGHT), _bank_ratio(location))
	if _height_nodes.size() >= CACHE_LIMIT:
		_height_nodes.erase(_height_nodes.keys()[0])
	_height_nodes[coordinate] = height
	return height

func raw_height_at(cell: Vector2i) -> float:
	if not extent.has_point(cell):
		return 0.0
	if not _organic:
		return 1.0
	var control := Vector2(cell - extent.position) / HEIGHT_GRID
	var coordinate := Vector2i(floori(control.x), floori(control.y))
	var fraction := control - Vector2(coordinate)
	var above := lerpf(_height_node(coordinate), _height_node(coordinate + Vector2i.RIGHT), fraction.x)
	var below := lerpf(_height_node(coordinate + Vector2i.DOWN), _height_node(coordinate + Vector2i.ONE), fraction.x)
	return lerpf(above, below, fraction.y)

func height_at(cell: Vector2i) -> float:
	return snappedf(raw_height_at(cell), .5)

func sample(cell: Vector2i) -> Dictionary:
	if not extent.has_point(cell):
		return {"land": false, "height": 0.0, "water_feature": "ocean", "area_id": ""}
	var water := _water_feature(Vector2(cell))
	var land := water.is_empty()
	return {"land": land, "height": height_at(cell) if land else 0.0, "water_feature": water, "area_id": area_id(cell) if land else ""}
