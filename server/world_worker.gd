extends SceneTree

const World = preload("res://scripts/hub_world.gd")
const Build = preload("res://scripts/character_build.gd")
const Profile = preload("res://scripts/character_profile.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Codec = preload("res://scripts/map_chunk_codec.gd")
const SPEED := 3.8
const TICK_RATE := 20
const INPUT_TIMEOUT := 0.5
var connection := StreamPeerTCP.new()
var buffer := ""
var players: Dictionary = {}
var seed_value := 0
var edition := 4
var tick := 0
var initialized := false

func _initialize() -> void:
	Engine.physics_ticks_per_second = TICK_RATE
	Engine.max_fps = TICK_RATE
	var port := int(OS.get_environment("WORLD_WORKER_PORT"))
	if port <= 0 or connection.connect_to_host("127.0.0.1", port) != OK:
		quit(1)

func _process(_delta: float) -> bool:
	connection.poll()
	if connection.get_status() == StreamPeerTCP.STATUS_ERROR or connection.get_status() == StreamPeerTCP.STATUS_NONE:
		quit(1)
		return true
	if connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var count := connection.get_available_bytes()
	if count > 0:
		var result := connection.get_data(count)
		if result[0] != OK:
			quit(1)
			return true
		buffer += result[1].get_string_from_utf8()
	if buffer.length() > 1048576:
		quit(1)
		return true
	while buffer.contains("\n"):
		var line := buffer.get_slice("\n", 0)
		buffer = buffer.substr(line.length() + 1)
		var command = JSON.parse_string(line)
		if command is Dictionary:
			_command(command)
	return false

func _command(command: Dictionary) -> void:
	match command.get("type", ""):
		"init":
			seed_value = int(command.seed)
			edition = int(command.generator_version)
			if not edition in [4, 5, 6]:
				_reply(command, {"error": "Unsupported generation edition"})
				return
			initialized = true
			_reply(command, {"ready": true, "engine": Engine.get_version_info()})
		"join":
			_join(command)
		"hub_travel":
			_travel(command)
		"leave":
			var record := _record(str(command.id)) if players.has(str(command.id)) else {}
			players.erase(str(command.id))
			_reply(command, {"player": record})
		"input":
			var id := str(command.id)
			if players.has(id):
				players[id].direction = Vector2(float(command.direction[0]), float(command.direction[1])).limit_length(1)
				players[id].input_at = Time.get_ticks_msec()
		"snapshot":
			var records: Array = []
			for id in players:
				records.append(_record(id))
			_reply(command, {"players": records})
		"chunks":
			var id := str(command.id)
			if not players.has(id):
				_reply(command, {"error": "Unknown player"})
				return
			var world = players[id].world
			var chunks: Array = []
			var regions: Array = []
			var seen := {}
			for coordinate in command.coordinates:
				var cell := Vector2i(int(coordinate[0]), int(coordinate[1]))
				var region_cell: Vector2i = cell * World.CHUNK_SIZE
				var region_coordinate := Vector2i(floori(float(region_cell.x) / World.REGION_SIZE), floori(float(region_cell.y) / World.REGION_SIZE))
				chunks.append({"coordinate": [cell.x, cell.y], "cells": Codec.encode(world._build_chunk(cell).cells), "region_coordinate": [region_coordinate.x, region_coordinate.y]})
				if not seen.has(region_coordinate):
					seen[region_coordinate] = true
					regions.append({"coordinate": [region_coordinate.x, region_coordinate.y], "data": Codec.encode(world.region_at(region_cell))})
			_reply(command, {"chunks": chunks, "regions": regions})

func _join(command: Dictionary) -> void:
	if not initialized or not Build.CLASSES.has(command.get("class_id", "")):
		_reply(command, {"error": "Invalid class or uninitialized world"})
		return
	var maximum := int(OS.get_environment("MAX_PLAYERS")) if not OS.get_environment("MAX_PLAYERS").is_empty() else 32
	if players.size() >= maximum and not players.has(str(command.id)):
		_reply(command, {"error": "World is full"})
		return
	var build := Build.new()
	build.reset(command.class_id)
	build.restore(build.snapshot())
	var profile := Profile.new()
	profile.display_name = command.username
	var inventory := Inventory.new()
	var record: Dictionary = command.get("record", {})
	if not record.is_empty():
		if not build.restore(record.get("build", {})) or build.class_id != command.class_id or not profile.restore(record.get("profile", {}), command.class_id) or not inventory.restore(record.get("inventory", {}), command.class_id):
			_reply(command, {"error": "Invalid persisted character"})
			return
	var world := World.new()
	world.generate(seed_value, edition)
	var point := world.spawn_point()
	var saved = record.get("position", [])
	if saved is Array and saved.size() == 2 and is_finite(float(saved[0])) and is_finite(float(saved[1])) and absf(float(saved[0])) <= 1000000 and absf(float(saved[1])) <= 1000000:
		point = Vector2(float(saved[0]), float(saved[1]))
	world.load_around(point)
	point = world.safe_position(point)
	if not world.walkable(point):
		world.load_around(Vector2(world.start))
		point = world.safe_position(Vector2(world.start))
	world.load_around(point)
	var heading := Vector2.DOWN
	var saved_heading = record.get("heading", [])
	if saved_heading is Array and saved_heading.size() == 2:
		var candidate := Vector2(float(saved_heading[0]), float(saved_heading[1]))
		if candidate.is_finite() and candidate.length_squared() > 0:
			heading = candidate.normalized()
	players[str(command.id)] = {"id": str(command.id), "username": command.username, "class_id": command.class_id, "world": world, "build": build, "profile": profile, "inventory": inventory, "position": point, "heading": heading, "direction": Vector2.ZERO, "input_at": 0}
	_reply(command, {"player": _record(str(command.id))})

func _travel(command: Dictionary) -> void:
	var id := str(command.get("id", ""))
	if not players.has(id) or command.get("destination") not in ["world", "hub"]:
		_reply(command, {"error": "Unknown traveler or gate"})
		return
	var actor: Dictionary = players[id]
	var world = actor.world
	var source: Vector2 = world.hub.portal if command.destination == "world" else Vector2(world.start)
	if actor.position.distance_to(source) > 2 or not world.walkable(actor.position):
		_reply(command, {"refused": "Stand beside the Worldgate before traveling."})
		return
	var destination: Vector2 = Vector2(world.start) if command.destination == "world" else world.spawn_point()
	world.load_around(destination)
	destination = world.safe_position(destination)
	if not world.walkable(destination):
		_reply(command, {"refused": "The destination is not ready. Try again shortly."})
		return
	actor.position = destination
	actor.direction = Vector2.ZERO
	actor.input_at = 0
	_reply(command, {"player": _record(id)})

func _physics_process(delta: float) -> bool:
	if not initialized:
		return false
	tick += 1
	var records: Array = []
	for id in players:
		var actor: Dictionary = players[id]
		var direction: Vector2 = actor.direction
		if Time.get_ticks_msec() - int(actor.input_at) > int(INPUT_TIMEOUT * 1000):
			direction = Vector2.ZERO
		var world = actor.world
		if not direction.is_zero_approx():
			world.load_around(actor.position)
			var next: Vector2 = world.move_actor(actor.position, direction * SPEED * delta)
			if absf(next.x) <= 1000000 and absf(next.y) <= 1000000:
				actor.position = next
			actor.heading = direction.normalized()
		if tick % 1200 == 0:
			world.route_plans.clear()
			world.regions.clear()
			if world.site_planner != null:
				world.site_planner = World.SitePlanner.new(seed_value)
		records.append(_record(id))
	_send({"type": "state", "tick": tick, "players": records})
	return false

func _record(id: String) -> Dictionary:
	var actor: Dictionary = players[id]
	return {"id": actor.id, "username": actor.username, "class_id": actor.class_id, "profile": actor.profile.snapshot(), "build": actor.build.snapshot(), "inventory": actor.inventory.snapshot(), "position": [actor.position.x, actor.position.y], "heading": [actor.heading.x, actor.heading.y]}

func _reply(command: Dictionary, value: Dictionary) -> void:
	value.request = command.get("request", 0)
	_send(value)

func _send(value: Dictionary) -> void:
	if connection.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		connection.put_data((JSON.stringify(value, "", false, true) + "\n").to_utf8_buffer())
