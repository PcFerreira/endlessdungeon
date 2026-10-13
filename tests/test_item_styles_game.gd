extends SceneTree

const Game = preload("res://scripts/game.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
var directory := "user://test-item-styles-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func point_for(game, item: String) -> Vector2:
	for radius in range(1, 7):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var point: Vector2 = game.player_point + Vector2(x, y)
				if game.world_items.placement(item, point, 0).problem.is_empty():
					return point
	return Vector2.INF

func verify(game, uid: String) -> Array:
	var record: Dictionary = game.world_items.state.placed.filter(func(entry): return entry.uid == uid)[0]
	var node: Node3D = game.world_items.placed_nodes[uid]
	var biome: int = game.world.cell_info(Vector2i(game.world_items.position(record).round())).biome if game.layer == "overworld" else (game.dungeon.biome if game.layer in ["dungeon", "interior"] else 0)
	assert(game.world_items.Visual.families.styles.allows(node.get_meta("render_asset"), biome))
	var box := Bounds.bounds(node)
	assert(box.size.is_equal_approx(Vector3(record.footprint[0], record.height, record.footprint[1])) and is_zero_approx(box.position.y))
	return [record.item, node.get_meta("source_asset"), node.get_meta("render_asset")]

func run() -> void:
	var game = fresh()
	game.start_run(12345)
	game.begin_journey()
	var cities := {}
	for x in range(-12, 13):
		for y in range(-12, 13):
			var city: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE).city
			if not cities.has(city.biome):
				cities[city.biome] = city
			if cities.size() == 4:
				break
		if cities.size() == 4:
			break
	assert(cities.size() == 4)
	var item := "world_native:native_environment:block_voxel:table"
	for biome in range(4):
		var city: Dictionary = cities[biome]
		game._generate_surface(Vector2(city.cell) + Vector2(0, 3), false)
		var random_before: int = game.rng.state
		for kind in ["gold_coin", "health", "mana", "health_potion", "iron_sword", "arcane_staff"]:
			game._drop(game.player_point, kind)
			var node: Node3D = game.pickups[-1].node
			assert(game.world_items.Visual.families.styles.allows(node.get_meta("render_asset"), biome))
			assert(node.find_children("*", "Sprite3D", true, false).is_empty())
		game._update_pickups(.01)
		assert(game.pickups.is_empty() and game.inventory.count("gold_coin") > 0)
		assert(game.rng.state == random_before, "Representation cannot consume combat RNG")
		assert(game.inventory.add(item))
		var point := point_for(game, item)
		assert(point != Vector2.INF and game.world_items.place(item, point))
		var record: Dictionary = game.world_items.state.placed[-1]
		var uid: String = record.uid
		assert(record.item == item)
		var identity := verify(game, uid)
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.world_items.snapshot()))
		random_before = game.rng.state
		assert(game.save_game(1))
		game.queue_free()
		await process_frame
		game = fresh()
		var loaded: bool = game.load_game(1)
		var restored_snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.world_items.snapshot()))
		if not loaded or game.rng.state != random_before or restored_snapshot != snapshot:
			printerr("FAIL: restoration ", loaded, " / ", game.menu_notice, " rng ", [random_before, game.rng.state], " state ", [snapshot, game.world_items.snapshot()])
			game.queue_free()
			await process_frame
			quit(1)
			return
		assert(verify(game, uid) == identity)
		game.player_point = point + Vector2(.6, 0)
		assert(game.world_items.pickup(uid))
		assert(game.inventory.add("oak_chair"))
		assert(game.use_sanctum_sigil())
		assert(game.furnishings.place("oak_chair", Vector2(5 + biome * 2, 12), 0, game.inventory))
		game.furnishings.apply(game.dungeon)
		game.sanctum_view.refresh_furnishings(game.dungeon)
		var chair: Node3D = game.sanctum_view.furniture_nodes[game.furnishings.records[-1].uid]
		assert(chair.get_meta("visual_family") == "block_voxel")
		assert(game.save_game(2) and game.load_game(2))
		assert(game.leave_sanctum())
		var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
		game.enter_dungeon(site)
		random_before = game.rng.state
		for kind in ["gold_coin", "health", "mana", "health_potion", "iron_sword"]:
			game._drop(game.player_point, kind)
			assert(game.world_items.Visual.families.styles.allows(game.pickups[-1].node.get_meta("render_asset"), game.dungeon.biome))
		game._update_pickups(.01)
		assert(game.pickups.is_empty() and game.rng.state == random_before)
		assert(game.save_game(3))
		game.queue_free()
		await process_frame
		game = fresh()
		assert(game.load_game(3) and game.rng.state == random_before)
		game.return_to_surface()
	print("PASS: four-climate actual reward geometry/collection, unchanged RNG, cross-family source-item placement/pickup, exact bounds, fresh-scene disk identities and styled home furniture")
	game.queue_free()
	await process_frame
	quit()
