extends SceneTree

const Game = preload("res://scripts/game.gd")
class Terrace:
	extends "res://scripts/grid_area.gd"
	func ground_height(point: Vector2) -> float:
		return 1.0 if point.x >= 1.5 else 0.0
var game
var directory := "user://test-gameplay-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	assert(game.state == "playing" and game.layer == "overworld")
	assert(game.world.walkable(game.player_point) and game.world_view.chunk_nodes.size() == 25)
	var city: Dictionary = game.world.nearest_site(game.player_point, "city")
	game.player_point = Vector2(city.cell) + Vector2.DOWN
	game.hp = 20
	game.mana = 10
	game.interact()
	assert(game.hp == game.max_hp and game.mana == game.max_mana, "Cities must provide rest")
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	site = site.duplicate(true)
	site.floors = 2
	game.player_point = Vector2(site.cell)
	game.interact()
	assert(game.layer == "dungeon" and game.depth == 1)
	var guardian: Dictionary = game.enemies[0]
	var guardian_id: String = guardian.id
	game._hit_enemy(guardian, 100000.0)
	var remaining: int = game.enemies.size()
	var layout: Dictionary = game.dungeon.tiles.duplicate()
	game.return_to_surface()
	assert(game.layer == "overworld" and game.player_point.distance_to(site.cell) < 3)
	game.enter_dungeon(site)
	assert(game.enemies.size() == remaining and game.dungeon.tiles == layout, "Re-entering a dungeon must preserve its layout and defeated enemies")
	assert(game.encounter_states[guardian_id].hp == 0)
	assert(game.enemies.size() > 0)
	for enemy in game.enemies:
		assert(not enemy.node.visible or (enemy.point.distance_to(game.player_point) < 8.5 and game.dungeon.line_clear(game.player_point, enemy.point)), "Unseen enemies must be hidden on a new floor")
	for enemy in game.enemies:
		enemy.node.queue_free()
	game.enemies.clear()
	var combat_point := _combat_point()
	assert(combat_point.is_finite(), "Combat fixture needs a clear firing lane outside furnishings")
	game._spawn_enemy(combat_point, 0)
	assert(game.ACTION_BAR.size() == 10, "Action bar must have ten slots")
	game.cast_slot(0)
	assert(game.projectiles.is_empty(), "Offensive spells need a selected target")
	var target: Dictionary = game.enemies[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.camera.unproject_position(target.node.global_position + Vector3(0, .55, 0))
	game._unhandled_input(click)
	assert(game.selected_target == target, "Clicking the model must select the enemy")
	assert(game.projectiles.is_empty(), "Selecting must not attack")
	game.aim = Vector2.LEFT
	var health: float = game.enemies[0].hp
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_1
	game._unhandled_key_input(key)
	assert(game.projectiles.size() == 1, "Key 1 must cast the first slot")
	for frame in range(60):
		game.simulate(1.0 / 60)
	assert(target.hp < health, "Bolt must track and hit the selected enemy")
	key.physical_keycode = KEY_0
	var empty_shots: int = game.projectiles.size()
	game._unhandled_key_input(key)
	assert(game.projectiles.size() == empty_shots, "Empty slot 0 must not cast")
	var original_point: Vector2 = target.point
	var original_mana: float = game.mana
	target.point = game.player_point + Vector2(12, 0)
	game.cooldowns.fire = 0.0
	game.cast_slot(1)
	assert(game.mana == original_mana and game.cooldowns.fire == 0, "Out-of-range casts must not spend resources")
	target.point = game.player_point + Vector2(0, -5)
	game.cast_slot(1)
	assert(game.mana == original_mana and game.cooldowns.fire == 0, "Blocked casts must not spend resources")
	target.point = original_point
	game.mana = 0
	var shots: int = game.projectiles.size()
	game.cooldowns.fire = 0.0
	game.cast("fire")
	assert(game.projectiles.size() == shots, "Fireball must require mana")
	game.mana = game.max_mana
	game.cooldowns.nova = 0.0
	game._spawn_enemy(game.player_point + Vector2(1, 0), 2)
	game.cast("nova")
	assert(game.enemies[-1].slow > 0, "Nova must slow nearby enemies")
	var before: Vector2 = game.player_point
	game.cooldowns.blink = 0.0
	game.cast("blink")
	assert(game.player_point.distance_to(before) > .1)
	assert(game.dungeon.walkable(game.player_point), "Blink must stay inside floor")
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000.0)
	assert(game.enemies.is_empty())
	assert(game.selected_target.is_empty(), "Death of the target must clear selection")
	game.player_point = Vector2(game.dungeon.exit)
	game.interact()
	assert(game.state == "playing")
	assert(game.depth == 2 and game.state == "playing")
	assert(game.enemies.size() > 0 and game.projectiles.is_empty())
	assert(game.selected_target.is_empty(), "Descent must clear selection")
	game.return_to_surface()
	game.enter_dungeon(site)
	assert(game.depth == 2, "Each dungeon must retain its current depth")
	assert(not game.dungeon.walkable(Vector2(game.dungeon.exit)), "The final chest must have a solid footprint")
	game.player_point = Vector2(game.dungeon.exit)
	game.interact()
	assert(game.build.skill_points == 0, "The chest must stay sealed while wardens remain")
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000.0)
	game.interact()
	assert(game.build.skill_points == 1 and game.claimed_chests.has(site.id))
	game.interact()
	assert(game.build.skill_points == 1 and game.depth == site.floors, "A final chest must grant one point only and never generate another floor")
	assert(game.learn_skill("power"))
	game.return_to_surface()
	game.enter_dungeon(site)
	game.player_point = Vector2(game.dungeon.exit)
	game.interact()
	assert(game.build.skill_points == 0, "Leaving and re-entering must not duplicate chest rewards")
	game.jump()
	assert(not game.grounded)
	for frame in range(15):
		game.simulate(1.0 / 60)
	assert(game.player_y > .8, "Jump must produce real vertical movement")
	game.jump()
	for frame in range(90):
		game.simulate(1.0 / 60)
	assert(game.grounded and is_equal_approx(game.player_y, 0), "Jump must land without allowing a second jump in the air")
	game.invulnerable = 0
	game._hurt_player(100000.0)
	assert(game.state == "dead")
	game.respawn()
	assert(game.layer == "overworld" and game.hp == game.max_hp and game.damage_multiplier > 1, "Respawn must preserve progression and return to sanctuary")
	game.start_run(12345)
	assert(game.depth == 1 and game.hp == game.max_hp)
	assert(game.damage_multiplier == 1.0, "Restart must reset learned skills")
	game.state = "paused"
	var mana: float = game.mana
	game._physics_process(1.0)
	assert(game.mana == mana, "Pause must stop simulation")
	game.state = "title"
	game.choose_class("sword")
	assert(game.ACTION_BAR[0] == "strike" and game.max_hp == 140)
	game.state = "playing"
	game.enter_dungeon(site)
	for enemy in game.enemies:
		enemy.node.queue_free()
	game.enemies.clear()
	game._spawn_enemy(game.player_point + Vector2(1, 0), 0)
	game.select_target(game.enemies[0])
	var melee: Dictionary = game.enemies[0]
	game.cast("strike")
	assert(melee.hp < melee.max_hp and game.projectiles.is_empty(), "Sword attacks must deal immediate melee damage")
	melee.point = game.player_point + Vector2(4, 0)
	var before_hp: float = melee.hp
	game.cooldowns.strike = 0
	game.cast("strike")
	assert(melee.hp == before_hp and game.cooldowns.strike == 0, "Melee attacks must respect reach")
	game.cast("guard")
	game.invulnerable = 0
	var hp_before: float = game.hp
	game._hurt_player(20)
	assert(is_equal_approx(hp_before - game.hp, 7), "Guard must reduce incoming damage")
	for limit in [1, 20]:
		game.return_to_surface()
		var boundary: Dictionary = site.duplicate(true)
		boundary.id += ":limit%s" % limit
		boundary.floors = limit
		game.dungeon_progress[boundary.id] = limit
		game.enter_dungeon(boundary)
		assert(game.depth == limit and game.dungeon_view.final_floor)
		for enemy in game.enemies.duplicate():
			game._hit_enemy(enemy, 100000)
		game.player_point = Vector2(game.dungeon.exit) + Vector2.DOWN
		var points: int = game.build.skill_points
		game.interact()
		game.descend()
		assert(game.depth == limit and game.build.skill_points == points + 1, "One-floor and twenty-floor dungeons must terminate and award a point")
	var area = game.dungeon
	var terrace := Terrace.new()
	for x in range(5):
		for y in range(3):
			terrace.tiles[Vector2i(x, y)] = true
	game.dungeon = terrace
	game.player_point = Vector2(1.45, 1)
	game.player_y = .7
	game.vertical_velocity = -1
	game.grounded = false
	game._update_vertical(.016)
	assert(game.grounded and is_equal_approx(game.player_y, 1), "A landing must support the whole footprint at a terrace edge")
	var landed: Vector2 = terrace.move_actor(game.player_point, Vector2(.3, 0), game.player_y)
	assert(landed.x > 1.5, "A character supported by a ledge must be able to walk onto it")
	game.dungeon = area
	print("PASS: finite dungeon and one-time chest, skill progression, class combat, jump/footprint landing, targeting/resource gates, travel/respawn, reset/pause")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.15).timeout
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	quit()

func _combat_point() -> Vector2:
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var point: Vector2 = game.player_point + direction * 2
		var clear := true
		for index in range(21):
			clear = clear and game.dungeon.walkable(game.player_point.lerp(point, index / 20.0))
		if clear and game.dungeon.line_clear(game.player_point, point):
			return point
	return Vector2.INF
