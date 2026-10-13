extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-biome-new-journey-%s" % OS.get_process_id()
var game

func _initialize() -> void:
	call_deferred("run_checks")

func new_game():
	var value := Game.new()
	value.records_enabled = false
	value.save_directory = directory
	value.settings_path = directory.path_join("settings.cfg")
	root.add_child(value)
	value.set_physics_process(false)
	return value

func run_checks() -> void:
	game = new_game()
	game.start_run(91, 4)
	assert(game.save_game(1))
	var legacy := FileAccess.get_file_as_bytes(game.saves.slot_path(1))
	game.new_character()
	assert(game.world.generator_version == 6 and game.state == "title" and not game.has_journey)
	assert(is_equal_approx(game.world.temperature.frequency, .0013 / 5))
	game.choose_class("mage")
	game.begin_journey()
	assert(game.floating_hub.active() and game.world.generator_version == 6)
	assert(game.world.Biomes.valid_cell(game.world.cell_info(Vector2i(game.player_point.round()))))
	assert(game.save_game(2))
	assert(FileAccess.get_file_as_bytes(game.saves.slot_path(1)) == legacy)
	var seed_value: int = game.run_seed
	game.queue_free()
	await process_frame
	game = new_game()
	assert(game.load_game(2) and game.floating_hub.active() and game.world.generator_version == 6 and game.run_seed == seed_value)
	game._clear_actors()
	var hub: Dictionary = game.floating_hub.city()
	game.player_point = hub.hub_portal
	game.grounded = true
	assert(game.floating_hub.target().kind == "depart")
	game.interact()
	assert(not game.floating_hub.active() and game.world.generator_version == 6)
	assert(game.world.walkable(game.player_point) and game.hp == game.max_hp)
	assert(game.world.Biomes.valid_cell(game.world.cell_info(Vector2i(game.player_point.round()))))
	assert(game.save_game(2))
	assert(game.load_game(1) and game.world.generator_version == 4)
	assert(FileAccess.get_file_as_bytes(game.saves.slot_path(1)) == legacy)
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: actual new-character edition6/fivefold climate and first Lanternwake arrival, fresh hub disk restoration, physical departure to safe edition6 lands and byte-preserved legacy4 journey reload")
	quit()
