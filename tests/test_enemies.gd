extends SceneTree

const Game = preload("res://scripts/game.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const World = preload("res://scripts/world.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-enemies-%s" % Time.get_ticks_usec()
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var kinds := {}
	var world := World.new()
	world.generate(12345)
	for x in range(-12, 13):
		for y in range(-12, 13):
			var chunk: Dictionary = world._build_chunk(Vector2i(x, y))
			assert(chunk.spawns.size() <= 2)
			for spawn in chunk.spawns:
				var city: Dictionary = world.region_at(spawn.cell).city
				assert(Vector2(spawn.cell).distance_to(city.cell) >= 15)
				assert(chunk.cells[spawn.cell].walkable)
				assert(spawn.kind in Enemies.surface_pool(chunk.cells[spawn.cell].biome, chunk.cells[spawn.cell].facet))
				kinds[spawn.kind] = true
	assert(kinds.size() >= 6, "Wilderness should contain varied native creatures")
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.enter_dungeon(site)
	for kind in range(Enemies.TYPES.size()):
		game._clear_actors()
		game._spawn_enemy(game.player_point + Vector2(2, 0), kind, "test:%s" % kind)
		var enemy: Dictionary = game.enemies[0]
		assert(enemy.max_hp > 0 and game.EnemyModels.bounds(enemy.model).size.y > 0)
		assert(game.ENEMY_NAMES[kind] == Enemies.TYPES[kind].name)
		game.select_target(enemy)
		assert(game.save_game(1))
		var before: int = game.rng.state
		game._snapshot_encounters()
		assert(game.rng.state == before)
		game._hit_enemy(enemy, 100000)
		assert(game.enemies.is_empty() and game.selected_target.is_empty())
		assert(game.encounter_states["test:%s" % kind].hp == 0)
	game.return_to_surface()
	var city: Dictionary = game.world.nearest_site(game.player_point, "city")
	game._generate_surface(Vector2(city.cell) + Vector2.DOWN)
	game._clear_actors()
	game._spawn_enemy(game.player_point + Vector2.RIGHT, 3)
	var hp: float = game.hp
	for frame in range(120):
		game.simulate(1.0 / 60)
	assert(game.hp == hp and not game.enemies[0].active, "Town sanctuaries must remain protected")
	print("PASS: biome/facet enemy pools, bounded wilderness spawns, all enemy models/stats/targets/rewards, persistent deaths and sanctuary protection")
	game.queue_free()
	await process_frame
	quit()
