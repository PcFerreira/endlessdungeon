extends "res://scripts/grid_area.gd"

const CHUNK_SIZE := 16
const GENERATOR_VERSION := 4
const Areas = preload("res://scripts/area_catalog.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const MonsterAreas = preload("res://scripts/monster_areas.gd")
const TownMagic = preload("res://scripts/town_magic.gd")
const TownTypes = preload("res://scripts/town_types.gd")
const TownVoxelLayout = preload("res://scripts/town_voxel_layout.gd")
const SitePlanner = preload("res://scripts/site_planner.gd")
const RoadRoutes = preload("res://scripts/road_routes.gd")
const SurfaceLocations = preload("res://scripts/surface_locations.gd")
const Biomes = preload("res://scripts/biome_catalog.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const MicroBiomes = preload("res://scripts/micro_biome_catalog.gd")
const LandmarkCatalog = preload("res://scripts/biome_landmark_catalog.gd")
const NEW_JOURNEY_EDITION := 7
static var REGION_SIZE: int = int(Areas.DATA.geography.town_spacing)
const CHUNK_RADIUS := 2
const BIOMES := ["Greenwood", "Sunlit Meadows", "Amber Wastes", "Frostlands"]
const MAP_COLORS := [Color("447857"), Color("83a166"), Color("c6a567"), Color("a7bfcd")]
var run_seed := 0
var generator_version := GENERATOR_VERSION
var site_planner
var start := Vector2i(REGION_SIZE / 2, REGION_SIZE / 2 + 3)
var chunks: Dictionary = {}
var installed_chunks: Dictionary = {}
var cells: Dictionary = {}
var regions: Dictionary = {}
var route_plans: Dictionary = {}
var micro_patches: Dictionary = {}
var landmark_plans: Dictionary = {}
var temperature := FastNoiseLite.new()
var moisture := FastNoiseLite.new()
var elevation := FastNoiseLite.new()
var continents := FastNoiseLite.new()
var erosion := FastNoiseLite.new()
var ridges := FastNoiseLite.new()
var rivers := FastNoiseLite.new()
var current_chunk := Vector2i(999999, 999999)

func generate(seed_value: int, edition: int = GENERATOR_VERSION) -> void:
	assert(edition in [4, 5, 6, 7], "Unsupported world generation edition")
	assert(edition < 5 or int(SitePlanner.DATA.region_size) == REGION_SIZE, "World and independent planning must use the same region size")
	generator_version = edition
	run_seed = seed_value
	site_planner = SitePlanner.new(seed_value) if edition >= 5 else null
	chunks.clear()
	installed_chunks.clear()
	cells.clear()
	tiles.clear()
	regions.clear()
	route_plans.clear()
	micro_patches.clear()
	landmark_plans.clear()
	current_chunk = Vector2i(999999, 999999)
	for noise in [temperature, moisture, elevation, continents, erosion, ridges, rivers]:
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_octaves = 3
	temperature.seed = _hash("heat") % 2147483647
	temperature.frequency = .0013
	temperature.fractal_octaves = 2
	moisture.seed = _hash("rain") % 2147483647
	moisture.frequency = .0018
	moisture.fractal_octaves = 2
	if edition >= 6:
		temperature.frequency /= Biomes.DATA.size_multiplier
		moisture.frequency /= Biomes.DATA.size_multiplier
	elevation.seed = _hash("land") % 2147483647
	elevation.frequency = .007
	continents.seed = _hash("continents") % 2147483647
	continents.frequency = .0015
	erosion.seed = _hash("erosion") % 2147483647
	erosion.frequency = .003
	ridges.seed = _hash("ridges") % 2147483647
	ridges.frequency = .006
	rivers.seed = _hash("rivers") % 2147483647
	rivers.frequency = .0038
	rivers.fractal_octaves = 2
	if edition >= 6:
		site_planner.routing = RoadRoutes.new(self)

func _raw_height(cell: Vector2i) -> float:
	return floorf(_height_field(cell) * 2) * .5

func _height_field(cell: Vector2i) -> float:
	var broad := continents.get_noise_2d(cell.x, cell.y)
	var worn := (erosion.get_noise_2d(cell.x, cell.y) + 1) * .5
	var ridge := pow(clampf(1.0 - absf(ridges.get_noise_2d(cell.x, cell.y) * 2), 0, 1), 3)
	var detail := elevation.get_noise_2d(cell.x, cell.y)
	return clampf(1.5 + broad * 5.5 + ridge * (1 - worn) * 7 + detail * 1.8, 0, 8)

func ground_height(point: Vector2) -> float:
	return cell_info(Vector2i(point.round())).height

func _highway_height(cell: Vector2i, center: Vector2i) -> float:
	var axis := Vector2i.RIGHT if absi(cell.x - center.x) > absi(cell.y - center.y) else Vector2i.DOWN
	var distance := cell.x - center.x if axis.x != 0 else cell.y - center.y
	var neighbor := center + axis * REGION_SIZE * (1 if distance >= 0 else -1)
	return _route_plan(center, neighbor, _raw_height(center), _raw_height(neighbor), 13, 13).cells[cell].height

static func city_distance(point: Vector2, center: Vector2i) -> float:
	var local := point - Vector2(center)
	return maxf(absf(local.x), absf(local.y))

func _natural_water(cell: Vector2i) -> bool:
	return _raw_height(cell) <= 0 or elevation.get_noise_2d(cell.x,cell.y) < -.45 or absf(rivers.get_noise_2d(cell.x,cell.y)) < .023

func _route_plan(from: Vector2i, to: Vector2i, from_height: float, to_height: float, start_flat: int, end_flat: int) -> Dictionary:
	if from.x > to.x or from.y > to.y:
		return _route_plan(to, from, to_height, from_height, end_flat, start_flat)
	var key := "%s:%s:%s:%s:%s:%s" % [from,to,from_height,to_height,start_flat,end_flat]
	if route_plans.has(key):
		return route_plans[key]
	var axis := Vector2i.RIGHT if from.x != to.x else Vector2i.DOWN
	var side := Vector2i.DOWN if axis.x != 0 else Vector2i.RIGHT
	var length := absi(to.x - from.x) + absi(to.y - from.y)
	var cells := {}
	var spans: Array[Dictionary] = []
	var span_start := -1
	for index in range(length + 1):
		var cell := from + axis * index
		var fraction := clampf(float(index - start_flat) / maxi(1,length - start_flat - end_flat),0,1)
		var height := floorf(lerpf(from_height,to_height,fraction) * 2) * .5
		var bridge := false
		if index > start_flat and index < length - end_flat:
			for offset in range(-1,2):
				bridge = bridge or _natural_water(cell + side * offset)
			bridge = bridge or height - _raw_height(cell) >= 2
		if bridge:
			height = maxf(.5,height)
			if span_start < 0:
				span_start = index
		elif span_start >= 0:
			spans.append({"id": "bridge:%s:%s:%s" % [from,to,span_start], "from": from + axis * span_start, "to": cell - axis, "axis": axis, "length": index - span_start})
			span_start = -1
		for offset in range(-1,2):
			cells[cell + side * offset] = {"height": height, "bridge": bridge, "axis": axis, "edge": offset, "pier": index % 4 == 0}
	if span_start >= 0:
		spans.append({"id": "bridge:%s:%s:%s" % [from,to,span_start], "from": from + axis * span_start, "to": to, "axis": axis, "length": length - span_start + 1})
	var result := {"cells": cells, "bridges": spans}
	if route_plans.size() >= 128:
		route_plans.erase(route_plans.keys()[0])
	route_plans[key] = result
	return result

func _surface_height(cell: Vector2i, region: Dictionary, road: bool) -> float:
	if generator_version >= 5:
		if road:
			return _travel_height(cell)
		var altitude := _raw_height(cell)
		for site in sites_in(region):
			var distance := city_distance(Vector2(cell), site.cell)
			var flat: int = maxi(site.radius, site.approach_distance)
			altitude = lerpf(altitude, site.height, 1 - smoothstep(flat, site.flatten, distance))
		return floorf(altitude * 2) * .5
	var center: Vector2i = region.city.cell
	var distance := city_distance(Vector2(cell),center)
	var altitude := lerpf(_raw_height(cell), region.city.height, 1 - smoothstep(13, 21, distance))
	if road and distance >= 13:
		altitude = region.roads[cell].height
	if not road and distance > 13:
		for site in region.dungeons:
			var proximity := Vector2(cell).distance_to(site.cell)
			altitude = lerpf(altitude, site.height, 1 - smoothstep(3.2, 7, proximity))
	return floorf(altitude * 2) * .5

func _town_streets(center: Vector2i, houses: Array[Dictionary], existing: Dictionary = {}, props: Array = [], targets: Array = []) -> Dictionary:
	var blocked := {center: true, center + Vector2i(3,-3): true}
	for decoration in props:
		blocked[decoration.cell] = true
	for house in houses:
		var plot: Rect2i = house.footprint
		for x in range(plot.position.x,plot.end.x):
			for y in range(plot.position.y,plot.end.y):
				blocked[Vector2i(x,y)] = true
	for x in range(8,11):
		for y in range(8,11):
			blocked[center + Vector2i(x,y)] = true
	var streets := existing.duplicate()
	for index in range(-12,13):
		for offset in range(-1,2):
			for cell in [center + Vector2i(index,offset),center + Vector2i(offset,index)]:
				if not blocked.has(cell):
					streets[cell] = true
	for x in range(-3,4):
		for y in range(-3,4):
			var cell := center + Vector2i(x,y)
			if not blocked.has(cell):
				streets[cell] = true
	var limits := Rect2i(center - Vector2i(12,12),Vector2i(25,25))
	for house in houses:
		if house.has("door"):
			continue
		var plot: Rect2i = house.footprint
		var toward := center - plot.get_center()
		var horizontal := Vector2i.RIGHT if toward.x >= 0 else Vector2i.LEFT
		var vertical := Vector2i.DOWN if toward.y >= 0 else Vector2i.UP
		var choices: Array = [horizontal,vertical,-vertical,-horizontal] if absi(toward.x) > absi(toward.y) else [vertical,horizontal,-horizontal,-vertical]
		for facing in choices:
			var door := plot.get_center()
			if facing.x != 0:
				door.x = plot.end.x if facing.x > 0 else plot.position.x - 1
			else:
				door.y = plot.end.y if facing.y > 0 else plot.position.y - 1
			if blocked.has(door) or not limits.has_point(door):
				continue
			if targets.any(func(source): return Vector2(door).distance_to(source.point) < 2.4 or Vector2(door).distance_to(source.approach) < 2.4):
				continue
			var previous := {door: door}
			var queue: Array[Vector2i] = [door]
			var cursor := 0
			var goal := Vector2i(999999,999999)
			while cursor < queue.size():
				var cell := queue[cursor]
				cursor += 1
				if streets.has(cell):
					goal = cell
					break
				for step in DIRECTIONS:
					var next: Vector2i = cell + step
					if limits.has_point(next) and not blocked.has(next) and not previous.has(next):
						previous[next] = cell
						queue.append(next)
			if not previous.has(goal):
				continue
			house.door = Vector2(door)
			house.approach = Vector2(door)
			house.facing = facing
			while goal != door:
				streets[goal] = true
				goal = previous[goal]
			streets[door] = true
			break
	return streets

func _densify(city: Dictionary, definition: Dictionary, layout: Dictionary) -> void:
	if not definition.has("density"):
		return
	var density: Dictionary = definition.density
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash("infill:" + city.id)
	var wanted := rng.randi_range(int(density.additional_buildings[0]),int(density.additional_buildings[1]))
	var candidates: Array = layout.infill_plots.duplicate(true)
	candidates.sort_custom(func(a,b): return _hash("%s:%s" % [city.id,a]) < _hash("%s:%s" % [city.id,b]))
	var count := 0
	city.quarters = {}
	for candidate in candidates:
		if count >= wanted:
			break
		var local := Vector2i(candidate[0],candidate[1])
		var plot := Rect2i(city.cell + local,Vector2i(2,2))
		var available := true
		for x in range(plot.position.x,plot.end.x):
			for y in range(plot.position.y,plot.end.y):
				available = available and not city.streets.has(Vector2i(x,y))
		for decoration in city.decorations:
			available = available and not plot.has_point(decoration.cell)
		if not available:
			continue
		var quarter_id := ("n" if local.y < 0 else "s") + ("w" if local.x < 0 else "e")
		var quarter: Dictionary = density.quarters[quarter_id]
		var use_id: String = density.required_uses[count] if count < density.required_uses.size() else quarter.uses[rng.randi_range(0,quarter.uses.size() - 1)]
		var use: Dictionary = Areas.DATA.building_uses[use_id]
		var architecture: Dictionary = definition.architecture.duplicate(true)
		architecture.merge(use.get("architecture",{}),true)
		var floors := rng.randi_range(1,2)
		var house := {"id": "%s:house:%s:%s" % [city.id,local.x,local.y],"footprint": plot,"height": rng.randf_range(architecture.height[0],architecture.height[1]) + (.65 if floors == 2 else 0),"style": rng.randi_range(0,3),"archetype": city.archetype_id,"architecture": architecture,"use_id": use_id,"use_name": use.name,"interior_type": use.interior_type,"infill": true,"floors": floors,"quarter_id": quarter_id}
		var structures: Array[Dictionary] = city.houses.duplicate()
		structures.append_array(city.outdoor_lots)
		structures.append(house)
		var streets := _town_streets(city.cell,structures,city.streets,city.decorations,city.residents + city.books)
		if not house.has("door"):
			continue
		city.houses.append(house)
		city.streets = streets
		if not city.quarters.has(quarter_id):
			city.quarters[quarter_id] = {"name": quarter.name,"houses": []}
		city.quarters[quarter_id].houses.append(house.id)
		count += 1
	city.density = {"primary_buildings": city.houses.size() - count,"infill_buildings": count,"requested_infill": wanted}

func _hash(salt: String) -> int:
	var value: int = hash("%s:%s" % [run_seed, salt]) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	return value ^ (value >> 16)

func _biome_at(cell: Vector2i) -> int:
	var heat := temperature.get_noise_2d(cell.x, cell.y)
	if heat < -.22:
		return 3
	if heat > .23:
		return 2
	return 0 if moisture.get_noise_2d(cell.x, cell.y) > 0 else 1

func biome_at(cell: Vector2i, climate: int = -1) -> Dictionary:
	var biome := _biome_at(cell) if climate < 0 else climate
	if generator_version < 6:
		return {"biome": biome, "biome_id": Biomes.LEGACY_IDS[biome], "biome_secondary": Biomes.LEGACY_IDS[biome], "biome_blend": 0.0}
	var shore := 0.0
	if _raw_height(cell) > 0:
		var lowest := INF
		var second := INF
		for direction in DIRECTIONS:
			var height := _height_field(cell + direction * 8)
			if height < lowest:
				second = lowest
				lowest = height
			elif height < second:
				second = height
		shore = 1 - smoothstep(0, .5, second)
	return Biomes.sample(cell, biome, run_seed, temperature.get_noise_2d(cell.x, cell.y), moisture.get_noise_2d(cell.x, cell.y), shore)

func _ecology_facet(context: Dictionary) -> String:
	var id: String = Biomes.DATA.profiles[context.biome_id].get("facet", "")
	return id if not id.is_empty() and context.biome in Areas.DATA.facets[id].biomes else ""

static func chunk_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CHUNK_SIZE), floori(point.y / CHUNK_SIZE))

func _city(coordinate: Vector2i, center: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var prefixes := ["Dawn", "Amber", "Silver", "Thorn", "Mist", "Oak", "Star", "Ash"]
	var suffixes := ["haven", "watch", "brook", "reach", "crest", "gate", "ford", "fall"]
	var name: String = prefixes[rng.randi_range(0, 7)] + suffixes[rng.randi_range(0, 7)]
	var houses: Array[Dictionary] = []
	var archetype: String = Areas.DATA.start_city if coordinate == Vector2i.ZERO else Areas.city_type(_biome_at(center), _hash("city-type:%s:%s" % [coordinate.x, coordinate.y]))
	var definition: Dictionary = Areas.CITIES[archetype]
	var city_id := "city:%s:%s" % [coordinate.x, coordinate.y]
	var outdoor_lots: Array[Dictionary] = []
	for recipe in definition.outdoor_lots:
		var plot := Rect2i(center + Vector2i(recipe.position[0],recipe.position[1]),Vector2i(recipe.size[0],recipe.size[1]))
		outdoor_lots.append({"id": city_id + ":lot:" + recipe.id,"kind": recipe.kind,"name": recipe.name,"footprint": plot,"recipe": recipe,"solid_cells": [plot.get_center()] if recipe.kind == "market" else []})
	var layout: Dictionary = definition.layouts[_hash("layout:%s:%s" % [coordinate.x,coordinate.y]) % definition.layouts.size()]
	var slots: Array = layout.plots
	var count := rng.randi_range(int(definition.house_count[0]),int(definition.house_count[1]))
	var offset := rng.randi_range(0,slots.size() - 1)
	for index in range(count):
		var slot_data: Array = slots[(index + offset) % slots.size()]
		var slot := Vector2i(slot_data[0],slot_data[1])
		var footprint := Rect2i(center + slot, Vector2i(rng.randi_range(2, 3), rng.randi_range(2, 3)))
		var overlaps := false
		for existing in houses:
			if existing.footprint.intersects(footprint):
				overlaps = true
		if not overlaps:
			var use_id: String = definition.required_buildings[index] if index < definition.required_buildings.size() else definition.extra_buildings[rng.randi_range(0,definition.extra_buildings.size() - 1)]
			var use: Dictionary = Areas.DATA.building_uses[use_id]
			var architecture: Dictionary = definition.architecture.duplicate(true)
			architecture.merge(use.get("architecture",{}),true)
			houses.append({"id": "city:%s:%s:house:%s:%s" % [coordinate.x,coordinate.y,slot.x,slot.y], "footprint": footprint, "height": rng.randf_range(architecture.height[0],architecture.height[1]), "style": rng.randi_range(0, 3), "archetype": archetype, "architecture": architecture,"use_id": use_id,"use_name": use.name,"interior_type": use.interior_type})
	var structures: Array[Dictionary] = houses.duplicate()
	structures.append_array(outdoor_lots)
	var streets := _town_streets(center,structures)
	var decorations: Array[Dictionary] = []
	for house in houses:
		var facing: Vector2i = house.facing
		var side_axis := Vector2i.DOWN if facing.x != 0 else Vector2i.RIGHT
		var frontage: int = house.footprint.size.y if facing.x != 0 else house.footprint.size.x
		var corner: Vector2i = house.door
		if facing.x != 0:
			corner.y = house.footprint.position.y
		else:
			corner.x = house.footprint.position.x
		for side in [0, frontage - 1]:
			var decor_cell: Vector2i = corner + side_axis * side
			var local := decor_cell - center
			var available := not streets.has(decor_cell) and city_distance(Vector2(decor_cell),center) < 12
			for other in houses:
				available = available and not other.footprint.has_point(decor_cell)
			for lot in outdoor_lots:
				available = available and not lot.footprint.has_point(decor_cell)
			for decoration in decorations:
				available = available and decoration.cell != decor_cell
			if available:
				var props: Array = Areas.CITIES[archetype].props
				decorations.append({"cell": decor_cell, "kind": props[posmod(house.style + side, props.size())]})
	decorations.append({"cell": center + Vector2i(3, -3), "kind": "bookstand"})
	var residents: Array[Dictionary] = []
	for index in range(2):
		var side := 1 if index == 0 else -1
		residents.append({"id": "%s:npc:%s" % [city_id, index], "kind": "npc", "role": "fountain_keeper" if index == 0 else Areas.CITIES[archetype].role, "point": Vector2(center + Vector2i(side * 3, 3)), "approach": Vector2(center + Vector2i(side * 2, 3)), "city_id": city_id, "city_name": name, "biome": _biome_at(center), "appearance": _hash("npc:%s:%s" % [city_id, index]) % 4})
	var city := {"id": city_id, "cell": center, "height": _raw_height(center), "name": name, "houses": houses, "outdoor_lots": outdoor_lots, "streets": streets, "decorations": decorations, "residents": residents, "archetype_id": archetype, "layout_id": layout.id, "biome": _biome_at(center), "type": "city", "style": rng.randi_range(0, 2), "books": [{"id": city_id + ":book", "kind": "book", "book_id": Areas.CITIES[archetype].book, "point": Vector2(center + Vector2i(3,-3)), "approach": Vector2(center + Vector2i(2,-3))}]}
	return {"city": city, "definition": definition, "layout": layout}

func region_at(cell: Vector2i) -> Dictionary:
	var coordinate := Vector2i(floori(float(cell.x) / REGION_SIZE), floori(float(cell.y) / REGION_SIZE))
	if regions.has(coordinate):
		return regions[coordinate]
	if generator_version >= 5:
		return _independent_region(coordinate)
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash("region:%s:%s" % [coordinate.x, coordinate.y])
	var center := coordinate * REGION_SIZE + Vector2i.ONE * (REGION_SIZE / 2)
	var generated := _city(coordinate, center, rng)
	var city: Dictionary = generated.city
	var definition: Dictionary = generated.definition
	var layout: Dictionary = generated.layout
	var archetype: String = city.archetype_id
	var facet := ""
	for id in Areas.DATA.facets:
		var profile: Dictionary = Areas.DATA.facets[id]
		var heat := temperature.get_noise_2d(center.x,center.y)
		if archetype in profile.get("city_types",[]) or (_hash("facet:%s:%s" % [coordinate.x,coordinate.y]) % 4 == 0 and city.biome in profile.biomes and heat >= profile.get("min_temperature",-1) and heat <= profile.get("max_temperature",1)):
			facet = id
			break
	var dungeons: Array[Dictionary] = []
	for index in range(2):
		var side := 1 if index == 0 else -1
		var location := center + Vector2i(rng.randi_range(16, 24) * side, rng.randi_range(16, 24) * -side)
		var dungeon_names := ["Whispering Crypt", "Broken Sanctum", "Hollow Sepulchre", "Moonken Ruins", "Ashbound Vault", "Elder Catacombs"]
		var site_seed := _hash("dungeon:%s:%s:%s" % [coordinate.x, coordinate.y, index])
		var family := Areas.family_type(city.biome, facet, _hash("family:%s:%s:%s" % [coordinate.x, coordinate.y, index]))
		if coordinate == Vector2i.ZERO:
			family = Areas.DATA.start_families[index]
		elif index == 0 and not facet.is_empty():
			family = Areas.DATA.facets[facet].family
		if index == 1 and family == dungeons[0].family:
			for id in Areas.DUNGEONS:
				if id != family and city.biome in Areas.DUNGEONS[id].biomes and Areas.DUNGEONS[id].get("required_facet",facet) == facet:
					family = id
					break
		var road_height := _highway_height(Vector2i(location.x, center.y), center)
		var grade_limit := (absi(location.y - center.y) - 5) * .5
		var site_height := floorf(clampf(_raw_height(location), road_height - grade_limit, road_height + grade_limit) * 2) * .5
		dungeons.append({"id": "ruin:%s:%s:%s" % [coordinate.x, coordinate.y, index], "cell": location, "height": site_height, "name": dungeon_names[rng.randi_range(0, 5)], "family": family, "type": "dungeon", "seed": site_seed, "floors": 1 + site_seed % 20})
	var roads := {}
	var bridges := {}
	for direction in DIRECTIONS:
		var neighbor: Vector2i = center + direction * REGION_SIZE
		var plan := _route_plan(center,neighbor,city.height,_raw_height(neighbor),13,13)
		roads.merge(plan.cells)
		for bridge in plan.bridges:
			bridges[bridge.id] = bridge
	for site in dungeons:
		var junction := Vector2i(site.cell.x,center.y)
		var plan := _route_plan(junction,site.cell,_highway_height(junction,center),site.height,0,3)
		roads.merge(plan.cells)
		for bridge in plan.bridges:
			bridges[bridge.id] = bridge
	definition = TownTypes.apply(city,definition,_hash("town-type:" + city.id),coordinate == Vector2i.ZERO)
	_densify(city,definition,layout)
	city.gateway = TownVoxelLayout.gateway(city,roads)
	if definition.has("magic_profile"):
		var charm := TownTypes.profile_for(city,definition)
		city.magic = TownMagic.plan(city,charm.id,charm.profile,_hash("town-magic:" + city.id))
	var result := {"city": city, "dungeons": dungeons, "roads": roads, "bridges": bridges, "coordinate": coordinate, "facet": facet, "facet_center": center + Vector2i(-17,12), "transition": Areas.DATA.facets[facet].transition if not facet.is_empty() else "transition_boundary_common"}
	if regions.size() >= 32:
		regions.erase(regions.keys()[0])
	regions[coordinate] = result
	return result

func _road_at(cell: Vector2i, region: Dictionary) -> bool:
	return region.roads.has(cell) or region.get("city", {}).get("streets", {}).has(cell)

func _travel_base(cell: Vector2i) -> float:
	return clampf(2.5 + continents.get_noise_2d(cell.x, cell.y) * 2 + erosion.get_noise_2d(cell.x, cell.y) * .75, .5, 6)

func _travel_height(cell: Vector2i) -> float:
	var altitude := _travel_base(cell)
	for site in sites_in(site_planner.slots(SitePlanner.coordinate(cell))):
		var distance := city_distance(Vector2(cell), site.cell)
		var flat: int = maxi(site.radius, site.approach_distance)
		altitude = lerpf(altitude, _travel_base(site.cell), 1 - smoothstep(flat, site.flatten, distance))
	return floorf(altitude * 2) * .5

func _independent_region(coordinate: Vector2i) -> Dictionary:
	var raw: Dictionary = site_planner.slots(coordinate)
	var city := {}
	if not raw.city.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = _hash("region:%s:%s" % [coordinate.x, coordinate.y])
		var generated := _city(coordinate, raw.city.cell, rng)
		city = generated.city
		city.merge(raw.city, true)
		city.height = _travel_height(city.cell)
		if generator_version >= 6:
			city.merge(biome_at(city.cell, city.biome), true)
		var definition: Dictionary = TownTypes.apply(city, generated.definition, _hash("town-type:" + city.id), coordinate == Vector2i.ZERO)
		_densify(city, definition, generated.layout)
		if definition.has("magic_profile"):
			var charm := TownTypes.profile_for(city, definition)
			city.magic = TownMagic.plan(city, charm.id, charm.profile, _hash("town-magic:" + city.id))
	var dungeons: Array[Dictionary] = []
	for index in range(raw.dungeons.size()):
		var site: Dictionary = raw.dungeons[index].duplicate(true)
		site.biome = _biome_at(site.cell)
		site.height = _travel_height(site.cell)
		site.seed = _hash("dungeon-v5:" + site.id)
		var context := biome_at(site.cell, site.biome)
		var facet := _ecology_facet(context) if generator_version >= 6 else ""
		if generator_version >= 6:
			site.merge(context, true)
			site.facet = facet
		site.family = Areas.family_type(site.biome, facet, _hash("family-v5:" + site.id))
		if coordinate == Vector2i.ZERO:
			site.family = Areas.DATA.start_families[index]
		site.name = Areas.DUNGEONS[site.family].name
		site.floors = 1 + site.seed % 20
		dungeons.append(site)
	var locations: Array[Dictionary] = []
	for planned in raw.locations:
		var site: Dictionary = planned.duplicate(true)
		site.biome = _biome_at(site.cell)
		site.height = _travel_height(site.cell)
		site.seed = _hash("location-v5:" + site.id)
		if generator_version >= 6:
			site.merge(biome_at(site.cell, site.biome), true)
		site.name = {"ruin": "Forgotten Ruins", "castle": "Old Border Castle", "church": "Wayside Church", "temple": "Hill Temple"}[site.type]
		locations.append(SurfaceLocations.compose(site))
	var result := {"coordinate": coordinate, "city": city, "dungeons": dungeons, "locations": locations, "facet": "", "facet_center": coordinate * REGION_SIZE, "transition": "transition_boundary_common", "roads": {}, "bridges": {}, "routes": []}
	if generator_version >= 6:
		var center: Vector2i = city.cell if not city.is_empty() else (dungeons[0].cell if not dungeons.is_empty() else coordinate * REGION_SIZE + Vector2i.ONE * (REGION_SIZE / 2))
		var context := biome_at(center)
		result.facet = _ecology_facet(context)
		result.facet_center = center
		if not result.facet.is_empty():
			result.transition = Areas.DATA.facets[result.facet].transition
	var limits := Rect2i(coordinate * REGION_SIZE, Vector2i.ONE * REGION_SIZE)
	for route in site_planner.roads_for(coordinate):
		result.routes.append({"id": route.id, "from_id": route.from.id, "to_id": route.to.id, "from": route.from.approach, "to": route.to.approach, "path": route.path})
		if generator_version >= 6:
			var plan: Dictionary = site_planner.routing.materialize(route)
			for point in plan.cells:
				if not limits.has_point(point):
					continue
				var incoming: Dictionary = plan.cells[point]
				if result.roads.has(point):
					var previous: Dictionary = result.roads[point]
					var centerline: bool = previous.centerline or incoming.centerline
					if incoming.bridge and not previous.bridge:
						previous.merge(incoming,true)
					previous.centerline = centerline
				else:
					result.roads[point] = incoming.duplicate()
					result.roads[point].height = _travel_height(point)
			for span in plan.bridges:
				if span.path.any(func(point): return limits.grow(1).has_point(point)):
					result.bridges[span.id] = span
			continue
		var path := SitePlanner.raster(route.path)
		for index in range(path.size()):
			var cell: Vector2i = path[index]
			var axis: Vector2i = path[index + 1] - cell if index + 1 < path.size() else cell - path[index - 1]
			var side := Vector2i.DOWN if axis.x != 0 else Vector2i.RIGHT
			var offsets: Array[Vector2i] = [-side, Vector2i.ZERO, side]
			var corner := index > 0 and index + 1 < path.size() and path[index] - path[index - 1] != axis
			if corner and (city.is_empty() or city_distance(Vector2(cell), city.cell) > 13):
				for x in range(-1, 2):
					for y in range(-1, 2):
						var offset := Vector2i(x, y)
						if offset not in offsets:
							offsets.append(offset)
			for offset in offsets:
				var point: Vector2i = cell + offset
				if not limits.has_point(point):
					continue
				if result.roads.has(point):
					if offset == Vector2i.ZERO:
						result.roads[point].centerline = true
					continue
				var height := _travel_height(point)
				var bridge := _natural_water(point) or height - _raw_height(point) >= 2
				var edge: int = offset.x * side.x + offset.y * side.y if not corner else 0
				result.roads[point] = {"height": height, "bridge": bridge, "axis": axis, "edge": edge, "pier": posmod(point.x + point.y, 4) == 0, "route_id": route.id, "centerline": offset == Vector2i.ZERO}
				if bridge:
					result.bridges["%s:%s" % [route.id, point]] = {"id": "%s:%s" % [route.id, point], "from": point, "to": point, "axis": axis, "length": 1}
	for site in locations:
		for cell in site.walks:
			if not result.roads.has(cell):
				result.roads[cell] = {"height": _travel_height(cell), "bridge": site_planner.routing.protected_water(cell) if generator_version >= 6 else _natural_water(cell), "axis": site.facing, "edge": 0, "pier": posmod(cell.x + cell.y, 4) == 0, "route_id": site.id + ":approach", "centerline": cell in [site.cell + site.facing * int(site.approach_distance), site.cell]}
	if not city.is_empty():
		city.gateway = TownVoxelLayout.gateway(city,result.roads)
	if regions.size() >= 32:
		regions.erase(regions.keys()[0])
	regions[coordinate] = result
	return result

func _protected_nature(cell: Vector2i) -> bool:
	var region := region_at(cell)
	if _road_at(cell, region) or (not region.city.is_empty() and city_distance(Vector2(cell), region.city.cell) <= 13):
		return true
	for site in sites_in(region):
		if site.type == "dungeon":
			if Vector2(cell).distance_to(site.cell) < 3.2:
				return true
		elif site.footprint.has_point(cell):
			return true
	return false

func _micro_patch(feature: Dictionary) -> Dictionary:
	if micro_patches.has(feature.id):
		return micro_patches[feature.id]
	if micro_patches.size() >= 32:
		micro_patches.erase(micro_patches.keys()[0])
	micro_patches[feature.id] = {}
	if not MicroBiomes.nature_world(self, feature.center) or _natural_water(feature.center) or _protected_nature(feature.center):
		return {}
	var ecology := biome_at(feature.center)
	var profile := MicroBiomes.profile_for(run_seed, feature.id, ecology.biome_id)
	if profile.is_empty():
		return {}
	if profile.water_required:
		var water := false
		var radius: int = int(profile.radius)
		for x in range(-radius, radius + 1):
			if water:
				break
			for y in range(-radius, radius + 1):
				var point: Vector2i = feature.center + Vector2i(x, y)
				if x * x + y * y <= radius * radius and _natural_water(point) and MicroBiomes.nature_world(self, point) and not _protected_nature(point):
					water = true
					break
		if not water:
			return {}
	micro_patches[feature.id] = profile
	return profile

func _landmark_plan(feature: Dictionary) -> Dictionary:
	if not landmark_plans.has(feature.id):
		if landmark_plans.size() >= 32:
			landmark_plans.erase(landmark_plans.keys()[0])
		landmark_plans[feature.id] = LandmarkCatalog.plan(self, feature)
	return landmark_plans[feature.id]

func cell_info(cell: Vector2i) -> Dictionary:
	if cells.has(cell):
		return cells[cell]
	var region := region_at(cell)
	var biome := _biome_at(cell)
	var city: Dictionary = region.city
	var in_city := not city.is_empty() and city_distance(Vector2(cell),city.cell) <= 13
	if in_city:
		biome = city.biome
	for site in region.get("locations", []):
		if site.footprint.has_point(cell):
			biome = site.biome
	var road := _road_at(cell, region)
	var altitude := _surface_height(cell, region, road)
	var facet_distance: float = Vector2(cell).distance_to(region.facet_center)
	var facet_profile: Dictionary = Areas.DATA.facets.get(region.facet,{})
	var inner: float = facet_profile.get("radius",11)
	var outer: float = facet_profile.get("margin",16)
	var margin := facet_distance < outer and _hash("margin:%s:%s" % [cell.x,cell.y]) % 100 < (outer - facet_distance) * 100 / maxf(1,outer - inner)
	var facet: String = region.facet if not road and (facet_distance < inner or margin or (city.get("archetype_id", "") in facet_profile.get("city_types",[]) and in_city)) else ""
	var ecology := biome_at(cell, biome) if generator_version >= 6 else {}
	if generator_version >= 6:
		for site in sites_in(region):
			if site.type != "dungeon" and site.footprint.has_point(cell):
				ecology = {"biome": biome, "biome_id": site.biome_id, "biome_secondary": site.biome_secondary, "biome_blend": site.biome_blend}
				if site.has("biome_mix"):
					ecology.biome_mix = site.biome_mix
	var biome_profile: Dictionary = Biomes.DATA.profiles[ecology.biome_id] if generator_version >= 6 else Areas.DATA.biomes[str(biome)]
	var vegetation_id: String = ecology.get("biome_id", "")
	var density: float = biome_profile.density
	var detail_chance: float = biome_profile.get("detail_chance", 0.0)
	if generator_version >= 6:
		density = 0
		detail_chance = 0
		var threshold: float = float(_hash("ecotone:%s:%s" % [cell.x, cell.y]) % 1024) / 1024
		var cumulative := 0.0
		for component in ecology.biome_mix:
			var profile: Dictionary = Biomes.DATA.profiles[component.id]
			density += profile.density * component.weight
			detail_chance += profile.detail_chance * component.weight
			if threshold >= cumulative and threshold < cumulative + component.weight:
				biome_profile = profile
				vegetation_id = component.id
			cumulative += component.weight
	var water := _natural_water(cell) and not in_city
	var cleared := false
	for site in region.dungeons:
		if Vector2(cell).distance_to(site.cell) < 3.2:
			cleared = true
			water = false
	for site in region.get("locations", []):
		if site.footprint.has_point(cell):
			cleared = true
			water = false
	var composition := {}
	var feature := {}
	if generator_version >= 7 and not water and not in_city and not road and not cleared:
		feature = Composition.feature(run_seed, cell)
		var micro_profile := _micro_patch(feature)
		var wet_edge := false
		var slope := 0.0
		var wet_profile: bool = ecology.biome_mix.any(func(part): return part.id in ["marsh", "coast"]) or micro_profile.get("water_required", false)
		var hill_profile: bool = ecology.biome_mix.any(func(part): return part.id == "highlands")
		if wet_profile or hill_profile:
			for direction in DIRECTIONS:
				if wet_profile:
					wet_edge = wet_edge or _natural_water(cell + direction)
				if hill_profile:
					slope = maxf(slope, absf(_raw_height(cell + direction) - altitude))
		composition = Composition.sample(run_seed, cell, ecology, wet_edge, slope, micro_profile, feature)
		density = composition.density
		detail_chance = composition.detail_chance
		biome_profile = biome_profile.duplicate()
		biome_profile.props = composition.props
		biome_profile.details = composition.details
	var record: Dictionary = region.roads.get(cell,{"bridge": false,"axis": Vector2i.RIGHT,"edge": 0,"pier": false})
	var bridge: bool = road and not in_city and not cleared and record.bridge
	var terrain := "water" if water else "land"
	var prop := ""
	var walkable := not water
	if road:
		terrain = "bridge" if bridge else ("paving" if in_city or cleared else "road")
		if bridge:
			altitude = maxf(.5,altitude)
		walkable = true
	elif in_city:
		terrain = "land"
	else:
		var roll := _hash("cell:%s:%s" % [cell.x, cell.y]) % 1000
		if cleared:
			terrain = "paving"
			walkable = true
		var spaced := true
		if roll < density:
			for x in range(-1, 2):
				for y in range(-1, 2):
					if x == 0 and y == 0:
						continue
					if _hash("cell:%s:%s" % [cell.x + x, cell.y + y]) % 1000 <= roll:
						spaced = false
		if not water and not cleared and spaced and roll < density:
			var props: Array = Areas.DATA.facets[facet].props if not facet.is_empty() and generator_version < 6 else biome_profile.props
			if generator_version >= 6 and vegetation_id == "coast" and biome == 3:
				props = ["pine", "rock"]
			prop = props[roll % props.size()]
			walkable = false
		if not composition.is_empty():
			if composition.clear:
				prop = ""
				walkable = true
			if not composition.prop_override.is_empty():
				prop = composition.prop_override
				walkable = false
	if in_city:
		for lot in city.outdoor_lots:
			if lot.footprint.has_point(cell):
				terrain = "farmland" if lot.kind == "farm" else "paving"
				walkable = cell not in lot.solid_cells
		for house in city.houses:
			if house.footprint.has_point(cell):
				walkable = false
				terrain = "paving"
		for decoration in city.decorations:
			if decoration.cell == cell:
				walkable = false
				terrain = "paving"
		if cell in city.get("gateway",{}).get("solid_cells",[]):
			walkable = false
			terrain = "paving"
	for site in region.dungeons:
		var facing: Vector2i = site.get("facing", Vector2i.DOWN)
		var side := Vector2i(-facing.y, facing.x)
		if cell in [site.cell + side, site.cell - side]:
			walkable = false
	for site in region.get("locations", []):
		if cell in site.solid_cells:
			walkable = false
	if not city.is_empty() and (cell == city.cell or Rect2i(city.cell + Vector2i(8, 8), Vector2i(3, 3)).has_point(cell)):
		walkable = false
	if terrain == "water":
		altitude = 0
	var detail := ""
	var detail_roll: int = _hash("detail:%s:%s" % [cell.x,cell.y])
	var detail_present: bool = detail_roll % 1000 < int(detail_chance * 1000) if generator_version >= 6 else detail_roll % 23 == 0
	if walkable and terrain == "land" and not in_city and not biome_profile.details.is_empty() and detail_present:
		detail = biome_profile.details[_hash("detail-kind:%s:%s" % [cell.x,cell.y]) % biome_profile.details.size()]
		if detail == "biome:lily":
			detail = "biome:reeds"
	if generator_version >= 6 and terrain == "water" and ecology.biome_id == "marsh" and detail_roll % 17 == 0:
		detail = "biome:lily"
	if not composition.is_empty() and walkable and terrain == "land" and not composition.detail_override.is_empty():
		detail = composition.detail_override
	var base_height := 0.0 if water else minf(_raw_height(cell),altitude - .5)
	var bridge_edge: int = record.edge
	var bridge_side := Vector2i.DOWN if record.axis.x != 0 else Vector2i.RIGHT
	if bridge and bridge_edge != 0 and _road_at(cell + bridge_side * bridge_edge,region):
		bridge_edge = 0
	var result := {"biome": biome, "terrain": terrain, "prop": prop, "detail": detail, "facet": facet, "walkable": walkable, "height": altitude, "base_height": base_height, "base_terrain": "water" if water else "land", "bridge_axis": record.axis, "bridge_edge": bridge_edge, "bridge_pier": record.pier, "tone": _hash("tone:%s:%s" % [cell.x, cell.y]) % 3}
	result.merge(ecology, true)
	if generator_version >= 7:
		result.composition_zone = composition.get("zone", "protected")
		result.composition_motif = composition.get("motif", "")
		result.composition_feature = composition.get("feature_id", "")
		result.micro_biome_id = composition.get("micro_biome_id", "")
		result.micro_biome_name = composition.get("micro_biome_name", "")
		if not result.micro_biome_id.is_empty():
			result.tone = MicroBiomes.Biomes.salt(run_seed, result.micro_biome_id) % 3
		result.landmark_id = ""
		result.landmark_kind = ""
		if not feature.is_empty() and MicroBiomes.nature_world(self, cell):
			var landmark := _landmark_plan(feature)
			if not landmark.is_empty() and (landmark.footprint.has_point(cell) or cell in [landmark.door, landmark.approach, landmark.approach_far]):
				result.prop = ""
				result.detail = ""
				result.walkable = cell not in landmark.solid_cells
				if landmark.footprint.has_point(cell):
					result.terrain = "paving"
					result.height = landmark.height
					result.base_height = minf(_raw_height(cell), landmark.height - .5)
					result.composition_zone = "landmark"
				result.landmark_id = landmark.id
				result.landmark_kind = landmark.kind
	return result

func load_around(point: Vector2) -> bool:
	var center := chunk_at(point)
	if center == current_chunk:
		return false
	current_chunk = center
	var wanted := {}
	for x in range(center.x - CHUNK_RADIUS, center.x + CHUNK_RADIUS + 1):
		for y in range(center.y - CHUNK_RADIUS, center.y + CHUNK_RADIUS + 1):
			var coordinate := Vector2i(x, y)
			wanted[coordinate] = true
			if not chunks.has(coordinate):
				chunks[coordinate] = _build_chunk(coordinate)
			if not installed_chunks.has(coordinate):
				cells.merge(chunks[coordinate].cells)
				for cell in chunks[coordinate].cells:
					if chunks[coordinate].cells[cell].walkable:
						tiles[cell] = true
				installed_chunks[coordinate] = true
	for coordinate in chunks.keys():
		if not wanted.has(coordinate):
			if installed_chunks.has(coordinate):
				for cell in chunks[coordinate].cells:
					cells.erase(cell)
					tiles.erase(cell)
				installed_chunks.erase(coordinate)
			chunks.erase(coordinate)
	bounds = Rect2i((center - Vector2i.ONE * CHUNK_RADIUS) * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE * (CHUNK_RADIUS * 2 + 1))
	return true

func _build_chunk(coordinate: Vector2i) -> Dictionary:
	var data := {}
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var cell := coordinate * CHUNK_SIZE + Vector2i(x, y)
			data[cell] = cell_info(cell)
	var spawns := MonsterAreas.spawns(self, coordinate, data, Enemies)
	return {"cells": data, "spawns": spawns}

func nearby_sites(point: Vector2) -> Array[Dictionary]:
	var coordinate: Vector2i = region_at(Vector2i(point.round())).coordinate
	var result: Array[Dictionary] = []
	for x in range(coordinate.x - 1, coordinate.x + 2):
		for y in range(coordinate.y - 1, coordinate.y + 2):
			var region := region_at(Vector2i(x, y) * REGION_SIZE)
			result.append_array(sites_in(region))
	return result

static func sites_in(region: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not region.get("city", {}).is_empty():
		result.append(region.city)
	result.append_array(region.get("dungeons", []))
	result.append_array(region.get("locations", []))
	return result

func site_by_id(id: String, cell: Vector2i) -> Dictionary:
	for site in sites_in(region_at(cell)):
		if site.id == id and site.cell == cell:
			return site
	return {}

func city_at(point: Vector2, margin: float = 0) -> Dictionary:
	var city: Dictionary = region_at(Vector2i(point.round())).get("city", {})
	if city.is_empty() or city_distance(point, city.cell) > 13 + margin:
		return {}
	return city

func nearest_site(point: Vector2, type: String = "") -> Dictionary:
	var closest: Dictionary = {}
	var distance := INF
	var candidates := nearby_sites(point)
	if generator_version >= 5 and type in ["", "city"]:
		for planned in site_planner.nearby_settlements(SitePlanner.coordinate(Vector2i(point.round()))):
			var city: Dictionary = region_at(planned.cell).city
			if not candidates.any(func(site): return site.id == city.id):
				candidates.append(city)
	for site in candidates:
		if not type.is_empty() and site.type != type:
			continue
		var candidate: float = point.distance_squared_to(site.cell)
		if candidate < distance:
			distance = candidate
			closest = site
	return closest
