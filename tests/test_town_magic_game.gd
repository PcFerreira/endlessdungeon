extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-town-magic-%s" % Time.get_ticks_usec()
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var city: Dictionary = game.world.region_at(game.world.start).city
	var keeper: Dictionary = game.life.actors[city.residents[0].id]
	game._generate_surface(keeper.point - Vector2(1,0))
	game.interact()
	assert(game.state == "dialogue","Resident approach must open conversation: %s / %s" % [game.state,game.layer])
	var buttons: Array = game.expansion.overlay.find_children("*","Button",true,false).filter(func(node): return node.text == "Town charm" or node.tooltip_text == "Town charm")
	assert(buttons.size() == 1)
	var inventory: Dictionary = game.inventory.snapshot()
	var rng_state: int = game.rng.state
	buttons[0].pressed.emit()
	var profile: Dictionary = city.magic.profile
	assert(game.expansion.overlay.find_children("*","Label",true,false).any(func(node): return node.text.contains(profile.account) and node.text.contains(profile.custom)))
	assert(game.inventory.snapshot() == inventory and game.rng.state == rng_state)
	game.expansion.close_lore()
	assert(game.state == "playing" and game.save_game(1))
	var payload: Dictionary = game.saves.read(1).data
	assert(payload.generator_version == 4)
	assert(game.Journey.restore(game,payload))
	assert(game.world.region_at(game.world.start).city.houses == city.houses)
	assert(game.world.region_at(game.world.start).city.magic == city.magic)
	var target: Dictionary = game.interiors.describe(city,city.houses.filter(func(house): return house.get("infill",false))[0])
	game._generate_surface(target.approach)
	game.interact()
	assert(game.layer == "interior")
	game.interiors.leave()
	assert(game.layer == "overworld" and game.player_point.is_equal_approx(target.approach))
	print("PASS: actual E resident/charm account, unchanged inventory/combat RNG, generator-4 disk round-trip and exact infill interior exit")
	game.queue_free()
	await process_frame
	quit()
