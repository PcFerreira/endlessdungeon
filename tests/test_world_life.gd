extends SceneTree

const Life = preload("res://scripts/world_life.gd")
const World = preload("res://scripts/world.gd")
const Game = preload("res://scripts/game.gd")
var directory := "user://test-world-life-%s" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var world := World.new()
	world.generate(12345)
	world.load_around(world.start)
	var life := Life.new()
	life.reset(12345)
	life.sync(world, Vector2(world.start))
	assert(life.residents().filter(func(actor): return not actor.get("traveling", false)).size() == 2 and life.actors.size() >= 4 and life.actors.size() <= Life.MAX_ACTORS)
	var city: Dictionary = world.region_at(world.start).city
	var id: String = city.residents[1].id
	var initial: Vector2 = life.actors[id].point
	for index in range(300):
		life.advance(.1)
		life.step(world, Vector2(city.cell) + Vector2(0, 10), .1)
		for actor in life.actors.values():
			assert(life.AnimalHabitat.usable(world, actor.point, actor.get("medium", "land")))
			if not actor.get("traveling", false):
				assert(actor.point.distance_to(actor.origin) < 12)
		assert(life.route_requests <= 1 and life.actors.size() <= Life.MAX_ACTORS)
	assert(not life.actors[id].point.is_equal_approx(initial), "Residents must actually follow their routine")
	assert(city.residents[1].point == initial, "Living state must not mutate generated place plans")
	life.advance(10)
	assert(life.event_at(city.id).kind == "supper" and life.event_at(city.id).phase == "active")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
	assert(Life.valid_snapshot(saved))
	var restored := Life.new()
	assert(restored.restore(saved, 12345))
	restored.sync(world, Vector2(world.start))
	assert(restored.actors[id].point.is_equal_approx(life.actors[id].point))
	assert(restored.event_at(city.id) == life.event_at(city.id))
	life.advance(140)
	assert(life.event_at(city.id).kind == "delivery" and life.event_at(city.id).phase == "aftermath")
	var untouched := Life.new()
	untouched.reset(12345)
	untouched.advance(180)
	assert(untouched.event_at(city.id) == life.event_at(city.id), "Offscreen events depend on time, not observation")
	for bad in [null, {}, {"version": 1, "tick": -1, "fraction": 0, "actors": {}}, {"version": 1, "tick": 0, "fraction": INF, "actors": {}}]:
		assert(not Life.valid_snapshot(bad))
	var bad: Dictionary = saved.duplicate(true)
	bad.actors[id].point = [9999999, 0]
	assert(not Life.valid_snapshot(bad))
	bad = saved.duplicate(true)
	bad.actors[id].path = [[NAN, 0]]
	assert(not Life.valid_snapshot(bad))
	var before_invalid := restored.snapshot()
	assert(not restored.restore(bad, 12345) and restored.snapshot() == before_invalid)
	for coordinate in [Vector2i(-2, -1), Vector2i(50, -60), Vector2i.ZERO]:
		var region: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
		world.load_around(region.city.cell)
		life.sync(world, Vector2(region.city.cell))
		assert(life.actors.size() <= Life.MAX_ACTORS and life.cities.size() <= Life.MAX_CITIES)
		for actor in life.actors.values():
			assert(life.AnimalHabitat.usable(world, actor.point, actor.get("medium", "land")))
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var rng_state: int = game.rng.state
	game.life.advance(40)
	game.life.step(game.world, game.player_point, .1)
	game.life_view.sync(game)
	assert(game.rng.state == rng_state)
	assert(game.life_view.models.size() == game.life.actors.size())
	assert(game.world_view.npc_models.size() == game.life.residents().size())
	var resident: Dictionary = game.life.actors[id]
	game.player_point = resident.point + Vector2(.6, 0)
	game._snap_camera()
	assert(game.expansion.target().id == id)
	game.interact()
	assert(game.state == "dialogue" and game.expansion.speaker.id == id)
	var heard_before: Array = game.expansion.heard.get(id, []).duplicate()
	game.expansion.talk("topic_local_life")
	var reply := {}
	for entry in game.expansion.Lore.LINES:
		if entry.id in game.expansion.heard.get(id, []) and entry.id not in heard_before and entry.speaker == resident.role and entry.event == "topic_local_life":
			reply = entry
			break
	assert(not reply.is_empty() and not game.expansion.dialogue_text.is_empty(), "Actual local-life conversation must use an authored response")
	var activity: Array = game.expansion.Lore.LIFE_CONDITIONS.get(reply.condition, [reply.get("life_kind", ""), reply.get("life_phase", "")])
	assert(activity == ["supper", "active"], "The selected wording must describe the actual active supper")
	var tick: int = game.life.tick
	game._physics_process(.5)
	assert(game.life.tick == tick)
	game.expansion.close_lore()
	for paused_state in ["paused", "inventory", "grimoire", "map", "dead", "menu"]:
		game.state = paused_state
		game._physics_process(.5)
		assert(game.life.tick == tick)
	game.state = "playing"
	var snapshot: Dictionary = game.life.snapshot()
	game._spawn_enemy(game.player_point + Vector2(15,0), 0)
	var busy_enemy: Dictionary = game.enemies[-1]
	busy_enemy.active = true
	game.life.advance(140)
	game.life_view.sync(game)
	assert(game.life_view.episode_id.is_empty(), "Combat must defer new episodes and clear stale presentation")
	busy_enemy.node.queue_free()
	game.enemies.erase(busy_enemy)
	assert(game.life.restore(snapshot, game.run_seed))
	game.life.sync(game.world, game.player_point)
	game.life_view.sync(game)
	assert(game.save_game(1))
	game.life.advance(12)
	assert(game.load_game(1) and game.life.snapshot() == snapshot)
	assert(game.use_sanctum_sigil())
	tick = game.life.tick
	game.simulate(20)
	assert(game.life.tick == tick and not game.life_view.visible)
	assert(game.save_game(2) and game.load_game(2))
	assert(game.leave_sanctum() and game.life.tick == tick)
	var site: Dictionary = game.world.region_at(game.world.start).dungeons[0]
	game.enter_dungeon(site)
	game.life.advance(140)
	game.return_to_surface()
	assert(game.life.event_at(city.id).phase == "aftermath")
	var legacy: Dictionary = game.make_save_data()
	legacy.progress.erase("life")
	assert(game.saves.validate(legacy) and game.Journey.restore(game, legacy))
	assert(game.life.tick == 0)
	game.start_run(456)
	assert(game.life.tick == 0)
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: bounded peaceful routines, physical movement, autonomous episodes, live E positions, separate RNG, validated saves, pause/home clocks, old-save defaults and reset")
	quit()
