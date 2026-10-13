extends SceneTree

const Game = preload("res://scripts/game.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Bundles = preload("res://scripts/bundle_catalog.gd")
const Habitat = preload("res://scripts/animal_habitat.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-bundle-gameplay-%s" % Time.get_ticks_usec()
	root.add_child(game)
	call_deferred("checks")

func checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var samples := {}
	for item in Bundles.data.items:
		if not samples.has(item.kind):
			samples[item.kind] = item
		if item.kind == "equipment" and game.build.class_id in item.classes:
			samples.equipment = item
	for item in samples.values():
		game._drop(game.player_point, item.id)
		game._update_pickups(.01)
		assert(game.inventory.count(item.id) == 1)
	game.hp = 25
	game.mana = 5
	var consumable: Dictionary = samples.consumable
	assert(game.use_item(consumable.id) and game.inventory.count(consumable.id) == 0)
	assert(game.hp > 25 or game.mana > 5)
	assert(game.inventory.add(consumable.id))
	game.hp = game.max_hp
	game.mana = game.max_mana
	assert(not game.use_item(consumable.id) and game.inventory.count(consumable.id) == 1)
	assert(game.equip_item(samples.equipment.id))
	assert(game.save_game(1))
	var before: Dictionary = game.inventory.snapshot()
	assert(game.load_game(1) and game.inventory.snapshot() == before)
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.enter_dungeon(site)
	game._clear_actors()
	var rng_before: int = game.rng.state
	var ordinal: int = game.kills + 1
	while not Items.should_drop(game.run_seed, ordinal) or ordinal % 4 == 0:
		ordinal += 1
	game.kills = ordinal - 1
	game._spawn_enemy(game.player_point + Vector2(2,0), game.EnemyCatalog.TYPES.size() - 1, "bundle-encounter")
	game._hit_enemy(game.enemies[0], 10000)
	var reward := Items.enemy_reward(game.run_seed, ordinal, game.EnemyCatalog.TYPES[-1], {"class":game.build.class_id,"biome":game.dungeon.biome,"family":site.family,"facet":""})
	assert(game.pickups.any(func(pickup): return pickup.kind == reward))
	assert(game.pickups.any(func(pickup): return pickup.kind == "gold_coin"))
	assert(game.rng.state != rng_before, "Existing combat effects retain their own RNG")
	for point in [Vector2(-100,-100), Vector2(game.dungeon.start)]:
		game._drop(point, samples.material.id)
		assert(game.dungeon.walkable(game.pickups[-1].point), "Drops must stay accessible")
	var data: Dictionary = game.make_save_data()
	assert(game.saves.validate(data))
	game.return_to_surface()
	var water_species: Array = game.life.catalog.data.species.filter(func(species): return species.get("medium", "land") == "water")
	assert(water_species.size() >= 3)
	var origin := Vector2.INF
	for x in range(15,160,8):
		game.world.load_around(Vector2(x,24))
		origin = Habitat.origin(game.world, Vector2(x,24), "water")
		if origin.is_finite():
			break
	assert(origin.is_finite(), "A water habitat should be available in sampled wilderness")
	var species: Dictionary = water_species[0]
	var body := {"id":"habitat:%s:%s:animal:0" % [floori(origin.x/16),floori(origin.y/16)],"kind":"animal","species":species.id,"asset_id":game.life.catalog.model_choices[species.id][0].id,"height":species.height,"speed":species.speed,"idle":species.idle,"walk":species.walk,"medium":"water","point":origin,"city_id":"city:0:0","city_name":"Test"}
	game.life.actors.clear()
	game.life._add_actor(game.world,body,{})
	assert(game.life.actors.has(body.id))
	for tick in range(60):
		game.life.advance(.1)
		game.life.step(game.world,Vector2.ZERO,.1)
		assert(Habitat.usable(game.world,game.life.actors[body.id].point,"water"))
	var state: Dictionary = game.life.snapshot()
	assert(game.life.valid_snapshot(state))
	assert(game.life.restore(state, game.run_seed))
	game.life._add_actor(game.world,body,{})
	assert(game.life.actors[body.id].species == species.id and game.life.actors[body.id].medium == "water")
	print("PASS: catalog drops/collection, consumables and class equipment, disk saves, enemy loot, accessible placements, aquatic movement and saved species")
	game.queue_free()
	await process_frame
	quit()
