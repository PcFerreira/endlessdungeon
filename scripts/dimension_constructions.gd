extends RefCounted

const Locations = preload("res://scripts/surface_locations.gd")
const Cultural = preload("res://scripts/native_cultural_models.gd")
const Lore = preload("res://scripts/lore_catalog.gd")
const Themes = preload("res://scripts/town_voxel_layout.gd")
static var DATA: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/dimension_constructions.json"))
static var PACK: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/town_voxel_runtime.json"))
static var ARCHITECTURE: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/town_architecture.json"))
static var _checked := false

static func profile(kind: String) -> Dictionary:
	return DATA.get("profiles", {}).get(kind, {}).duplicate(true)

static func token(value) -> bool:
	return value is String and not value.is_empty() and value.length() <= 64 and not value.contains(":") and not value.contains("/")

static func integer(value, low: int, high: int) -> bool:
	return Locations.number(value) and value == int(value) and value >= low and value <= high

static func mode(part: Dictionary, group: String) -> String:
	return part.get("collision", "solid" if part.get("solid", not part.has("support")) else "none")

static func valid_site_recipe(recipe) -> bool:
	if not recipe is Dictionary or not recipe.get("type") is String:
		return false
	if recipe.has("theme_id") and recipe.theme_id not in Themes.THEMES:
		return false
	var kind: String = recipe.type
	if not DATA.get("profiles", {}).has(kind):
		return kind in ["city", "church"] and not recipe.has("construction_id")
	if recipe.has("construction_id"):
		var id = recipe.construction_id
		if not id is String or not DATA.get("constructions", {}).has(id) or not DATA.constructions[id] is Dictionary or DATA.constructions[id].get("kind") != kind:
			return false
	elif not DATA.get("defaults", {}).has(kind):
		return false
	if not recipe.has("residents"):
		return true
	if not recipe.residents is Array or recipe.residents.size() > 8:
		return false
	var options: Array = [recipe.construction_id] if recipe.has("construction_id") else DATA.defaults[kind]
	for id in options:
		var shape: Dictionary = DATA.profiles[kind]
		var site := _compile(_validation_base(kind, id, shape), DATA.constructions[id], id, "fairy", shape)
		for resident in recipe.residents:
			if not resident is Dictionary or not Locations.pair(resident.get("offset"), false) or not resident.get("route", []) is Array or not resident.get("route", []).all(func(point): return Locations.pair(point, false)):
				return false
			var offset := Vector2(resident.offset[0], resident.offset[1])
			if not _free(site, offset):
				return false
			var from := offset
			for point in resident.get("route", []):
				var to := Vector2(point[0], point[1])
				if not _line_safe(site, from, to):
					return false
				from = to
	return true

static func _part_valid(part, group: String, previous: Dictionary) -> bool:
	if not part is Dictionary or not token(part.get("id")) or previous.has(part.id) or part.id in ["reader_lectern", "reader_book"] or not Locations.pair(part.get("size"), false) or part.size.any(func(value): return value <= 0) or not Locations.number(part.get("height")) or part.height <= 0 or part.height > 8 or not Locations.number(part.get("elevation", 0)) or part.get("elevation", 0) < 0:
		return false
	var shape := mode(part, group)
	if shape not in ["none", "solid", "shell", "posts"]:
		return false
	if part.has("support"):
		if group != "fixtures" or not previous.has(part.support) or shape != "none":
			return false
		var support: Dictionary = previous[part.support]
		if float(part.size[0]) > float(support.size[0]) - .1 or float(part.size[1]) > float(support.size[1]) - .1:
			return false
	elif not Locations.pair(part.get("cell")):
		return false
	if shape != "none" and (not part.size.all(func(value): return integer(value, 1, 49) and int(value) % 2 == 1) or part.get("elevation", 0) != 0):
		return false
	if part.has("solid_offsets") and (not part.solid_offsets is Array or not part.solid_offsets.all(func(value): return Locations.pair(value))):
		return false
	if part.has("solid_offsets"):
		var declared := {}
		for value in part.solid_offsets:
			declared[Vector2i(value[0], value[1])] = true
		var original: Dictionary = part.duplicate()
		original.erase("solid_offsets")
		var expected := _offsets(original, group)
		if declared.size() != expected.size() or not expected.all(func(value): return declared.has(value)):
			return false
	if part.has("town_voxel"):
		if not part.town_voxel is String:
			return false
		for theme in Themes.THEMES:
			var id: String = part.town_voxel.replace("$theme", theme)
			var native: Dictionary = PACK.get("templates", {}).get(id, {})
			if native.is_empty():
				return false
			if native.kind in ["house", "workshop"] and (shape not in ["solid", "shell"] or part.height < 1.9):
				return false
			if shape == "shell" and (native.kind not in ["house", "workshop"] or part.height < 1.9 or part.size[0] < 3 or part.size[1] < 3):
				return false
			if shape == "posts" and (native.kind != "gate" or part.size[0] < 5 or part.size[1] != 1):
				return false
	elif shape in ["shell", "posts"]:
		return false
	elif part.has("template"):
		if not ARCHITECTURE.templates.has(part.template):
			return false
	elif part.get("role") not in Cultural.ROLES:
		return false
	return true

static func _recipe_valid(recipe, data: Dictionary) -> bool:
	if not recipe is Dictionary or not data.profiles.has(recipe.get("kind")) or not recipe.get("name") is String or recipe.name.is_empty() or not Lore.BOOKS.has(recipe.get("book")):
		return false
	for key in ["reader", "reading_approach", "rest"]:
		if not Locations.pair(recipe.get(key)):
			return false
	var previous := {}
	for group in ["structures", "fixtures"]:
		if not recipe.get(group) is Array or recipe[group].is_empty() or recipe[group].size() > 64:
			return false
		for part in recipe[group]:
			if not _part_valid(part, group, previous):
				return false
			previous[part.id] = part
	if not recipe.get("resident_spots", []) is Array or recipe.get("resident_spots", []).size() > 8:
		return false
	var residents := {}
	for spot in recipe.get("resident_spots", []):
		if not spot is Dictionary or not token(spot.get("id")) or residents.has(spot.id) or not Locations.pair(spot.get("point")) or not Locations.pair(spot.get("approach")) or not spot.get("route") is Array or spot.route.is_empty() or spot.route.size() > 16 or not spot.route.all(func(value): return Locations.pair(value)):
			return false
		residents[spot.id] = true
	return true

static func valid(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("profiles") is Dictionary or data.profiles.is_empty() or data.profiles.size() > 16 or not data.get("constructions") is Dictionary or data.constructions.is_empty() or data.constructions.size() > 64 or not data.get("defaults") is Dictionary or not data.get("area_themes") is Dictionary:
		return false
	for kind in data.profiles:
		var definition = data.profiles[kind]
		if not token(kind) or not definition is Dictionary or not integer(definition.get("radius"), 3, 24) or not integer(definition.get("flatten"), int(definition.radius) + 2, 48) or not integer(definition.get("approach"), 1, int(definition.radius) + 2):
			return false
		if not data.defaults.get(kind) is Array or data.defaults[kind].is_empty() or not data.defaults[kind].all(func(id): return id is String and data.constructions.has(id) and data.constructions[id] is Dictionary and data.constructions[id].get("kind") == kind):
			return false
	for theme in data.area_themes.values():
		if theme not in Themes.THEMES:
			return false
	for id in data.constructions:
		var recipe = data.constructions[id]
		if not token(id) or not _recipe_valid(recipe, data):
			return false
		var shape: Dictionary = data.profiles[recipe.kind]
		var compiled := _compile(_validation_base(recipe.kind, id, shape), recipe, id, "fairy", shape)
		if not _geometry_valid(compiled):
			return false
	return true

static func _validation_base(kind: String, id: String, shape: Dictionary) -> Dictionary:
	var radius := int(shape.radius)
	return {"id": "validation:" + id, "type": kind, "cell": Vector2i.ZERO, "facing": Vector2i.DOWN, "radius": radius, "footprint": Rect2i(-Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1)), "height": 1.0, "biome": 0}

static func _free(site: Dictionary, point: Vector2) -> bool:
	for offset in [Vector2(-.20, -.20), Vector2(.20, -.20), Vector2(-.20, .20), Vector2(.20, .20)]:
		if not site.walks.has(Vector2i((point + offset).round())):
			return false
	return true

static func _line_safe(site: Dictionary, start: Vector2, end: Vector2) -> bool:
	var count := maxi(1, ceili(start.distance_to(end) / .2))
	for step in range(count + 1):
		if not _free(site, start.lerp(end, float(step) / count)):
			return false
	return true

static func _offsets(part: Dictionary, group: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if part.has("solid_offsets"):
		for offset in part.solid_offsets:
			result.append(Vector2i(offset[0], offset[1]))
		return result
	var shape := mode(part, group)
	if shape == "none":
		return result
	var half := Vector2i(int(part.size[0]) / 2, int(part.size[1]) / 2)
	for x in range(-half.x, half.x + 1):
		for y in range(-half.y, half.y + 1):
			if shape == "shell" and ((absi(x) != half.x and absi(y) != half.y) or (x == 0 and y == half.y)):
				continue
			if shape == "posts" and (absi(x) != half.x or y != 0):
				continue
			result.append(Vector2i(x, y))
	return result

static func _compile(base: Dictionary, definition: Dictionary, id: String, theme: String, shape: Dictionary) -> Dictionary:
	var site := base.duplicate(true)
	site.name = base.get("name", definition.name)
	site.owner = base.get("owner", "")
	site.construction_id = id
	site.theme_id = theme
	site.approach_distance = int(shape.approach)
	site.approach = site.cell + Locations.rotate(Vector2i(0, shape.approach), site.facing)
	site.structures = []
	site.fixtures = []
	site.solid_cells = []
	site.doors = []
	site.resident_anchors = []
	var support := {}
	for group in ["structures", "fixtures"]:
		for recipe in definition[group]:
			var part: Dictionary = recipe.duplicate(true)
			part.support = part.get("support", "ground")
			part.elevation = float(part.get("elevation", 0))
			if part.support != "ground":
				part.local_cell = support[part.support].local_cell
				part.elevation = support[part.support].elevation + support[part.support].height
			else:
				part.local_cell = Vector2i(part.cell[0], part.cell[1])
			part.cell = site.cell + Locations.rotate(part.local_cell, site.facing)
			part.solid = mode(recipe, group) != "none"
			part.fixed = part.get("fixed", group == "structures")
			part.pool = part.get("role", "")
			if part.has("town_voxel"):
				part.town_voxel = part.town_voxel.replace("$theme", theme)
			for offset in _offsets(recipe, group):
				var cell: Vector2i = site.cell + Locations.rotate(part.local_cell + offset, site.facing)
				if cell not in site.solid_cells:
					site.solid_cells.append(cell)
			if mode(recipe, group) in ["shell", "posts"]:
				var front: Vector2i = part.local_cell + Vector2i(0, int(part.size[1]) / 2)
				site.doors.append({"id": site.id + ":" + part.id + ":door", "point": Vector2(site.cell + Locations.rotate(front, site.facing)), "approach": Vector2(site.cell + Locations.rotate(front + Vector2i.DOWN, site.facing)), "inside": Vector2(site.cell + Locations.rotate(front + Vector2i.UP, site.facing))})
			site[group].append(part)
			support[part.id] = part
	var reader := Vector2i(definition.reader[0], definition.reader[1])
	var reading := Vector2i(definition.reading_approach[0], definition.reading_approach[1])
	site.books = [{"id": site.id + ":book", "kind": "book", "book_id": definition.book, "point": Vector2(site.cell + Locations.rotate(reader, site.facing)), "approach": Vector2(site.cell + Locations.rotate(reading, site.facing)), "site_id": site.id, "site_cell": site.cell}]
	site.rest_point = Vector2(site.cell + Locations.rotate(Vector2i(definition.rest[0], definition.rest[1]), site.facing))
	for part in [{"id": "reader_lectern", "role": "bookstand", "pool": "bookstand", "size": [1, 1], "height": .9, "elevation": 0.0, "support": "ground", "fixed": true, "solid": true}, {"id": "reader_book", "role": "book", "pool": "book", "size": [.45, .35], "height": .1, "elevation": .9, "support": "reader_lectern", "fixed": true, "solid": false}]:
		part.local_cell = reader
		part.cell = site.cell + Locations.rotate(reader, site.facing)
		site.fixtures.append(part)
	site.solid_cells.append(site.cell + Locations.rotate(reader, site.facing))
	for spot in definition.get("resident_spots", []):
		var route: Array[Vector2] = []
		for point in spot.route:
			route.append(Vector2(site.cell + Locations.rotate(Vector2i(point[0], point[1]), site.facing)))
		site.resident_anchors.append({"id": site.id + ":anchor:" + spot.id, "point": Vector2(site.cell + Locations.rotate(Vector2i(spot.point[0], spot.point[1]), site.facing)), "approach": Vector2(site.cell + Locations.rotate(Vector2i(spot.approach[0], spot.approach[1]), site.facing)), "route": route})
	site.walks = _reachable(site)
	return site

static func _reachable(site: Dictionary) -> Dictionary:
	var result := {}
	var limits: Rect2i = site.footprint.grow(2)
	var queue: Array[Vector2i] = [site.approach]
	var blocked := {}
	for cell in site.solid_cells:
		blocked[cell] = true
	if blocked.has(site.approach):
		return result
	result[site.approach] = true
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = cell + direction
			if limits.has_point(next) and not result.has(next) and not blocked.has(next):
				result[next] = true
				queue.append(next)
	return result

static func _geometry_valid(site: Dictionary) -> bool:
	var bounds := Rect2(Vector2(-site.radius - .5, -site.radius - .5), Vector2.ONE * (site.radius * 2 + 1))
	for part in site.structures + site.fixtures:
		var size := Vector2(part.size[0], part.size[1])
		if not bounds.encloses(Rect2(Vector2(part.local_cell) - size * .5, size)):
			return false
	for cell in site.solid_cells:
		if not site.footprint.has_point(cell):
			return false
	var targets: Array = [site.books[0].approach, site.rest_point]
	for door in site.doors:
		targets.append_array([door.point, door.approach, door.inside])
	for anchor in site.resident_anchors:
		targets.append_array([anchor.point, anchor.approach])
		targets.append_array(anchor.route)
		for index in range(anchor.route.size() - 1):
			var start: Vector2 = anchor.route[index]
			var end: Vector2 = anchor.route[index + 1]
			if not _line_safe(site, start, end):
				return false
	return targets.all(func(point): return _free(site, Vector2(point)))

static func compose(base: Dictionary, recipe: Dictionary = {}) -> Dictionary:
	if not _checked:
		assert(valid(DATA), "Invalid original dimension constructions")
		_checked = true
	var request := recipe.duplicate(true)
	request.type = base.type
	assert(valid_site_recipe(request), "Unknown construction or incompatible site kind/theme")
	var options: Array = DATA.defaults[base.type]
	var id: String = request.get("construction_id", options[posmod(int(base.get("seed", 0)), options.size())])
	var definition: Dictionary = DATA.constructions[id]
	var theme: String = request.get("theme_id", DATA.area_themes.get(base.get("area_id", ""), "fairy"))
	var site := _compile(base, definition, id, theme, profile(base.type))
	assert(_geometry_valid(site), "Construction footprint/reader/rest/door/resident access differs from its profile")
	return site
