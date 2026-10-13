extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Profiles = preload("res://scripts/asset_profiles.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Placement = preload("res://scripts/contextual_placement.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Styles = preload("res://scripts/environment_styles.gd")
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/dungeon_dressing.json"))
static var registry := Registry.new()
static var styles := Styles.new(registry)
static var pools: Dictionary = {}
var protected: Array[Vector2] = []
var accessible: Dictionary = {}

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(value)

static func _pair(value) -> bool:
	return value is Array and value.size() == 2 and value.all(_number)

static func _part(part) -> bool:
	if not part is Dictionary or not part.get("kind") is String or not _pair(part.get("footprint")) or part.footprint.any(func(value): return value <= 0 or value > 2) or not _number(part.get("height")) or part.height <= 0 or part.height > 1.5:
		return false
	if part.has("query"):
		var query = part.query
		return query is Dictionary and query.get("pack") is String and query.get("patterns") is Array and not query.patterns.is_empty() and query.patterns.all(func(value): return value is String)
	return Profiles.MODELS.has(part.kind) or Scenery.MODELS.has(part.kind)

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("templates") is Dictionary or not document.get("families") is Dictionary:
		return false
	for key in ["cells_per_fixture", "fixture_cap"]:
		if not _number(document.get(key)) or document[key] != int(document[key]) or document[key] < 1 or document[key] > 24:
			return false
	for family in Areas.DUNGEONS:
		if not document.families.get(family) is Dictionary:
			return false
		for role in Areas.DUNGEONS[family].roles:
			var ensemble = document.families[family].get(role)
			if not ensemble is Array or ensemble.size() < 3 or ensemble.size() > 8 or not ensemble.all(func(id): return id is String and document.templates.has(id)):
				return false
	for recipe in document.templates.values():
		if not _part(recipe) or not recipe.get("purpose") is String or recipe.purpose.strip_edges().is_empty() or not recipe.get("contents") is Array or recipe.contents.size() > 6:
			return false
		if recipe.get("placement", "wall") not in ["wall", "floor"]:
			return false
		if recipe.has("limit") and (not _number(recipe.limit) or recipe.limit != int(recipe.limit) or recipe.limit < 1 or recipe.limit > document.fixture_cap):
			return false
		var elevation = recipe.get("elevation", 0)
		if not _number(elevation) or elevation < 0 or elevation + recipe.height > 1.5 or (elevation > 0 and recipe.get("placement", "wall") != "wall"):
			return false
		if recipe.kind == "table" and recipe.contents.is_empty():
			return false
		if not recipe.contents.is_empty() and recipe.get("surface") != true:
			return false
		var surface := Rect2(-Vector2(recipe.footprint[0], recipe.footprint[1]) * .5, Vector2(recipe.footprint[0], recipe.footprint[1]))
		var occupied: Array[Rect2] = []
		for part in recipe.contents:
			if not _part(part) or not _pair(part.get("point")):
				return false
			var footprint := Rect2(Vector2(part.point[0], part.point[1]) - Vector2(part.footprint[0], part.footprint[1]) * .5, Vector2(part.footprint[0], part.footprint[1]))
			if not surface.encloses(footprint) or occupied.any(func(box): return box.grow(.02).intersects(footprint)) or recipe.height + part.height > 1.5:
				return false
			occupied.append(footprint)
	return true

func model_id(part: Dictionary, salt: String, biome: int) -> String:
	var family := styles.family_for(biome)
	var role: String = styles.data.anchors.get(part.kind, part.kind)
	assert(not family.is_empty() and styles.supports(role), "Dungeon parts need a classified source or purposeful same-family fallback")
	if not part.has("query"):
		var source: String = Profiles.MODELS[part.kind][0].trim_prefix("res://assets/expansion/") if Profiles.MODELS.has(part.kind) else part.kind
		return source if styles.allows(source, biome) and registry.resource(source) != null else styles.native_id(family, role)
	var key := JSON.stringify(part.query) + ":" + family
	if not pools.has(key):
		pools[key] = registry.find("model", [], part.query.pack).filter(func(asset): return styles.allows(asset.id, biome) and part.query.patterns.any(func(pattern): return asset.id.matchn(pattern)))
	var pool: Array = pools[key]
	if pool.is_empty():
		return styles.native_id(family, role)
	var selected: String = pool[(hash("dungeon-purpose:" + salt) & 0x7fffffff) % pool.size()].id
	return selected if registry.resource(selected) != null else styles.native_id(family, role)

func decorate(dungeon, seed_value: int, depth: int) -> void:
	assert(valid(data), "Invalid dungeon purpose catalogue")
	_reserve_routes(dungeon)
	for index in range(dungeon.rooms.size()):
		var role: String = dungeon.room_roles[index]
		var ensemble: Array = data.families[dungeon.family][role]
		var anchor := Vector2.ZERO
		var counts := {}
		var target: int = mini(int(data.fixture_cap), maxi(ensemble.size(), ceili(dungeon.rooms[index].get_area() / float(data.cells_per_fixture))))
		var placed := 0
		for part_index in range(target * 3):
			if placed >= target:
				break
			var recipe_id: String = ensemble[part_index % ensemble.size()]
			if counts.get(recipe_id, 0) >= data.templates[recipe_id].get("limit", target):
				continue
			var salt := "%s:%s:%s:%s:%s" % [seed_value, depth, dungeon.family, index, part_index]
			var prop := _place(dungeon, index, recipe_id, salt, anchor)
			if not prop.is_empty():
				placed += 1
				counts[recipe_id] = counts.get(recipe_id, 0) + 1
				if anchor == Vector2.ZERO:
					anchor = prop.point

func _reserve_routes(dungeon) -> void:
	protected.clear()
	var previous := {dungeon.start: dungeon.start}
	var queue: Array[Vector2i] = [dungeon.start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in dungeon.DIRECTIONS:
			var next: Vector2i = cell + direction
			if not previous.has(next) and dungeon.can_step(Vector2(cell), Vector2(next)):
				previous[next] = cell
				queue.append(next)
	var targets: Array[Vector2i] = [dungeon.exit]
	accessible = previous.duplicate()
	for room in dungeon.rooms:
		targets.append(room.get_center())
	for readable in dungeon.readables:
		targets.append(Vector2i(readable.approach))
	protected.append(Vector2(dungeon.start))
	for target in targets:
		protected.append(Vector2(target))

func _place(dungeon, index: int, recipe_id: String, salt: String, anchor: Vector2) -> Dictionary:
	var recipe: Dictionary = data.templates[recipe_id]
	var primary := model_id(recipe, salt, dungeon.biome)
	if primary.is_empty():
		return {}
	var contents: Array[Dictionary] = []
	for part in recipe.contents:
		var model := model_id(part, salt + ":" + str(contents.size()), dungeon.biome)
		if model.is_empty():
			continue
		var content: Dictionary = part.duplicate(true)
		content.model_id = model
		content.visual_family = styles.family_for(dungeon.biome)
		contents.append(content)
	if not recipe.contents.is_empty() and contents.size() != recipe.contents.size():
		return {}
	var footprint := Vector2(recipe.footprint[0], recipe.footprint[1])
	var slots := _floor_slots(dungeon, dungeon.rooms[index], footprint, anchor) if recipe.get("placement", "wall") == "floor" else Placement.wall_slots(dungeon, dungeon.rooms[index], footprint)
	if recipe.get("placement", "wall") == "floor":
		slots.append_array(Placement.wall_slots(dungeon, dungeon.rooms[index], footprint))
	slots = slots.filter(func(slot): return not protected.any(func(point): return Rect2(slot.point - slot.footprint * .5, slot.footprint).grow(.21).has_point(point)))
	if slots.is_empty():
		return {}
	if anchor != Vector2.ZERO:
		slots.sort_custom(func(a, b): return a.point.distance_squared_to(anchor) < b.point.distance_squared_to(anchor))
	var choice: int = (hash("dressing:" + salt) & 0x7fffffff) % (mini(4, slots.size()) if anchor != Vector2.ZERO else slots.size())
	for offset in range(slots.size()):
		var prop: Dictionary = slots[(choice + offset) % slots.size()].duplicate(true)
		var remaining := _connected_floor(dungeon, Rect2(prop.point - prop.footprint * .5, prop.footprint))
		if remaining.is_empty():
			continue
		accessible = remaining
		prop.merge({"kind": recipe.kind, "model_id": primary, "visual_family": styles.family_for(dungeon.biome), "height": recipe.height, "elevation": recipe.get("elevation", 0), "contents": contents, "room_index": index, "room_role": dungeon.room_roles[index], "recipe_id": recipe_id, "purpose": recipe.purpose, "uid": "dressing:" + salt}, true)
		dungeon.decorations.append(prop)
		dungeon.obstacles.append(Rect2(prop.point - prop.footprint * .5, prop.footprint))
		return prop
	return {}

func _connected_floor(dungeon, box: Rect2) -> Dictionary:
	var remaining := accessible.duplicate()
	var expanded := box.grow(.20)
	for x in range(floori(expanded.position.x), ceili(expanded.end.x) + 1):
		for y in range(floori(expanded.position.y), ceili(expanded.end.y) + 1):
			var cell := Vector2i(x, y)
			if expanded.has_point(Vector2(cell)):
				remaining.erase(cell)
	var visited := {dungeon.start: true}
	var queue: Array[Vector2i] = [dungeon.start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in dungeon.DIRECTIONS:
			var next: Vector2i = cell + direction
			if remaining.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return remaining if visited.size() == remaining.size() else {}

func _floor_slots(dungeon, room: Rect2i, size: Vector2, anchor: Vector2) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for x in range(room.position.x + 1, room.end.x - 1):
		for y in range(room.position.y + 1, room.end.y - 1):
			var cell := Vector2i(x, y)
			var point := Vector2(cell)
			var direction := (anchor - point).normalized() if anchor != Vector2.ZERO else Vector2.DOWN
			var yaw := atan2(direction.x, direction.y)
			var rotated := Vector2(size.y, size.x) if absf(direction.x) > absf(direction.y) else size
			yaw = snappedf(yaw, PI / 2)
			var box := Rect2(point - rotated * .5, rotated)
			var clear := box.grow(.14)
			var supported := true
			for support_x in range(floori(clear.position.x + .5), ceili(clear.end.x + .5)):
				for support_y in range(floori(clear.position.y + .5), ceili(clear.end.y + .5)):
					supported = supported and dungeon.tiles.has(Vector2i(support_x, support_y))
			if not supported or point.distance_to(dungeon.start) < 1.5 or point.distance_to(dungeon.exit) < 1.5 or dungeon.obstacles.any(func(previous): return previous.grow(.41).intersects(box)):
				continue
			if not dungeon.DIRECTIONS.any(func(step): return dungeon.walkable(point + Vector2(step))):
				continue
			slots.append({"cell": cell, "point": point, "yaw": yaw, "footprint": rotated})
	return slots
