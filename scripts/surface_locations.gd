extends RefCounted

const Cultural = preload("res://scripts/native_cultural_models.gd")
const Lore = preload("res://scripts/lore_catalog.gd")
static var DATA: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/surface_locations.json"))

static func number(value) -> bool:
	return (value is float or value is int) and is_finite(value)

static func pair(value, integer: bool = true) -> bool:
	return value is Array and value.size() == 2 and value.all(func(item): return number(item) and absf(item) <= 32 and (not integer or item == int(item)))

static func valid(data) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("locations") is Dictionary or data.locations.size() != 4:
		return false
	for kind in ["ruin", "castle", "church", "temple"]:
		var definition = data.locations.get(kind)
		if not definition is Dictionary or not definition.get("names") is Array or definition.names.is_empty() or not definition.names.all(func(name): return name is String and not name.is_empty()) or not Lore.BOOKS.has(definition.get("book")):
			return false
		for key in ["reader", "reading_approach", "rest"]:
			if not pair(definition.get(key)):
				return false
		var ids := {"reader_lectern": true, "reader_book": true}
		for group in ["structures", "fixtures"]:
			if not definition.get(group) is Array or definition[group].is_empty():
				return false
			for part in definition[group]:
				if not part is Dictionary or not part.get("id") is String or part.id.is_empty() or ids.has(part.id) or not pair(part.get("size"), group == "structures") or part.size.any(func(value): return value <= 0) or not number(part.get("height")) or part.height <= 0 or part.height > 8 or not number(part.get("elevation", 0)) or part.get("elevation", 0) < 0:
					return false
				if not (part.get("role") in Cultural.ROLES or (group == "structures" and part.get("template") is String)):
					return false
				if part.has("support"):
					if group != "fixtures" or not ids.has(part.support):
						return false
				elif not pair(part.get("cell")):
					return false
				if part.get("solid", group == "fixtures" and not part.has("support")) and (not part.size.all(func(value): return value == int(value) and int(value) % 2 == 1) or part.get("elevation", 0) != 0):
					return false
				ids[part.id] = true
	return true

static func rotate(point: Vector2i, facing: Vector2i) -> Vector2i:
	return Vector2i(point.x * facing.y + point.y * facing.x, -point.x * facing.x + point.y * facing.y)

static func cells_in(plot: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(plot.position.x, plot.end.x):
		for y in range(plot.position.y, plot.end.y):
			result.append(Vector2i(x, y))
	return result

static func compose(site: Dictionary) -> Dictionary:
	assert(valid(DATA), "Invalid independent surface-place composition")
	var result: Dictionary = site.duplicate(true)
	var definition: Dictionary = DATA.locations[site.type]
	result.name = definition.names[site.seed % definition.names.size()]
	result.owner = ""
	result.structures = []
	result.fixtures = []
	result.solid_cells = []
	result.walks = {}
	var support := {}
	for group in ["structures", "fixtures"]:
		for recipe in definition[group]:
			var part: Dictionary = recipe.duplicate(true)
			part.support = part.get("support", "ground")
			part.elevation = part.get("elevation", 0.0)
			if part.support != "ground":
				part.local_cell = support[part.support].local_cell
				part.elevation = support[part.support].elevation + support[part.support].height
			else:
				part.local_cell = Vector2i(part.cell[0], part.cell[1])
			part.cell = site.cell + rotate(part.local_cell, site.facing)
			part.solid = part.get("solid", group == "fixtures" and part.support == "ground")
			part.fixed = part.get("fixed", group == "structures")
			part.pool = part.get("role", "")
			if part.solid:
				var size := Vector2i(part.size[0], part.size[1])
				var local := Rect2i(part.local_cell - size / 2, size)
				for point in cells_in(local):
					var cell: Vector2i = site.cell + rotate(point, site.facing)
					assert(site.footprint.has_point(cell), "A surface structure must remain inside its planned footprint")
					if cell not in result.solid_cells:
						result.solid_cells.append(cell)
			result[group].append(part)
			support[part.id] = part
	var reader := Vector2i(definition.reader[0], definition.reader[1])
	var reading: Vector2i = site.cell + rotate(Vector2i(definition.reading_approach[0], definition.reading_approach[1]), site.facing)
	result.books = [{"id": site.id + ":book", "kind": "book", "book_id": definition.book, "point": Vector2(site.cell + rotate(reader, site.facing)), "approach": Vector2(reading), "site_id": site.id, "site_cell": site.cell}]
	result.rest_point = Vector2(site.cell + rotate(Vector2i(definition.rest[0], definition.rest[1]), site.facing))
	for part in [{"id": "reader_lectern", "role": "bookstand", "pool": "bookstand", "local_cell": reader, "size": [1, 1], "height": .9, "elevation": 0.0, "solid": true, "fixed": true, "support": "ground"}, {"id": "reader_book", "role": "book", "pool": "book", "local_cell": reader, "size": [.45, .35], "height": .10, "elevation": .9, "solid": false, "fixed": true, "support": "reader_lectern"}]:
		part.cell = site.cell + rotate(part.local_cell, site.facing)
		result.fixtures.append(part)
		if part.solid:
			result.solid_cells.append(part.cell)
	for distance in range(site.approach_distance + 1):
		for offset in range(-1, 2):
			var cell: Vector2i = site.cell + rotate(Vector2i(offset, distance), site.facing)
			if cell not in result.solid_cells:
				result.walks[cell] = true
	assert(reading not in result.solid_cells and Vector2i(result.rest_point) not in result.solid_cells, "A site's reader and rest point must remain clear")
	return result

static func rest_target(world, point: Vector2) -> Dictionary:
	for site in world.region_at(Vector2i(point.round())).get("locations", []):
		if point.distance_to(site.rest_point) < 1.5 and world.line_clear(point, site.rest_point):
			return site
	return {}
