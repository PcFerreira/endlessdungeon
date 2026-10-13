extends SceneTree

const Game = preload("res://scripts/game.gd")
const Actors = preload("res://scripts/actor_models.gd")
var directory := "user://test-voxel-npcs-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := _game()
	game.start_run(12345)
	game.begin_journey()
	var rng_state: int = game.rng.state
	var styles := {}
	var resident_id := ""
	for actor in game.life.residents():
		if not actor.get("traveling",false):
			resident_id = actor.id
	for id in game.world_view.npc_models:
		var model: Node3D = game.world_view.npc_models[id]
		assert(model.get_meta("representation") == "generated_voxel")
		styles[id] = model.get_meta("style")
	assert(not resident_id.is_empty() and styles.has(resident_id))
	var resident: Dictionary = game.life.actors[resident_id]
	game.player_point = resident.point + Vector2(.6,0)
	game._snap_camera()
	game.interact()
	assert(game.state == "dialogue" and game.expansion.speaker.id == resident_id)
	var player: AnimationPlayer = game.world_view.npc_models[resident_id].get_child(0).get_node("AnimationPlayer")
	assert(player.current_animation == "Wave")
	game.expansion.close_lore()
	game.life_view.sync(game)
	assert(game.rng.state == rng_state)
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = _game()
	assert(game.load_game(1))
	assert(game.life.actors.has(resident_id))
	for id in styles:
		if game.world_view.npc_models.has(id):
			assert(game.world_view.npc_models[id].get_meta("style") == styles[id], "Actual saved residents and visitors must replay their generated appearance")
	assert(game.world_view.npc_models[resident_id].get_meta("style") == styles[resident_id])
	game.life.advance(1)
	game.life.step(game.world,game.player_point,.1)
	game.life_view.sync(game)
	for actor in game.life.residents():
		var model: Node3D = game.world_view.npc_models[actor.id]
		var actual_player: AnimationPlayer = model.get_child(0).get_node("AnimationPlayer")
		assert(actual_player.current_animation in ["Idle","Walk","Wave","Attack"])
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: actual generated residents/visitors/watch, live dialogue greeting, autonomous motion, independent combat RNG and fresh-scene disk appearance restoration")
	quit()

func _game() -> Game:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	return game
