extends SceneTree

const Game = preload("res://scripts/game.gd")
const Types = preload("res://scripts/town_types.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-town-types-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("checks")

func checks() -> void:
	game.set_physics_process(false)
	game.start_run(0)
	var city := {}
	for x in range(-5,6):
		for y in range(-5,6):
			var candidate: Dictionary = game.world.region_at(Vector2i(x,y) * game.World.REGION_SIZE).city
			if candidate.settlement_type_id == "city_rainwood":
				city = candidate.duplicate(true)
				break
		if not city.is_empty():
			break
	assert(not city.is_empty())
	game._generate_surface(Vector2(city.cell) + Vector2(0,3),false)
	game.begin_journey()
	var keeper: Dictionary = game.life.actors[city.residents[0].id]
	game._generate_surface(keeper.point - Vector2(1,0),false)
	game.interact()
	assert(game.state == "dialogue")
	var bag: Dictionary = game.inventory.snapshot()
	var random_state: int = game.rng.state
	game.expansion.town_charm()
	assert(game.expansion.overlay.find_children("*","Label",true,false).any(func(node): return node.text.contains(Types.DATA.types.city_rainwood.magic.custom)))
	assert(game.inventory.snapshot() == bag and game.rng.state == random_state)
	game.expansion.close_lore()
	assert(game.save_game(1) and game.load_game(1))
	var restored: Dictionary = game.world.region_at(city.cell).city
	assert(restored.settlement_type_id == city.settlement_type_id and restored.magic == city.magic and restored.houses == city.houses)
	assert(restored.exterior_profile == city.exterior_profile)
	var style_nodes: Array = game.world_view.find_children("*","MeshInstance3D",true,false).filter(func(node): return node.get_meta("house_id","").begins_with(city.id + ":house:"))
	assert(not style_nodes.is_empty(),"Actual streamed towns must include the native exterior component")
	var signature: Dictionary = restored.houses.filter(func(house): return house.get("infill",false) and house.use_id == "scribe")[0]
	var target: Dictionary = game.interiors.describe(restored,signature)
	game._generate_surface(target.approach,false)
	game.interact()
	assert(game.layer == "interior")
	game.interiors.leave()
	assert(game.layer == "overworld" and game.player_point.is_equal_approx(target.approach))
	print("PASS: real themed resident/custom, unchanged inventory/combat RNG, disk-restored identity/houses/charm and reachable signature-business interior")
	game.queue_free()
	await process_frame
	quit()
