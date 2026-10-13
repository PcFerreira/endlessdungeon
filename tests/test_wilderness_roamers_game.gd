extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-wilderness-roamers-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run_checks")

func body_signature(model: Node3D) -> Dictionary:
	return {"representation": model.get_meta("representation"), "style": model.get_meta("style",{}), "wonder_id": model.get_meta("wonder_id",""), "variant": model.get_meta("appearance_variant",0)}

func run_checks() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345,6)
	game.begin_journey()
	game._generate_surface(Vector2(40,100),false)
	var walkers: Array = game.life.residents().filter(func(actor): return actor.get("roaming",false))
	assert(not walkers.is_empty())
	var speaker := {}
	for actor in walkers:
		assert(not game.valid_enemy(actor), "Peaceful roamers must not be hostile combat targets")
		var model: Node3D = game.world_view.npc_models[actor.id]
		var wonder_id: String = actor.get("wonder_id","")
		assert(model.get_meta("representation") == ("generated_voxel" if wonder_id.is_empty() else "original_wonder_voxel"))
		assert(model.get_meta("wonder_id","") == wonder_id)
		var nearby: Vector2 = actor.point + Vector2(.5,0)
		if not game.world.walkable(nearby):
			continue
		game.player_point = nearby
		game.player_y = game.world.ground_height(nearby)
		game._snap_camera()
		if game.sanctum_problem().is_empty() and game.expansion.target().get("id", "") == actor.id:
			speaker = actor
			break
	assert(not speaker.is_empty(), "A natural peaceful walker must be safely reachable for conversation")
	var id: String = speaker.id
	var random_before: int = game.rng.state
	assert(game.interaction_hint().contains(speaker.roaming_name.to_lower()))
	game.interact()
	assert(game.state == "dialogue" and game.expansion.speaker.id == id)
	assert(not game.expansion.dialogue_text.is_empty())
	game.expansion.talk("topic_route")
	assert(game.expansion.dialogue_text.contains(speaker.city_name))
	game.expansion.talk("topic_work")
	assert(not game.expansion.dialogue_text.is_empty())
	var before := game.life.snapshot()
	game._physics_process(.5)
	assert(game.life.snapshot() == before, "Roaming must pause during conversation")
	game.expansion.close_lore()
	assert(game.rng.state == random_before, "Roaming appearance/dialogue must not consume combat RNG")
	var saved_point: Vector2 = speaker.point
	var saved_style := body_signature(game.world_view.npc_models[id])
	assert(game.save_game(1) and game.load_game(1))
	assert(game.life.actors.has(id) and game.life.actors[id].point.is_equal_approx(saved_point))
	assert(body_signature(game.world_view.npc_models[id]) == saved_style)
	assert(game.use_sanctum_sigil())
	var home_tick: int = game.life.tick
	game.simulate(2)
	assert(game.life.tick == home_tick)
	assert(game.leave_sanctum())
	assert(game.life.actors.has(id) and game.life.actors[id].point.is_equal_approx(saved_point))
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: naturally streamed peaceful voxel roamers, real E/work/path dialogue, modal freeze, combat-target exclusion, independent RNG, disk point/body identity and Sanctum carry")
	quit()
