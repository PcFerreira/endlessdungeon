extends SceneTree

const BaseWorld = preload("res://scripts/world.gd")
const Codec = preload("res://scripts/map_chunk_codec.gd")
const Remote = preload("res://scripts/remote_world.gd")

func _initialize() -> void:
	var script = load("res://scripts/floating_city.gd")
	assert(script != null, "The starting floating city needs an authoritative floor and stable service layout")
	var city = script.new()
	assert(city.walkable(city.spawn) and city.ground_height(city.spawn) > 8)
	var seen := {Vector2i(city.spawn): true}
	var queue: Array[Vector2i] = [Vector2i(city.spawn)]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in city.DIRECTIONS:
			var next: Vector2i = cell + direction
			if not seen.has(next) and city.can_step(Vector2(cell), Vector2(next)):
				seen[next] = true
				queue.append(next)
	for point in city.service_points():
		assert(seen.has(Vector2i(point)), "Every guild, market and departure approach must connect to the arrival plaza")
	assert(not city.walkable(Vector2(city.center) + Vector2(60, 0)), "Players cannot walk into the sky")
	var collision: Array = city.obstacles.duplicate()
	var floor: Dictionary = city.tiles.duplicate()
	var identity: Dictionary = city.city_record()
	assert(city.set_theme("arcane") and city.tiles == floor and city.obstacles == collision)
	assert(city.city_record().id == identity.id and city.city_record().houses == identity.houses and city.city_record().outdoor_lots == identity.outdoor_lots, "Season changes must preserve permanent building/store identities")
	assert(not city.set_theme("unknown") and city.theme == "arcane")
	for edition in [4, 6]:
		var provider = load("res://scripts/hub_world.gd").new()
		provider.generate(12345, edition)
		provider.load_around(city.spawn)
		assert(provider.walkable(city.spawn) and provider.chunks.values().all(func(chunk): return chunk.spawns.is_empty()))
		var plain := BaseWorld.new()
		plain.generate(12345, edition)
		assert(provider.cell_info(plain.start) == plain.cell_info(plain.start), "Floating hubs must preserve natural world generation")
		var remote := Remote.new()
		remote.generate(12345, edition)
		remote.content_revision = "hub-fixture"
		var chunks := []
		var regions := []
		var known := {}
		for coordinate in provider.chunks:
			chunks.append({"coordinate": [coordinate.x, coordinate.y], "cells": Codec.encode(provider.chunks[coordinate].cells)})
			var region: Dictionary = provider.region_at(coordinate * provider.CHUNK_SIZE)
			if not known.has(region.coordinate):
				known[region.coordinate] = true
				regions.append(Codec.encode(region))
		assert(remote.ingest(JSON.parse_string(JSON.stringify({"type": "chunks", "revision": "hub-fixture", "chunks": chunks, "regions": regions}))))
		assert(remote.walkable(city.spawn) and remote.ground_height(city.spawn) == provider.ground_height(city.spawn))
		for cell in provider.cells:
			assert(remote.cell_info(cell) == provider.cell_info(cell), "The online lobby must render server-authored island and sky cells")
	print("PASS: floating arrival, connected guild/market/dock approaches, sky collision, stable seasonal identity, unchanged natural terrain and exact remote hub chunks")
	quit()
