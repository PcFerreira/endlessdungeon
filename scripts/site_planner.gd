extends RefCounted

static var DATA: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/site_planning.json"))
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var seed := 0
var plans: Dictionary = {}
var routes: Dictionary = {}

func _init(seed_value: int = 0) -> void:
	assert(valid(DATA), "Invalid independent-site planning policy")
	seed = seed_value

static func integer(value, lower: int, upper: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == int(value) and value >= lower and value <= upper

static func valid(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not integer(data.get("region_size"), 96, 256) or not integer(data.get("macro_size"), 2, 6) or not integer(data.get("town_chance"), 1, 80) or not integer(data.get("location_chance"), 1, 80) or not integer(data.get("clearance"), 2, 8) or not integer(data.get("placement_trials"), 1, 32):
		return false
	if not data.get("dungeon_counts") is Array or data.dungeon_counts.is_empty() or not data.dungeon_counts.all(func(count): return integer(count, 0, 3)) or not data.get("locations") is Dictionary or not data.get("profiles") is Dictionary:
		return false
	for kind in ["city", "dungeon", "ruin", "castle", "church", "temple"]:
		var profile = data.profiles.get(kind)
		if not profile is Dictionary or not integer(profile.get("radius"), 2, 24) or not integer(profile.get("flatten"), profile.radius + 2, 32) or not integer(profile.get("approach"), 1, profile.radius + 3):
			return false
	for kind in ["ruin", "castle", "church", "temple"]:
		if not integer(data.locations.get(kind), 1, 100):
			return false
	return data.locations.size() == 4

func salt(text: String) -> int:
	var value: int = hash("sites-v5:%s:%s" % [seed, text]) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	return value ^ (value >> 16)

static func coordinate(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / DATA.region_size), floori(float(cell.y) / DATA.region_size))

static func macro_at(region: Vector2i) -> Vector2i:
	return Vector2i(floori(float(region.x) / DATA.macro_size), floori(float(region.y) / DATA.macro_size))

func anchor_coordinate(macro: Vector2i) -> Vector2i:
	if macro == Vector2i.ZERO:
		return Vector2i.ZERO
	var value := salt("anchor:" + str(macro))
	return macro * int(DATA.macro_size) + Vector2i(value % int(DATA.macro_size), (value / int(DATA.macro_size)) % int(DATA.macro_size))

func macro_anchor(macro: Vector2i) -> Dictionary:
	return settlement(anchor_coordinate(macro))

func settlement(region: Vector2i) -> Dictionary:
	var anchor: bool = region == anchor_coordinate(macro_at(region))
	if not anchor and salt("town-present:" + str(region)) % 100 >= DATA.town_chance:
		return {}
	var point: Vector2i = region * int(DATA.region_size)
	if region == Vector2i.ZERO:
		point += Vector2i.ONE * int(DATA.region_size / 2)
	else:
		var margin := 32
		var width: int = DATA.region_size - margin * 2
		point += Vector2i(margin + salt("town-x:" + str(region)) % width, margin + salt("town-y:" + str(region)) % width)
	var result := site("city:%s:%s" % [region.x, region.y], "city", region, point, Vector2i.DOWN)
	result.macro_anchor = anchor
	return result

func site(id: String, type: String, region: Vector2i, cell: Vector2i, facing: Vector2i) -> Dictionary:
	var profile: Dictionary = DATA.profiles[type]
	var radius: int = profile.radius
	var approach: int = profile.approach
	var corridors: Array[Rect2i] = []
	for direction in DIRECTIONS if type == "city" else [facing]:
		var tip: Vector2i = cell + direction * (radius + 7 if type == "city" else approach + 5)
		var origin := Vector2i(mini(cell.x, tip.x), mini(cell.y, tip.y))
		corridors.append(Rect2i(origin, Vector2i(absi(cell.x - tip.x) + 1, absi(cell.y - tip.y) + 1)).grow(1))
	return {"id": id, "type": type, "coordinate": region, "cell": cell, "facing": facing, "radius": radius, "flatten": int(profile.flatten), "approach_distance": approach, "approach": cell + facing * approach, "footprint": Rect2i(cell - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1)), "corridors": corridors}

func free_slot(candidate: Dictionary, occupied: Array) -> bool:
	for previous in occupied:
		if candidate.footprint.grow(DATA.clearance).intersects(previous.footprint):
			return false
		if previous.corridors.any(func(box): return box.intersects(candidate.footprint.grow(1))) or candidate.corridors.any(func(box): return box.intersects(previous.footprint.grow(1))):
			return false
	return true

func place(region: Vector2i, kind: String, index: int, occupied: Array) -> Dictionary:
	var id := "ruin:%s:%s:%s" % [region.x, region.y, index] if kind == "dungeon" else "place:%s:%s:%s:%s" % [kind, region.x, region.y, index]
	var margin: int = DATA.profiles[kind].flatten + int(DATA.clearance)
	var width: int = DATA.region_size - margin * 2
	var facing: Vector2i = DIRECTIONS[salt(id + ":facing") % DIRECTIONS.size()]
	for trial in range(int(DATA.placement_trials)):
		var position := region * int(DATA.region_size) + Vector2i(margin + salt("%s:x:%s" % [id, trial]) % width, margin + salt("%s:y:%s" % [id, trial]) % width)
		var candidate := site(id, kind, region, position, facing)
		if free_slot(candidate, occupied):
			return candidate
	return {}

func slots(region: Vector2i) -> Dictionary:
	if plans.has(region):
		return plans[region]
	var city := settlement(region)
	var occupied: Array = [] if city.is_empty() else [city]
	var locations: Array[Dictionary] = []
	if salt("location-present:" + str(region)) % 100 < DATA.location_chance:
		var total := 0
		for weight in DATA.locations.values():
			total += int(weight)
		var roll := salt("location-kind:" + str(region)) % total
		for kind in DATA.locations:
			roll -= int(DATA.locations[kind])
			if roll >= 0:
				continue
			var location := place(region, kind, 0, occupied)
			if not location.is_empty():
				locations.append(location)
				occupied.append(location)
			break
	var dungeons: Array[Dictionary] = []
	var count: int = DATA.dungeon_counts[salt("dungeon-count:" + str(region)) % DATA.dungeon_counts.size()]
	if region == Vector2i.ZERO:
		count = 2
	for index in range(count):
		var dungeon := place(region, "dungeon", index, occupied)
		if not dungeon.is_empty():
			dungeons.append(dungeon)
			occupied.append(dungeon)
	var result := {"coordinate": region, "city": city, "locations": locations, "dungeons": dungeons}
	if plans.size() >= 128:
		plans.erase(plans.keys()[0])
	plans[region] = result
	return result

func nearby_settlements(region: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for x in range(region.x - 1, region.x + 2):
		for y in range(region.y - 1, region.y + 2):
			var town := settlement(Vector2i(x, y))
			if not town.is_empty():
				result.append(town)
				seen[town.id] = true
	var anchor := macro_anchor(macro_at(region))
	if not seen.has(anchor.id):
		result.append(anchor)
	return result

func edge(a: Dictionary, b: Dictionary) -> Dictionary:
	var first: Dictionary = a if a.id < b.id else b
	var last: Dictionary = b if a.id < b.id else a
	return {"id": "road-v5:%s~%s" % [first.id, last.id], "from": first, "to": last}

func backbone(macro: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origin := macro_anchor(macro)
	for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
		result.append(edge(origin, macro_anchor(macro + direction)))
	return result

func connections(region: Vector2i) -> Array[Dictionary]:
	var plan := slots(region)
	var result: Array[Dictionary] = []
	var anchor := macro_anchor(macro_at(region))
	if not plan.city.is_empty() and plan.city.id != anchor.id:
		result.append(edge(plan.city, anchor))
	var towns := nearby_settlements(region)
	for source in plan.locations + plan.dungeons:
		var nearest: Dictionary = towns[0]
		for town in towns:
			var candidate: int = source.cell.distance_squared_to(town.cell)
			var distance: int = source.cell.distance_squared_to(nearest.cell)
			if candidate < distance or (candidate == distance and town.id < nearest.id):
				nearest = town
		result.append(edge(source, nearest))
	return result

func roads_for(region: Vector2i) -> Array[Dictionary]:
	var bounds := Rect2i(region * int(DATA.region_size), Vector2i.ONE * int(DATA.region_size)).grow(2)
	var macro := macro_at(region)
	var records := {}
	for x in range(macro.x - 1, macro.x + 2):
		for y in range(macro.y - 1, macro.y + 2):
			var neighbor := Vector2i(x, y)
			var edges := backbone(neighbor)
			for region_x in range(int(DATA.macro_size)):
				for region_y in range(int(DATA.macro_size)):
					edges.append_array(connections(neighbor * int(DATA.macro_size) + Vector2i(region_x, region_y)))
			for record in edges:
				var extent := Rect2i(record.from.cell, Vector2i.ONE).expand(record.to.cell).grow(64)
				if extent.intersects(bounds):
					records[record.id] = record
	var result: Array[Dictionary] = []
	var ids: Array = records.keys()
	ids.sort()
	for id in ids:
		var record: Dictionary = records[id].duplicate()
		record.path = path(record.from, record.to)
		if not record.path.is_empty():
			result.append(record)
	return result

func connector(source: Dictionary, toward: Vector2i) -> Array[Vector2i]:
	if source.type != "city":
		return [source.approach, source.approach + source.facing * 5]
	var point: Vector2i = source.cell
	var delta := toward - point
	var direction := Vector2i(signi(delta.x), 0) if absi(delta.x) > absi(delta.y) else Vector2i(0, signi(delta.y))
	if direction == Vector2i.ZERO:
		direction = Vector2i.DOWN
	var exit_point := point + direction * (int(source.radius) + 7)
	if direction == Vector2i.DOWN:
		return [source.approach, exit_point]
	if direction == Vector2i.UP:
		return [source.approach, point + Vector2i(-3, 3), point + Vector2i(-3, -3), point + Vector2i(0, -3), exit_point]
	return [source.approach, point + Vector2i(direction.x * 3, 3), point + Vector2i(direction.x * 3, 0), exit_point]

func obstacles(points: Array, omit: Array) -> Array[Rect2i]:
	var bounds := Rect2i(points[0], Vector2i.ONE)
	for point in points:
		bounds = bounds.expand(point)
	bounds = bounds.grow(64)
	var from := coordinate(bounds.position)
	var to := coordinate(bounds.end)
	var result: Array[Rect2i] = []
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var region := slots(Vector2i(x, y))
			var sources: Array = region.locations + region.dungeons
			if not region.city.is_empty():
				sources.append(region.city)
			for source in sources:
				if source.id not in omit:
					result.append(source.footprint.grow(1))
	return result

func coarse(from: Vector2i, to: Vector2i, key: String, boxes: Array[Rect2i]) -> Array[Vector2i]:
	var horizontal: bool = salt(key + ":bend") % 2 == 0
	var first: int = from.x if horizontal else from.y
	var last: int = to.x if horizontal else to.y
	var preferred: int = roundi(lerpf(first, last, .25 + float(salt(key + ":fraction") % 51) / 100))
	var choices: Array[int] = [preferred, first, last]
	for box in boxes:
		choices.append((box.position.x if horizontal else box.position.y) - 1)
		choices.append((box.end.x if horizontal else box.end.y) + 1)
	choices.sort_custom(func(a, b): return absi(a - preferred) < absi(b - preferred))
	for value in choices:
		var a := Vector2i(value, from.y) if horizontal else Vector2i(from.x, value)
		var b := Vector2i(value, to.y) if horizontal else Vector2i(to.x, value)
		if not boxes.any(func(box): return box.has_point(a) or box.has_point(b)):
			return [from, a, b, to]
	return []

static func raster(points: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if points.is_empty():
		return result
	var point: Vector2i = points[0]
	result.append(point)
	for target in points.slice(1):
		while point != target:
			point += Vector2i(signi(target.x - point.x), signi(target.y - point.y))
			result.append(point)
	return result

func bypass(points: Array[Vector2i], boxes: Array[Rect2i]) -> Array[Vector2i]:
	for attempt in range(256):
		var modified := false
		for index in range(1, points.size()):
			var from: Vector2i = points[index - 1]
			var to: Vector2i = points[index]
			var horizontal: bool = from.y == to.y
			var hit := Rect2i()
			for point in raster([from, to]):
				for box in boxes:
					if box.has_point(point):
						hit = box
						break
				if hit.has_area():
					break
			if not hit.has_area():
				continue
			var positive: bool = (to.x > from.x) if horizontal else (to.y > from.y)
			var before: Vector2i = Vector2i(hit.position.x - 1 if positive else hit.end.x + 1, from.y) if horizontal else Vector2i(from.x, hit.position.y - 1 if positive else hit.end.y + 1)
			var after: Vector2i = Vector2i(hit.end.x + 1 if positive else hit.position.x - 1, from.y) if horizontal else Vector2i(from.x, hit.end.y + 1 if positive else hit.position.y - 1)
			var sides: Array = [hit.position.y - 1, hit.end.y + 1] if horizontal else [hit.position.x - 1, hit.end.x + 1]
			sides.sort_custom(func(a, b): return absi(a - (from.y if horizontal else from.x)) < absi(b - (from.y if horizontal else from.x)))
			for side in sides:
				var a := Vector2i(before.x, side) if horizontal else Vector2i(side, before.y)
				var b := Vector2i(after.x, side) if horizontal else Vector2i(side, after.y)
				if boxes.any(func(box): return box.has_point(before) or box.has_point(after) or box.has_point(a) or box.has_point(b)):
					continue
				var replacement: Array[Vector2i] = [before, a, b, after]
				for offset in range(replacement.size()):
					points.insert(index + offset, replacement[offset])
				modified = true
				break
			if not modified:
				return []
			break
		if not modified:
			return points
	return []

func path(a: Dictionary, b: Dictionary) -> Array[Vector2i]:
	var record := edge(a, b)
	if routes.has(record.id):
		return routes[record.id]
	var start := connector(record.from, record.to.cell)
	var finish := connector(record.to, record.from.cell)
	var boxes := obstacles([start[-1], finish[-1]], [a.id, b.id])
	var middle_boxes: Array[Rect2i] = boxes.duplicate()
	middle_boxes.append(record.from.footprint.grow(1))
	middle_boxes.append(record.to.footprint.grow(1))
	var middle := coarse(start[-1], finish[-1], record.id, middle_boxes)
	if not middle.is_empty():
		middle = bypass(middle, middle_boxes)
	var points: Array[Vector2i] = []
	if not middle.is_empty():
		points.assign(start)
		points.append_array(middle.slice(1, -1))
		finish.reverse()
		points.append_array(finish)
		points = bypass(points, boxes)
		for index in range(points.size() - 1, 0, -1):
			if points[index] == points[index - 1]:
				points.remove_at(index)
	if routes.size() >= 128:
		routes.erase(routes.keys()[0])
	routes[record.id] = points
	return points
