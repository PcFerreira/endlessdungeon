extends RefCounted

const World = preload("res://scripts/world.gd")
const IntegerText = preload("res://scripts/integer_text.gd")
const Catalog = preload("res://scripts/world_life_catalog.gd")
const AnimalHabitat = preload("res://scripts/animal_habitat.gd")
const Activity = preload("res://scripts/world_activity.gd")
const Travel = preload("res://scripts/surface_travel.gd")
const Roamers = preload("res://scripts/wilderness_roamers.gd")
const Wonder = preload("res://scripts/wonder_catalog.gd")
const VERSION := 1
const MAX_ACTORS := 24
const MAX_LOCAL_ACTORS := 12
const MAX_ROAD_ACTORS := 8
const MAX_CITIES := 3
const MAX_ROUTE_CELLS := 169
var catalog := Catalog.new()
var activity := Activity.new()
var roamers := Roamers.new()
var seed := 0
var world_edition := 4
var road_version := 1
var pending_road_version := 1
var tick := 0
var fraction := 0.0
var actors: Dictionary = {}
var cities: Dictionary = {}
var pending: Dictionary = {}
var route_requests := 0
var route_cursor := 0
var last_step_tick := 0

func reset(seed_value: int) -> void:
	seed = seed_value
	roamers = Roamers.new()
	world_edition = 4
	road_version = 1
	pending_road_version = 1
	tick = 0
	fraction = 0
	actors.clear()
	cities.clear()
	pending.clear()
	route_cursor = 0
	last_step_tick = 0

func advance(delta: float) -> void:
	if delta <= 0:
		return
	fraction += delta
	var steps := floori(fraction * 2)
	tick += steps
	fraction -= steps * .5

func _salt(id: String) -> int:
	return hash("life:%s:%s:%s" % [VERSION, seed, id]) & 0x7fffffff

func event_at(city_id: String) -> Dictionary:
	var offset := 0 if city_id == "city:0:0" else _salt(city_id) % 60
	var local_tick := tick + offset
	var cycle_ticks := int(catalog.data.cycle_seconds * 2)
	var cycle := floori(float(local_tick) / cycle_ticks)
	var phase_tick := local_tick % cycle_ticks
	if city_id != "city:0:0" and _salt("%s:%s" % [city_id, cycle]) % 5 == 0:
		return {}
	for episode in catalog.data.episodes:
		if phase_tick >= episode.start_seconds * 2 and phase_tick < episode.end_seconds * 2:
			return {"kind": episode.id, "phase": "active" if phase_tick < episode.finish_seconds * 2 else "aftermath", "instance_id": "%s:%s:%s" % [city_id, episode.id, cycle], "home_city_id": city_id, "start_tick": cycle * cycle_ticks + int(episode.start_seconds * 2) - offset, "finish_tick": cycle * cycle_ticks + int(episode.finish_seconds * 2) - offset, "label": episode.label, "visual": episode.visual}
	return activity.event(city_id, tick, _salt(city_id))

func sync(world, point: Vector2) -> void:
	world_edition = world.generator_version
	road_version = 2 if world.generator_version >= 6 else 1
	if pending.is_empty() and tick - last_step_tick > 10:
		for id in actors.keys():
			if id.begins_with("road:") or id.begins_with("road5:"):
				actors.erase(id)
		last_step_tick = tick
	var candidates := {}
	for chunk in world.chunks:
		var city: Dictionary = world.region_at(chunk * World.CHUNK_SIZE).city
		if not city.is_empty() and Vector2(city.cell).distance_to(point) < 28 and world.walkable(Vector2(city.residents[0].point)):
			candidates[city.id] = city
	var ordered: Array = candidates.values()
	ordered.sort_custom(func(a, b):
		var da: float = Vector2(a.cell).distance_squared_to(point)
		var db: float = Vector2(b.cell).distance_squared_to(point)
		return a.id < b.id if is_equal_approx(da, db) else da < db)
	var wanted := {}
	cities.clear()
	for city in ordered.slice(0, MAX_CITIES):
		cities[city.id] = city
		for resident in city.residents:
			_add_actor(world, resident, wanted)
		for index in range(2):
			var animal := _animal("%s:animal:%s" % [city.id, index], "town", city.biome, Vector2(city.cell) + Vector2(-2 if index == 0 else 2, 5), city)
			if not animal.is_empty():
				_add_actor(world, animal, wanted)
	_add_habitats(world, point, wanted)
	_add_roamers(world, point, wanted)
	_add_travel(world, point, wanted)
	for id in actors.keys():
		if not wanted.has(id):
			actors.erase(id)
	pending.clear()
	pending_road_version = road_version

func _add_roamers(world, point: Vector2, wanted: Dictionary) -> void:
	var hazards := Roamers.grounds(world)
	var preferred: Array = (pending.keys() if not pending.is_empty() else actors.keys()).filter(func(id): return id.begins_with("roamer:"))
	for source in roamers.sources(world,point,preferred,not pending.is_empty()):
		if not pending.is_empty() and not pending.has(source.id):
			continue
		wanted[source.id] = true
		if actors.has(source.id) and Roamers.allowed(world, actors[source.id].point, hazards):
			continue
		var actor: Dictionary = source.duplicate(true)
		actor.next_tick = tick + _salt(actor.id) % 6
		if pending.has(source.id):
			var record: Dictionary = pending[source.id]
			roamers.set_wonder(actor,record.get("wonder_id",""))
			var restored := Vector2(record.point[0],record.point[1])
			var envelope := Roamers.routing_bounds(World.chunk_at(actor.origin),World.CHUNK_SIZE)
			if envelope.has_point(Vector2i(restored.round())) and Roamers.allowed(world,restored,hazards):
				actor.point = restored
				actor.target = Vector2(record.target[0],record.target[1])
				actor.heading = Vector2(record.heading[0],record.heading[1])
				actor.activity = record.activity
				actor.next_tick = int(record.next_tick)
				actor.path = record.path.map(func(cell): return Vector2(cell[0],cell[1]))
				if not envelope.has_point(Vector2i(actor.target.round())) or not Roamers.allowed(world,actor.target,hazards) or actor.path.any(func(cell): return not envelope.has_point(Vector2i(cell.round())) or not Roamers.allowed(world,cell,hazards)):
					actor.target = actor.point
					actor.path.clear()
		actors[source.id] = actor

func _animal(id: String, habitat: String, biome: int, point: Vector2, city: Dictionary, ecology_id: String = "") -> Dictionary:
	var definition := Wonder.ambient_for(ecology_id, _salt(id)) if habitat == "wild" else {}
	if definition.is_empty():
		definition = catalog.species_for(habitat, biome, _salt(id))
	if definition.is_empty():
		return {}
	return {"id": id, "kind": "animal", "biome": biome, "species": definition.id, "asset_id": definition.asset_id, "height": definition.height, "speed": definition.speed, "idle": definition.idle, "walk": definition.walk, "medium": definition.get("medium", "land"), "point": point, "city_id": city.get("id", ""), "city_name": city.get("name", ""), "wonder_seed": _salt(id)}

func _add_habitats(world, point: Vector2, wanted: Dictionary) -> void:
	var candidates: Array = world.chunks.keys()
	candidates.sort_custom(func(a, b):
		var da: float = Vector2(a * World.CHUNK_SIZE + Vector2i(8,8)).distance_squared_to(point)
		var db: float = Vector2(b * World.CHUNK_SIZE + Vector2i(8,8)).distance_squared_to(point)
		return (a.x < b.x or (a.x == b.x and a.y < b.y)) if is_equal_approx(da, db) else da < db)
	var groups := 0
	for chunk in candidates:
		if groups >= 2 or wanted.size() >= MAX_ACTORS:
			break
		var center := Vector2(chunk * World.CHUNK_SIZE + Vector2i(8,8))
		if center.distance_to(point) > 24 or _salt("habitat:%s:%s" % [chunk.x, chunk.y]) % 3 != 0:
			continue
		var city: Dictionary = world.region_at(Vector2i(center)).city
		if not city.is_empty() and center.distance_to(city.cell) < 22:
			continue
		var medium := "water" if _salt("water:%s:%s" % [chunk.x, chunk.y]) % 2 == 0 else "land"
		var origin: Vector2 = AnimalHabitat.origin(world, center, medium)
		if not origin.is_finite() or not AnimalHabitat.usable(world, origin, medium):
			medium = "land" if medium == "water" else "water"
			origin = AnimalHabitat.origin(world, center, medium)
		if not origin.is_finite() or not AnimalHabitat.usable(world, origin, medium) or origin.distance_to(center) > 4:
			continue
		var info: Dictionary = world.cell_info(Vector2i(origin.round()))
		for index in range(2):
			var animal := _animal("habitat:%s:%s:animal:%s" % [chunk.x, chunk.y, index], "water" if medium == "water" else "wild", info.biome, origin, city, info.get("biome_id", ""))
			if not animal.is_empty():
				animal.point = AnimalHabitat.origin(world, origin + Vector2(index, 0), animal.medium)
				_add_actor(world, animal, wanted)
		groups += 1

func _add_actor(world, source: Dictionary, wanted: Dictionary) -> void:
	if wanted.size() >= MAX_LOCAL_ACTORS:
		return
	var id: String = source.id
	if not pending.is_empty() and not pending.has(id):
		return
	wanted[id] = true
	if actors.has(id):
		return
	var actor: Dictionary = source.duplicate(true)
	actor.medium = actor.get("medium", "land")
	if actor.kind == "animal" and not actor.has("biome"):
		actor.biome = world._biome_at(Vector2i(source.point.round()))
	if actor.kind == "animal" and pending.has(id):
		var record: Dictionary = pending[id]
		var definition := Wonder.ambient(record.species) if Wonder.source(record.asset_id) else catalog.species(record.species)
		if not definition.is_empty() and (record.asset_id == "wonder:" + record.species if Wonder.source(record.asset_id) else catalog.model_choices[record.species].any(func(model): return model.id == record.asset_id)):
			actor.species = record.species
			actor.asset_id = record.asset_id
			actor.medium = definition.get("medium", "land")
			for key in ["height", "speed", "idle", "walk"]:
				actor[key] = definition[key]
	actor.origin = AnimalHabitat.origin(world, source.point, actor.medium)
	if not actor.origin.is_finite():
		wanted.erase(id)
		return
	actor.point = actor.origin
	actor.spots = _spots(world, actor.origin, actor.medium)
	if actor.kind == "npc":
		var city: Dictionary = cities[actor.city_id]
		actor.event_spot = world.safe_position(Vector2(city.cell) + Vector2(1 if actor.role == "fountain_keeper" else -1, 4), 1)
		actor.routine = catalog.routine(actor.role)
	actor.path = []
	actor.target = actor.origin
	actor.heading = Vector2.DOWN
	actor.activity = "graze" if actor.kind == "animal" else "work"
	actor.next_tick = tick + _salt(id) % 8
	actor.moving = false
	if pending.has(id):
		var record: Dictionary = pending[id]
		var restored_point := Vector2(record.point[0], record.point[1])
		if AnimalHabitat.usable(world, restored_point, actor.medium):
			actor.point = restored_point
			actor.target = Vector2(record.target[0], record.target[1])
			actor.heading = Vector2(record.heading[0], record.heading[1])
			actor.activity = record.activity
			actor.next_tick = int(record.next_tick)
			for cell in record.path:
				var step := Vector2(cell[0], cell[1])
				if not AnimalHabitat.usable(world, step, actor.medium):
					actor.path.clear()
					break
				actor.path.append(step)
	actors[id] = actor

func _spots(world, origin: Vector2, medium: String = "land") -> Array[Vector2]:
	var result: Array[Vector2] = [origin]
	for offset in [Vector2(0,2), Vector2(2,0), Vector2(-2,0), Vector2(0,-2)]:
		var point: Vector2 = origin + offset
		if AnimalHabitat.can_step(world, origin, origin + offset * .5, medium) and AnimalHabitat.can_step(world, origin + offset * .5, point, medium):
			result.append(point)
	return result

func step(world, player: Vector2, delta: float) -> void:
	last_step_tick = tick
	route_requests = 0
	var ordered: Array = actors.keys()
	ordered.sort()
	if ordered.is_empty():
		return
	var roaming_grounds := Roamers.grounds(world)
	for id in ordered:
		var actor: Dictionary = actors[id]
		actor.moving = false
		if _pauses_near_player(actor, player):
			actor.heading = (player - actor.point).normalized()
			continue
		if tick >= actor.next_tick:
			if actor.get("traveling", false):
				_road_decide(actor)
			else:
				actor.next_tick = tick + (int(actor.routine.dwell_seconds * 2) if actor.kind == "npc" else 8)
				_decide(actor, player)
	for index in range(ordered.size()):
		var actor: Dictionary = actors[ordered[(route_cursor + index) % ordered.size()]]
		var policing: bool = actor.get("law_mode", "patrol") in ["guard_demand", "guard_pursuit", "guard_return"]
		if actor.get("traveling", false) and not policing:
			continue
		if actor.path.is_empty() and actor.point.distance_to(actor.target) > .1 and not _pauses_near_player(actor, player):
			actor.path = _route(world, actor.point, actor.target, actor.point if policing else actor.origin, "roamer" if actor.get("roaming",false) else actor.get("medium", "land"), roaming_grounds)
			if policing and actor.path.any(func(point): return point.distance_to(actor.origin) > 20):
				actor.path.clear()
			route_requests = 1
			route_cursor = (route_cursor + index + 1) % ordered.size()
			if actor.path.is_empty():
				actor.target = actor.point
			break
	for id in ordered:
		var actor: Dictionary = actors[id]
		if actor.get("traveling", false) and actor.get("law_mode", "patrol") not in ["guard_demand", "guard_pursuit", "guard_return"]:
			_move_road(world, actor, player, delta)
			continue
		if actor.path.is_empty() or _pauses_near_player(actor, player):
			continue
		var target: Vector2 = actor.path[0]
		var before: Vector2 = actor.point
		var direction := (target - before).normalized()
		var speed: float = actor.speed if actor.kind == "animal" else actor.get("law_speed", actor.routine.speed)
		var distance: float = minf(speed * minf(delta, .1), before.distance_to(target))
		if actor.get("medium", "land") == "water":
			var next := before + direction * distance
			actor.point = next if AnimalHabitat.usable(world, next, "water") else before
		else:
			actor.point = world.move_actor(before, direction * distance)
			if actor.get("roaming",false) and not Roamers.allowed(world,actor.point,roaming_grounds):
				actor.point = before
		actor.moving = not actor.point.is_equal_approx(before)
		if actor.moving:
			actor.heading = direction
		else:
			actor.path.clear()
			actor.target = actor.point
		if actor.point.distance_to(target) < .035 and not actor.path.is_empty():
			actor.path.pop_front()

static func _pauses_near_player(actor: Dictionary, player: Vector2) -> bool:
	if actor.kind != "npc" or actor.get("law_mode", "patrol") == "guard_return":
		return false
	return actor.point.distance_to(player) < (.85 if actor.get("law_mode", "patrol") == "guard_pursuit" else 1.75)

func _decide(actor: Dictionary, player: Vector2) -> void:
	var episode := {} if actor.get("roaming",false) else event_at(actor.city_id)
	var phase := floori(float(tick) / (actor.routine.phase_seconds * 2 if actor.kind == "npc" else 36))
	var index: int = (_salt(actor.id) + phase) % actor.spots.size()
	actor.activity = "graze" if actor.kind == "animal" else ("rest" if index == 0 else "work")
	if actor.get("roaming",false) and index != 0:
		actor.activity = "roam"
	if actor.kind == "npc" and not episode.is_empty() and episode.phase == "active":
		actor.activity = episode.kind
	if actor.kind == "animal" and actor.point.distance_to(player) < 1.4:
		var distance := -1.0
		for candidate in range(actor.spots.size()):
			var next_distance: float = actor.spots[candidate].distance_squared_to(player)
			if next_distance > distance:
				distance = next_distance
				index = candidate
	var target: Vector2 = actor.spots[index]
	if actor.kind == "npc" and not episode.is_empty() and episode.phase == "active":
		target = actor.event_spot
	if not target.is_equal_approx(actor.target):
		actor.path.clear()
		actor.target = target

func _route(world, from: Vector2, to: Vector2, origin: Vector2, medium: String = "land", hazards: Array = []) -> Array[Vector2]:
	var start := Vector2i(from.round())
	var goal := Vector2i(to.round())
	var bounds := Rect2i(Vector2i(origin.round()) - Vector2i(6,6), Vector2i(13,13))
	if medium == "roamer":
		bounds = Roamers.routing_bounds(World.chunk_at(origin),World.CHUNK_SIZE)
	var parents := {start: start}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size() and parents.size() < MAX_ROUTE_CELLS and not parents.has(goal):
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for direction in World.DIRECTIONS:
			var next: Vector2i = cell + direction
			if bounds.has_point(next) and not parents.has(next) and AnimalHabitat.can_step(world, Vector2(cell), Vector2(next), medium) and (medium != "roamer" or Roamers.allowed(world,Vector2(next),hazards)):
				parents[next] = cell
				queue.append(next)
	var result: Array[Vector2] = []
	if not parents.has(goal):
		return result
	var cell := goal
	while cell != start:
		result.push_front(Vector2(cell))
		cell = parents[cell]
	if from.distance_to(Vector2(start)) > .035:
		result.push_front(Vector2(start))
	if result.size() > 32:
		result.clear()
	return result

func residents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor in actors.values():
		if actor.kind == "npc":
			result.append(actor)
	return result

func snapshot() -> Dictionary:
	var records := pending.duplicate(true)
	for id in actors:
		var actor: Dictionary = actors[id]
		var path := []
		for point in actor.path:
			path.append([point.x, point.y])
		records[id] = {"point": [actor.point.x, actor.point.y], "target": [actor.target.x, actor.target.y], "heading": [actor.heading.x, actor.heading.y], "path": path, "activity": actor.activity, "next_tick": actor.next_tick}
		if actor.kind == "animal":
			records[id].species = actor.species
			records[id].asset_id = actor.asset_id
		if actor.get("roaming",false):
			records[id].wonder_id = actor.get("wonder_id","")
		if actor.get("traveling", false):
			records[id].road_direction = actor.road_direction
			records[id].rest_until = actor.rest_until
			records[id].waypoint = actor.waypoint
			if actor.role == "guard":
				records[id].law_cooldown_tick = actor.get("law_cooldown_tick", 0)
				records[id].law_windup_tick = actor.get("law_windup_tick", 0)
	var result := {"version": VERSION, "tick": tick, "fraction": fraction, "actors": records}
	if world_edition >= 5:
		result.context = {"edition": world_edition, "seed": str(seed), "roads": road_version}
	return result

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _point(value, center: Vector2) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1]) and Vector2(value[0], value[1]).distance_to(center) < 14

static func valid_snapshot(data, seed_value: String = "", edition: int = 0) -> bool:
	if not data is Dictionary or data.get("version") != VERSION or not _number(data.get("tick")) or data.tick < 0 or data.tick > 1000000000000 or data.tick != floorf(data.tick):
		return false
	if not _number(data.get("fraction")) or data.fraction < 0 or data.fraction >= .5 or not data.get("actors") is Dictionary or data.actors.size() > MAX_ACTORS:
		return false
	if data.actors.keys().filter(func(id): return id is String and id.begins_with("roamer:")).size() > Roamers.MAX_ACTORS:
		return false
	var planner = null
	var road_world
	if data.has("context"):
		var context = data.context
		if not context is Dictionary or not _number(context.get("edition")) or context.edition != int(context.edition) or int(context.edition) not in [5, 6, 7] or (edition != 0 and context.edition != edition) or not IntegerText.valid(context.get("seed")) or (not seed_value.is_empty() and context.seed != seed_value):
			return false
		var roads = context.get("roads",1)
		if not _number(roads) or roads != int(roads) or int(roads) not in [1,2] or (roads == 2 and context.edition < 6):
			return false
		if roads == 2:
			road_world = World.new()
			road_world.generate(context.seed.to_int(),int(context.edition))
			planner = road_world.site_planner
		else:
			planner = Travel.Planner.new(context.seed.to_int())
	elif edition >= 5:
		return false
	for id in data.actors:
		if not id is String:
			return false
		var fields: PackedStringArray = id.split(":")
		if fields[0] in ["road", "road5", "watch"]:
			if not _valid_travel_record(id, data.actors[id], data.tick, planner):
				return false
			continue
		var roaming := fields[0] == "roamer"
		if roaming:
			if fields.size() != 4 or not fields[1].is_valid_int() or not fields[2].is_valid_int() or fields[3] not in ["0", "1"]:
				return false
		elif fields.size() != 5 or fields[0] not in ["city", "habitat"] or not fields[1].is_valid_int() or not fields[2].is_valid_int() or fields[3] not in ["npc", "animal"] or fields[4] not in ["0", "1"] or (fields[0] == "habitat" and fields[3] != "animal"):
			return false
		var size := World.REGION_SIZE if fields[0] == "city" else World.CHUNK_SIZE
		if not IntegerText.bounded(fields[1], 9600000.0 / size) or not IntegerText.bounded(fields[2], 9600000.0 / size):
			return false
		var coordinate := Vector2i(fields[1].to_int(), fields[2].to_int())
		var canonical := "roamer:%s:%s:%s" % [coordinate.x,coordinate.y,fields[3]] if roaming else "%s:%s:%s:%s:%s" % [fields[0], coordinate.x, coordinate.y, fields[3], fields[4]]
		if absi(coordinate.x * size) > 9600000 or absi(coordinate.y * size) > 9600000 or id != canonical:
			return false
		var record = data.actors[id]
		var center := Vector2(coordinate * size) + Vector2.ONE * size * .5
		if planner != null and fields[0] == "city":
			var town: Dictionary = planner.settlement(coordinate)
			if town.is_empty():
				return false
			center = Vector2(town.cell)
		if not record is Dictionary or not _point(record.get("point"), center) or not _point(record.get("target"), center) or not _point(record.get("heading"), Vector2.ZERO):
			return false
		var envelope := Roamers.routing_bounds(coordinate,size)
		if roaming and (not envelope.has_point(Vector2i(Vector2(record.point[0],record.point[1]).round())) or not envelope.has_point(Vector2i(Vector2(record.target[0],record.target[1]).round()))):
			return false
		if record.has("wonder_id") and (not roaming or not record.wonder_id is String or (not record.wonder_id.is_empty() and Roamers.Wonder.npc(record.wonder_id).is_empty())):
			return false
		if fields[3] == "animal" and (not record.get("species") is String or record.species.is_empty() or record.species.length() > 128 or not record.get("asset_id") is String or record.asset_id.is_empty() or record.asset_id.length() > 512):
			return false
		if not roaming and fields[3] == "animal" and (record.asset_id.begins_with("wonder:") or Wonder.DATA.creatures.has(record.species)) and (fields[0] != "habitat" or not Wonder.source(record.asset_id) or record.asset_id != "wonder:" + record.species):
			return false
		if not record.get("path") is Array or record.path.size() > 32 or not record.get("activity") is String or record.activity.length() > 128 or not _number(record.get("next_tick")) or record.next_tick < 0 or record.next_tick > data.tick + 64 or record.next_tick != floorf(record.next_tick):
			return false
		for point in record.path:
			if not _point(point, center):
				return false
			if roaming and not envelope.has_point(Vector2i(Vector2(point[0],point[1]).round())):
				return false
	return true

func restore(data: Dictionary, seed_value: int) -> bool:
	if not valid_snapshot(data, str(seed_value)):
		return false
	reset(seed_value)
	world_edition = int(data.context.edition) if data.has("context") else 4
	road_version = int(data.get("context",{}).get("roads",1))
	pending_road_version = road_version
	tick = int(data.tick)
	last_step_tick = tick
	fraction = data.fraction
	pending = data.actors.duplicate(true)
	return true

func _add_travel(world, point: Vector2, wanted: Dictionary) -> void:
	var sources := []
	for city in cities.values():
		for index in range(2):
			var center := Vector2(city.cell)
			var waypoints := [center + Vector2(1,1), center + Vector2(12,1), center + Vector2(1,1), center + Vector2(1,12), center + Vector2(1,1), center + Vector2(-12,1), center + Vector2(1,1), center + Vector2(1,-12)]
			var initial: Vector2 = waypoints[1 + index * 2]
			sources.append({"id": "watch:%s:%s:%s" % [city.id.split(":")[1], city.id.split(":")[2], index], "kind":"npc", "role":"guard", "point":initial, "origin":center, "city_id":city.id, "city_name":city.name, "destination":city.name, "biome":city.biome, "appearance":index, "waypoints":waypoints, "waypoint":2 + index * 2, "road_direction":1, "rest_until":tick, "traveling":true})
	sources.append_array(_independent_road_sources(world, point) if world.generator_version >= 5 else _legacy_road_sources(world, point))
	sources.sort_custom(func(a,b):
		var da: float = a.point.distance_squared_to(point)
		var db: float = b.point.distance_squared_to(point)
		return a.id < b.id if is_equal_approx(da,db) else da < db)
	for source in sources.slice(0, MAX_ROAD_ACTORS):
		if not pending.is_empty() and not pending.has(source.id):
			continue
		wanted[source.id] = true
		if actors.has(source.id):
			continue
		var actor: Dictionary = source.duplicate(true)
		actor.routine = activity.role(actor.role)
		actor.target = actor.point
		actor.heading = Vector2.DOWN
		actor.path = []
		actor.next_tick = tick
		actor.moving = false
		actor.activity = "patrol" if actor.role == "guard" else "travel"
		if pending.has(actor.id):
			var record: Dictionary = pending[actor.id]
			var position := Vector2(record.point[0], record.point[1])
			if world.walkable(position):
				actor.point = position
				actor.target = Vector2(record.target[0], record.target[1])
				actor.heading = Vector2(record.heading[0], record.heading[1])
				actor.activity = record.activity
				actor.next_tick = int(record.next_tick)
				actor.road_direction = int(record.road_direction)
				actor.rest_until = int(record.rest_until)
				actor.waypoint = int(record.waypoint)
				if actor.role == "guard":
					actor.path = record.path.map(func(cell): return Vector2(cell[0],cell[1]))
					if actor.path.any(func(cell): return not world.walkable(cell)):
						actor.path.clear()
					actor.law_mode = record.activity if record.activity in ["guard_demand", "guard_pursuit", "guard_return"] else "patrol"
					actor.law_cooldown_tick = int(record.get("law_cooldown_tick",0))
					actor.law_windup_tick = int(record.get("law_windup_tick",0))
		actors[actor.id] = actor

func _legacy_road_sources(world, point: Vector2) -> Array:
	var sources := []
	var coordinate: Vector2i = world.region_at(Vector2i(point.round())).coordinate
	var travelers: Array = activity.data.travelers.filter(func(role): return role.id != "merchant")
	for x in range(coordinate.x - 1, coordinate.x + 2):
		for y in range(coordinate.y - 1, coordinate.y + 2):
			var region: Dictionary = world.region_at(Vector2i(x,y) * World.REGION_SIZE)
			for axis_index in range(2):
				var axis := Vector2.RIGHT if axis_index == 0 else Vector2.DOWN
				var neighbor: Dictionary = world.region_at(region.city.cell + Vector2i(axis) * World.REGION_SIZE)
				for slot in range(3):
					var id := "road:%s:%s:%s:%s" % [x,y,axis_index,slot]
					var definition: Dictionary = activity.role("merchant") if slot == 0 else travelers[_salt(id) % travelers.size()]
					var side := Vector2(-axis.y, axis.x) * (.55 if slot % 2 == 0 else -.55)
					var start := Vector2(region.city.cell) + axis * 12 + side
					var finish := Vector2(neighbor.city.cell) - axis * 12 + side
					var length := start.distance_to(finish)
					var travel_seconds: float = length / definition.speed
					var period: float = (travel_seconds + definition.pause_seconds) * 2
					var offset: float = 0 if x == 0 and y == 0 and axis_index == 0 and slot == 0 else _salt(id) % ceili(period)
					var phase := fposmod(tick * .5 + offset, period)
					var reverse: bool = phase >= travel_seconds + definition.pause_seconds
					var leg: float = phase - (travel_seconds + definition.pause_seconds if reverse else 0)
					var progress := clampf(leg / travel_seconds, 0, 1)
					var position := finish.lerp(start, progress) if reverse else start.lerp(finish, progress)
					var actual: Vector2 = actors[id].point if actors.has(id) else position
					if pending.has(id):
						actual = Vector2(pending[id].point[0],pending[id].point[1])
					var limit := 56 if pending.has(id) else (34 if actors.has(id) else 30)
					if actual.distance_to(point) > limit or not world.walkable(actual):
						continue
					sources.append({"id":id, "kind":"npc", "role":definition.id, "point":position, "origin":start, "city_id":region.city.id, "city_name":region.city.name, "destination":neighbor.city.name, "biome":region.city.biome, "appearance":slot, "waypoints":[start,finish], "waypoint":0 if reverse else 1, "road_direction":-1 if reverse else 1, "rest_until":tick + maxi(0, ceili((travel_seconds + definition.pause_seconds - leg) * 2)) if leg >= travel_seconds else tick, "traveling":true})
	return sources

func _independent_road_sources(world, point: Vector2) -> Array:
	var sources := []
	var routes := {}
	var coordinate: Vector2i = world.region_at(Vector2i(point.round())).coordinate
	for x in range(coordinate.x - 1, coordinate.x + 2):
		for y in range(coordinate.y - 1, coordinate.y + 2):
			for route in world.region_at(Vector2i(x, y) * World.REGION_SIZE).routes:
				if route.from_id.begins_with("city:") and route.to_id.begins_with("city:") and Travel.near_path(point, route.path, 56):
					routes[route.id] = route
	var travelers: Array = activity.data.travelers.filter(func(role): return role.id != "merchant")
	for route in routes.values():
		for slot in range(3):
			var id := Travel.identity(route.from_id, route.to_id, slot)
			var resolved := Travel.resolve(world.site_planner, id)
			if resolved.is_empty():
				continue
			var definition: Dictionary = activity.role("merchant") if slot == 0 else travelers[_salt(id) % travelers.size()]
			var travel_seconds: float = Travel.length(resolved.points) / definition.speed
			var period: float = (travel_seconds + definition.pause_seconds) * 2
			var offset: float = 0 if resolved.from.id == "city:0:0" and slot == 0 else _salt(id) % ceili(period)
			var phase := fposmod(tick * .5 + offset, period)
			var reverse: bool = phase >= travel_seconds + definition.pause_seconds
			var leg: float = phase - (travel_seconds + definition.pause_seconds if reverse else 0)
			var sample := Travel.at_distance(resolved.points, minf(leg, travel_seconds) * definition.speed, reverse)
			if pending.has(id) and pending_road_version == 1 and road_version == 2:
				_remap_road_record(id,resolved)
			var actual: Vector2 = actors[id].point if actors.has(id) else sample.point
			if pending.has(id):
				actual = Vector2(pending[id].point[0], pending[id].point[1])
			var limit := 56 if pending.has(id) else (34 if actors.has(id) else 30)
			if actual.distance_to(point) > limit or not world.walkable(actual):
				continue
			var first: Dictionary = world.region_at(resolved.from.cell).city
			var last: Dictionary = world.region_at(resolved.to.cell).city
			sources.append({"id": id, "kind": "npc", "role": definition.id, "point": sample.point, "origin": resolved.points[0], "city_id": first.id, "city_name": first.name, "destination": last.name, "biome": world._biome_at(Vector2i(actual.round())), "appearance": slot, "waypoints": resolved.points, "waypoint": sample.waypoint, "road_direction": -1 if reverse else 1, "rest_until": tick + maxi(0, ceili((travel_seconds + definition.pause_seconds - leg) * 2)) if leg >= travel_seconds else tick, "traveling": true, "polyline": true})
	return sources

func _remap_road_record(id: String, route: Dictionary) -> void:
	var legacy := Travel.resolve(Travel.Planner.new(seed),id)
	if legacy.is_empty():
		return
	var record: Dictionary = pending[id]
	var old_length := Travel.length(legacy.points)
	var new_length := Travel.length(route.points)
	for key in ["point","target"]:
		var point := Vector2(record[key][0],record[key][1])
		var fraction := Travel.projected_distance(legacy.points,point) / maxf(.001,old_length)
		var reverse: bool = record.road_direction == -1
		var mapped := Travel.at_distance(route.points,new_length * (1 - fraction if reverse else fraction),reverse)
		record[key] = [mapped.point.x,mapped.point.y]
		if key == "point":
			record.waypoint = mapped.waypoint

func _road_decide(actor: Dictionary) -> void:
	if actor.get("law_mode", "patrol") in ["guard_demand", "guard_pursuit", "guard_return"]:
		actor.activity = actor.law_mode
		actor.next_tick = tick + 2
		return
	actor.activity = ("watch" if actor.role == "guard" else "rest") if tick < actor.rest_until else ("patrol" if actor.role == "guard" else "travel")
	actor.next_tick = tick + 2

func _move_road(world, actor: Dictionary, player: Vector2, delta: float) -> void:
	if actor.point.distance_to(player) < 1.75 or tick < actor.rest_until:
		return
	var goal: Vector2 = actor.waypoints[actor.waypoint]
	if actor.point.distance_to(goal) < .06:
		if actor.get("polyline", false) and actor.waypoint > 0 and actor.waypoint < actor.waypoints.size() - 1:
			actor.waypoint += actor.road_direction
			return
		actor.rest_until = tick + int(actor.routine.pause_seconds * 2)
		if actor.role == "guard":
			actor.waypoint = (actor.waypoint + 1) % actor.waypoints.size()
		elif actor.get("polyline", false):
			actor.road_direction *= -1
			actor.waypoint += actor.road_direction
		else:
			actor.road_direction *= -1
			actor.waypoint = 1 - actor.waypoint
		_road_decide(actor)
		return
	var direction: Vector2 = (goal - actor.point).normalized()
	actor.target = actor.point + direction * minf(1, actor.point.distance_to(goal))
	if not world.walkable(actor.target):
		return
	var before: Vector2 = actor.point
	actor.point = world.move_actor(before, direction * minf(actor.routine.speed * minf(delta,.1), before.distance_to(goal)))
	actor.moving = not actor.point.is_equal_approx(before)
	if actor.moving:
		actor.heading = direction
		actor.activity = "patrol" if actor.role == "guard" else "travel"

static func _valid_travel_record(id: String, record, tick_value: float, planner = null) -> bool:
	var fields := id.split(":")
	if fields[0] == "road5":
		return _valid_independent_travel(id, record, tick_value, planner)
	if fields[0] == "road" and planner != null:
		return false
	var guard := fields[0] == "watch"
	if fields.size() != (4 if guard else 5):
		return false
	if not IntegerText.bounded(fields[1], 9600000.0 / World.REGION_SIZE) or not IntegerText.bounded(fields[2], 9600000.0 / World.REGION_SIZE):
		return false
	for field in fields.slice(1):
		if not IntegerText.valid(field) or str(field.to_int()) != field:
			return false
	var coordinate := Vector2i(fields[1].to_int(), fields[2].to_int())
	if absi(coordinate.x * World.REGION_SIZE) > 9600000 or absi(coordinate.y * World.REGION_SIZE) > 9600000 or int(fields[3]) not in [0,1] or (not guard and int(fields[4]) not in [0,1,2]):
		return false
	var center := Vector2(coordinate * World.REGION_SIZE) + Vector2.ONE * World.REGION_SIZE * .5
	if guard and planner != null:
		var town: Dictionary = planner.settlement(coordinate)
		if town.is_empty():
			return false
		center = Vector2(town.cell)
	var activities := ["patrol","watch","travel","rest","guard_demand","guard_pursuit","guard_return"] if guard else ["travel","rest"]
	if not record is Dictionary or not record.get("path") is Array or record.path.size() > (32 if guard else 0) or not _point(record.get("heading"), Vector2.ZERO) or not record.get("activity") is String or record.activity not in activities:
		return false
	for key in ["point", "target"]:
		var value = record.get(key)
		if not value is Array or value.size() != 2 or not _number(value[0]) or not _number(value[1]):
			return false
		var local := Vector2(value[0],value[1]) - center
		if guard:
			if local.length() > 20:
				return false
		else:
			var along := local.x if int(fields[3]) == 0 else local.y
			var side := local.y if int(fields[3]) == 0 else local.x
			if along < 11 or along > World.REGION_SIZE - 11 or absf(side) > 1.2:
				return false
	for point in record.path:
		if not point is Array or point.size() != 2 or not _number(point[0]) or not _number(point[1]) or Vector2(point[0],point[1]).distance_to(center) > 20:
			return false
	for key in ["law_cooldown_tick", "law_windup_tick"]:
		var value = record.get(key,0)
		if not _number(value) or value != floorf(value) or value < 0 or value > tick_value + 64:
			return false
	for key in ["next_tick", "rest_until", "waypoint", "road_direction"]:
		if not _number(record.get(key)) or record[key] != floorf(record[key]):
			return false
	return record.next_tick >= 0 and record.next_tick <= tick_value + 64 and record.rest_until >= 0 and record.rest_until <= tick_value + 64 and int(record.road_direction) in [-1,1] and record.waypoint >= 0 and record.waypoint < (8 if guard else 2)

static func _valid_independent_travel(id: String, record, tick_value: float, planner) -> bool:
	if planner == null or not record is Dictionary or not record.get("path") is Array or not record.path.is_empty() or not _point(record.get("heading"), Vector2.ZERO) or record.get("activity") not in ["travel", "rest"]:
		return false
	var route := Travel.resolve(planner, id)
	if route.is_empty():
		return false
	for key in ["point", "target"]:
		var value = record.get(key)
		if not value is Array or value.size() != 2 or not _number(value[0]) or not _number(value[1]) or not Travel.near_path(Vector2(value[0], value[1]), route.points):
			return false
	for key in ["next_tick", "rest_until", "waypoint", "road_direction"]:
		if not _number(record.get(key)) or record[key] != floorf(record[key]):
			return false
	return record.next_tick >= 0 and record.next_tick <= tick_value + 64 and record.rest_until >= 0 and record.rest_until <= tick_value + 64 and int(record.road_direction) in [-1, 1] and record.waypoint >= 0 and record.waypoint < route.points.size()
