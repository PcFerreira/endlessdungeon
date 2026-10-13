extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Planner = preload("res://scripts/site_planner.gd")
const Terrain = preload("res://scripts/dimension_terrain.gd")
const Constructions = preload("res://scripts/dimension_constructions.gd")
const Population = preload("res://scripts/dimension_population.gd")
const DIRECTORY := "res://config/dimensions"
static var records: Dictionary = {}

static func integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == int(value) and value >= low and value <= high

static func pair(value) -> bool:
	return value is Array and value.size() == 2 and value.all(func(number): return integer(number, -65536, 65536))

static func rect(value) -> bool:
	return value is Array and value.size() == 4 and value.all(func(number): return integer(number, -65536, 65536)) and value[2] > 0 and value[3] > 0

static func box(value: Array) -> Rect2i:
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))

static func point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func token(value) -> bool:
	return value is String and not value.is_empty() and value.length() <= 64 and value.to_snake_case() == value and not value.contains(":") and not value.contains("/")

static func site_profile(kind: String) -> Dictionary:
	var shape := Constructions.profile(kind)
	return Planner.DATA.profiles.get(kind, {}) if shape.is_empty() else shape

static func valid(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not token(data.get("id")) or not integer(data.get("map_version"), 1, 99999) or not data.get("name") is String or data.name.is_empty() or not rect(data.get("bounds")):
		return false
	var extent := box(data.bounds)
	if data.has("content_version") and not integer(data.content_version, 1, 99999):
		return false
	if extent.size.x % 16 != 0 or extent.size.y % 16 != 0 or extent.position.x % 16 != 0 or extent.position.y % 16 != 0 or extent.size.x > 16384 or extent.size.y > 16384:
		return false
	var revisions = data.get("compatible_revisions", [])
	if not revisions is Array or not revisions.all(func(revision): return integer(revision, 1, int(data.map_version) - 1)):
		return false
	for key in ["spawn", "return_portal", "sanctum_portal"]:
		if not pair(data.get(key)) or (key != "sanctum_portal" and not extent.has_point(point(data[key]))):
			return false
	if not data.get("areas") is Array or data.areas.is_empty() or not data.get("sites") is Array or not data.get("routes") is Array:
		return false
	var ids := {}
	var boxes: Array[Rect2i] = []
	for area in data.areas:
		if not area is Dictionary or not token(area.get("id")) or ids.has(area.id) or not area.get("name") is String or not rect(area.get("bounds")) or not pair(area.get("label_cell")) or not integer(area.get("biome"), 0, 3) or not Biomes.DATA.profiles.has(area.get("biome_id")) or not Biomes.DATA.profiles[area.biome_id].climates.has(int(area.biome)) or not area.get("map_color") is String or not Color.html_is_valid(area.map_color):
			return false
		var limits := box(area.bounds)
		if not extent.encloses(limits) or not limits.has_point(point(area.label_cell)) or boxes.any(func(previous): return previous.intersects(limits)):
			return false
		boxes.append(limits)
		ids[area.id] = true
	if not boxes.any(func(limits): return limits.has_point(point(data.spawn))) or not boxes.any(func(limits): return limits.has_point(point(data.return_portal))):
		return false
	var sites := {}
	var town_regions := {}
	var footprints: Array[Rect2i] = []
	for site in data.sites:
		if not site is Dictionary or not token(site.get("id")) or sites.has(site.id) or not site.get("type") is String or not site.get("name") is String or not pair(site.get("cell")) or not ids.has(site.get("area_id")) or not Constructions.valid_site_recipe(site):
			return false
		var cell := point(site.cell)
		var radius: int = site_profile(site.type).radius
		var footprint := Rect2i(cell - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1))
		if not extent.encloses(footprint) or footprints.any(func(previous): return previous.grow(2).intersects(footprint.grow(2))) or not data.areas.any(func(area): return area.id == site.area_id and box(area.bounds).encloses(footprint)):
			return false
		footprints.append(footprint)
		if site.type == "city":
			if not Areas.CITIES.has(site.get("archetype_id")):
				return false
			var first := Planner.coordinate(footprint.grow(2).position)
			var last := Planner.coordinate(footprint.grow(2).end - Vector2i.ONE)
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					var coordinate := Vector2i(x, y)
					if town_regions.has(coordinate):
						return false
					town_regions[coordinate] = true
		sites[site.id] = true
	var routes := {}
	for route in data.routes:
		if not route is Dictionary or not token(route.get("id")) or routes.has(route.id) or not integer(route.get("width"), 3, 9) or not route.get("path") is Array or route.path.size() < 2:
			return false
		for index in range(route.path.size()):
			if not pair(route.path[index]) or not extent.has_point(point(route.path[index])):
				return false
			if index > 0:
				var before := point(route.path[index - 1])
				var after := point(route.path[index])
				if before == after:
					return false
		routes[route.id] = true
	return Terrain.valid(data) and connected_routes(data) and Population.valid(data)

static func connected_routes(data: Dictionary) -> bool:
	var corridors: Array[Rect2i] = []
	var segments: Array[Dictionary] = []
	for route in data.routes:
		for index in range(route.path.size() - 1):
			var from := point(route.path[index])
			var to := point(route.path[index + 1])
			corridors.append(Rect2i(Vector2i(mini(from.x, to.x), mini(from.y, to.y)), Vector2i(absi(from.x - to.x) + 1, absi(from.y - to.y) + 1)).grow(int(route.width) / 2))
			segments.append({"from": Vector2(from), "to": Vector2(to), "radius": float(route.width) / 2})
	var reached := {}
	var queue: Array[int] = []
	for index in range(corridors.size()):
		if on_segment(Vector2(point(data.spawn)), segments[index]):
			reached[index] = true
			queue.append(index)
	var head := 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for index in range(corridors.size()):
			if not reached.has(index) and corridors[current].intersects(corridors[index]) and touching(segments[current], segments[index]):
				reached[index] = true
				queue.append(index)
	if reached.size() != corridors.size() or not segments.any(func(segment): return on_segment(Vector2(point(data.return_portal)), segment)):
		return false
	for site in data.sites:
		var approach := point(site.cell) + Vector2i.DOWN * int(site_profile(site.type).approach)
		if not segments.any(func(segment): return on_segment(Vector2(approach), segment)):
			return false
	return true

static func on_segment(location: Vector2, segment: Dictionary) -> bool:
	return location.distance_to(Geometry2D.get_closest_point_to_segment(location, segment.from, segment.to)) <= segment.radius

static func touching(first: Dictionary, second: Dictionary) -> bool:
	if Geometry2D.segment_intersects_segment(first.from, first.to, second.from, second.to) != null:
		return true
	var distance := INF
	for location in [first.from, first.to]:
		distance = minf(distance, location.distance_to(Geometry2D.get_closest_point_to_segment(location, second.from, second.to)))
	for location in [second.from, second.to]:
		distance = minf(distance, location.distance_to(Geometry2D.get_closest_point_to_segment(location, first.from, first.to)))
	return distance <= first.radius + second.radius

static func _load() -> void:
	if not records.is_empty():
		return
	assert(Constructions.valid(Constructions.DATA), "Invalid dimension construction catalogue")
	for filename in DirAccess.get_files_at(DIRECTORY):
		if filename.get_extension() != "json":
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(filename)))
		assert(valid(data), "Invalid authored dimension: " + filename)
		assert(not records.has(data.id), "Duplicate dimension ID: " + data.id)
		records[data.id] = data
	assert(not records.is_empty(), "No authored dimensions found")

static func all() -> Array[Dictionary]:
	_load()
	var result: Array[Dictionary] = []
	for id in records:
		result.append(records[id].duplicate(true))
	return result

static func default_id() -> String:
	_load()
	var defaults := records.keys().filter(func(id): return records[id].get("default", false))
	assert(defaults.size() == 1, "Exactly one default Sanctum dimension is required")
	return defaults[0]

static func definition(id: String = "") -> Dictionary:
	_load()
	return records.get(default_id() if id.is_empty() else id, {}).duplicate(true)

static func valid_point(id: String, location: Vector2) -> bool:
	var data := definition(id)
	return not data.is_empty() and is_finite(location.x) and is_finite(location.y) and box(data.bounds).has_point(Vector2i(location.round()))
