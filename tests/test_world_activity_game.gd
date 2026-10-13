extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-world-activity-%s" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var merchant: Dictionary = game.life.residents().filter(func(actor): return actor.role == "merchant")[0]
	game.player_point = merchant.point + Vector2(.5,0)
	game._snap_camera()
	assert(game.expansion.target().id == merchant.id)
	assert(game.interaction_hint().contains("merchant"))
	game.interact()
	assert(game.state == "dialogue" and game.expansion.speaker.id == merchant.id)
	assert(game.expansion.dialogue_text.contains(merchant.destination))
	assert(game.inventory.add("ember_shard", 9))
	var count: int = game.inventory.count("health_potion")
	game.expansion._trade("health_potion")
	assert(game.inventory.count("health_potion") == count + 1 and game.inventory.count("ember_shard") == 6)
	var before := game.life.snapshot()
	game._physics_process(.5)
	assert(game.life.snapshot() == before)
	game.expansion.close_lore()
	assert(game.save_game(1))
	game.life.advance(8)
	assert(game.load_game(1))
	assert(game.life.snapshot() == before and game.inventory.count("ember_shard") == 6)
	assert(game.world_view.npc_models.has(merchant.id))
	assert(game.world_view.npc_models[merchant.id].get_meta("representation") == "generated_voxel")
	game._clear_actors()
	var city: Dictionary = game.world.region_at(game.world.start).city
	var home := Vector2(city.cell) + Vector2(20,0)
	game.player_point = home
	game._spawn_enemy(home, 0, "activity:leash")
	var enemy: Dictionary = game.enemies[0]
	enemy.grounds = {"home":home,"radius":7}
	game.player_point = home + Vector2(20,0)
	enemy.active = true
	var kills: int = game.kills
	var hp: float = game.hp
	game._update_enemies(.1)
	assert(not enemy.active and enemy.windup == 0 and game.hp == hp and game.kills == kills)
	game.player_point = home
	enemy.point = home + Vector2(2,0)
	enemy.returning = false
	enemy.active = true
	game.life.actors["test_guard"] = {"id":"test_guard","kind":"npc","role":"guard","point":enemy.point}
	assert(game._return_to_grounds(enemy,.1) and not enemy.active)
	game.life.actors.erase("test_guard")
	game.kills = 1
	var expected_shard := game.Inventory.Catalog.should_drop_shard(game.run_seed,2)
	game._hit_enemy(enemy,100000)
	assert(game.pickups.any(func(pickup): return pickup.kind == "ember_shard") == expected_shard, "Actual shards must follow the declared independent seeded policy")
	assert(game.pickups.any(func(pickup): return pickup.kind == "gold_coin"), "Creature kills must retain guaranteed merchant coin currency")
	game._clear_actors()
	game._generate_surface(Vector2(game.world.start), false)
	assert(game.use_sanctum_sigil())
	var tick: int = game.life.tick
	game.simulate(20)
	assert(game.life.tick == tick)
	assert(game.leave_sanctum())
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: live merchant E/dialogue/barter, frozen modal activity, disk travel/inventory saves, guard deterrence, monster leashes without rewards and Sanctum carry")
	quit()
