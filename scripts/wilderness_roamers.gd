extends RefCounted

const PATH := "res://config/wilderness_roamers.json"
const Wonder = preload("res://scripts/wonder_npc_catalog.gd")
const MAX_ACTORS := 4
const CACHE_LIMIT := 32
var data: Dictionary = {}
var cache := {}
var world_key := ""

static func routing_bounds(coordinate: Vector2i, chunk_size: int = 16) -> Rect2i:
	return Rect2i(coordinate * chunk_size + Vector2i(2,2),Vector2i(13,13))

func _init() -> void:
	var value = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if valid(value):
		data = value

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("profiles") is Array or value.profiles.size() < 4 or value.profiles.size() > 32:
		return false
	var ids := {}
	for profile in value.profiles:
		if not profile is Dictionary or not profile.get("id") is String or not profile.id.is_valid_identifier() or profile.id.length() > 64 or ids.has(profile.id) or profile.get("role") not in ["pilgrim", "scholar", "hunter", "courier"]:
			return false
		ids[profile.id] = true
		for key in ["name", "activity", "work"]:
			if not profile.get(key) is String or profile[key].strip_edges().is_empty() or profile[key].length() > (1000 if key == "work" else 80):
				return false
		if not (profile.get("speed") is float or profile.get("speed") is int) or not is_finite(profile.speed) or profile.speed < .5 or profile.speed > 1.4:
			return false
		if not profile.get("greetings") is Array or profile.greetings.is_empty() or profile.greetings.size() > 8 or not profile.greetings.all(func(text): return text is String and not text.strip_edges().is_empty() and text.length() <= 1000):
			return false
	return true

static func grounds(world) -> Array:
	var result := {}
	for chunk in world.chunks.values():
		for spawn in chunk.spawns:
			if spawn.has("area_id"):
				if not result.has(spawn.area_id):
					result[spawn.area_id] = {"home": spawn.home, "radius": spawn.radius, "members": []}
				result[spawn.area_id].members.append(Vector2(spawn.cell))
	return result.values()

static func supports(world, point: Vector2) -> bool:
	var path: String = world.get_script().resource_path
	return path == "res://scripts/world.gd" or (path == "res://scripts/hub_world.gd" and not world.hub.reserved.has_point(Vector2i(point.round())))

static func allowed(world, point: Vector2, hazards: Array) -> bool:
	if not supports(world,point):
		return false
	var info: Dictionary = world.cells.get(Vector2i(point.round()), {})
	return info.get("terrain", "") == "land" and world.walkable(point) and world.city_at(point,4).is_empty() and not hazards.any(func(area): return point.distance_to(area.home) <= area.radius + 1 or area.members.any(func(member): return point.distance_to(member) < 9.5))

static func open_ground_spots(world, origin: Vector2, center: Vector2i, hazards: Array, rng: RandomNumberGenerator) -> Array[Vector2]:
	var bounds := Rect2i(center - Vector2i(6,6),Vector2i(13,13))
	var queue: Array[Vector2i] = [Vector2i(origin)]
	var visited := {Vector2i(origin): true}
	var cursor := 0
	while cursor < queue.size() and queue.size() < 169:
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if visited.has(next) or not bounds.has_point(next) or Vector2(next).distance_squared_to(origin) > 36:
				continue
			if not allowed(world,Vector2(next),hazards):
				visited[next] = true
				continue
			var rise: float = world.cells[next].height - world.cells[cell].height
			if absf(rise) <= .51:
				visited[next] = true
				queue.append(next)
	var candidates: Array[Vector2] = []
	for cell in queue:
		if Vector2(cell).distance_squared_to(origin) >= 4:
			candidates.append(Vector2(cell))
	for index in range(candidates.size() - 1,0,-1):
		var other := rng.randi_range(0,index)
		var point := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = point
	var diagonals: Array[Vector2] = candidates.filter(func(point): return absf(point.x - origin.x) >= 1 and absf(point.y - origin.y) >= 1)
	if diagonals.is_empty():
		return []
	var spots: Array[Vector2] = [origin,diagonals[0]]
	while spots.size() < 6:
		var selected := Vector2.INF
		var best := 4.0
		for point in candidates:
			if spots.size() == 2 and is_zero_approx((point - origin).cross(spots[1] - origin)):
				continue
			var distance := INF
			for chosen in spots:
				distance = minf(distance,point.distance_squared_to(chosen))
			if distance >= best:
				best = distance
				selected = point
		if selected == Vector2.INF:
			break
		spots.append(selected)
	if spots.size() < 3:
		spots.clear()
	return spots

func _plan(world, coordinate: Vector2i, slot: int, hazards: Array) -> Dictionary:
	var id := "roamer:%s:%s:%s" % [coordinate.x, coordinate.y, slot]
	var rng := RandomNumberGenerator.new()
	rng.seed = world._hash(id)
	var profile: Dictionary = data.profiles[rng.randi_range(0, data.profiles.size() - 1)]
	var center: Vector2i = coordinate * world.CHUNK_SIZE + Vector2i.ONE * (world.CHUNK_SIZE / 2)
	for attempt in range(20):
		var origin := Vector2(center + Vector2i(rng.randi_range(-4,4), rng.randi_range(-4,4)))
		if not allowed(world,origin,hazards):
			continue
		var spots := open_ground_spots(world,origin,center,hazards,rng)
		if spots.size() < 3:
			continue
		var info: Dictionary = world.cells[Vector2i(origin)]
		var actor := {"id": id, "kind": "npc", "role": profile.role, "roaming": true, "roaming_profile": profile.id, "roaming_name": profile.name, "point": origin, "origin": origin, "spots": spots, "city_id": id, "city_name": world.Biomes.name_for(info), "biome": info.biome, "biome_id": info.get("biome_id",world.Biomes.LEGACY_IDS[int(info.biome)]), "appearance": world._hash("appearance:" + id), "medium": "land", "routine": {"speed": profile.speed, "dwell_seconds": 3.0, "phase_seconds": 12.0}, "path": [], "target": origin, "heading": Vector2.DOWN, "activity": "rest", "next_tick": 0, "moving": false}
		var wonder_seed: int = world._hash("wonder:" + id)
		set_wonder(actor,Wonder.npc_for(actor.biome_id,wonder_seed) if posmod(wonder_seed,2) == 0 else "")
		return actor
	return {}

func set_wonder(actor: Dictionary, id: String) -> void:
	actor.wonder_id = id
	var profiles: Array = data.profiles.filter(func(profile): return profile.id == actor.roaming_profile)
	var profile: Dictionary = Wonder.npc(id) if not id.is_empty() else profiles[0]
	actor.role = profile.role
	actor.roaming_name = profile.name
	actor.routine.speed = profile.speed
	actor.wonder_trade_profile = profile.get("trade_profile","")
	if id.is_empty():
		actor.erase("height")
	else:
		actor.height = profile.height

func sources(world, point: Vector2, preferred: Array = [], restoring: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if data.is_empty() or not supports(world,point):
		return result
	var key := "%s:%s:%s" % [world.get_instance_id(),world.run_seed,world.generator_version]
	if key != world_key:
		cache.clear()
		world_key = key
	var hazards := grounds(world)
	var candidates := []
	for coordinate in world.chunks:
		var distance: float = Vector2(coordinate * world.CHUNK_SIZE + Vector2i(8,8)).distance_squared_to(point)
		for slot in range(2):
			var id := "roamer:%s:%s:%s" % [coordinate.x,coordinate.y,slot]
			var keep: bool = id in preferred and (restoring or distance <= 34 * 34)
			if keep or distance <= 26 * 26:
				candidates.append({"id": id, "coordinate": coordinate, "slot": slot, "keep": keep, "distance": distance})
	candidates.sort_custom(func(a,b):
		if a.keep != b.keep:
			return a.keep
		return a.id < b.id if is_equal_approx(a.distance,b.distance) else a.distance < b.distance)
	for candidate in candidates:
		var cache_id: String = candidate.id
		if not cache.has(cache_id):
			if cache.size() >= CACHE_LIMIT:
				cache.erase(cache.keys()[0])
			cache[cache_id] = _plan(world, candidate.coordinate, candidate.slot, hazards)
		var actor: Dictionary = cache[cache_id]
		if actor.is_empty() or not actor.spots.all(func(spot): return allowed(world,spot,hazards)):
			continue
		if result.any(func(other): return other.point.distance_to(actor.point) < 2):
			continue
		result.append(actor)
		if result.size() == MAX_ACTORS:
			return result
	return result

func dialogue(actor: Dictionary, event: String, salt: int) -> String:
	var profiles: Array = data.profiles.filter(func(profile): return profile.id == actor.roaming_profile)
	if profiles.is_empty():
		return "Safe travels."
	var profile: Dictionary = Wonder.npc(actor.wonder_id) if not actor.get("wonder_id","").is_empty() else profiles[0]
	if event == "farewell":
		return "Safe travels. I will carry on with my walk."
	if event == "topic_route":
		return "I explore the open ground around %s, stopping to rest and keeping clear of the creature grounds." % actor.city_name
	if event == "topic_work":
		return profile.work
	return profile.greetings[posmod(salt,profile.greetings.size())]
