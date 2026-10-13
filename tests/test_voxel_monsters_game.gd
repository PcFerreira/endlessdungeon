extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-voxel-monsters-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func _game() -> Game:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	return game

func run() -> void:
	var game := _game()
	game.start_run(12345)
	game.begin_journey()
	var site: Dictionary = game.world.nearest_site(game.player_point,"dungeon")
	game.enter_dungeon(site)
	assert(not game.enemies.is_empty())
	var styles := {}
	var states := {}
	for enemy in game.enemies:
		assert(enemy.model.get_meta("representation") == ("original_wonder_voxel" if enemy.model.has_meta("wonder_id") else "generated_voxel"))
		styles[enemy.id] = signature(enemy.model)
		states[enemy.id] = {"hp":enemy.hp,"species":enemy.species,"variant":enemy.variant}
	var rng_state: int = game.rng.state
	var probes: Array[Node3D] = []
	for kind in range(game.EnemyCatalog.TYPES.size()):
		var model := game.EnemyModels.create(kind,81,"",game.dungeon.biome,true)
		probes.append(model)
	assert(game.rng.state == rng_state, "Rendering must not consume combat randomness")
	for model in probes:
		model.free()
	var first: Dictionary = game.enemies[0]
	first.hp -= 3
	states[first.id].hp = first.hp
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = _game()
	assert(game.load_game(1) and game.layer == "dungeon")
	for enemy in game.enemies:
		assert(styles.has(enemy.id) and signature(enemy.model) == styles[enemy.id])
		assert(enemy.variant == states[enemy.id].variant and enemy.species == states[enemy.id].species and is_equal_approx(enemy.hp,states[enemy.id].hp))
	var legacy: Dictionary = game.make_save_data()
	for record in legacy.progress.encounters.values():
		record.variant = "old/imported/monster.glb"
	assert(game.saves.validate(legacy) and game.Journey.restore(game,legacy))
	for enemy in game.enemies:
		assert(enemy.model.get_meta("representation") == ("original_wonder_voxel" if enemy.model.has_meta("wonder_id") else "generated_voxel"))
		assert(enemy.variant.begins_with("wonder:" if enemy.model.has_meta("wonder_id") else "voxel-monster:1:"))
	var defeated: Dictionary = game.enemies[0]
	var defeated_id: String = defeated.id
	game.select_target(defeated)
	var kills: int = game.kills
	game._hit_enemy(defeated,100000)
	assert(game.kills == kills + 1 and game.selected_target.is_empty())
	assert(game.encounter_states[defeated_id].hp == 0)
	assert(game.pickups.any(func(pickup): return pickup.kind == "gold_coin"))
	assert(game.save_game(2) and game.load_game(2))
	assert(not game.enemies.any(func(enemy): return enemy.id == defeated_id))
	game.return_to_surface()
	game._clear_actors()
	game._spawn_enemy(game.player_point + Vector2(3,0),0,"surface-probe")
	assert(game.enemies[0].model.get_meta("representation") != "generated_voxel", "The dungeon replacement must preserve surface renderer selection")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: actual generated dungeon encounters, independent RNG, fresh-disk descriptors/health, imported-variant legacy compatibility, combat/coin/death persistence and surface renderer separation")
	quit()

func signature(body: Node3D) -> Dictionary:
	if body.has_meta("wonder_id"):
		return {"template": body.get_meta("wonder_id"), "variant": body.get_meta("appearance_variant"), "family": body.get_meta("visual_family")}
	return body.get_meta("monster_style")
