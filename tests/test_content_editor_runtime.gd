extends SceneTree

const Game = preload("res://scripts/game.gd")
const Edits = preload("res://scripts/content_edits.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Items = preload("res://scripts/item_catalog.gd")
var game

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-workbench-runtime-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.enter_dungeon(site)
	game._clear_actors()
	var point := Vector2.INF
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var candidate: Vector2 = game.player_point + direction * 2
		if game.dungeon.walkable(candidate) and game.dungeon.line_clear(game.player_point, candidate):
			point = candidate
			break
	assert(point.is_finite())
	var original: Dictionary = Enemies.TYPES[0]
	var definition := original.duplicate(true)
	definition.merge({"hp": 150.0, "damage": 30.0, "level": 5, "level_mode": "fixed", "facing_degrees": 180.0, "aggressive": false, "retaliates": true, "drops": {"coins": 3, "item_chance": 1.0, "shard_chance": 0.0, "entries": [{"item": "health_potion", "weight": 1}]}}, true)
	Enemies.TYPES[0] = definition
	game._spawn_enemy(point, 0, "workbench-neutral", {"attack": 10.0})
	var enemy: Dictionary = game.enemies[0]
	assert(is_equal_approx(enemy.max_hp, Edits.combat_stats(definition, game.depth).hp))
	assert(is_equal_approx(absf(enemy.model.get_child(0).rotation_degrees.y), 180))
	game._update_enemies(.1)
	assert(not enemy.active, "Neutral creatures must not acquire targets on sight in the actual game")
	game._hit_enemy(enemy, 1.0)
	assert(enemy.active, "Neutral creatures retaliate when hit")
	definition.retaliates = false
	game._update_enemies(.1)
	assert(not enemy.active)
	game._hit_enemy(enemy, 1.0)
	assert(not enemy.active, "Fully passive creatures must not retaliate")
	definition.aggressive = true
	game._update_enemies(.1)
	assert(enemy.active, "Hostile creatures acquire visible nearby targets")
	var before_coins: int = game.inventory.count("gold_coin")
	var before_potions: int = game.inventory.count("health_potion")
	game._hit_enemy(enemy, 10000.0)
	assert(game.pickups.filter(func(pickup): return pickup.kind == "gold_coin").size() == 3)
	assert(game.pickups.any(func(pickup): return pickup.kind == "health_potion"))
	assert(not game.pickups.any(func(pickup): return pickup.kind == "ember_shard"))
	for pickup in game.pickups.duplicate():
		game.player_point = pickup.point
		game._update_pickups(.01)
	assert(game.inventory.count("gold_coin") == before_coins + 3)
	assert(game.inventory.count("health_potion") == before_potions + 1)
	assert(game.save_game(1))
	Enemies.TYPES[0] = original
	var drops := definition.duplicate(true)
	Items.definitions.health_potion.level = 5
	assert(Items.enemy_reward(42, 1, drops, {"class": "mage", "level": 4}).is_empty())
	assert(Items.enemy_reward(42, 1, drops, {"class": "mage", "level": 5}) == "health_potion")
	Items.definitions.health_potion.erase("level")
	print("PASS: actual Game edited health/levels/facing, neutral/hostile/passive behavior, custom loot/coins/collection/save and minimum item drop levels")
	game.queue_free()
	await process_frame
	quit()
