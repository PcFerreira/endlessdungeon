extends RefCounted

const World = preload("res://scripts/world.gd")
const Build = preload("res://scripts/character_build.gd")

static func pack(point: Vector2) -> Array:
	return [point.x, point.y]

static func unpack(values: Array) -> Vector2:
	return Vector2(values[0], values[1])

static func capture(game) -> Dictionary:
	game._snapshot_encounters()
	game._snapshot_discovery()
	var encounters := {}
	for id in game.encounter_states:
		var record: Dictionary = game.encounter_states[id].duplicate()
		record.point = pack(record.point)
		encounters[id] = record
	var discovery := {}
	for id in game.dungeon_discovery:
		discovery[id] = []
		for cell in game.dungeon_discovery[id]:
			discovery[id].append(pack(Vector2(cell)))
	var drops := []
	for pickup in game.pickups:
		drops.append({"kind": pickup.kind, "point": pack(pickup.point)})
	var shots := []
	for shot in game.projectiles:
		shots.append({"point": pack(shot.point), "direction": pack(shot.direction), "height": shot.height, "spell": shot.spell, "hostile": shot.hostile, "target": shot.target.get("id", ""), "life": shot.life, "trail": shot.trail})
	return {
		"generator_version": World.GENERATOR_VERSION, "saved_at": Time.get_unix_time_from_system(), "seed": str(game.run_seed), "rng_state": str(game.rng.state), "build": game.build.snapshot(),
		"location": {"layer": game.layer, "name": game.location_name(), "point": pack(game.player_point), "player_y": game.player_y, "velocity": game.vertical_velocity, "grounded": game.grounded, "depth": game.depth, "site_cell": pack(Vector2(game.active_dungeon.get("cell", Vector2i.ZERO))), "site_id": game.active_dungeon.get("id", ""), "surface_return": pack(game.surface_return_point), "sanctuary": pack(game.sanctuary), "aim": pack(game.aim), "heading": pack(game.move_heading), "selected": game.selected_target.get("id", "")},
		"stats": {"hp": game.hp, "mana": game.mana, "kills": game.kills, "elapsed": game.elapsed, "guard": game.guard_time, "invulnerable": game.invulnerable, "best_depth": game.best_depth, "cooldowns": game.cooldowns.duplicate()},
		"progress": {"encounters": encounters, "floors": game.dungeon_progress.duplicate(), "claimed": game.claimed_chests.keys(), "cities": game.visited_cities.keys(), "waypoint": game.waypoint.get("id", ""), "waypoint_cell": pack(Vector2(game.waypoint.get("cell", Vector2i.ZERO))), "discovery": discovery},
		"home": {"item": "sanctum_sigil", "return_journey": game.sanctum_return.duplicate(true)},
		"view": {"yaw": game.camera_yaw, "target_yaw": game.target_yaw, "surface_zoom": game.surface_zoom, "dungeon_zoom": game.dungeon_zoom}, "pickups": drops, "projectiles": shots
	}

static func restore(game, data: Dictionary) -> bool:
	var world := World.new()
	world.generate(data.seed.to_int())
	var place: Dictionary = data.location
	var destination: Dictionary = data.home.return_journey.location if place.layer == "sanctum" else place
	var site := {}
	if destination.layer == "dungeon":
		for candidate in world.region_at(Vector2i(unpack(destination.site_cell))).dungeons:
			if candidate.id == destination.site_id and Vector2(candidate.cell).is_equal_approx(unpack(destination.site_cell)):
				site = candidate
		if site.is_empty() or destination.depth > site.floors:
			return false
	var build := Build.new()
	if not build.restore(data.build):
		return false
	game._clear_actors()
	game.view_key = ""
	game.world = world
	game.run_seed = world.run_seed
	game.world_view.reset()
	game.build = build
	game.ACTION_BAR = build.action_bar
	game._apply_build()
	game.player_mesh.mesh = game.Voxels.character(build.class_id)
	game.encounter_states.clear()
	for id in data.progress.encounters:
		var record: Dictionary = data.progress.encounters[id].duplicate()
		record.point = unpack(record.point)
		game.encounter_states[id] = record
	game.dungeon_progress.clear()
	for id in data.progress.floors:
		game.dungeon_progress[id] = int(data.progress.floors[id])
	game.claimed_chests.clear()
	for id in data.progress.claimed:
		game.claimed_chests[id] = true
	game.visited_cities.clear()
	for id in data.progress.cities:
		game.visited_cities[id] = true
	game.dungeon_discovery.clear()
	for id in data.progress.discovery:
		game.dungeon_discovery[id] = []
		for cell in data.progress.discovery[id]:
			game.dungeon_discovery[id].append(Vector2i(unpack(cell)))
	game.sanctuary = unpack(place.sanctuary)
	game.surface_return_point = unpack(place.surface_return)
	game.active_dungeon = site
	game.sanctum_return = data.get("home", {}).get("return_journey", {}).duplicate(true)
	game.best_depth = maxi(game.best_depth, int(data.stats.best_depth))
	game.camera_yaw = data.view.yaw
	game.target_yaw = data.view.target_yaw
	game.surface_zoom = clampf(data.view.surface_zoom, 12, 24)
	game.dungeon_zoom = clampf(data.view.dungeon_zoom, 10, 22)
	var point := unpack(place.point)
	if place.layer == "sanctum":
		game._generate_sanctum(point)
	elif place.layer == "dungeon":
		game.layer = "dungeon"
		game.depth = int(place.depth)
		game._generate_floor(false)
		game.player_point = game.dungeon.safe_position(point)
		if not game.dungeon.walkable(game.player_point):
			game.player_point = Vector2(game.dungeon.start)
		game.dungeon_view.reveal(game.dungeon, game.player_point)
	else:
		game._generate_surface(point, false)
	var clearance: float = place.player_y + (.51 if place.grounded else .05)
	if game.dungeon.walkable(point) and game.dungeon.clearance_height(point) <= clearance:
		game.player_point = point
	game._snap_camera()
	if game.player_point.is_equal_approx(point):
		game.player_y = maxf(data.location.player_y, game.dungeon.ground_height(point))
		game.vertical_velocity = place.velocity
		game.grounded = place.grounded
	game.player.position = Vector3(game.player_point.x, game.player_y, game.player_point.y)
	game.hp = clampf(data.stats.hp, 0, game.max_hp)
	game.mana = clampf(data.stats.mana, 0, game.max_mana)
	game.kills = int(data.stats.kills)
	game.elapsed = data.stats.elapsed
	game.guard_time = data.stats.guard
	game.invulnerable = data.stats.invulnerable
	for spell in game.cooldowns:
		game.cooldowns[spell] = data.stats.cooldowns[spell]
	game.aim = unpack(place.aim)
	game.move_heading = unpack(place.heading)
	game.waypoint = {}
	if not data.progress.waypoint.is_empty():
		var region: Dictionary = world.region_at(Vector2i(unpack(data.progress.waypoint_cell)))
		var candidates: Array = [region.city]
		candidates.append_array(region.dungeons)
		for candidate in candidates:
			if candidate.id == data.progress.waypoint:
				game.waypoint = candidate
	var targets := {}
	for enemy in game.enemies:
		targets[enemy.id] = enemy
		enemy.node.visible = enemy.point.distance_to(game.player_point) < 8.5 and game.dungeon.line_clear(game.player_point, enemy.point)
		if enemy.id == place.get("selected", ""):
			game.select_target(enemy)
	for pickup in data.pickups:
		game._drop(unpack(pickup.point), pickup.kind)
	for shot in data.projectiles:
		if not shot.hostile and not targets.has(shot.target):
			continue
		game._shoot(unpack(shot.point), unpack(shot.direction), shot.spell, shot.hostile, targets.get(shot.target, {}))
		var restored: Dictionary = game.projectiles[-1]
		for key in ["height", "life", "trail"]:
			restored[key] = shot[key]
		restored.node.position.y = shot.height
	game.rng.seed = game.run_seed
	game.rng.state = data.rng_state.to_int()
	game.has_journey = true
	game.state = "dead" if game.hp <= 0 else "playing"
	game.rotating_camera = false
	game.autosave_timer = 0
	game.interface.previous_state = ""
	return true
