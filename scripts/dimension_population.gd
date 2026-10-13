extends Node3D

const Actors = preload("res://scripts/actor_models.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const ACTIVE_LIMIT := 64
const RECORD_LIMIT := 512
const SAFE_RADIUS := 24.0
static var safety_cache: Dictionary = {}
var game
var dimensions: Dictionary = {}
var actors: Dictionary = {}
var models: Dictionary = {}
var motions: Dictionary = {}
var recipes: Array[Dictionary] = []
var world_id := 0

static func number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func integer(value, low: int, high: int) -> bool:
	return number(value, low, high) and value == int(value)

static func pair(value, extent: float = 65536) -> bool:
	return value is Array and value.size() == 2 and value.all(func(item): return number(item, -extent, extent))

static func token(value) -> bool:
	return value is String and not value.is_empty() and value.length() <= 64 and value.to_snake_case() == value and not value.contains(":") and not value.contains("/")

static func text_value(value, maximum: int = 80) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= maximum

static func point(value: Array) -> Vector2:
	return Vector2(value[0], value[1])

static func extent(definition: Dictionary) -> Rect2:
	var values: Array = definition.bounds
	return Rect2(values[0], values[1], values[2], values[3])

static func valid(definition: Dictionary) -> bool:
	if not token(definition.get("id")) or not definition.get("bounds") is Array or definition.bounds.size() != 4 or not definition.bounds.all(func(value): return number(value, -65536, 65536)) or definition.bounds[2] <= 0 or definition.bounds[3] <= 0 or not pair(definition.get("spawn")) or not pair(definition.get("return_portal")):
		return false
	var ids := {}
	var total := 0
	for site in definition.get("sites", []):
		var residents = site.get("residents", [])
		if not residents is Array or residents.size() > 16:
			return false
		for resident in residents:
			if not resident is Dictionary or not token(resident.get("id")) or ids.has(resident.id) or not text_value(resident.get("name")) or not token(resident.get("role")) or not pair(resident.get("offset"), 64):
				return false
			if not extent(definition).has_point(point(site.cell) + point(resident.offset)) or not number(resident.get("speed", .8), .2, 1.4) or not integer(resident.get("appearance", 0), 0, 255):
				return false
			var route = resident.get("route", [resident.offset])
			if not route is Array or route.is_empty() or route.size() > 16 or not route.all(func(item): return pair(item, 64) and extent(definition).has_point(point(site.cell) + point(item))):
				return false
			var dialogue = resident.get("dialogue")
			if not dialogue is Array or dialogue.is_empty() or dialogue.size() > 16 or not dialogue.all(func(line): return text_value(line, 1024)):
				return false
			if resident.has("role_label") and not text_value(resident.role_label):
				return false
			ids[resident.id] = true
			total += 1
	if total > RECORD_LIMIT:
		return false
	var encounters = definition.get("encounters", [])
	if not encounters is Array or encounters.size() > 128:
		return false
	ids.clear()
	for ground in encounters:
		if not ground is Dictionary or not token(ground.get("id")) or ids.has(ground.id) or not text_value(ground.get("label")) or not pair(ground.get("cell")) or not extent(definition).has_point(point(ground.cell)) or not integer(ground.get("radius"), 3, 12):
			return false
		var members = ground.get("members")
		if not members is Array or members.is_empty() or members.size() > 8:
			return false
		var member_ids := {}
		for member in members:
			if not member is Dictionary or not token(member.get("id")) or member_ids.has(member.id) or not member.get("enemy_id") is String or not Enemies.TYPES.any(func(enemy): return enemy.id == member.enemy_id) or not pair(member.get("offset"), ground.radius):
				return false
			var home := point(ground.cell) + point(member.offset)
			if not extent(definition).has_point(home) or home.distance_to(point(definition.spawn)) <= SAFE_RADIUS + ground.radius + 3 or home.distance_to(point(definition.return_portal)) <= SAFE_RADIUS + ground.radius + 3:
				return false
			member_ids[member.id] = true
		ids[ground.id] = true
	return true

static func hostile_point_allowed(world, location: Vector2) -> bool:
	if location.distance_to(Vector2(world.start)) <= SAFE_RADIUS or location.distance_to(Vector2(world.return_portal)) <= SAFE_RADIUS:
		return false
	var id: int = world.get_instance_id()
	if not safety_cache.has(id) or safety_cache[id].owner.get_ref() != world:
		if safety_cache.size() >= 8:
			safety_cache.erase(safety_cache.keys()[0])
		var boxes: Array[Rect2] = []
		var doors: Array[Vector2] = []
		for site in world.authored_sites():
			if site.type in ["city", "village"]:
				boxes.append(Rect2(site.footprint).grow(8))
			doors.append(Vector2(site.approach))
			for house in site.get("houses", []):
				boxes.append(Rect2(house.footprint).grow(2))
				doors.append(Vector2(house.get("approach", site.approach)))
		safety_cache[id] = {"owner": weakref(world), "boxes": boxes, "doors": doors}
	var zones: Dictionary = safety_cache[id]
	if zones.boxes.any(func(box): return box.has_point(location)) or zones.doors.any(func(door): return door.distance_to(location) < 3):
		return false
	return true

static func spawns(world, _coordinate: Vector2i, cells: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ground in world.definition.get("encounters", []):
		var ground_id: String = "dimension:%s:grounds:%s" % [world.dimension_id, ground.id]
		for member in ground.members:
			var location := Vector2i(point(ground.cell) + point(member.offset))
			if not cells.has(location) or not cells[location].walkable or not hostile_point_allowed(world, Vector2(location)):
				continue
			var kind: int = Enemies.index_of(member.enemy_id)
			if not Enemies.TYPES[kind].get("enabled", true):
				continue
			result.append({"id": ground_id + ":" + member.id, "area_id": ground_id, "cell": location, "home": Vector2(location), "radius": int(ground.radius), "label": ground.label, "kind": kind})
	result.sort_custom(func(left, right): return left.id < right.id)
	return result.slice(0, 2)

static func resident_records(world) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in world.authored_sites():
		for recipe in site.get("population_residents", []):
			var home := Vector2(site.cell) + point(recipe.offset)
			var route: Array[Vector2] = []
			for waypoint in recipe.get("route", [recipe.offset, [recipe.offset[0] + 1, recipe.offset[1]]]):
				route.append(Vector2(site.cell) + point(waypoint))
			result.append({"id": "dimension:%s:resident:%s" % [world.dimension_id, recipe.id], "kind": "npc", "dimension_id": world.dimension_id, "name": recipe.name, "role": recipe.role, "role_label": recipe.get("role_label", recipe.role.replace("_", " ").capitalize()), "home": home, "point": home, "route": route, "route_index": 1 if route.size() > 1 else 0, "speed": float(recipe.get("speed", .8)), "pause": 0.0, "heading": Vector2.DOWN, "moving": false, "appearance": int(recipe.get("appearance", 0)), "dialogue": recipe.dialogue.duplicate(), "city_id": site.id, "city_name": site.name, "site_id": site.id, "biome": site.biome})
	return result

static func valid_snapshot(data, seed_value: String = "") -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not data.get("seed") is String or not data.seed.is_valid_int() or not seed_value.is_empty() and data.seed != seed_value or not data.get("dimensions") is Dictionary or data.dimensions.size() > 32:
		return false
	var catalog = load("res://scripts/dimension_catalog.gd")
	for id in data.dimensions:
		if not id is String or not data.dimensions[id] is Dictionary:
			return false
		var definition: Dictionary = catalog.definition(id)
		var record: Dictionary = data.dimensions[id]
		if definition.is_empty() or not integer(record.get("revision"), 1, 99999) or record.revision != definition.map_version and not definition.get("compatible_revisions", []).any(func(revision): return revision == record.revision) or not record.get("residents") is Dictionary or record.residents.size() > RECORD_LIMIT:
			return false
		for npc_id in record.residents:
			var state = record.residents[npc_id]
			if not npc_id is String or not npc_id.begins_with("dimension:%s:resident:" % id) or npc_id.length() > 192 or not state is Dictionary or not pair(state.get("point")) or not extent(definition).has_point(point(state.point)) or not pair(state.get("heading"), 1) or not integer(state.get("route_index"), 0, 15) or not integer(state.get("line"), 0, 15) or not state.get("met") is bool or not number(state.get("pause"), 0, 10):
				return false
			if not token(npc_id.trim_prefix("dimension:%s:resident:" % id)):
				return false
	return true

func enabled() -> bool:
	return game != null and game.offline_actions_allowed() and game.dimension.active and game.layer == "overworld"

func _record(id: String) -> Dictionary:
	if not dimensions.has(id):
		dimensions[id] = {"revision": game.world.map_version, "residents": {}}
	return dimensions[id]

func _remember(actor: Dictionary) -> void:
	var record := _record(actor.dimension_id)
	var old: Dictionary = record.residents.get(actor.id, {})
	record.residents[actor.id] = {"point": [actor.point.x, actor.point.y], "heading": [actor.heading.x, actor.heading.y], "route_index": actor.route_index, "pause": actor.pause, "met": old.get("met", false), "line": old.get("line", 0)}

func clear_location(remember: bool = true) -> void:
	for id in actors:
		if remember:
			_remember(actors[id])
		if game != null and game.world_view.npc_models.get(id) == models.get(id):
			game.world_view.npc_models.erase(id)
	for model in models.values():
		remove_child(model)
		model.queue_free()
	actors.clear()
	models.clear()
	motions.clear()
	recipes.clear()
	world_id = 0

func reset() -> void:
	clear_location(false)
	dimensions.clear()

func snapshot() -> Dictionary:
	for actor in actors.values():
		_remember(actor)
	return {} if dimensions.is_empty() else {"version": 1, "seed": str(game.run_seed), "dimensions": dimensions.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data, str(game.run_seed)):
		return false
	reset()
	dimensions = data.get("dimensions", {}).duplicate(true)
	return true

func sync() -> void:
	if not enabled():
		clear_location()
		return
	if world_id != game.world.get_instance_id():
		clear_location()
		world_id = game.world.get_instance_id()
		recipes = resident_records(game.world)
	var record := _record(game.world.dimension_id)
	record.revision = game.world.map_version
	var wanted := {}
	for recipe in recipes:
		if wanted.size() >= ACTIVE_LIMIT or not game.world.chunks.has(game.world.chunk_at(recipe.home)) or recipe.home.distance_to(game.player_point) > 56:
			continue
		wanted[recipe.id] = recipe
	for id in actors.keys():
		if wanted.has(id):
			continue
		_remember(actors[id])
		if game.world_view.npc_models.get(id) == models[id]:
			game.world_view.npc_models.erase(id)
		remove_child(models[id])
		models[id].queue_free()
		models.erase(id)
		actors.erase(id)
		motions.erase(id)
	for id in wanted:
		if not actors.has(id):
			var actor: Dictionary = wanted[id].duplicate(true)
			var saved: Dictionary = record.residents.get(id, {})
			actor.point = game.world.safe_position(point(saved.get("point", [actor.home.x, actor.home.y])), 3)
			if actor.point.distance_to(actor.home) > 64:
				actor.point = game.world.safe_position(actor.home, 3)
			actor.heading = point(saved.get("heading", [0, 1]))
			actor.route_index = int(saved.get("route_index", actor.route_index)) % actor.route.size()
			actor.pause = float(saved.get("pause", 0))
			var model := Actors.create(actor.appearance, actor)
			var label := Label3D.new()
			label.text = actor.name
			label.position.y = 1.65
			label.font_size = 24
			label.pixel_size = .007
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			model.add_child(label)
			add_child(model)
			actors[id] = actor
			models[id] = model
		game.world_view.npc_models[id] = models[id]
		_place(actors[id])

func _place(actor: Dictionary) -> void:
	var model: Node3D = models[actor.id]
	model.position = Vector3(actor.point.x, game.world.ground_height(actor.point), actor.point.y)
	model.rotation.y = atan2(actor.heading.x, actor.heading.y)
	var desired: String = "Walk" if actor.moving else "Idle"
	if motions.get(actor.id, "") == desired:
		return
	motions[actor.id] = desired
	for player in model.find_children("*", "AnimationPlayer", true, false):
		var key: String = Actors.animation_key(player, desired)
		if not key.is_empty():
			player.play(key, .15)

func step(delta: float) -> void:
	if not enabled() or game.state != "playing":
		return
	sync()
	for actor in actors.values():
		actor.pause = maxf(0, actor.pause - delta)
		var goal: Vector2 = game.world.safe_position(actor.route[actor.route_index], 2)
		var direction: Vector2 = goal - actor.point
		var previous: Vector2 = actor.point
		if direction.length() < .18:
			actor.route_index = (actor.route_index + 1) % actor.route.size()
			actor.pause = 2.0
		elif actor.pause <= 0:
			actor.point = game.world.move_actor(actor.point, direction.normalized() * minf(actor.speed * delta, direction.length()), game.world.ground_height(actor.point))
		actor.moving = actor.point.distance_squared_to(previous) > .000001
		if actor.moving:
			actor.heading = (actor.point - previous).normalized()
		_place(actor)

func target() -> Dictionary:
	if not enabled():
		return {}
	var result := {}
	var distance := 2.0
	for actor in actors.values():
		var next: float = actor.point.distance_to(game.player_point)
		if next < distance and game.world.line_clear(game.player_point, actor.point):
			result = actor
			distance = next
	return result

func hint() -> String:
	var actor := target()
	return "" if actor.is_empty() else "E: Talk to " + actor.name

func interact() -> bool:
	var actor := target()
	return not actor.is_empty() and game.expansion.open_dialogue(actor)

func greet(id: String) -> void:
	if models.has(id):
		Actors.greet(models[id])
		motions.erase(id)

func dialogue(actor: Dictionary, event: String) -> String:
	_remember(actor)
	var state: Dictionary = _record(actor.dimension_id).residents[actor.id]
	state.met = true
	if event == "greeting":
		state.line = 0
	elif event == "farewell":
		state.line = actor.dialogue.size() - 1
	else:
		state.line = (int(state.line) + 1) % actor.dialogue.size()
	return actor.dialogue[int(state.line)]
