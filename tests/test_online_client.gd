extends SceneTree

const Game = preload("res://scripts/game.gd")
const Codec = preload("res://scripts/map_chunk_codec.gd")
const Minimap = preload("res://scripts/minimap.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-online-%s" % Time.get_ticks_usec()
	game.online.config_path = "user://test-online-token-%s.cfg" % Time.get_ticks_usec()
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	var offline_point: Vector2 = game.player_point
	var offline_inventory: Dictionary = game.inventory.snapshot()
	var map_packets := []
	for region in game.world.regions.values():
		map_packets.append({"type": "chunks", "revision": game.online.content_revision, "chunks": [], "regions": [Codec.encode(region)]})
	for coordinate in game.world.chunks:
		map_packets.append({"type": "chunks", "revision": game.online.content_revision, "chunks": [{"coordinate": [coordinate.x, coordinate.y], "cells": Codec.encode(game.world.chunks[coordinate].cells)}], "regions": []})
	game.online.open_lobby()
	assert(game.state == "online_lobby" and not game.offline_actions_allowed())
	assert(not game.online.credential_problem("no space", "long-password-123").is_empty())
	assert(not game.online.credential_problem("Good_Name", "short").is_empty())
	game.online.receive({"type": "error", "code": "invalid_credentials", "message": "Account name or password is incorrect."})
	assert(game.state == "online_lobby" and not game.online.connecting and not game.online.session)
	var player := {"id": "one", "username": "First", "class_id": "mage", "profile": game.profile.snapshot(), "build": game.build.snapshot(), "inventory": game.inventory.snapshot(), "position": [offline_point.x, offline_point.y], "heading": [1, 0]}
	var second: Dictionary = player.duplicate(true)
	second.id = "two"
	second.username = "Second"
	second.position = [offline_point.x + 1, offline_point.y]
	var welcome := {"type": "welcome", "protocol": 1, "token": "test-token", "player": player, "world": {"id": "public", "seed": "12345", "generator_version": 4, "content_revision": game.online.content_revision}, "players": [player, second]}
	game.online.receive(JSON.parse_string(JSON.stringify(welcome)))
	assert(not game.online.session and game.state == "online_lobby", "Map chunks must arrive before entering")
	for packet in map_packets:
		game.online.receive(JSON.parse_string(JSON.stringify(packet, "", false, true)))
	assert(game.online.session and game.state == "playing" and game.enemies.is_empty())
	assert(game.world.get_script() == game.online.RemoteWorld and game.world.temperature.seed == 0)
	var atlas := Minimap.new()
	atlas.game = game
	var knowledge_before: Dictionary = game.exploration.knowledge.snapshot()
	var metadata_before: Dictionary = game.world.regions.duplicate(true)
	var downloaded: Array[Dictionary] = atlas.map_sites()
	assert(not downloaded.is_empty(), "Public atlas must show real places in received cells")
	for site in downloaded:
		assert(game.world.cells.has(Vector2i(site.cell)))
	assert(game.world.regions == metadata_before and game.exploration.knowledge.snapshot() == knowledge_before)
	var signature: String = atlas.chart_key(Vector2i(game.player_point.round()), 48)
	var cell_count: int = game.world.cells.size()
	game.online.receive(JSON.parse_string(JSON.stringify(map_packets[-1], "", false, true)))
	assert(game.world.cells.size() == cell_count and atlas.chart_key(Vector2i(game.player_point.round()), 48) != signature, "Equal-size incoming chunks must refresh a stationary map")
	var city: Dictionary = downloaded.filter(func(site): return site.type == "city")[0]
	var city_cell := Vector2i(city.cell)
	var city_info: Dictionary = game.world.cells[city_cell]
	game.world.cells.erase(city_cell)
	assert(not atlas.map_sites().any(func(site): return site.id == city.id), "Region metadata alone must not reveal an undownloaded site")
	game.world.cells[city_cell] = city_info
	assert(game.online.avatars.size() == 1 and game.online.avatars.two.node.position.distance_to(game.player.position) > .5)
	var before: Dictionary = game.inventory.snapshot()
	assert(not game.use_item("health_potion") and not game.discard_item("sanctum_sigil"))
	assert(not game.save_game(1) and not game.load_game(1) and game.make_save_data().is_empty())
	game.cast("blink")
	game.respawn()
	game.interact()
	game.world_items.place("rune_lantern", game.player_point)
	assert(game.inventory.snapshot() == before and game.layer == "overworld" and game.projectiles.is_empty())
	game.camera_yaw = PI / 4
	game.target_yaw = PI / 4
	var steering: Vector2 = game.online.movement(Vector2.UP, true)
	assert(steering.is_equal_approx(game.screen_movement(Vector2.UP)))
	game.state = "paused"
	assert(game.online.movement(Vector2.UP, true) == Vector2.ZERO)
	game.state = "playing"
	assert(game.online.movement(Vector2.UP, false) == Vector2.ZERO)
	var boundary: Dictionary = player.duplicate(true)
	boundary.position = [offline_point.x, 31.95]
	game.player_point = Vector2(offline_point.x, 32.10)
	game.online.receive({"type": "state", "tick": 0, "players": [boundary, second]})
	game.online.render(.001)
	assert(game.world.current_chunk == game.world.chunk_at(Vector2(boundary.position[0], boundary.position[1])), "Map requests must use authority rather than interpolated render position")
	second.position = [offline_point.x + 2, offline_point.y]
	game.online.receive({"type": "state", "tick": 2, "players": [player, second]})
	game.online.render(.05)
	assert(game.online.avatars.two.node.position.x > offline_point.x + 1)
	var moved: Dictionary = player.duplicate(true)
	moved.position = [offline_point.x + .3, offline_point.y]
	game.online.receive({"type": "state", "tick": 2.5, "players": [moved, second]})
	assert(game.online.tick == 2, "Fractional ticks are invalid")
	game.online.receive({"type": "state", "tick": 1, "players": [player]})
	assert(game.online.avatars.has("two"), "Old snapshots cannot remove newer players")
	game.online.receive({"type": "state", "tick": 3, "players": [player]})
	assert(game.online.avatars.is_empty())
	game.online.disconnect_world("Connection lost.")
	assert(not game.online.session and game.state == "menu" and game.has_journey)
	assert(game.player_point == offline_point and game.inventory.snapshot() == offline_inventory)
	assert(atlas.map_sites() == game.exploration.known_sites(), "Offline knowledge filtering must remain authoritative")
	atlas.free()
	game.online.open_lobby()
	var incompatible := {"type": "welcome", "protocol": 1, "token": "test-token", "player": player, "world": {"id": "public", "seed": "12345", "generator_version": 4, "content_revision": "another-build"}, "players": [player, second]}
	game.online.receive(incompatible)
	assert(not game.online.session and game.state == "online_lobby" and "Update" in game.online.status)
	game.online.disconnect_world("")
	DirAccess.remove_absolute(game.online.config_path)
	game.queue_free()
	print("PASS online authority, isometric steering, snapshots, remote avatars and offline cleanup")
	quit()
