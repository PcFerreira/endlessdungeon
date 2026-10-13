extends RefCounted

const Placement = preload("res://scripts/contextual_placement.gd")
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/interior_dressing.json"))
static var stores: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/stores.json"))

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(value)

static func _pair(value) -> bool:
	return value is Array and value.size() == 2 and value.all(_number)

static func _contents(parts) -> bool:
	if not parts is Array or parts.size() > 6:
		return false
	var supports := {"root": Vector2.ONE}
	var boxes := {}
	for part in parts:
		if not part is Dictionary or not part.get("id") is String or supports.has(part.id) or not part.get("fallback") is String or not _pair(part.get("point")) or not _pair(part.get("footprint")) or part.footprint.any(func(value): return value <= 0 or value >= 1) or not _number(part.get("height")) or part.height <= 0 or part.height > .35 or not supports.has(part.get("support")):
			return false
		var box := Rect2(Vector2(part.point[0], part.point[1]) - Vector2(part.footprint[0], part.footprint[1]) * .5, Vector2(part.footprint[0], part.footprint[1]))
		if not Rect2(-Vector2.ONE * .5, Vector2.ONE).encloses(box):
			return false
		for previous in boxes.get(part.support, []):
			if previous.grow(.01).intersects(box):
				return false
		if not boxes.has(part.support):
			boxes[part.support] = []
		boxes[part.support].append(box)
		supports[part.id] = Vector2(part.footprint[0], part.footprint[1])
	return true

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not _number(document.get("cells_per_fixture")) or document.cells_per_fixture != int(document.cells_per_fixture) or document.cells_per_fixture < 8 or document.cells_per_fixture > 32 or not _number(document.get("fixture_cap")) or document.fixture_cap != int(document.fixture_cap) or document.fixture_cap < 8 or document.fixture_cap > 24 or not document.get("types") is Dictionary or not document.get("templates") is Dictionary or not document.get("table_contents") is Dictionary or not document.get("use_contents") is Dictionary:
		return false
	for type in ["home", "inn", "shop", "workshop", "shrine"]:
		if not document.types.get(type) is Array or document.types[type].is_empty() or not document.types[type].all(func(id): return id is String and document.templates.has(id)) or not _contents(document.table_contents.get(type)):
			return false
	if not document.types.has(document.get("default_type", "")):
		return false
	for type in document.types:
		if not document.types[type] is Array or document.types[type].is_empty() or not document.types[type].all(func(id): return id is String and document.templates.has(id)) or not _contents(document.table_contents.get(type)):
			return false
	for contents in document.use_contents.values():
		if not _contents(contents):
			return false
	for template in document.templates.values():
		if not template is Dictionary or not template.get("fallback") is String or not template.get("purpose") is String or template.purpose.is_empty() or not _pair(template.get("footprint")) or template.footprint.any(func(value): return value <= 0 or value > 1.5) or not _number(template.get("height")) or template.height <= 0 or template.height > 1.5 or not _contents(template.get("contents")):
			return false
		if template.get("placement", "wall") not in ["wall", "floor"] or not _number(template.get("limit", 24)) or template.get("limit", 24) != int(template.get("limit", 24)) or template.get("limit", 24) < 1:
			return false
		if not template.get("companions", []) is Array:
			return false
		for companion in template.get("companions", []):
			if not companion is Dictionary or not companion.get("fallback") is String or not _pair(companion.get("point")) or not _pair(companion.get("footprint")) or companion.footprint.any(func(value): return value <= 0 or value > 1.5) or not _number(companion.get("height")) or companion.height <= 0 or companion.height > 1.5:
				return false
	return true

func decorate(area, variants: Dictionary) -> void:
	assert(valid(data), "Invalid purposeful interior dressing")
	var original: Array = area.props.duplicate()
	var definition: Dictionary = area.content.get_entry("interiors", area.place.type)
	var type: String = definition.get("dressing_type", area.place.type)
	if not data.types.has(type):
		type = data.default_type
	var materials: Array = data.use_contents.get(area.place.get("use_id", ""), data.table_contents[type])
	for prop in original:
		if prop.fallback in ["table", "workbench"]:
			_contents_on(area, prop, materials, "authored:" + prop.source_key, variants)
	var target := mini(int(data.fixture_cap), ceili(area.tiles.size() / float(data.cells_per_fixture)))
	var count := original.size()
	var choices: Array = data.types[type]
	var counts := {}
	var protected := [Vector2(area.start), Vector2(area.exit)]
	for readable in area.readables:
		protected.append(readable.approach)
	if area.rest_point != Vector2.ZERO:
		protected.append(area.rest_point)
	if stores.get("interiors", {}).has(area.place.type):
		var point: Array = stores.interiors[area.place.type].point
		protected.append(Vector2(point[0], point[1]))
	var room := Rect2i(1, 1, area.bounds.size.x - 2, area.bounds.size.y - 2)
	for index in range(target * 3):
		if count >= target:
			break
		var recipe_id: String = choices[index % choices.size()]
		var template: Dictionary = data.templates[recipe_id]
		if count + 1 + template.get("companions", []).size() > target:
			continue
		if counts.get(recipe_id, 0) >= template.get("limit", target):
			continue
		var size := Vector2(template.footprint[0], template.footprint[1])
		var slots := _floor_slots(area, size, original) if template.get("placement", "wall") == "floor" else Placement.wall_slots(area, room, size)
		var candidate_count := mini(8, slots.size()) if template.get("placement", "wall") == "floor" else slots.size()
		var offset := posmod(hash("interior-group:%s:%s" % [area.place.id, index]), maxi(1, candidate_count))
		for attempt in range(slots.size()):
			var slot: Dictionary = slots[(offset + attempt) % slots.size()]
			var box := Rect2(slot.point - slot.footprint * .5, slot.footprint)
			var companions := []
			var additions: Array[Rect2] = [box]
			for companion in template.get("companions", []):
				var point: Vector2 = slot.point + Vector2(companion.point[0], companion.point[1])
				var spec: Dictionary = companion.duplicate(true)
				spec.point = [point.x, point.y]
				spec.face = [slot.point.x, slot.point.y]
				spec.purpose = template.purpose
				companions.append(spec)
				additions.append(Rect2(point - Vector2(companion.footprint[0], companion.footprint[1]) * .5, Vector2(companion.footprint[0], companion.footprint[1])))
			if not _valid_group(area, additions, protected) or not _connected(area, additions):
				continue
			var spec: Dictionary = template.duplicate(true)
			spec.source_key = "group:%s" % index
			spec.point = [slot.point.x, slot.point.y]
			spec.footprint = [slot.footprint.x, slot.footprint.y]
			spec.facing = [-slot.wall.x, -slot.wall.y]
			area._add_prop(spec, area.props.size(), variants)
			_contents_on(area, area.props[-1], template.contents, spec.source_key, variants)
			for child_index in range(companions.size()):
				var child: Dictionary = companions[child_index]
				child.source_key = spec.source_key + ":seat:%s" % child_index
				area._add_prop(child, area.props.size(), variants)
			count += 1 + companions.size()
			counts[recipe_id] = counts.get(recipe_id, 0) + 1
			break

func _floor_slots(area, size: Vector2, original: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var anchors: Array = original.filter(func(prop): return prop.fallback in ["table", "workbench", "anvil"])
	var center := Vector2(area.bounds.size) * .5
	if not anchors.is_empty():
		center = Vector2.ZERO
		for anchor in anchors:
			center += anchor.point
		center /= anchors.size()
	for x in range(2, area.bounds.size.x - 2):
		for y in range(2, area.bounds.size.y - 2):
			var point := Vector2(x, y)
			result.append({"point": point, "footprint": size, "wall": Vector2.UP})
	result.sort_custom(func(a, b): return a.point.distance_squared_to(center) < b.point.distance_squared_to(center))
	return result

func _valid_group(area, boxes: Array[Rect2], protected: Array) -> bool:
	var allowed := Rect2(Vector2(.57, .57), Vector2(area.bounds.size) - Vector2.ONE * 2.14)
	for index in range(boxes.size()):
		var box := boxes[index]
		if not allowed.encloses(box) or protected.any(func(point): return box.grow(.21).has_point(point)) or area.obstacles.any(func(previous): return previous.grow(.12).intersects(box)):
			return false
		for previous in boxes.slice(0, index):
			if previous.grow(.12).intersects(box):
				return false
	return true

func _contents_on(area, primary: Dictionary, contents: Array, prefix: String, variants: Dictionary) -> void:
	var supports := {"root": primary}
	for part in contents:
		var support: Dictionary = supports[part.support]
		var local_size: Vector2 = support.footprint
		if absf(sin(support.yaw)) > .5:
			local_size = Vector2(local_size.y, local_size.x)
		var offset: Vector3 = Basis(Vector3.UP, support.yaw) * Vector3(part.point[0] * local_size.x, 0, part.point[1] * local_size.y)
		var size := local_size * Vector2(part.footprint[0], part.footprint[1])
		if absf(sin(support.yaw)) > .5:
			size = Vector2(size.y, size.x)
		var point: Vector2 = support.point + Vector2(offset.x, offset.z)
		var spec := {"fallback": part.fallback, "point": [point.x, point.y], "footprint": [size.x, size.y], "height": part.height, "elevation": support.elevation + support.height, "source_key": prefix + ":" + part.id, "parent": support.source_key, "solid": false, "purpose": primary.get("purpose", "Materials for " + area.place.type)}
		area._add_prop(spec, area.props.size(), variants)
		area.props[-1].yaw = support.yaw
		supports[part.id] = area.props[-1]

func _connected(area, additions: Array[Rect2]) -> bool:
	var remaining := {}
	for cell in area.tiles:
		if area.walkable(Vector2(cell)) and not additions.any(func(box): return box.grow(.2).has_point(Vector2(cell))):
			remaining[cell] = true
	if not remaining.has(area.start):
		return false
	var seen := {area.start: true}
	var queue: Array[Vector2i] = [area.start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in area.DIRECTIONS:
			var next: Vector2i = cell + direction
			if remaining.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == remaining.size()
