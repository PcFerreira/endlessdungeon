extends SceneTree

const Game = preload("res://scripts/game.gd")
const Population = preload("res://scripts/dimension_population.gd")
var directory := "user://test-dimension-population-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func enter_realm(game) -> void:
	assert(game.use_sanctum_sigil())
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	assert(game.floating_hub.from_sanctum())
	game.player_point = game.floating_hub.portal_point("dimension")
	game._snap_camera()
	assert(game.dimension.enter())

func checks() -> void:
	var game = fresh()
	assert(game.get("population") != null, "Actual Game must own the authored dimension population service")
	game.start_run(12345)
	game._clear_actors()
	var original: Vector2 = game.player_point
	enter_realm(game)
	assert(Population.valid(game.world.definition))
	var residents := Population.resident_records(game.world)
	assert(residents.size() >= 48 and game.world.definition.encounters.size() >= 16)
	var malformed_definition: Dictionary = game.world.definition.duplicate(true)
	var inhabited: Array = malformed_definition.sites.filter(func(site): return not site.get("residents", []).is_empty())
	inhabited[1].residents[0].id = inhabited[0].residents[0].id
	assert(not Population.valid(malformed_definition), "Authored citizen identities must be unique across sites")
	malformed_definition = game.world.definition.duplicate(true)
	malformed_definition.encounters[0].members[0].enemy_id = "missing_authored_monster"
	assert(not Population.valid(malformed_definition))
	assert(game.life.actors.is_empty() and game.enemies.all(func(enemy): return Population.hostile_point_allowed(game.world, enemy.point)))
	var recipe: Dictionary = residents[0]
	game._generate_surface(recipe.home, false)
	assert(game.population.actors.has(recipe.id) and game.population.models.has(recipe.id))
	assert(not game.enemies.any(func(enemy): return enemy.id == recipe.id))
	var before: Vector2 = game.population.actors[recipe.id].point
	for frame in range(20):
		game.population.step(.05)
	assert(game.population.actors[recipe.id].point.distance_to(before) > .05, "An authored citizen must actually walk its route")
	var actor: Dictionary = game.population.actors[recipe.id]
	game.select_target(actor)
	assert(game.selected_target.is_empty(), "Authored citizens must remain outside hostile targeting")
	var model: Node3D = game.population.models[recipe.id]
	assert(is_equal_approx(model.position.y, game.world.ground_height(actor.point)))
	game.player_point = game.world.safe_position(actor.point + Vector2(0, .8), 2)
	game._snap_camera()
	assert(game.population.target().get("id", "") == actor.id)
	game.interact()
	assert(game.state == "dialogue" and game.expansion.speaker.id == actor.id and game.expansion.dialogue_text == actor.dialogue[0])
	game.expansion.talk("topic_authored")
	assert(game.expansion.dialogue_text == actor.dialogue[1 % actor.dialogue.size()])
	game.expansion.close_lore()
	assert(game.save_game(1))
	var npc_point: Vector2 = game.population.actors[recipe.id].point
	game._generate_surface(Vector2(game.world.start), false)
	assert(not game.population.models.has(recipe.id))
	game._generate_surface(recipe.home, false)
	assert(game.population.actors[recipe.id].point.is_equal_approx(npc_point))
	var restored = fresh()
	assert(restored.load_game(1) and restored.population.actors[recipe.id].point.is_equal_approx(npc_point))
	assert(restored.population.snapshot().dimensions[restored.dimension.id].residents[recipe.id].met)
	var ground: Dictionary = restored.world.definition.encounters[0]
	restored._generate_surface(Population.point(ground.cell), false)
	var prefix: String = "dimension:%s:grounds:%s:" % [restored.dimension.id, ground.id]
	var opponents: Array = restored.enemies.filter(func(enemy): return enemy.id.begins_with(prefix))
	assert(not opponents.is_empty(), "An authored ground must create actual combatants through Game's chunk spawn pipeline")
	var defeated: String = opponents[0].id
	var coins: int = restored.inventory.count("gold_coin")
	for enemy in opponents:
		restored.player_point = restored.world.safe_position(enemy.point + Vector2(0, .7), 2)
		restored._snap_camera()
		restored.select_target(enemy)
		for attack in range(40):
			if not restored.valid_enemy(enemy):
				break
			restored.cooldowns.bolt = 0
			restored.mana = restored.max_mana
			restored.cast("bolt")
			for frame in range(30):
				restored._update_projectiles(.025)
		assert(not restored.valid_enemy(enemy), "Real targeted bolts must defeat the authored enemy")
		for pickup in restored.pickups.duplicate():
			restored.player_point = pickup.point
			restored._snap_camera()
			restored._update_pickups(.05)
	assert(restored.inventory.count("gold_coin") > coins)
	var kill_count: int = restored.kills
	var visited: Dictionary = restored.visited_cities.duplicate()
	assert(restored.encounter_states[defeated].hp == 0 and restored.save_game(2))
	assert(restored.load_game(2) and not restored.enemies.any(func(enemy): return enemy.id == defeated))
	var spawn: Vector2 = restored.world.start
	restored._generate_surface(spawn, false)
	assert(restored.enemies.all(func(enemy): return enemy.point.distance_to(spawn) > 24))
	var vitality: float = restored.hp
	restored._hurt_player(10)
	assert(restored.hp == vitality, "Arrival protection must include hostile damage")
	assert(restored.use_sanctum_sigil() and restored.use_sanctum_sigil() and restored.leave_sanctum())
	assert(restored.player_point.is_equal_approx(original) and restored.encounter_states[defeated].hp == 0)
	assert(restored.kills == kill_count and visited.keys().all(func(id): return restored.visited_cities.has(id)))
	enter_realm(restored)
	restored._generate_surface(Population.point(ground.cell), false)
	assert(not restored.enemies.any(func(enemy): return enemy.id == defeated), "Defeat must survive the original Journey and a later realm entry")
	var invalid: Dictionary = restored.make_save_data()
	invalid.progress.population.dimensions[restored.dimension.id].residents[recipe.id].point = [999999, 999999]
	assert(not restored.saves.validate(invalid))
	var legacy: Dictionary = restored.make_save_data()
	legacy.progress.erase("population")
	assert(restored.saves.validate(legacy))
	invalid = restored.make_save_data()
	invalid.progress.population.seed = "different_hero"
	assert(not restored.saves.validate(invalid))
	invalid = restored.make_save_data()
	invalid.progress.population.dimensions[restored.dimension.id].residents[recipe.id].route_index = 999
	assert(not restored.saves.validate(invalid))
	restored.online.session = true
	assert(restored.population.target().is_empty() and not restored.population.interact())
	restored.online.session = false
	game.queue_free()
	restored.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: authored moving citizens/dialogue, bounded unload and fresh saves, actual projectile fight/loot, stable defeat through disk/hub/original Journey, safe arrival and malformed/legacy/online guards")
	quit()
