extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://stores-preview-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	game.inventory.add("gold_coin",120)
	var city: Dictionary = game.world.region_at(game.world.start).city
	var kinds := {}
	for house in city.houses:
		var place: Dictionary = game.interiors.describe(city,house)
		if place.type not in ["shop","workshop"] or kinds.has(place.type):
			continue
		kinds[place.type] = true
		game._generate_surface(place.approach,false)
		game.interact()
		assert(game.layer == "interior")
		var source: Dictionary = game.stores.sources()[0]
		game.player_point = source.point
		game.player.position = game.to_world(source.point)
		game._snap_camera()
		await frame("stores-" + place.type + "-counter")
		game.interact()
		assert(game.state == "store")
		await frame("stores-" + place.type + "-trade")
		var item: String = game.stores.offers(source).keys()[0]
		assert(game.stores.buy(item))
		game.stores._show()
		await frame("stores-" + place.type + "-purchase")
		game.stores.close()
		game.player_point = Vector2(game.dungeon.exit)
		game.interact()
	assert(kinds.size() == 2)
	var market: Dictionary = city.outdoor_lots.filter(func(lot): return lot.kind == "market")[0]
	game._generate_surface(Vector2(market.footprint.position),false)
	var source: Dictionary = game.stores.sources().filter(func(entry): return entry.id == market.id)[0]
	game.player_point = source.point
	game.player.position = game.to_world(source.point)
	game._snap_camera()
	await frame("stores-market-counter")
	game.interact()
	assert(game.state == "store")
	await frame("stores-market-trade")
	print("PASS: actual shop/workshop counters, market approach, stock UI and coin purchase native captures")
	game.queue_free()
	await process_frame
	quit()

func frame(label: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK)
