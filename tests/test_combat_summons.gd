extends SceneTree

const Game = preload("res://scripts/game.gd")
const Summons = preload("res://scripts/combat_summons.gd")
const Grid = preload("res://scripts/dungeon.gd")
var directory := "user://summons-test-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game._clear_actors()
	var area = Grid.new()
	for x in range(15):
		for y in range(15):
			area.tiles[Vector2i(x, y)] = true
	area.obstacles.append(Rect2(6.5, -.5, 1, 10))
	game.dungeon = area
	game.layer = "dungeon"
	game.active_dungeon = {"name": "Summon Arena", "floors": 1, "family": area.family}
	game.player_point = Vector2(4, 5)
	game._rebuild_navigation()
	var summons = Summons.new()
	summons.game = game
	game.add_child(summons)
	var rng_before: int = game.rng.state
	assert(summons.summon("lantern_familiar"))
	assert(game.rng.state == rng_before, "Companion spawn geometry must not consume gameplay RNG")
	assert(summons.allies[0].hp == 35 and summons.allies[0].life == 24)
	var first: int = summons.allies[0].id
	assert(summons.summon("lantern_familiar") and summons.allies.size() == 1)
	assert(summons.allies[0].id != first)
	assert(summons.summon("ancestral_warden"))
	assert(summons.summon("runic_blade"))
	assert(summons.allies.size() == 2 and summons.allies[0].spell == "ancestral_warden")
	game.online.session = true
	assert(not summons.summon("lantern_familiar"))
	var paused_life: float = summons.allies[0].life
	summons.step(1)
	assert(summons.allies[0].life == paused_life)
	game.online.session = false
	game.state = "paused"
	summons.step(1)
	assert(summons.allies[0].life == paused_life)
	game.state = "playing"
	game.player_point = Vector2(10, 5)
	for tick in range(180):
		summons.step(.05)
		for ally in summons.allies:
			assert(area.walkable(ally.point), "Every movement must retain physical floor/obstacle support")
	assert(summons.allies[0].point.x > 8, "A guardian must route around a wall through the actual navigation graph")
	game._spawn_enemy(summons.allies[0].point + Vector2.RIGHT * .8, 0)
	var enemy: Dictionary = game.enemies[0]
	enemy.hp = 10000
	game.select_target(enemy)
	var before_hp: float = enemy.hp
	summons.step(.05)
	assert(enemy.hp < before_hp, "A companion strike must pass through real creature damage")
	var ally: Dictionary = summons.allies[0]
	enemy.point = ally.point + Vector2(.4, 0)
	game.player_point = ally.point + Vector2(-2, 0)
	assert(summons.enemy_target(enemy) == ally, "A nearer supported companion can intercept creature aggro")
	game.player_point = ally.point + Vector2(-9, 0)
	assert(summons.enemy_target(enemy).is_empty(), "Companions must not draw combat outside the owner's engagement radius")
	game.player_point = ally.point + Vector2(-2, 0)
	assert(not summons.projectile_hit(ally.point, 8, 5), "Shots above companion geometry must miss")
	assert(summons.projectile_hit(ally.point, area.ground_height(ally.point) + ally.height, 5))
	assert(ally.hp == ally.max_hp - 5)
	assert(summons.hurt(ally, 100) and not summons.allies.has(ally))
	summons.clear()
	game.player_point = Vector2(4, 5)
	assert(summons.summon("lantern_familiar"))
	game._spawn_enemy(Vector2(10, 5), 0)
	enemy = game.enemies[-1]
	enemy.hp = 10000
	game.selected_target = enemy
	for tick in range(10):
		summons.step(.05)
	assert(enemy.hp == 10000, "A lantern cannot shoot through an obstacle wall")
	game.layer = "sanctum"
	enemy.point = summons.allies[0].point + Vector2.RIGHT * .8
	summons.allies[0].attack = 0
	summons.step(.1)
	assert(enemy.hp == 10000 and summons.enemy_target(enemy).is_empty())
	assert(not summons.projectile_hit(summons.allies[0].point, summons.allies[0].height, 5))
	game.layer = "dungeon"
	summons.step(25)
	assert(summons.allies.is_empty(), "Temporary companions must expire at their bounded lifetime")
	assert(summons.summon("runic_blade"))
	game.state = "dead"
	summons.step(.1)
	assert(summons.allies.is_empty())
	game.state = "playing"
	area.tiles.clear()
	assert(not summons.summon("runic_blade"), "Unsupported void must reject the summon")
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: summon replacement/cap, RNG, authority/pause/death, obstacle navigation, actual attacks, aggro/shot contact, safezones and bounded expiry")
	quit()
