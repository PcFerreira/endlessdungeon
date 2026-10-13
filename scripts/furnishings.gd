extends RefCounted

const Catalog = preload("res://scripts/furnishing_catalog.gd")
const Sanctum = preload("res://scripts/sanctum.gd")
const MAX_PLACED := 48
var records: Array[Dictionary] = []
var next_id := 1
var error := ""

func reset() -> void:
	records.clear()
	next_id = 1
	error = ""

static func point(record: Dictionary) -> Vector2:
	return Vector2(record.point[0], record.point[1])

static func box(record: Dictionary) -> Rect2:
	var extent := Catalog.footprint(Catalog.definition(record.item), int(record.rotation))
	return Rect2(point(record) - extent * .5, extent)

static func elevation(record: Dictionary, placed: Array) -> float:
	if record.get("parent", "").is_empty():
		return float(Catalog.definition(record.item).get("elevation", 0))
	for parent in placed:
		if parent.uid == record.parent:
			var spec := Catalog.definition(parent.item)
			return float(spec.height) + float(spec.get("elevation", 0))
	return 0

func get_record(uid: String) -> Dictionary:
	for record in records:
		if record.uid == uid:
			return record
	return {}

func has_dependants(uid: String) -> bool:
	return records.any(func(record): return record.parent == uid)

func candidate(id: String, target: Vector2, rotation: int, moving: String = "", player: Vector2 = Vector2.INF, extra_obstacles: Array[Rect2] = []) -> Dictionary:
	var spec := Catalog.definition(id)
	var record := {"uid": moving if not moving.is_empty() else "f:%s" % next_id, "item": id, "point": [target.x, target.y], "rotation": rotation, "parent": ""}
	if spec.is_empty():
		return {"record": record, "problem": "This furnishing needs a supported placement recipe."}
	var position := (target * 4).round() / 4
	if spec.support == "wall" or spec.get("wall_back", false):
		var normal := -Vector2(sin(rotation * PI / 2), cos(rotation * PI / 2)).round()
		var extent := Catalog.footprint(spec, rotation)
		var closest := INF
		for wall in Sanctum.new().furnishing_walls:
			if wall.normal != normal:
				continue
			var tangent := Vector2(-normal.y, normal.x)
			var half := (extent.x if normal.y != 0 else extent.y) * .5
			var offset := clampf((position - wall.point).dot(tangent), -wall.length * .5 + half + .10, wall.length * .5 - half - .10)
			var depth := (extent.y if normal.y != 0 else extent.x) * .5
			var anchored: Vector2 = wall.point + tangent * offset - normal * (depth + .10)
			var distance := position.distance_to(anchored)
			if distance < closest and distance <= 1.3:
				closest = distance
				record.point = [anchored.x, anchored.y]
	else:
		record.point = [position.x, position.y]
	if spec.support == "surface":
		for parent in records:
			if parent.uid != moving and Catalog.definition(parent.item).get("surface", false) and parent.parent.is_empty() and box(parent).grow(-.04).encloses(box(record)):
				record.parent = parent.uid
				break
	var proposed: Array = records.filter(func(existing): return existing.uid != moving)
	proposed.append(record)
	var problem := validate_records(proposed, extra_obstacles)
	if not moving.is_empty() and has_dependants(moving):
		problem = "Pick up the displayed objects before moving their support."
	if problem.is_empty() and spec.solid and record.parent.is_empty() and box(record).grow(.25).has_point(player):
		problem = "Move the furniture away from your character."
	return {"record": record, "problem": problem}

func place(id: String, target: Vector2, rotation: int, inventory, player: Vector2 = Vector2.INF, extra_obstacles: Array[Rect2] = []) -> bool:
	var proposal := candidate(id, target, rotation, "", player, extra_obstacles)
	error = proposal.problem
	if not error.is_empty():
		return false
	if not inventory.remove(id):
		error = "That furnishing is not in your backpack."
		return false
	records.append(proposal.record)
	next_id += 1
	return true

func move(uid: String, target: Vector2, rotation: int, player: Vector2 = Vector2.INF, extra_obstacles: Array[Rect2] = []) -> bool:
	var record := get_record(uid)
	if record.is_empty():
		return false
	var proposal := candidate(record.item, target, rotation, uid, player, extra_obstacles)
	error = proposal.problem
	if not error.is_empty():
		return false
	records[records.find(record)] = proposal.record
	return true

func remove(uid: String, inventory) -> bool:
	var record := get_record(uid)
	if record.is_empty():
		return false
	if has_dependants(uid):
		error = "Pick up the displayed objects first."
		return false
	if not inventory.add(record.item):
		error = "Your backpack is full. The furnishing stays here."
		return false
	records.erase(record)
	error = ""
	return true

func snapshot() -> Dictionary:
	return {"version": 1, "next_id": next_id, "placed": records.duplicate(true)}

static func valid(data) -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not integer(data.get("next_id")) or data.next_id < 1 or data.next_id > 2000000000 or not data.get("placed") is Array or data.placed.size() > MAX_PLACED:
		return false
	var ids := {}
	for record in data.placed:
		if not record is Dictionary or not record.get("uid") is String or not record.uid.begins_with("f:") or not record.uid.substr(2).is_valid_int() or record.uid.substr(2).to_int() < 1 or record.uid.substr(2).to_int() >= data.next_id or ids.has(record.uid):
			return false
		ids[record.uid] = true
		if not record.get("item") is String or Catalog.definition(record.item).is_empty() or not integer(record.get("rotation")) or record.rotation < 0 or record.rotation > 3 or not record.get("parent") is String or not record.get("point") is Array or record.point.size() != 2 or not record.point.all(number):
			return false
	return validate_records(data.placed).is_empty()

static func number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func integer(value) -> bool:
	return number(value) and value == int(value)

func restore(data) -> bool:
	if not valid(data):
		return false
	if data.is_empty():
		reset()
		return true
	records.clear()
	for saved in data.placed:
		var record: Dictionary = saved.duplicate(true)
		record.rotation = int(record.rotation)
		records.append(record)
	next_id = int(data.next_id)
	return true

static func validate_records(placed: Array, extra_obstacles: Array[Rect2] = []) -> String:
	if placed.size() > MAX_PLACED:
		return "Your sanctum holds up to %s furnishings." % MAX_PLACED
	var home := Sanctum.new()
	for record in placed:
		var spec := Catalog.definition(record.item)
		if spec.is_empty() or record.rotation < 0 or record.rotation > 3:
			return "This furnishing needs a supported placement recipe."
		var footprint := box(record)
		if not floor_supports(home, footprint.grow(.05)):
			return "Keep the entire furnishing on island floor."
		for anchor in [Vector2(home.start), Vector2(home.exit), home.hearth + Vector2.DOWN, Vector2(5, 7)]:
			if footprint.grow(.55).has_point(anchor):
				return "Keep the hearth, study and return portal clear."
		if home.obstacles.any(func(obstacle): return obstacle.grow(.025).intersects(footprint)):
			return "Leave the walls and fixed furnishings clear."
		if not spec.get("rug", false) and extra_obstacles.any(func(obstacle): return obstacle.grow(.025).intersects(footprint)):
			return "Leave other placed objects clear."
		if spec.support == "surface":
			var supported := false
			for parent in placed:
				if parent.uid == record.parent and parent.uid != record.uid and parent.parent.is_empty() and Catalog.definition(parent.item).get("surface", false) and box(parent).grow(-.04).encloses(footprint):
					supported = true
			if not supported:
				return "Place this object on a table, cabinet or shelf."
		elif not record.parent.is_empty():
			return "This furnishing belongs on its own support."
		if spec.support == "wall" or spec.get("wall_back", false):
			var normal := -Vector2(sin(record.rotation * PI / 2), cos(record.rotation * PI / 2)).round()
			var supported := false
			for wall in home.furnishing_walls:
				var tangent := Vector2(-normal.y, normal.x)
				var half := (footprint.size.x if normal.y != 0 else footprint.size.y) * .5
				var depth := (footprint.size.y if normal.y != 0 else footprint.size.x) * .5
				var back := point(record) + normal * depth
				if wall.normal == normal and absf((back - wall.point).dot(normal) + .10) < .001 and absf((point(record) - wall.point).dot(tangent)) + half <= wall.length * .5 - .08:
					supported = true
			if not supported or elevation(record, placed) + spec.height > 1.8:
				return "Bring it near an alcove wall and rotate it to face inward."
		for other in placed:
			if other.uid == record.uid:
				continue
			var other_spec := Catalog.definition(other.item)
			if other_spec.is_empty():
				return "This furnishing needs a supported placement recipe."
			if spec.get("rug", false) != other_spec.get("rug", false):
				continue
			var bottom := elevation(record, placed)
			var other_bottom := elevation(other, placed)
			if footprint.grow(.025).intersects(box(other)) and bottom < other_bottom + other_spec.height - .005 and bottom + spec.height > other_bottom + .005:
				return "Leave space between furnishings."
	home.obstacles.append_array(extra_obstacles)
	apply_records(home, placed)
	var seen := {home.start: true}
	var queue: Array[Vector2i] = [home.start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in home.DIRECTIONS:
			var next: Vector2i = cell + direction
			if not seen.has(next) and home.walkable(Vector2(next)):
				seen[next] = true
				queue.append(next)
	for cell in home.tiles:
		if home.walkable(Vector2(cell)) and not seen.has(cell):
			return "Keep a walking path through your home."
	for target in [home.exit, Vector2i(home.hearth) + Vector2i.DOWN, Vector2i(5, 7)]:
		if not seen.has(target):
			return "Keep the hearth, study and return portal accessible."
	return ""

static func floor_supports(home, footprint: Rect2) -> bool:
	var first := Vector2i((footprint.position + Vector2.ONE * .5).floor())
	var last := Vector2i((footprint.end + Vector2.ONE * .5 - Vector2.ONE * .0001).floor())
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			if not home.tiles.has(Vector2i(x, y)):
				return false
	return true

static func apply_records(home, placed: Array) -> void:
	home.placements.assign(placed.duplicate(true))
	for record in placed:
		if Catalog.definition(record.item).solid and record.parent.is_empty():
			home.obstacles.append(box(record))

func apply(home) -> void:
	apply_records(home, records)
