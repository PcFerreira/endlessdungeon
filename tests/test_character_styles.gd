extends SceneTree

const Game = preload("res://scripts/game.gd")
const Profile = preload("res://scripts/character_profile.gd")
var game
var directory := "user://test-character-styles-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	assert(game.profile.get("costume") != null, "Character clothing must have a saved class style")
	assert(game.customize_character({"costume": "mage_scholar"}))
	assert(not game.customize_character({"costume": "sword_sentinel"}), "Clothing must match the selected class")
	var choices: Array = game.profile.premades()
	assert(choices.size() >= 4)
	assert(choices.filter(func(entry): return entry.pack == "kaykit_adventures").size() >= 5, "Fantasy adventurer premades must be available")
	for entry in choices:
		assert(game.customize_character({"model": entry.id}))
		assert(game.player_mesh.imported and game.player_mesh.body != null)
		assert(not game.player_mesh.animations.is_empty())
		var bounds: AABB = game.player_mesh.visual_bounds()
		assert(bounds.size.y > .9 and bounds.size.y < 1.3 and absf(bounds.position.y) < .03, "Imported characters must stand on the floor at player scale")
		game.player_mesh.animate(true, true)
		assert(game.player_mesh.motion == "Walk")
		for animation in game.player_mesh.animations:
			assert(animation.current_animation in ["Walk", "Walking_A", "Walking_B"] and animation.is_playing())
		game.player_mesh.animate(false, false)
		assert(game.player_mesh.motion == "Jump_Idle")
		game.player_mesh.animate(false, true)
		assert(game.player_mesh.motion == "Idle")
	var selected: String = choices[0].id
	assert(game.customize_character({"model": selected, "name": "Nara"}))
	assert(not game.customize_character({"model": "res://project.godot"}))
	assert(game.use_sanctum_sigil() and game.save_game(1))
	game.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.load_game(1) and game.profile.model == selected and game.player_mesh.imported)
	assert(game.use_sanctum_sigil() and game.profile.model == selected)
	assert(game.customize_character({"model": "custom"}) and not game.player_mesh.imported)
	game.state = "title"
	game.choose_class("sword")
	assert(game.profile.costume == "class_default", "Changing class must replace incompatible clothing")
	assert(game.customize_character({"costume": "sword_sentinel"}))
	var legacy := Profile.new()
	assert(legacy.restore({"name": "Old hero", "ancestry": "human", "skin": 0, "hair": 0, "outfit": 0, "head": "hood"}))
	assert(legacy.costume == "class_default" and legacy.model == "custom")
	print("PASS: class clothing validation, registry characters including five fantasy adventurers, normalized feet/height, idle/walk/jump animations, safe model IDs, disk saves and sanctum carry, custom switching, class change, legacy appearance fields")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	await create_timer(.15).timeout
	quit()
