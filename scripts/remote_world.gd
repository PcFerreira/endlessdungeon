extends "res://scripts/world.gd"

const Codec = preload("res://scripts/map_chunk_codec.gd")
signal chunks_requested(coordinates: Array)
var content_revision := ""
var changed := false
var requested: Dictionary = {}

func generate(seed_value: int, edition: int = GENERATOR_VERSION) -> void:
	run_seed = seed_value
	generator_version = edition
	chunks.clear()
	cells.clear()
	tiles.clear()
	regions.clear()
	route_plans.clear()
	requested.clear()
	current_chunk = Vector2i(999999,999999)
	changed = true

func ready_around(point: Vector2) -> bool:
	var center := chunk_at(point)
	for x in range(center.x - CHUNK_RADIUS,center.x + CHUNK_RADIUS + 1):
		for y in range(center.y - CHUNK_RADIUS,center.y + CHUNK_RADIUS + 1):
			var coordinate := Vector2i(x,y)
			if not chunks.has(coordinate) or not regions.has(_region(coordinate * CHUNK_SIZE)):
				return false
	return true

func load_around(point: Vector2) -> bool:
	var center := chunk_at(point)
	var wanted := {}
	var missing := []
	for x in range(center.x - CHUNK_RADIUS,center.x + CHUNK_RADIUS + 1):
		for y in range(center.y - CHUNK_RADIUS,center.y + CHUNK_RADIUS + 1):
			var coordinate := Vector2i(x,y)
			wanted[coordinate] = true
			if not chunks.has(coordinate) and not requested.has(coordinate):
				requested[coordinate] = true
				missing.append([x,y])
	for coordinate in chunks.keys():
		if not wanted.has(coordinate):
			chunks.erase(coordinate)
			changed = true
	for coordinate in requested.keys():
		if not wanted.has(coordinate):
			requested.erase(coordinate)
	var keep_regions := {}
	for coordinate in wanted:
		keep_regions[_region(coordinate * CHUNK_SIZE)] = true
	for coordinate in regions.keys():
		if not keep_regions.has(coordinate):
			regions.erase(coordinate)
	if center != current_chunk or changed:
		current_chunk = center
		bounds = Rect2i((center - Vector2i.ONE * CHUNK_RADIUS) * CHUNK_SIZE,Vector2i.ONE * CHUNK_SIZE * (CHUNK_RADIUS * 2 + 1))
		_reindex()
		changed = false
		if not missing.is_empty():
			chunks_requested.emit(missing)
		return true
	if not missing.is_empty():
		chunks_requested.emit(missing)
	return false

func _reindex() -> void:
	cells.clear()
	tiles.clear()
	for chunk in chunks.values():
		cells.merge(chunk.cells)
		for cell in chunk.cells:
			if chunk.cells[cell].walkable:
				tiles[cell] = true

func ingest(message: Dictionary) -> bool:
	if message.get("type") != "chunks" or message.get("revision") != content_revision or not message.get("chunks") is Array or message.chunks.size() > 25 or not message.get("regions") is Array or message.regions.size() > 9:
		return false
	var new_regions := {}
	for encoded in message.regions:
		var decoded := Codec.decode(encoded)
		if not decoded.ok or not decoded.value is Dictionary or not decoded.value.get("coordinate") is Vector2i or not decoded.value.get("city") is Dictionary or not decoded.value.get("dungeons") is Array:
			return false
		if generator_version >= 6:
			for site in sites_in(decoded.value):
				if not Biomes.valid_cell(site):
					return false
		new_regions[decoded.value.coordinate] = decoded.value
	var new_chunks := {}
	for chunk in message.chunks:
		if not chunk is Dictionary or not _coordinate(chunk.get("coordinate")):
			return false
		var coordinate := Vector2i(chunk.coordinate[0],chunk.coordinate[1])
		var decoded := Codec.decode(chunk.get("cells"))
		if not decoded.ok or not decoded.value is Dictionary or decoded.value.size() != CHUNK_SIZE * CHUNK_SIZE:
			return false
		for cell in decoded.value:
			var info = decoded.value[cell]
			if not cell is Vector2i or chunk_at(Vector2(cell)) != coordinate or not info is Dictionary or not info.get("walkable") is bool or not info.get("height") is float and not info.get("height") is int:
				return false
			for key in ["biome","terrain","prop","detail","facet","base_height","base_terrain","bridge_axis","bridge_edge","bridge_pier","tone"]:
				if not info.has(key):
					return false
			if generator_version >= 6 and not Biomes.valid_cell(info):
				return false
		new_chunks[coordinate] = {"cells":decoded.value,"spawns":[]}
	regions.merge(new_regions,true)
	chunks.merge(new_chunks,true)
	for coordinate in new_chunks:
		requested.erase(coordinate)
	_reindex()
	changed = true
	return true

static func _coordinate(value) -> bool:
	return value is Array and value.size() == 2 and value.all(func(number): return (number is int or number is float) and is_finite(float(number)) and number == floorf(number) and absf(number) <= 6250000)

static func _region(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / REGION_SIZE),floori(float(cell.y) / REGION_SIZE))

func region_at(cell: Vector2i) -> Dictionary:
	var coordinate := _region(cell)
	return regions.get(coordinate,{"coordinate":coordinate,"city":{},"dungeons":[],"locations":[],"roads":{},"bridges":{},"facet":"","facet_center":Vector2i.ZERO,"transition":""})

func cell_info(cell: Vector2i) -> Dictionary:
	return cells.get(cell,{"biome":0,"terrain":"water","prop":"","detail":"","facet":"","walkable":false,"height":0.0,"base_height":0.0,"base_terrain":"water","bridge_axis":Vector2i.RIGHT,"bridge_edge":0,"bridge_pier":false,"tone":0})

func _build_chunk(_coordinate_value: Vector2i) -> Dictionary:
	return {}

func _biome_at(cell: Vector2i) -> int:
	return int(cell_info(cell).biome)

func biome_at(cell: Vector2i, _climate: int = -1) -> Dictionary:
	if not cells.has(cell):
		return {}
	var info: Dictionary = cells[cell]
	var id: String = info.get("biome_id",Biomes.LEGACY_IDS[int(info.biome)])
	var context := {"biome":info.biome,"biome_id":id,"biome_secondary":info.get("biome_secondary",id),"biome_blend":info.get("biome_blend",0.0)}
	if info.has("biome_mix"):
		context.biome_mix = info.biome_mix.duplicate(true)
	return context

func _raw_height(cell: Vector2i) -> float:
	return float(cell_info(cell).base_height)

func nearby_sites(_point: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for region in regions.values():
		result.append_array(sites_in(region))
	return result

func nearest_site(point: Vector2, type: String = "") -> Dictionary:
	var closest := {}
	var distance := INF
	for site in nearby_sites(point):
		if not type.is_empty() and site.type != type:
			continue
		var delta: float = point.distance_squared_to(Vector2(site.cell))
		if delta < distance:
			closest = site
			distance = delta
	return closest
