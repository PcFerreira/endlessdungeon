extends "res://scripts/world.gd"

const Catalog = preload("res://scripts/dimension_catalog.gd")
const Terrain = preload("res://scripts/dimension_terrain.gd")
const Constructions = preload("res://scripts/dimension_constructions.gd")
const Population = preload("res://scripts/dimension_population.gd")
var terrain
var dimension_id := ""
var map_version := 1
var definition: Dictionary = {}
var map_extent := Rect2i()
var return_portal := Vector2i.ZERO
var decoration_seed := 0
var _areas: Array[Dictionary] = []
var _sites: Array[Dictionary] = []
var _segments: Array[Dictionary] = []
var _segment_index: Dictionary = {}

func _init(id: String = "") -> void:
	definition = Catalog.definition(id)
	assert(not definition.is_empty(), "Unknown finite dimension: " + id)
	dimension_id = definition.id
	map_version = int(definition.map_version)
	map_extent = Catalog.box(definition.bounds)
	start = Catalog.point(definition.spawn)
	return_portal = Catalog.point(definition.return_portal)
	decoration_seed = _hash("dressing")
	terrain = Terrain.new(definition)
	for recipe in definition.areas:
		var area: Dictionary = recipe.duplicate(true)
		area.bounds = Catalog.box(recipe.bounds)
		area.label_cell = Catalog.point(recipe.label_cell)
		area.map_color = Color(recipe.map_color)
		area.biome = int(recipe.biome)
		_areas.append(area)
	for route in definition.routes:
		for index in range(route.path.size() - 1):
			var from := Catalog.point(route.path[index])
			var to := Catalog.point(route.path[index + 1])
			var radius: float = float(route.width) / 2
			var limits := Rect2i(Vector2i(mini(from.x, to.x), mini(from.y, to.y)), Vector2i(absi(from.x - to.x) + 1, absi(from.y - to.y) + 1)).grow(ceili(radius))
			var segment := {"bounds": limits, "id": "dimension:%s:route:%s" % [dimension_id, route.id], "axis": Vector2i.RIGHT if absi(from.x - to.x) >= absi(from.y - to.y) else Vector2i.DOWN, "from": Vector2(from), "to": Vector2(to), "radius": radius}
			_segments.append(segment)
			var first := SitePlanner.coordinate(limits.position)
			var last := SitePlanner.coordinate(limits.end - Vector2i.ONE)
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					var coordinate := Vector2i(x, y)
					if not _segment_index.has(coordinate):
						_segment_index[coordinate] = []
					_segment_index[coordinate].append(segment)

func generate(seed_value: int, edition: int = GENERATOR_VERSION) -> void:
	assert(edition in [4, 5, 6, 7], "Unsupported hero world edition")
	run_seed = seed_value
	generator_version = edition
	site_planner = null
	chunks.clear()
	cells.clear()
	tiles.clear()
	regions.clear()
	route_plans.clear()
	obstacles.clear()
	current_chunk = Vector2i(999999, 999999)
	bounds = Rect2i()
	_sites.clear()
	var composer := SitePlanner.new(0)
	for recipe in definition.sites:
		var cell := Catalog.point(recipe.cell)
		var shape: Dictionary = Constructions.profile(recipe.type)
		var site: Dictionary
		if shape.is_empty():
			site = composer.site("dimension:%s:site:%s" % [dimension_id, recipe.id], recipe.type, SitePlanner.coordinate(cell), cell, Vector2i.DOWN)
		else:
			var radius := int(shape.radius)
			site = {"id": "dimension:%s:site:%s" % [dimension_id, recipe.id], "type": recipe.type, "coordinate": SitePlanner.coordinate(cell), "cell": cell, "facing": Vector2i.DOWN, "radius": radius, "flatten": int(shape.flatten), "approach_distance": int(shape.approach), "approach": cell + Vector2i.DOWN * int(shape.approach), "footprint": Rect2i(cell - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1)), "corridors": []}
		site.height = terrain.height_at(cell)
		site.seed = _hash("site:" + site.id)
		site.merge(biome_at(cell), true)
		site.area_id = recipe.area_id
		if site.type == "city":
			site = _town(site, recipe.archetype_id)
		elif not shape.is_empty():
			site = Constructions.compose(site, recipe)
		else:
			site = SurfaceLocations.compose(site)
		site.name = recipe.name
		site.population_residents = recipe.get("residents", []).duplicate(true)
		for resident in site.get("residents", []):
			resident.city_name = site.name
		_sites.append(site)
	var residents := Population.resident_records(self)
	for site in _sites:
		if site.type == "city" and not site.population_residents.is_empty():
			site.residents = residents.filter(func(resident): return resident.city_id == site.id)

func _hash(salt: String) -> int:
	return Biomes.salt(map_version, dimension_id + ":" + salt)

func _town(site: Dictionary, archetype: String) -> Dictionary:
	var style: Dictionary = Areas.CITIES[archetype]
	var center: Vector2i = site.cell
	var houses: Array[Dictionary] = []
	var offsets := [Vector2i(-8, -8), Vector2i(4, -8), Vector2i(-8, 4), Vector2i(4, 4), Vector2i(-8, -1)]
	for index in range(offsets.size()):
		var use_id: String = style.required_buildings[index] if index < style.required_buildings.size() else style.extra_buildings[index % style.extra_buildings.size()]
		var use: Dictionary = Areas.DATA.building_uses[use_id]
		var architecture: Dictionary = style.architecture.duplicate(true)
		architecture.merge(use.get("architecture", {}), true)
		houses.append({"id": site.id + ":house:" + str(index), "footprint": Rect2i(center + offsets[index], Vector2i(3, 3)), "height": float(architecture.height[0]), "style": index % 4, "archetype": archetype, "architecture": architecture, "use_id": use_id, "use_name": use.name, "interior_type": use.interior_type})
	var streets := _town_streets(center, houses)
	var residents: Array[Dictionary] = []
	for index in range(2):
		residents.append({"id": site.id + ":npc:" + str(index), "kind": "npc", "role": "fountain_keeper" if index == 0 else style.role, "point": Vector2(center + Vector2i(3 if index == 0 else -3, 3)), "approach": Vector2(center + Vector2i(2 if index == 0 else -2, 3)), "city_id": site.id, "biome": site.biome, "appearance": _hash(site.id + ":npc:" + str(index)) % 4})
	site.merge({"houses": houses, "outdoor_lots": [], "streets": streets, "decorations": [{"cell": center + Vector2i(3, -3), "kind": "bookstand"}], "residents": residents, "archetype_id": archetype, "layout_id": "authored_cross", "style": _hash(site.id) % 3, "books": [{"id": site.id + ":book", "kind": "book", "book_id": style.book, "point": Vector2(center + Vector2i(3, -3)), "approach": Vector2(center + Vector2i(2, -3))}]}, true)
	return site

func dimension_record() -> Dictionary:
	return definition.duplicate(true)

func authored_areas() -> Array[Dictionary]:
	return _areas.duplicate(true)

func authored_sites() -> Array[Dictionary]:
	return _sites.duplicate(true)

func area_at(cell: Vector2i) -> Dictionary:
	if not map_extent.has_point(cell):
		return {}
	var id: String = terrain.area_id(cell)
	var dry: bool = terrain.land_at(cell)
	for site in _sites:
		if site.footprint.grow(3).has_point(cell):
			id = site.area_id
			dry = true
			break
	if Vector2(cell).distance_to(Vector2(start)) <= 24 or Vector2(cell).distance_to(Vector2(return_portal)) <= 24:
		dry = true
	if not dry:
		return {}
	for area in _areas:
		if area.id == id:
			return area
	return {}

func _raw_height(cell: Vector2i) -> float:
	if not map_extent.has_point(cell):
		return 0.0
	var height: float = terrain.raw_height_at(cell)
	var total := 0.0
	var target := 0.0
	var influence := 0.0
	for site in _sites:
		var distance := city_distance(Vector2(cell), site.cell)
		var weight := 1 - smoothstep(maxf(20, site.radius + 3), 128, distance)
		if weight <= 0:
			continue
		influence = maxf(influence, weight)
		var share := pow(weight, 4)
		total += share
		target += site.height * share
	if total > 0:
		height = lerpf(height, target / total, influence)
	var arrival: float = minf(Vector2(cell).distance_to(Vector2(start)), Vector2(cell).distance_to(Vector2(return_portal)))
	var arrival_height: float = terrain.height_at(start)
	height = lerpf(arrival_height, height, smoothstep(24, 128, arrival))
	return snappedf(height, .5)

func _biome_at(cell: Vector2i) -> int:
	return int(area_at(cell).get("biome", 1))

func biome_at(cell: Vector2i, _climate: int = -1) -> Dictionary:
	var area := area_at(cell)
	var id: String = area.get("biome_id", "coast")
	var secondary := id
	var blend := 0.0
	if not area.is_empty():
		var weights: Array = terrain.area_weights(cell)
		if weights.size() > 1 and weights[0].id == area.id:
			for other in _areas:
				if other.id == weights[1].id:
					secondary = other.biome_id
					blend = snappedf(float(weights[1].weight), 1.0 / 16)
	var mixture: Array[Dictionary] = [{"id": id, "weight": 1.0}]
	if secondary != id and blend > 0:
		mixture = [{"id": id, "weight": 1.0 - blend}, {"id": secondary, "weight": blend}]
	return {"biome": int(area.get("biome", 1)), "biome_id": id, "biome_secondary": secondary, "biome_blend": blend, "biome_mix": mixture}

func region_at(cell: Vector2i) -> Dictionary:
	var coordinate := SitePlanner.coordinate(cell)
	if regions.has(coordinate):
		return regions[coordinate]
	var region := {"id": "dimension:%s:region:%s:%s:%s" % [dimension_id, map_version, coordinate.x, coordinate.y], "coordinate": coordinate, "city": {}, "dungeons": [], "locations": [], "roads": {}, "bridges": {}, "routes": [], "facet": "", "facet_center": coordinate * REGION_SIZE, "transition": "transition_boundary_common", "dimension_id": dimension_id}
	var limits := Rect2i(coordinate * REGION_SIZE, Vector2i.ONE * REGION_SIZE)
	if not map_extent.intersects(limits):
		return region
	for site in _sites:
		if limits.intersects(site.footprint.grow(2)):
			if site.type == "city":
				region.city = site
			else:
				region.locations.append(site)
	if regions.size() >= 32:
		regions.erase(regions.keys()[0])
	regions[coordinate] = region
	return region

func _road_record(cell: Vector2i) -> Dictionary:
	for segment in _segment_index.get(SitePlanner.coordinate(cell), []):
		if segment.bounds.has_point(cell) and Vector2(cell).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(cell), segment.from, segment.to)) <= segment.radius:
			return segment
	return {}

func _road_at(cell: Vector2i, _region: Dictionary) -> bool:
	return not _road_record(cell).is_empty()

func cell_info(cell: Vector2i) -> Dictionary:
	if cells.has(cell):
		return cells[cell]
	var area := area_at(cell) if map_extent.has_point(cell) else {}
	var road := _road_record(cell) if map_extent.has_point(cell) else {}
	var land := not area.is_empty()
	var terrain := "land" if land else "water"
	var walkable := land
	var prop := ""
	var detail := ""
	var height := _raw_height(cell) if land or not road.is_empty() else 0.0
	var cleared := not road.is_empty()
	var solid := false
	var nearby = _sites if map_extent.has_point(cell) else []
	for site in nearby:
		if not site.footprint.grow(2).has_point(cell):
			continue
		cleared = true
		if site.type == "city":
			solid = cell == site.cell or Rect2i(site.cell + Vector2i(8, 8), Vector2i(3, 3)).has_point(cell) or cell == site.cell + Vector2i(3, -3) or cell == site.cell + Vector2i(-12, 2)
			for house in site.houses:
				solid = solid or house.footprint.has_point(cell)
		else:
			solid = cell in site.solid_cells
		if site.footprint.has_point(cell):
			terrain = "paving"
			height = site.height
		walkable = land and not solid
		break
	if not road.is_empty() and not solid:
		terrain = "road" if land else "bridge"
		walkable = true
	var ecology := biome_at(cell)
	var profile: Dictionary = Biomes.DATA.profiles[ecology.biome_id]
	var roll := _hash("cell:%s:%s" % [cell.x, cell.y]) % 1000
	if land and not cleared:
		if roll < int(profile.density) and posmod(cell.x, 3) == 0 and posmod(cell.y, 3) == 0:
			prop = profile.props[roll % profile.props.size()]
			walkable = false
		elif roll < int(profile.detail_chance * 1000):
			detail = profile.details[roll % profile.details.size()]
			if detail == "biome:lily":
				detail = "biome:reeds"
	var result := {"biome": ecology.biome, "terrain": terrain, "prop": prop, "detail": detail, "facet": "", "walkable": walkable, "height": height, "base_height": 0.0 if not land else maxf(0, height - .5), "base_terrain": "land" if land else "water", "bridge_axis": road.get("axis", Vector2i.RIGHT), "bridge_edge": 0, "bridge_pier": posmod(cell.x + cell.y, 4) == 0, "tone": _hash("tone:%s:%s" % [cell.x, cell.y]) % 3, "dimension_id": dimension_id, "area_id": area.get("id", ""), "area_name": area.get("name", definition.name + " Sea")}
	result.merge(ecology, true)
	return result

func _build_chunk(coordinate: Vector2i) -> Dictionary:
	var data := {}
	var limits := Rect2i(coordinate * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE).intersection(map_extent)
	for x in range(limits.position.x, limits.end.x):
		for y in range(limits.position.y, limits.end.y):
			var cell := Vector2i(x, y)
			data[cell] = cell_info(cell)
	return {"cells": data, "spawns": Population.spawns(self, coordinate, data)}

func load_around(point: Vector2) -> bool:
	var center := chunk_at(point)
	if current_chunk == center:
		return false
	current_chunk = center
	var wanted := {}
	for x in range(center.x - CHUNK_RADIUS, center.x + CHUNK_RADIUS + 1):
		for y in range(center.y - CHUNK_RADIUS, center.y + CHUNK_RADIUS + 1):
			var coordinate := Vector2i(x, y)
			if not map_extent.intersects(Rect2i(coordinate * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE)):
				continue
			wanted[coordinate] = true
			if not chunks.has(coordinate):
				chunks[coordinate] = _build_chunk(coordinate)
	for coordinate in chunks.keys():
		if not wanted.has(coordinate):
			chunks.erase(coordinate)
	cells.clear()
	tiles.clear()
	for chunk in chunks.values():
		cells.merge(chunk.cells)
		for cell in chunk.cells:
			if chunk.cells[cell].walkable:
				tiles[cell] = true
	bounds = Rect2i((center - Vector2i.ONE * CHUNK_RADIUS) * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE * (CHUNK_RADIUS * 2 + 1)).intersection(map_extent)
	return true

func nearby_sites(point: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in _sites:
		if Vector2(site.cell).distance_to(point) <= REGION_SIZE * 1.5:
			result.append(site)
	return result

func site_by_id(id: String, cell: Vector2i) -> Dictionary:
	for site in _sites:
		if site.id == id and site.cell == cell:
			return site
	return {}

func nearest_site(point: Vector2, type: String = "") -> Dictionary:
	var closest := {}
	var distance := INF
	for site in _sites:
		if not type.is_empty() and site.type != type:
			continue
		var delta: float = Vector2(site.cell).distance_squared_to(point)
		if delta < distance:
			distance = delta
			closest = site
	return closest

func city_at(point: Vector2, margin: float = 0) -> Dictionary:
	for site in _sites:
		if site.type == "city" and city_distance(point, site.cell) <= site.radius + margin:
			return site
	return {}

func spawn_point() -> Vector2:
	return Vector2(start)

func _supported(point: Vector2) -> bool:
	for obstacle in obstacles:
		if obstacle.grow(.20).has_point(point):
			return false
	for offset in [Vector2(-.20, -.20), Vector2(.20, -.20), Vector2(-.20, .20), Vector2(.20, .20)]:
		if not cell_info(Vector2i((point + offset).round())).walkable:
			return false
	return true

func safe_position(point: Vector2, search_radius: int = 12) -> Vector2:
	if not Catalog.valid_point(dimension_id, point):
		return spawn_point()
	if _supported(point):
		return point
	var center := Vector2i(point.round())
	var closest := spawn_point()
	var distance := INF
	for x in range(center.x - search_radius, center.x + search_radius + 1):
		for y in range(center.y - search_radius, center.y + search_radius + 1):
			var candidate := Vector2(x, y)
			if not map_extent.has_point(Vector2i(x, y)) or not _supported(candidate):
				continue
			var delta := candidate.distance_squared_to(point)
			if delta < distance:
				distance = delta
				closest = candidate
	return closest
