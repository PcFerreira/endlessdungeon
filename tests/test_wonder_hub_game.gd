extends SceneTree

const Game = preload("res://scripts/game.gd")
const HubWorld = preload("res://scripts/hub_world.gd")
const CASES := {"clay_herbalist": Vector2(-24608, -19472), "lantern_peddler": Vector2(-24608, -23568)}
var directory := "user://wonder-hub-check-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func create_game():
	var game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func checks() -> void:
	var game = create_game()
	game.start_run(91, 6)
	game.has_journey = false
	game.begin_journey()
	assert(game.world is HubWorld and game.floating_hub.active())
	assert(not game.life.actors.values().any(func(actor): return actor.get("roaming", false)))
	game.player_point = game.floating_hub.city().hub_portal
	game.player_y = game.world.ground_height(game.player_point)
	game.grounded = true
	assert(game.floating_hub.target().get("kind") == "depart")
	game.interact()
	assert(game.world is HubWorld and not game.floating_hub.active())
	for id in CASES:
		game.life.reset(91)
		game._generate_surface(CASES[id], false)
		var matches: Array = game.life.actors.values().filter(func(actor): return actor.get("wonder_id", "") == id)
		assert(not matches.is_empty(), "Real departed HubWorld must allocate the supported " + id)
		var actor: Dictionary = matches[0]
		assert(not game.world.hub.reserved.has_point(Vector2i(actor.point.round())))
		assert(approach(game, actor.point).is_finite())
		game.grounded = true
		game.state = "playing"
		assert(game.expansion.target().get("id") == actor.id)
		assert(not game.stores._wonder_source(actor).is_empty(), "Actual HubWorld exterior traders must expose their trusted native shop")
		var rng_before: int = game.rng.state
		game.interact()
		assert(game.state == "dialogue")
		var buttons: Array = game.expansion.overlay.find_children("*", "Button", true, false).filter(func(button): return button.text == "Trade")
		assert(buttons.size() == 1)
		buttons[0].emit_signal("pressed")
		assert(game.state == "store" and game.stores.current.wonder_actor == actor.id)
		var store_id: String = game.stores.current.id
		assert(game.inventory.add("forage_bramble_berries"))
		var gold: int = game.inventory.count("gold_coin")
		var purse: int = game.stores.records[store_id].purse
		assert(game.stores.sell("forage_bramble_berries") and game.inventory.count("gold_coin") > gold)
		assert(game.stores.records[store_id].purse < purse and game.rng.state == rng_before)
		var saved_stock: Dictionary = game.stores.records[store_id].duplicate(true)
		game.stores.close()
		assert(game.save_game(1))
		game.queue_free()
		await process_frame
		game = create_game()
		assert(game.load_game(1) and game.world is HubWorld)
		assert(game.life.actors.has(actor.id) and game.life.actors[actor.id].wonder_id == id)
		assert(game.stores.records[store_id] == saved_stock)
		assert(game.use_sanctum_sigil() and game.leave_sanctum() and game.world is HubWorld)
		assert(game.life.actors.has(actor.id) and game.life.actors[actor.id].wonder_id == id)
		assert(game.stores.records[store_id] == saved_stock)
		var point: Vector2 = game.player_point
		game.player_point = game.world.hub.spawn
		assert(game.stores._wonder_source(game.life.actors[actor.id]).is_empty(), "Hub island context cannot expose an exterior trader")
		game.player_point = point
	game.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("PASS: physical Worldgate departure retains actual HubWorld residents and button-driven merchant sales, fresh disk/body/stock restoration, Sanctum return and reserved-island exclusion")
	quit()

func approach(game, point: Vector2) -> Vector2:
	for offset in [Vector2(.7, 0), Vector2(-.7, 0), Vector2(0, .7), Vector2(0, -.7), Vector2.ZERO]:
		var candidate: Vector2 = point + offset
		if game.world.walkable(candidate) and game.world.line_clear(candidate, point) and absf(game.world.ground_height(candidate) - game.world.ground_height(point)) < .5:
			game.player_point = candidate
			game.player_y = game.world.ground_height(candidate)
			return candidate
	return Vector2.INF
