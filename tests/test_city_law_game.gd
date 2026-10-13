extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-city-law-%s" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var objects = game.get("world_items")
	assert(objects != null, "The portable-item controller must supply actual city ownership")
	game._clear_actors()
	var city: Dictionary = game.world.region_at(game.world.start).city
	var building: Dictionary = game.interiors.describe(city,city.houses[0])
	game._generate_surface(building.approach,false)
	assert(game.interiors.enter(game.interiors.target()))
	assert(not objects.registered.is_empty())
	var authored: Dictionary = objects.registered.values()[0].record
	game.player_point = game.dungeon.safe_position(objects.position(authored))
	assert(objects.pickup(authored.uid) and not objects.registered[authored.uid].node.visible)
	assert(game.interiors.leave())
	objects = game.world_items
	var guard: Dictionary = game.life.residents().filter(func(actor): return actor.role == "guard")[0]
	var guard_id: String = guard.id
	var point: Vector2 = guard.point + Vector2(0,.5)
	game.player_point = point
	game._snap_camera()
	game._refresh_surface()
	game._clear_actors()
	var model := game.Voxels.cube(Vector3(.25,.35,.25),Color("e7be74"))
	model.position = game.to_world(point)
	game.add_child(model)
	var uid: String = city.id + ":law-test:lantern"
	objects.register_prop({"uid":uid,"item":"rune_lantern","point":point,"owner":city.id,"scope":"overworld"},model)
	var rng_state: int = game.rng.state
	assert(objects.pickup(uid))
	assert(game.inventory.stolen_count("rune_lantern") == 1 and not model.visible)
	assert(not game.inventory.remove("rune_lantern"), "Ordinary consumption must not launder stolen property")
	var hp: float = game.hp
	game.simulate(.1)
	assert(game.state == "guard_demand" and game.hp == hp and not objects.wanted(city.id).hostile)
	var tick: int = game.life.tick
	game._physics_process(.5)
	assert(game.life.tick == tick)
	game.city_law.refuse()
	assert(game.state == "playing" and objects.wanted(city.id).hostile)
	for index in range(35):
		game.simulate(.1)
	assert(game.hp < hp, "The town sanctuary must not shield a thief from the watch")
	assert(game.kills == 0 and game.enemies.is_empty() and game.rng.state == rng_state)
	assert(not game.use_sanctum_sigil())
	game.player_point = Vector2(city.cell) + Vector2(1,1)
	guard.point = game.player_point + Vector2(.5,0)
	assert(game.interaction_hint().contains("property"))
	var hp_before_well: float = game.hp
	game.interact()
	assert(game.state == "guard_demand" and game.hp == hp_before_well, "A nearby wanted guard must take priority over fountain healing")
	game.city_law.refuse()
	assert(game.save_game(1))
	assert(game.load_game(1) and game.world_items.wanted(city.id).hostile)
	objects = game.world_items
	assert(game.inventory.stolen_count("rune_lantern") == 1)
	var site: Dictionary = game.world.nearest_site(game.player_point,"dungeon")
	game.enter_dungeon(site)
	game._clear_actors()
	var stored := false
	for cell in game.dungeon.tiles:
		var proposal: Dictionary = game.world_items.placement("rune_lantern",Vector2(cell),0)
		if proposal.problem.is_empty():
			stored = game.world_items.place("rune_lantern",Vector2(cell),0)
			break
	assert(stored and game.inventory.stolen_count("rune_lantern") == 0)
	assert(game.world_items.wanted(city.id).hostile and game.world_items.state.placed.any(func(record): return record.source == uid))
	assert(game.save_game(3) and game.load_game(3), "Stored stolen property must survive dungeon saves")
	game.return_to_surface()
	game._generate_surface(Vector2(city.cell) + Vector2(1,8),false)
	objects = game.world_items
	var guard_after: Dictionary = game.life.actors[guard_id]
	game.player_point = guard_after.point + Vector2(.5,0)
	var other_city: Dictionary = game.world.region_at(city.cell + Vector2i.RIGHT * game.world.REGION_SIZE).city
	var other_uid: String = other_city.id + ":law-test:chair"
	var other_model := game.Voxels.cube(Vector3(.25,.3,.25),Color("a88861"))
	other_model.position = game.to_world(game.player_point)
	game.add_child(other_model)
	objects.register_prop({"uid":other_uid,"item":"oak_chair","point":game.player_point,"owner":other_city.id,"scope":"overworld"},other_model)
	assert(objects.pickup(other_uid) and objects.refuse_return(other_city.id))
	assert(game.expansion.open_dialogue(guard_after) and game.state == "guard_demand")
	assert(game.city_law.restitute())
	assert(objects.wanted(city.id).is_empty() and game.inventory.stolen_count("rune_lantern") == 0)
	assert(not objects.state.placed.any(func(record): return record.source == uid), "Restitution must reclaim stolen copies from other locations")
	assert(not objects.state.removed.has(authored.uid), "Guard restitution must restore actual authored indoor property")
	assert(objects.wanted(other_city.id).hostile and game.inventory.stolen_count("oak_chair") == 1, "Restitution must clear only the original city's debt")
	var hp_after: float = game.hp
	for index in range(30):
		game.simulate(.1)
	assert(game.hp == hp_after)
	assert(objects.return_stolen(other_city.id))
	game._generate_surface(building.approach,false)
	assert(game.interiors.enter(game.interiors.target()))
	assert(game.world_items.registered[authored.uid].node.visible)
	assert(game.interiors.leave())
	assert(game.save_game(2) and game.load_game(2) and game.world_items.wanted(city.id).is_empty())
	var coin_before: int = game.inventory.count("gold_coin")
	game.enter_dungeon(site)
	assert(game.enemies.size() >= 4)
	var killed: int = game.kills
	for enemy in game.enemies.slice(0,4):
		game._hit_enemy(enemy,100000)
	for drop in game.pickups.duplicate():
		if drop.kind == "gold_coin":
			game.player_point = drop.point
			game._update_pickups(.1)
	assert(game.kills == killed + 4 and game.inventory.count("gold_coin") == coin_before + 4, "Four real creature kills must fund the current potion price")
	game.return_to_surface()
	game._generate_surface(Vector2(game.world.start),false)
	game._clear_actors()
	var merchant: Dictionary = game.life.residents().filter(func(actor): return actor.role == "merchant")[0]
	game.player_point = merchant.point + Vector2(.5,0)
	game._snap_camera()
	game.interact()
	assert(game.state == "dialogue")
	var potions: int = game.inventory.count("health_potion")
	game.expansion._trade("health_potion","gold_coin")
	assert(game.inventory.count("health_potion") == potions + 1 and game.inventory.count("gold_coin") == coin_before)
	game.expansion.close_lore()
	assert(game.save_game(2) and game.load_game(2) and game.inventory.count("health_potion") == potions + 1)
	assert(game.use_sanctum_sigil())
	tick = game.life.tick
	game.simulate(10)
	assert(game.life.tick == tick)
	assert(game.leave_sanctum() and game.world_items.wanted(city.id).is_empty())
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: actual city theft, demand-before-force, refusal attacks, isolated rewards/RNG, blocked sigil, persistent hostility, guard-E restitution, cleared saves and Sanctum carry")
	quit()
