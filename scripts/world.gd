extends "res://scripts/grid_area.gd"

const CHUNK_SIZE := 16
const GENERATOR_VERSION := 1
const REGION_SIZE := 64
const CHUNK_RADIUS := 2
const BIOMES := ["Greenwood", "Sunlit Meadows", "Amber Wastes", "Frostlands"]
const MAP_COLORS := [Color("447857"), Color("83a166"), Color("c6a567"), Color("a7bfcd")]
var run_seed := 0
var start := Vector2i(32, 35)
var chunks: Dictionary = {}
var cells: Dictionary = {}
var regions: Dictionary = {}
var temperature := FastNoiseLite.new()
var moisture := FastNoiseLite.new()
var elevation := FastNoiseLite.new()
var continents := FastNoiseLite.new()
var erosion := FastNoiseLite.new()
var ridges := FastNoiseLite.new()
var rivers := FastNoiseLite.new()
var current_chunk := Vector2i(999999, 999999)

func generate(seed_value: int) -> void:
	run_seed = seed_value
	chunks.clear()
	cells.clear()
	tiles.clear()
	regions.clear()
	current_chunk = Vector2i(999999, 999999)
	for noise in [temperature, moisture, elevation, continents, erosion, ridges, rivers]:
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_octaves = 3
	temperature.seed = _hash("heat") % 2147483647
	temperature.frequency = .009
	moisture.seed = _hash("rain") % 2147483647
	moisture.frequency = .015
	elevation.seed = _hash("land") % 2147483647
	elevation.frequency = .022
	continents.seed = _hash("continents") % 2147483647
	continents.frequency = .004
	erosion.seed = _hash("erosion") % 2147483647
	erosion.frequency = .010
	ridges.seed = _hash("ridges") % 2147483647
	ridges.frequency = .026
	rivers.seed = _hash("rivers") % 2147483647
	rivers.frequency = .013

func _raw_height(cell: Vector2i) -> float:
	var broad := continents.get_noise_2d(cell.x, cell.y)
	var worn := (erosion.get_noise_2d(cell.x, cell.y) + 1) * .5
	var ridge := pow(clampf(1.0 - absf(ridges.get_noise_2d(cell.x, cell.y) * 2), 0, 1), 3)
	var detail := elevation.get_noise_2d(cell.x, cell.y)
	return floorf(clampf(1.5 + broad * 5.5 + ridge * (1 - worn) * 7 + detail * 1.8, 0, 8) * 2) * .5

func ground_height(point: Vector2) -> float:
	return cell_info(Vector2i(point.round())).height

func _highway_height(cell: Vector2i, center: Vector2i) -> float:
	var axis := Vector2i.RIGHT if absi(cell.x - center.x) > absi(cell.y - center.y) else Vector2i.DOWN
	var distance := cell.x - center.x if axis.x != 0 else cell.y - center.y
	var neighbor := center + axis * REGION_SIZE * (1 if distance >= 0 else -1)
	var fraction := clampf((absf(distance) - 13) / (REGION_SIZE - 26), 0, 1)
	return floorf(lerpf(_raw_height(center), _raw_height(neighbor), fraction) * 2) * .5

func _surface_height(cell: Vector2i, region: Dictionary, road: bool) -> float:
	var center: Vector2i = region.city.cell
	var distance := Vector2(cell).distance_to(center)
	var altitude := lerpf(_raw_height(cell), region.city.height, 1 - smoothstep(13, 21, distance))
	if road and distance >= 13:
		altitude = _highway_height(cell, center)
		for site in region.dungeons:
			if absi(cell.x - site.cell.x) <= 1 and cell.y >= mini(center.y, site.cell.y) and cell.y <= maxi(center.y, site.cell.y):
				var length: float = absi(site.cell.y - center.y)
				var fraction := clampf(absf(cell.y - center.y) / maxf(1, length - 4), 0, 1)
				altitude = lerpf(_highway_height(Vector2i(site.cell.x, center.y), center), site.height, fraction)
	if not road:
		for site in region.dungeons:
			var proximity := Vector2(cell).distance_to(site.cell)
			altitude = lerpf(altitude, site.height, 1 - smoothstep(3.2, 7, proximity))
	return floorf(altitude * 2) * .5

func _hash(salt: String) -> int:
	var value: int = hash("%s:%s" % [run_seed, salt]) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0x7fffffff
	return value ^ (value >> 16)

func _biome_at(cell: Vector2i) -> int:
	var heat := temperature.get_noise_2d(cell.x, cell.y)
	if heat < -.22:
		return 3
	if heat > .23:
		return 2
	return 0 if moisture.get_noise_2d(cell.x, cell.y) > 0 else 1

static func chunk_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CHUNK_SIZE), floori(point.y / CHUNK_SIZE))

func region_at(cell: Vector2i) -> Dictionary:
	var coordinate := Vector2i(floori(float(cell.x) / REGION_SIZE), floori(float(cell.y) / REGION_SIZE))
	if regions.has(coordinate):
		return regions[coordinate]
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash("region:%s:%s" % [coordinate.x, coordinate.y])
	var center := coordinate * REGION_SIZE + Vector2i(32, 32)
	var prefixes := ["Dawn", "Amber", "Silver", "Thorn", "Mist", "Oak", "Star", "Ash"]
	var suffixes := ["haven", "watch", "brook", "reach", "crest", "gate", "ford", "fall"]
	var name: String = prefixes[rng.randi_range(0, 7)] + suffixes[rng.randi_range(0, 7)]
	var houses: Array[Dictionary] = []
	var slots := [Vector2i(-8, -8), Vector2i(-4, -8), Vector2i(4, -8), Vector2i(6, -4), Vector2i(4, 4), Vector2i(-4, 6), Vector2i(-8, 4), Vector2i(-8, -4)]
	var count := rng.randi_range(6, 8)
	var offset := rng.randi_range(0, 7)
	for index in range(count):
		var slot: Vector2i = slots[(index + offset) % slots.size()]
		var footprint := Rect2i(center + slot, Vector2i(rng.randi_range(2, 3), rng.randi_range(2, 3)))
		houses.append({"footprint": footprint, "height": rng.randf_range(1.35, 2.10), "style": rng.randi_range(0, 3)})
	var decorations: Array[Dictionary] = []
	for house in houses:
		for side in [0, house.footprint.size.x - 1]:
			var decor_cell: Vector2i = house.footprint.position + Vector2i(side, house.footprint.size.y)
			var local := decor_cell - center
			var available := absi(local.x) > 1 and absi(local.y) > 1 and Vector2(local).length() < 12
			for other in houses:
				available = available and not other.footprint.has_point(decor_cell)
			for decoration in decorations:
				available = available and decoration.cell != decor_cell
			if available:
				decorations.append({"cell": decor_cell, "kind": "pot" if side > 0 else ("barrel" if house.style % 2 == 0 else "crates")})
	var city := {"id": "city:%s:%s" % [coordinate.x, coordinate.y], "cell": center, "height": _raw_height(center), "name": name, "houses": houses, "decorations": decorations, "biome": _biome_at(center), "type": "city", "style": rng.randi_range(0, 2)}
	var dungeons: Array[Dictionary] = []
	for index in range(2):
		var side := 1 if index == 0 else -1
		var location := center + Vector2i(rng.randi_range(16, 24) * side, rng.randi_range(16, 24) * -side)
		var dungeon_names := ["Whispering Crypt", "Broken Sanctum", "Hollow Sepulchre", "Moonken Ruins", "Ashbound Vault", "Elder Catacombs"]
		var site_seed := _hash("dungeon:%s:%s:%s" % [coordinate.x, coordinate.y, index])
		var road_height := _highway_height(Vector2i(location.x, center.y), center)
		var grade_limit := (absi(location.y - center.y) - 5) * .5
		var site_height := floorf(clampf(_raw_height(location), road_height - grade_limit, road_height + grade_limit) * 2) * .5
		dungeons.append({"id": "ruin:%s:%s:%s" % [coordinate.x, coordinate.y, index], "cell": location, "height": site_height, "name": dungeon_names[rng.randi_range(0, 5)], "type": "dungeon", "seed": site_seed, "floors": 1 + site_seed % 20})
	var result := {"city": city, "dungeons": dungeons, "coordinate": coordinate}
	if regions.size() >= 32:
		regions.erase(regions.keys()[0])
	regions[coordinate] = result
	return result

func _road_at(cell: Vector2i, region: Dictionary) -> bool:
	var center: Vector2i = region.city.cell
	if absi(cell.x - center.x) <= 1 or absi(cell.y - center.y) <= 1:
		return true
	for site in region.dungeons:
		if absi(cell.y - center.y) <= 1 and cell.x >= mini(center.x, site.cell.x) and cell.x <= maxi(center.x, site.cell.x):
			return true
		if absi(cell.x - site.cell.x) <= 1 and cell.y >= mini(center.y, site.cell.y) and cell.y <= maxi(center.y, site.cell.y):
			return true
	return false

func cell_info(cell: Vector2i) -> Dictionary:
	if cells.has(cell):
		return cells[cell]
	var region := region_at(cell)
	var biome := _biome_at(cell)
	var city: Dictionary = region.city
	var in_city: bool = Vector2(cell).distance_to(city.cell) < 13.0
	var road := _road_at(cell, region)
	var altitude := _surface_height(cell, region, road)
	if altitude >= 6 and not in_city:
		biome = 3
	var channel := absf(rivers.get_noise_2d(cell.x, cell.y)) < .025
	var water: bool = (altitude <= 0 or elevation.get_noise_2d(cell.x, cell.y) < -.43 or channel) and not in_city
	var terrain := "water" if water else "land"
	var prop := ""
	var walkable := not water
	if road:
		terrain = "bridge" if water else ("paving" if in_city else "road")
		walkable = true
	elif in_city:
		var local: Vector2i = cell - city.cell
		terrain = "paving" if maxi(absi(local.x), absi(local.y)) <= 3 else "land"
		for house in city.houses:
			if house.footprint.has_point(cell):
				walkable = false
				terrain = "paving"
		for decoration in city.decorations:
			if decoration.cell == cell:
				walkable = false
				terrain = "paving"
	else:
		var roll := _hash("cell:%s:%s" % [cell.x, cell.y]) % 1000
		var cleared := false
		for site in region.dungeons:
			if Vector2(cell).distance_to(site.cell) < 3.2:
				cleared = true
				water = false
				terrain = "paving"
				walkable = true
		var spaced := true
		if roll < [75, 22, 35, 55][biome]:
			for x in range(-1, 2):
				for y in range(-1, 2):
					if x == 0 and y == 0:
						continue
					if _hash("cell:%s:%s" % [cell.x + x, cell.y + y]) % 1000 <= roll:
						spaced = false
		if not water and not cleared and spaced and roll < [75, 22, 35, 55][biome]:
			prop = ["oak", "rock", "cactus", "pine"][biome]
			walkable = false
	for site in region.dungeons:
		if cell.y == site.cell.y and absi(cell.x - site.cell.x) == 1:
			walkable = false
	if cell == city.cell or Rect2i(city.cell + Vector2i(8, 8), Vector2i(3, 3)).has_point(cell):
		walkable = false
	if terrain == "water":
		altitude = 0
	if altitude >= 6 and terrain == "land":
		biome = 3
	return {"biome": biome, "terrain": terrain, "prop": prop, "walkable": walkable, "height": altitude, "tone": _hash("tone:%s:%s" % [cell.x, cell.y]) % 3}

func load_around(point: Vector2) -> bool:
	var center := chunk_at(point)
	if center == current_chunk:
		return false
	current_chunk = center
	var wanted := {}
	for x in range(center.x - CHUNK_RADIUS, center.x + CHUNK_RADIUS + 1):
		for y in range(center.y - CHUNK_RADIUS, center.y + CHUNK_RADIUS + 1):
			var coordinate := Vector2i(x, y)
			wanted[coordinate] = true
			if not chunks.has(coordinate):
				chunks[coordinate] = _build_chunk(coordinate)
	for coordinate in chunks.keys():
		if not wanted.has(coordinate):
			chunks.erase(coordinate)
	cells.clear()
	tiles.clear()
	for chunk in chunks.values():
		cells.merge(chunk.cells)
		for cell in chunk.cells:
			if chunk.cells[cell].walkable:
				tiles[cell] = true
	bounds = Rect2i((center - Vector2i.ONE * CHUNK_RADIUS) * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE * (CHUNK_RADIUS * 2 + 1))
	return true

func _build_chunk(coordinate: Vector2i) -> Dictionary:
	var data := {}
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var cell := coordinate * CHUNK_SIZE + Vector2i(x, y)
			data[cell] = cell_info(cell)
	var spawns: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash("encounter:%s:%s" % [coordinate.x, coordinate.y])
	if rng.randf() < .65:
		for attempt in range(24):
			var cell := coordinate * CHUNK_SIZE + Vector2i(rng.randi_range(1, 14), rng.randi_range(1, 14))
			var region := region_at(cell)
			if not data[cell].walkable or Vector2(cell).distance_to(region.city.cell) < 15:
				continue
			spawns.append({"cell": cell, "kind": rng.randi_range(0, 2), "id": "wild:%s:%s" % [coordinate.x, coordinate.y]})
			break
	return {"cells": data, "spawns": spawns}

func nearby_sites(point: Vector2) -> Array[Dictionary]:
	var coordinate: Vector2i = region_at(Vector2i(point.round())).coordinate
	var result: Array[Dictionary] = []
	for x in range(coordinate.x - 1, coordinate.x + 2):
		for y in range(coordinate.y - 1, coordinate.y + 2):
			var region := region_at(Vector2i(x, y) * REGION_SIZE)
			result.append(region.city)
			result.append_array(region.dungeons)
	return result

func nearest_site(point: Vector2, type: String = "") -> Dictionary:
	var closest: Dictionary = {}
	var distance := INF
	for site in nearby_sites(point):
		if not type.is_empty() and site.type != type:
			continue
		var candidate: float = point.distance_squared_to(site.cell)
		if candidate < distance:
			distance = candidate
			closest = site
	return closest
