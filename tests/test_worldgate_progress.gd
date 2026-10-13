extends SceneTree
const Game = preload("res://scripts/game.gd")
var directory := OS.get_cache_dir().path_join("endless-test-worldgate-progress-%s" % OS.get_process_id())
var game
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	return condition

func same(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	if left is Dictionary and right is Dictionary:
		return left.size() == right.size() and left.keys().all(func(key): return right.has(key) and same(left[key], right[key]))
	if left is Array and right is Array:
		return left.size() == right.size() and range(left.size()).all(func(index): return same(left[index], right[index]))
	return left == right

func finish() -> void:
	if game != null:
		game.queue_free()
	await process_frame
	if DirAccess.dir_exists_absolute(directory):
		for filename in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(filename))
		DirAccess.remove_absolute(directory)
	print("RESULT: ", {"failures": failures.size(), "private_saves_removed": not DirAccess.dir_exists_absolute(directory)})
	quit(0 if failures.is_empty() else 1)

func collect_drops() -> void:
	for pickup in game.pickups.duplicate():
		game.player_point = pickup.point
		game._update_pickups(.01)

func complete_short_dungeon() -> Dictionary:
	var site: Dictionary = game.world.site_by_id("ruin:-1:2:0", Vector2i(-19, 294))
	if not check(not site.is_empty() and site.floors == 2, "Seed12345 actual short dungeon must have two generated floors"):
		return {}
	game.enter_dungeon(site)
	var discovery_keys: Array[String] = []
	for floor_number in range(1, 3):
		if not check(game.layer == "dungeon" and game.depth == floor_number and not game.enemies.is_empty(), "Real generated floor must contain combat before descent/chest"):
			return {}
		for enemy in game.enemies.duplicate():
			game._hit_enemy(enemy, 100000)
		collect_drops()
		if not check(game.enemies.is_empty(), "Real floor combat must remove all enemies"):
			return {}
		game.player_point = Vector2(game.dungeon.exit) + Vector2.DOWN
		game._snap_camera()
		game.dungeon_view.reveal(game.dungeon, game.player_point)
		discovery_keys.append(game.view_key)
		if floor_number == 1:
			game.descend()
		else:
			var skill_points: int = game.build.skill_points
			game.interact()
			if not check(game.claimed_chests.has(site.id) and game.build.skill_points == skill_points + 1, "Physical generated chest interaction must claim a real skill reward"):
				return {}
			collect_drops()
	game.return_to_surface()
	var progress: Dictionary = game.make_save_data().progress
	check(progress.floors.get(site.id) == 2 and game.best_depth >= 2, "Real descent must populate floor history and best depth")
	for key in discovery_keys:
		check(not progress.discovery.get(key, []).is_empty(), "Real generated floor visibility must populate discovery: " + key)
	print("DUNGEON PROGRESS: ", {"id": site.id, "floor": progress.floors.get(site.id), "claimed": game.claimed_chests.has(site.id), "discovered": discovery_keys.map(func(key): return {"key": key, "cells": progress.discovery.get(key, []).size()}), "best_depth": game.best_depth})
	return {"id": site.id, "discovery_keys": discovery_keys, "skill_points": game.build.skill_points}

func run_checks() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_run(12345, 6)
	game._clear_actors()
	game._drop(game.player_point + Vector2.RIGHT * 4, "gold_coin")
	var origin: Dictionary = game.make_save_data()
	if not check(game.use_sanctum_sigil() and game.layer == "sanctum", "Initial H must enter home"):
		await finish()
		return
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	game.interact()
	if not check(game.floating_hub.active(), "Actual study shelf E must enter Lanternwake"):
		await finish()
		return
	check(same(game.dimension.outside_return.location, origin.location), "Study preserves the original location thread")
	game._clear_actors()
	game.player_point = game.floating_hub.city().hub_portal
	game._snap_camera()
	if not check(game.floating_hub.target().get("kind") == "depart", "Actual Worldgate departure target"):
		await finish()
		return
	game.interact()
	if not check(not game.floating_hub.active() and game.layer == "overworld", "Worldgate E must depart to Endless"):
		await finish()
		return
	var gate: Vector2 = game.world.region_at(Vector2i(game.player_point.round())).get("hub_world_gate", Vector2.INF)
	if not check(gate.is_finite(), "Actual departure region must own a return Worldgate"):
		await finish()
		return
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.enter_dungeon(site)
	if not check(game.layer == "dungeon" and not game.enemies.is_empty(), "Actual Endless dungeon must generate a real enemy"):
		await finish()
		return
	var victim: Dictionary = game.enemies[0]
	var victim_id: String = victim.id
	var prior_items: Dictionary = game.inventory.snapshot()
	game._hit_enemy(victim, 100000)
	collect_drops()
	var reward_items: Dictionary = game.inventory.snapshot()
	check(game.kills == origin.stats.kills + 1, "Real kill must increment the original counter")
	check(not same(prior_items, reward_items), "Real dropped rewards must be collected into inventory")
	game.return_to_surface()
	var completed := complete_short_dungeon()
	if completed.is_empty():
		await finish()
		return
	reward_items = game.inventory.snapshot()
	game._generate_surface(gate)
	if not check(game.floating_hub.target().get("kind") == "return", "Actual wilderness Worldgate return target"):
		await finish()
		return
	game.interact()
	if not check(game.floating_hub.active(), "Actual wilderness E must return to Lanternwake"):
		await finish()
		return
	game._clear_actors()
	var before: Dictionary = game.make_save_data()
	print("BEFORE HOME: ", {"kills": before.stats.kills, "best_depth": before.stats.best_depth, "inventory": before.inventory, "floors": before.progress.floors, "cities": before.progress.cities, "victim": victim_id, "dead_encounter": before.progress.encounters.get(victim_id), "historical_kills": game.dimension.outside_return.stats.kills, "historical_pickups": origin.pickups, "rng": before.rng_state, "origin_rng": origin.rng_state})
	if not check(game.save_game(1), "Private before-home save must validate and persist"):
		await finish()
		return
	if not check(game.use_sanctum_sigil() and game.layer == "sanctum", "H is used only after actual Worldgate return to hub"):
		await finish()
		return
	if not check(game.leave_sanctum() and game.layer == origin.location.layer, "H must resume the original journey"):
		await finish()
		return
	var after: Dictionary = game.make_save_data()
	print("AFTER ORIGINAL RETURN: ", {"kills": after.stats.kills, "best_depth": after.stats.best_depth, "inventory": after.inventory, "floors": after.progress.floors, "cities": after.progress.cities, "dead_encounter": after.progress.encounters.get(victim_id), "pickups": after.pickups, "rng": after.rng_state, "point": after.location.point, "origin_point": origin.location.point})
	check(after.stats.kills == before.stats.kills, "Legitimate Worldgate/home/original return must retain the real kill counter")
	check(same(after.inventory, reward_items), "Collected combat rewards must survive the original return")
	check(after.stats.best_depth >= before.stats.best_depth, "Best depth must not rewind")
	check(after.progress.floors.get(completed.id) == 2, "Actual descended floor must survive the original return")
	check(after.progress.claimed.has(completed.id), "Actual claimed chest must survive the original return")
	check(game.build.skill_points == completed.skill_points, "Actual chest skill reward must survive the original return")
	for key in completed.discovery_keys:
		check(same(after.progress.discovery.get(key), before.progress.discovery.get(key)), "Actual floor discovery must survive the original return: " + key)
	check(before.progress.cities.all(func(id): return after.progress.cities.has(id)), "Visited city history must survive the original return")
	check(after.progress.encounters.has(victim_id) and after.progress.encounters[victim_id].hp == 0, "Real defeated encounter must remain defeated")
	check(same(after.pickups, origin.pickups), "Intentional original pickup restoration must remain exact")
	check(after.rng_state == origin.rng_state, "Intentional original RNG restoration must remain exact")
	check(same(after.location.point, origin.location.point), "Intentional original location restoration must remain exact")
	check(game.save_game(2), "Private original-return save must validate and persist")
	if failures.is_empty():
		print("PASS: actual Worldgate combat/home/original return retains kills, cities, floors, chest, discovery, best depth, rewards and defeated encounter with exact original point/RNG/pickups")
	await finish()
