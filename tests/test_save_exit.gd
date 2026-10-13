extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-exit-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	game.hp = 47
	game.records_enabled = true
	root.close_requested.emit()
	var saved: Dictionary = game.saves.read(0)
	assert(not saved.data.is_empty() and saved.data.stats.hp == 47, "Window close must commit the autosave before quitting")
	assert(FileAccess.file_exists(game.settings_path))
	print("PASS: window close commits the journey and settings before engine exit")
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
