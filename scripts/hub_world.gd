extends "res://scripts/world.gd"

const City = preload("res://scripts/floating_city.gd")
var hub := City.new()

func cell_info(cell: Vector2i) -> Dictionary:
	if hub.reserved.has_point(cell):
		var record := hub.cell_info(cell)
		if generator_version >= 6:
			record.merge({"biome_id": Biomes.LEGACY_IDS[2], "biome_secondary": Biomes.LEGACY_IDS[2], "biome_blend": 0.0})
		return record
	return super.cell_info(cell)

func region_at(cell: Vector2i) -> Dictionary:
	var coordinate := Vector2i(floori(float(cell.x) / REGION_SIZE), floori(float(cell.y) / REGION_SIZE))
	if regions.has(coordinate):
		return regions[coordinate]
	var area := Rect2i(coordinate * REGION_SIZE, Vector2i.ONE * REGION_SIZE)
	if area.intersects(hub.reserved):
		var city: Dictionary = hub_city() if area.has_point(hub.center) else {}
		var result := {"coordinate": coordinate, "city": city, "dungeons": [], "locations": [], "roads": {}, "bridges": {}, "facet": "", "facet_center": hub.center, "transition": ""}
		regions[coordinate] = result
		return result
	var result: Dictionary = super.region_at(cell)
	if area.has_point(start):
		result.hub_world_gate = Vector2(start)
	return result

func _build_chunk(coordinate: Vector2i) -> Dictionary:
	if Rect2i(coordinate * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE).intersects(hub.reserved):
		var records := {}
		for x in range(CHUNK_SIZE):
			for y in range(CHUNK_SIZE):
				var cell := coordinate * CHUNK_SIZE + Vector2i(x, y)
				records[cell] = cell_info(cell)
		return {"cells": records, "spawns": []}
	return super._build_chunk(coordinate)

func city_at(point: Vector2, margin: float = 0) -> Dictionary:
	if hub.reserved.has_point(Vector2i(point.round())):
		return hub_city() if hub.tiles.has(Vector2i(point.round())) else {}
	return super.city_at(point, margin)

func spawn_point() -> Vector2:
	return hub.spawn

func site_by_id(id: String, cell: Vector2i) -> Dictionary:
	if id == City.data.id:
		return hub_city() if cell == hub.center else {}
	return super.site_by_id(id, cell)

func nearest_site(point: Vector2, type: String = "") -> Dictionary:
	if hub.reserved.has_point(Vector2i(point.round())) and type in ["", "city"]:
		return hub_city()
	return super.nearest_site(point, type)

func hub_city() -> Dictionary:
	var record := hub.city_record()
	if generator_version >= 6:
		record.merge({"biome_id": Biomes.LEGACY_IDS[2], "biome_secondary": Biomes.LEGACY_IDS[2], "biome_blend": 0.0})
	return record
