extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-furnished-home-%s" % Time.get_ticks_usec()

func new_game():
	var fresh := Game.new()
	fresh.records_enabled = false
	fresh.save_directory = directory
	fresh.settings_path = directory.path_join("settings.cfg")
	root.add_child(fresh)
	fresh.set_physics_process(false)
	return fresh

func _initialize() -> void:
	call_deferred("run_checks")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_key_input(event)

func run_checks() -> void:
	game = new_game()
	game.start_run(12345)
	game._clear_actors()
	assert(not game.furnishing_editor.open(), "Editor belongs only to the Sanctum")
	var outside: Vector2 = game.player_point
	assert(game.inventory.add("oak_chair", 2) and game.inventory.add("wool_rug"))
	assert(game.use_sanctum_sigil())
	var random_before: int = game.rng.state
	key(KEY_B)
	assert(game.state == "furnishing")
	game.furnishing_editor.select_item("oak_chair")
	key(KEY_R)
	key(KEY_ENTER)
	assert(game.furnishings.records.size() == 1 and game.furnishings.records[0].rotation == 1)
	assert(game.inventory.count("oak_chair") == 1)
	var uid: String = game.furnishings.records[0].uid
	assert(game.sanctum_view.furniture_nodes.has(uid))
	assert(not game.dungeon.walkable(Vector2(8, 11)), "Actual editor placement must work outside both former zones")
	game.furnishing_editor.select_item("wool_rug")
	key(KEY_ESCAPE)
	assert(game.inventory.count("wool_rug") == 1 and game.state == "furnishing")
	key(KEY_B)
	assert(game.state == "playing" and game.rng.state == random_before)
	assert(game.inventory.add("rune_lantern"))
	game.player_point = Vector2(14, 13)
	game._snap_camera()
	assert(game.world_items.place("rune_lantern", Vector2(15.5, 10.5)))
	var portable_box: Rect2 = game.world_items.applied_obstacles[0]
	assert(game.furnishing_editor.open("oak_chair"))
	game.furnishing_editor.target = Vector2(15.5, 10.5)
	assert(not game.furnishing_editor.confirm(), "Furniture must respect portable-object collision")
	game.furnishing_editor.target = Vector2(12, 12)
	assert(game.furnishing_editor.confirm())
	assert(game.dungeon.obstacles.has(portable_box), "Refreshing furniture must retain portable-object collision")
	game.furnishing_editor.select_placed(game.furnishings.records[-1].uid)
	assert(game.furnishing_editor.pickup())
	game.furnishing_editor.close()
	assert(game.save_game(1))
	var saved: Dictionary = game.make_save_data()
	var corrupt := saved.duplicate(true)
	corrupt.progress.furnishings.placed[0].point = [10, 17]
	assert(not game.saves.validate(corrupt) and not game.Journey.restore(game, corrupt))
	assert(game.furnishings.snapshot() == saved.progress.furnishings)
	var fresh = new_game()
	assert(fresh.load_game(1) and fresh.layer == "sanctum")
	assert(fresh.furnishings.snapshot() == saved.progress.furnishings and fresh.inventory.count("oak_chair") == 1)
	assert(fresh.sanctum_view.furniture_nodes.has(uid))
	assert(fresh.leave_sanctum() and fresh.player_point.is_equal_approx(outside))
	assert(fresh.inventory.count("oak_chair") == 1 and fresh.furnishings.records.size() == 1)
	assert(fresh.save_game(2) and fresh.load_game(2))
	assert(fresh.use_sanctum_sigil() and fresh.sanctum_view.furniture_nodes.has(uid))
	fresh.return_to_sanctuary()
	assert(fresh.furnishings.records.size() == 1)
	var city: Dictionary = fresh.world.region_at(fresh.world.start).city
	var place: Dictionary = fresh.interiors.describe(city, city.houses[0])
	fresh._generate_surface(place.approach)
	assert(fresh.interiors.enter(fresh.interiors.target()) and fresh.use_sanctum_sigil())
	assert(fresh.furnishings.place("wool_rug", Vector2(15.5, 10.5), 0, fresh.inventory))
	fresh.refresh_sanctum_furnishings()
	assert(fresh.leave_sanctum() and fresh.layer == "interior")
	assert(fresh.interiors.leave() and fresh.furnishings.records.size() == 2)
	assert(fresh.inventory.count("wool_rug") == 0)
	var legacy: Dictionary = fresh.make_save_data()
	legacy.progress.erase("furnishings")
	assert(fresh.saves.validate(legacy) and fresh.Journey.restore(fresh, legacy))
	assert(fresh.furnishings.records.is_empty())
	assert(game.use_sanctum_sigil())
	game.start_run(776)
	assert(game.furnishings.records.is_empty(), "New characters get independent homes")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: furnishing hotkeys/cancel, shared portable collision, no combat RNG use, corrupt/legacy saves, fresh-scene home/away saves, exact returns, indoor carry and independent homes")
	quit()
