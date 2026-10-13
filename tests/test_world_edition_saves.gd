extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-world-editions-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	call_deferred("run_checks")

func run_checks() -> void:
	game.start_run(91, 4)
	game.state = "playing"
	var legacy: Dictionary = game.make_save_data()
	assert(legacy.generator_version == 4 and game.saves.write(1, legacy))
	game.hp = 37
	assert(game.saves.write(1, game.make_save_data()))
	var marker: String = directory.path_join("generation-4.reset")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))
	var paths := {}
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path: String = game.saves.slot_path(1) + suffix
		if suffix in [".tmp", ".bak.tmp"]:
			FileAccess.open(path, FileAccess.WRITE).store_string("Recoverable user artifact " + suffix)
		paths[path] = FileAccess.get_file_as_bytes(path)
	assert(game.saves.reset_expansion())
	for path in paths:
		assert(FileAccess.get_file_as_bytes(path) == paths[path], "Edition initialization cannot delete or rewrite a user journey")
	assert(not game.saves.reset_expansion())
	FileAccess.open(game.saves.slot_path(1), FileAccess.WRITE).store_string("{damaged primary")
	assert(game.saves.read(1).recovered)
	var backup := FileAccess.get_file_as_bytes(game.saves.slot_path(1) + ".bak")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(marker))
	assert(game.saves.reset_expansion() and game.saves.read(1).recovered)
	assert(FileAccess.get_file_as_bytes(game.saves.slot_path(1) + ".bak") == backup)
	var staged: Dictionary = legacy.duplicate(true)
	staged.generator_version = 5
	staged.progress.erase("life")
	assert(game.saves.validate(staged) and game.saves.write(2, staged), "The envelope accepts both implemented World editions")
	assert(game.saves.read(2).data.generator_version == 5)
	var broader: Dictionary = staged.duplicate(true)
	broader.generator_version = 6
	broader.progress.life = game.life.snapshot()
	broader.progress.life.actors = {}
	broader.progress.life.context = {"edition": 6, "seed": broader.seed}
	assert(game.saves.validate(broader) and game.saves.write(3, broader), "Edition 6 is accepted without rewriting edition-4/5 journeys")
	assert(game.saves.read(3).data.generator_version == 6)
	broader.progress.life.context.edition = 5
	assert(not game.saves.validate(broader), "The living-world context must match the enclosing save edition")
	staged.generator_version = 999
	assert(not game.saves.validate(staged) and not game.saves.write(2, staged))
	assert(game.saves.read(2).data.generator_version == 5)
	staged.generator_version = 4.5
	assert(not game.saves.validate(staged), "Edition numbers must be exact integers")
	assert(game.load_game(1) and game.world.generator_version == 4 and game.hp == legacy.stats.hp)
	assert(game.use_sanctum_sigil())
	var home: Dictionary = game.make_save_data()
	home.generator_version = 5
	assert(not game.saves.validate(home), "Nested home/indoor journeys must belong to the same actual edition")
	home.generator_version = 6
	assert(not game.saves.validate(home))
	home.home.return_journey.generator_version = 6
	home.progress.erase("life")
	home.home.return_journey.progress.erase("life")
	assert(game.saves.validate(home), "An edition-6 home envelope requires its actual matching return journey")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: non-destructive edition initialization, byte-preserved slots/backups/temp files, damaged-primary recovery, supported editions, nested-edition rejection and actual edition-4 reload")
	quit()
