extends "res://scripts/grid_area.gd"

const PATH := "res://config/floating_city.json"
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
var center: Vector2i
var spawn: Vector2
var portal: Vector2
var theme := ""
var floor_kinds: Dictionary = {}
var houses: Array[Dictionary] = []
var markets: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var reserved: Rect2i

func _init(season: String = "") -> void:
	assert(valid(data), "Invalid floating city layout or seasonal theme")
	center = Vector2i(data.center[0], data.center[1])
	spawn = absolute(data.spawn)
	portal = absolute(data.portal)
	for source in data.gates:
		var record: Dictionary = source.duplicate(true)
		record.point = absolute(source.position)
		gates.append(record)
	theme = data.default_theme if season.is_empty() else season
	assert(data.themes.has(theme), "Unknown floating city season")
	reserved = Rect2i(center - Vector2i.ONE * 96, Vector2i.ONE * 192)
	bounds = reserved
	for island in data.islands:
		var origin := absolute(island.center)
		var radius := Vector2(island.radius[0], island.radius[1])
		for x in range(-int(radius.x), int(radius.x) + 1):
			for y in range(-int(radius.y), int(radius.y) + 1):
				if Vector2(x / radius.x, y / radius.y).length_squared() <= 1:
					var cell := Vector2i(origin) + Vector2i(x, y)
					tiles[cell] = true
					floor_kinds[cell] = "paving"
	for bridge in data.bridges:
		var plot := Rect2i(center + Vector2i(bridge[0], bridge[1]), Vector2i(bridge[2], bridge[3]))
		for x in range(plot.position.x, plot.end.x):
			for y in range(plot.position.y, plot.end.y):
				tiles[Vector2i(x, y)] = true
				floor_kinds[Vector2i(x, y)] = "bridge"
	for hall in data.halls:
		var plot := Rect2i(center + Vector2i(hall.position[0], hall.position[1]), Vector2i(hall.size[0], hall.size[1]))
		var approach := Vector2(plot.position.x + plot.size.x / 2, plot.end.y)
		houses.append({"id": data.id + ":hall:" + hall.id, "guild_id": hall.id, "use_name": hall.name, "interior_name": hall.name, "use_id": hall.use, "interior_type": hall.interior, "footprint": plot, "height": hall.height, "style": 0, "facing": Vector2i.DOWN, "door": approach, "approach": approach, "charter": hall.charter, "color": hall.color, "archetype": "arcane"})
		obstacles.append(Rect2(Vector2(plot.position) - Vector2.ONE * .5, Vector2(plot.size)))
	for market in data.markets:
		var plot := Rect2i(center + Vector2i(market.position[0], market.position[1]), Vector2i(market.size[0], market.size[1]))
		markets.append({"id": data.id + ":market:" + market.id, "name": market.name, "kind": "market", "footprint": plot, "approach": Vector2(plot.get_center()) + Vector2.DOWN, "facing": Vector2i.DOWN})
		obstacles.append(Rect2(Vector2(plot.position) - Vector2.ONE * .5, Vector2(plot.size)))
	obstacles.append(Rect2(absolute([0, -2]) - Vector2.ONE * .6, Vector2.ONE * 1.2))
	for point in data.benches:
		obstacles.append(Rect2(absolute(point) - Vector2(.9, .35), Vector2(1.8, .7)))
	for point in data.lamps:
		obstacles.append(Rect2(absolute(point) - Vector2.ONE * .15, Vector2.ONE * .3))
	for point in data.ornaments:
		obstacles.append(Rect2(absolute(point) - Vector2.ONE * .35, Vector2.ONE * .7))
	for side in [-1, 1]:
		obstacles.append(Rect2(portal + Vector2(side * 1.5, 0) - Vector2.ONE * .2, Vector2.ONE * .4))
		for gate in gates:
			obstacles.append(Rect2(gate.point + Vector2(side * 1.5, 0) - Vector2.ONE * .2, Vector2.ONE * .4))

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("id") is String or not document.id.begins_with("city:") or not document.get("name") is String or not document.get("themes") is Dictionary or not document.themes.has(document.get("default_theme")):
		return false
	for key in ["center", "spawn", "portal"]:
		if not pair(document.get(key)):
			return false
	if not number(document.get("elevation")) or document.elevation < 9 or document.elevation > 30:
		return false
	for key in ["islands", "bridges", "halls", "markets", "benches", "lamps", "ornaments", "gates"]:
		if not document.get(key) is Array or document[key].size() > 64:
			return false
	var gate_ids := {}
	for gate in document.gates:
		if not gate is Dictionary or not gate.get("id") is String or gate.id.is_empty() or gate_ids.has(gate.id) or not gate.get("name") is String or not pair(gate.get("position")) or gate.get("kind") not in ["sanctum", "dimension"]:
			return false
		if gate.kind == "dimension" and (not gate.get("destination_id") is String or gate.destination_id.is_empty()):
			return false
		gate_ids[gate.id] = true
	for island in document.islands:
		if not island is Dictionary or not pair(island.get("center")) or not pair(island.get("radius")) or not island.radius.all(func(value): return value >= 3 and value <= 30):
			return false
	for plot in document.halls + document.markets:
		if not plot is Dictionary or not plot.get("id") is String or not plot.get("name") is String or not pair(plot.get("position")) or not pair(plot.get("size")) or not plot.size.all(func(value): return value > 0 and value <= 10):
			return false
	for profile in document.themes.values():
		for key in ["stone", "edge", "roof", "accent", "magic", "sky"]:
			if not profile.get(key) is String or not Color.html_is_valid(profile[key]):
				return false
		if not profile.get("pumpkins") is bool:
			return false
	return true

static func number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func pair(value) -> bool:
	return value is Array and value.size() == 2 and value.all(number)

func absolute(point: Array) -> Vector2:
	return Vector2(center) + Vector2(point[0], point[1])

func ground_height(_point: Vector2) -> float:
	return float(data.elevation)

func set_theme(season: String) -> bool:
	if not data.themes.has(season):
		return false
	theme = season
	return true

func service_points() -> Array[Vector2]:
	var result: Array[Vector2] = [spawn, portal, absolute([0, 0])]
	for gate in gates:
		result.append(gate.point)
	for house in houses:
		result.append(house.approach)
	for market in markets:
		result.append(market.approach)
	return result

func city_record() -> Dictionary:
	var residents: Array[Dictionary] = []
	for index in range(4):
		var point := absolute([[2, 1], [-21, 2], [-5, -3], [21, 5]][index])
		residents.append({"id": data.id + ":npc:%s" % index, "kind": "npc", "role": "fountain_keeper" if index == 0 else "merchant", "point": point, "approach": point, "city_id": data.id, "city_name": data.name, "biome": 2, "appearance": index})
	return {"id": data.id, "name": data.name, "type": "city", "cell": center, "height": float(data.elevation), "biome": 2, "archetype_id": "arcane", "style": 0, "houses": houses.duplicate(true), "outdoor_lots": markets.duplicate(true), "residents": residents, "books": [], "decorations": [], "streets": tiles.duplicate(), "floating_city": true, "theme": theme, "hub_tiles": floor_kinds.duplicate(), "hub_spawn": spawn, "hub_portal": portal, "hub_gates": gates.duplicate(true), "hub_obstacles": obstacles.duplicate()}

func cell_info(cell: Vector2i) -> Dictionary:
	var supported := tiles.has(cell)
	return {"biome": 2, "terrain": floor_kinds.get(cell, "sky"), "prop": "", "detail": "", "facet": "", "walkable": supported and walkable(Vector2(cell)), "height": float(data.elevation), "base_height": 0.0, "base_terrain": "sky", "bridge_axis": Vector2i.RIGHT, "bridge_edge": 0, "bridge_pier": false, "tone": 0, "hub_id": data.id}
