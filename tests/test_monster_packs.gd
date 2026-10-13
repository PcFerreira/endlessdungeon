extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-monster-packs-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run_checks")

func open_patch(game) -> Vector2:
	for cell in game.world.cells:
		var point := Vector2(cell)
		if not game.world.city_at(point, 4).is_empty():
			continue
		var clear := true
		for x in range(-1, 2):
			for y in range(-1, 2):
				var next := point + Vector2(x, y)
				clear = clear and game.world.walkable(next) and absf(game.world.ground_height(next) - game.world.ground_height(point)) <= .5
		if clear:
			return point
	return Vector2.INF

func gap(game) -> float:
	var smallest := INF
	for enemy in game.enemies:
		for other in game.enemies:
			if enemy.id != other.id:
				smallest = minf(smallest, enemy.point.distance_to(other.point))
	return smallest

func step_pack(game, frames: int) -> void:
	for frame in range(frames):
		var previous := {}
		for enemy in game.enemies:
			previous[enemy.id] = enemy.point
		game._update_enemies(1.0 / 60)
		for enemy in game.enemies:
			assert(game.world.walkable(enemy.point), "Pack spacing must obey actual terrain collision")
			assert(enemy.point.distance_to(previous[enemy.id]) <= game.EnemyCatalog.TYPES[enemy.kind].speed / 60 + .0001, "Crowd avoidance must not exceed monster speed")
			assert(enemy.node.position.is_equal_approx(game.to_world(enemy.point)))

func check_body_spacing(game) -> void:
	for enemy in game.enemies:
		for other in game.enemies:
			if enemy.id != other.id:
				assert(enemy.point.distance_to(other.point) + .05 >= enemy.spacing_radius + other.spacing_radius, "Spacing must account for actual model widths")

func run_checks() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	game._clear_actors()
	game.life.actors.clear()
	var home := open_patch(game)
	assert(home != Vector2.INF, "The fixture needs an actual reachable wilderness patch")
	game.player_point = home + Vector2(0, 10)
	for index in range(3):
		game._spawn_enemy(home, [0, 1, 6][index], "pack:%s" % index)
		game.enemies[-1].grounds = {"home": home, "radius": 7, "cell": Vector2i(home) + [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN][index]}
		game.enemies[-1].attack = 100.0
	var random_before: int = game.rng.state
	step_pack(game, 180)
	assert(gap(game) >= .75, "Idle monsters at exactly the same point must spread apart")
	check_body_spacing(game)
	assert(game.enemies.all(func(enemy): return not enemy.active))
	game.player_point = home
	for enemy in game.enemies:
		enemy.point = home
		enemy.windup = 10.0
		enemy.active = true
	step_pack(game, 180)
	assert(gap(game) >= .75, "Attack windups must not freeze crowd separation")
	check_body_spacing(game)
	for enemy in game.enemies:
		enemy.windup = 0
	step_pack(game, 180)
	assert(gap(game) >= .75, "Chasing and attacking packs must retain personal space")
	check_body_spacing(game)
	game.player_point = home + Vector2(20, 0)
	var kills: int = game.kills
	for enemy in game.enemies:
		enemy.point = home
		enemy.path_time = 0
		enemy.returning = false
	step_pack(game, 240)
	assert(gap(game) >= .75, "Returning packs must not collapse onto a shared center")
	check_body_spacing(game)
	for enemy in game.enemies:
		assert(enemy.point.distance_to(Vector2(enemy.grounds.cell)) < 1.25 and not enemy.active)
	assert(game.rng.state == random_before and game.kills == kills, "Pack steering must not consume combat RNG or award rewards")
	game._generate_surface(Vector2(game.world.start), false)
	var added: Array = game.enemies.filter(func(enemy): return int(enemy.grounds.area_id.get_slice(":", 3)) >= 3)
	assert(added.size() >= 2, "New grounds must stream into an actual Game")
	var survivor: Dictionary = added[0]
	var survivor_id: String = survivor.id
	var defeated_id: String = added[1].id
	survivor.hp -= 1
	var saved_hp: float = survivor.hp
	game._hit_enemy(added[1], 100000)
	assert(game.save_game(1) and game.load_game(1))
	assert(game.enemies.any(func(enemy): return enemy.id == survivor_id and is_equal_approx(enemy.hp, saved_hp)))
	assert(not game.enemies.any(func(enemy): return enemy.id == defeated_id), "New ground deaths must remain defeated after a disk reload")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: actual mixed-size melee/ranged packs separate exact overlaps while idle/attacking/chasing/returning, respect terrain and speed, return individually, preserve combat RNG/rewards, and save new-ground health/deaths to disk")
	quit()
