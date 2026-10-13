extends SceneTree

const Review = preload("res://tools/biome_review_points.gd")
var game
var catalog
var directory := "res://artifacts/foraging/capture-%s" % Time.get_ticks_usec()
var frames := []
var collected: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	assert(DisplayServer.get_name() != "headless", "Foraging capture needs the native renderer")
	root.size = Vector2i(1280, 800)
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	catalog = load("res://scripts/forage_catalog.gd")
	game = load("res://scripts/game.gd").new()
	game.records_enabled = false
	game.save_directory = directory.path_join("preview-saves")
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(91, 6)
	var points := Review.find(game.world)
	var wanted := {"greenwood": "forage_bramble_berries", "haunted_hollows": "forage_wisp_glass", "volcanic_wastes": "forage_cinder_crystal", "crystal_tundra": "forage_prism_heart"}
	for biome_id in wanted:
		var record := _find_patch(points[biome_id].cell, biome_id, wanted[biome_id])
		assert(not record.is_empty(), "Find an actual patch for " + biome_id)
		game._generate_surface(record.point, false)
		game._clear_actors()
		for offset in [Vector2(-.8, 0), Vector2(.8, 0), Vector2(0, .8), Vector2.ZERO]:
			var candidate: Vector2 = record.point + offset
			if game.world.walkable(candidate) and game.world.line_clear(candidate, record.point) and absf(game.world.ground_height(candidate) - game.world.ground_height(record.point)) < .5:
				game.player_point = candidate
				break
		game.surface_zoom = 10
		game.camera_yaw = PI / 4
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.foraging.sync(true)
		assert(game.foraging.target().get("id", "") == record.id and game.foraging.models.has(record.id))
		await _frame(biome_id + "-before", record)
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
		await _frame(biome_id + "-before-reverse", record)
		game.interact()
		assert(game.foraging.harvested.has(record.id) and not game.foraging.models.has(record.id) and game.inventory.count(record.item) == record.quantity)
		collected.append(record)
		await _frame(biome_id + "-gathered", record)
	game.toggle_inventory()
	assert(game.state == "inventory")
	game.interface.inventory_filter = 4
	game.interface.inventory_selected = collected[1].item
	game.interface.previous_state = ""
	await _frame("backpack-wisp-glass", collected[1])
	game.interface.inventory_selected = collected[2].item
	game.interface.previous_state = ""
	await _frame("backpack-cinder-crystal", collected[2])
	game.toggle_inventory()
	await _trade()
	var manifest := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"resolution": [1280, 800], "seed": 91, "edition": 6, "catalog_sha256": JSON.stringify(catalog.DATA).sha256_text(), "frames": frames, "depletion": game.foraging.snapshot(), "inventory": game.inventory.snapshot()}, "\t"))
	manifest.close()
	game.queue_free()
	await process_frame
	print("CAPTURE_DIRECTORY: " + ProjectSettings.globalize_path(directory))
	print("PASS: %s native actual biome patch views, gathered disappearance, real material icons/backpack and market sale with increased gold" % frames.size())
	quit()

func _find_patch(point: Vector2i, biome_id: String, item_id: String) -> Dictionary:
	var center := Vector2i(floori(float(point.x) / catalog.DATA.spacing), floori(float(point.y) / catalog.DATA.spacing))
	for radius in range(25):
		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):
				if maxi(absi(x - center.x), absi(y - center.y)) != radius:
					continue
				var record: Dictionary = catalog.plan(game.world, Vector2i(x, y))
				if not record.is_empty() and record.biome_id == biome_id and record.item == item_id:
					return record
	return {}

func _trade() -> void:
	var city: Dictionary = game.world.region_at(game.world.start).city
	var shop := {}
	for house in city.houses:
		if house.use_id == "general_store":
			shop = game.interiors.describe(city, house)
			break
	assert(not shop.is_empty())
	game._generate_surface(shop.approach, false)
	game._clear_actors()
	game.interact()
	assert(game.layer == "interior")
	var source: Dictionary = game.stores.sources()[0]
	game.player_point = source.point
	game._snap_camera()
	game.interact()
	assert(game.state == "store")
	game.stores._change_mode(true)
	game.stores.selected_item = collected[0].item
	game.stores._show()
	await _frame("market-materials-before-sale", collected[0])
	var coins: int = game.inventory.count("gold_coin")
	assert(game.stores.sell(collected[0].item) and game.inventory.count("gold_coin") > coins)
	game.stores._show()
	await _frame("market-materials-sold", collected[0])

func _frame(name: String, record: Dictionary) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK)
	frames.append({"image": name + ".png", "biome_id": record.biome_id, "item": record.item, "display_name": game.Inventory.ITEMS[record.item].name, "quantity": record.quantity, "patch_id": record.id, "point": [record.point.x, record.point.y], "scope": catalog.scope(game.world), "layer": game.layer, "state": game.state, "remaining_patch": game.foraging.nodes.has(record.id), "carried": game.inventory.count(record.item), "gold": game.inventory.count("gold_coin")})
	print("CAPTURE: " + name)
