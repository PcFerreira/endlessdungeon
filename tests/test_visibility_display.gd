extends SceneTree

const Game = preload("res://scripts/game.gd")
const Grid = preload("res://scripts/grid_area.gd")
var game
var directory := "user://test-visibility-display-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game._clear_actors()
	var arena := Grid.new()
	for x in range(0, 80):
		for y in range(0, 80):
			arena.tiles[Vector2i(x,y)] = true
	game.dungeon = arena
	game.layer = "overworld"
	game.player_point = Vector2(32,32)
	game._snap_camera()
	game._spawn_enemy(Vector2(46,32), 0, "visibility:far")
	var enemy: Dictionary = game.enemies[-1]
	assert(enemy.node.visible, "Distant loaded enemies must be rendered at spawn")
	game._update_enemies(.1)
	assert(enemy.node.visible and not enemy.active, "Rendering must not extend combat activation")
	assert(enemy.point == Vector2(46,32))
	arena.tiles.erase(Vector2i(39,32))
	assert(not arena.line_clear(game.player_point, enemy.point))
	game._update_enemies(.1)
	assert(enemy.node.visible, "Player line of sight must not hide a model that the camera can see")
	game.layer = "dungeon"
	game.dungeon_view.explored.clear()
	game._update_enemies(.1)
	assert(not enemy.node.visible, "Undiscovered dungeon space must retain its fog")
	game.dungeon_view.explored[Vector2i(enemy.point)] = true
	game._update_enemies(.1)
	assert(enemy.node.visible and not enemy.active, "Discovered distant enemies remain rendered")
	game._generate_surface(Vector2(game.world.start), false)
	var far: Array = game.enemies.filter(func(actor): return actor.point.distance_to(game.player_point) > 9)
	assert(not far.is_empty())
	var saved_id: String = far[0].id
	assert(game.save_game(1) and game.load_game(1))
	var restored: Array = game.enemies.filter(func(actor): return actor.id == saved_id)
	assert(restored.size() == 1 and restored[0].node.visible)
	assert(not game.set_resolution(Vector2i(0,0)))
	assert(not game.set_resolution(Vector2i(99999,99999)))
	assert(game.set_resolution(Vector2i(1920,1080)))
	assert(game.windowed_resolution == Vector2i(1920,1080))
	assert(Vector2i(2560,1440) in game.resolution_choices())
	assert(Vector2i(3840,2160) in game.resolution_choices())
	game.set_fullscreen(true)
	assert(game.is_fullscreen())
	game.set_fullscreen(false)
	assert(not game.is_fullscreen() and game.windowed_resolution == Vector2i(1920,1080))
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_F11
	game._unhandled_key_input(key)
	assert(game.is_fullscreen())
	game._unhandled_key_input(key)
	assert(not game.is_fullscreen())
	game.records_enabled = true
	game._save_settings()
	var settings := ConfigFile.new()
	assert(settings.load(game.settings_path) == OK)
	assert(settings.get_value("video", "resolution") == Vector2i(1920,1080))
	game.windowed_resolution = Vector2i(1280,800)
	game._load_settings()
	assert(game.windowed_resolution == Vector2i(1920,1080))
	settings.set_value("video", "resolution", "broken")
	settings.save(game.settings_path)
	game.windowed_resolution = Vector2i(1280,800)
	game._load_settings()
	assert(game.windowed_resolution == Vector2i(1280,800))
	game.records_enabled = false
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: distant enemy spawn/update/load visibility, independent activation/LOS, discovery fog, resolution choices/validation, fullscreen return and real settings persistence")
	quit()
