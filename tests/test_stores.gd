extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-stores-%s" % Time.get_ticks_usec()

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
	assert(game.get("stores") != null, "Generated shops and markets need a persistent trading controller")
	var city: Dictionary = game.world.region_at(game.world.start).city
	var layouts := {}
	for house in city.houses:
		var place: Dictionary = game.interiors.describe(city,house)
		if not game.stores.catalog.data.interiors.has(place.type):
			continue
		for layout in game.InteriorArea.content.get_entry("interiors",place.type).layouts:
			var destination: Dictionary = place.duplicate(true)
			destination.layout_id = layout.id
			game._generate_interior(destination)
			var counter: Dictionary = game.stores.sources()[0]
			var reachable := {game.dungeon.start: true}
			var frontier := [game.dungeon.start]
			while not frontier.is_empty():
				var cell: Vector2i = frontier.pop_front()
				for direction in game.dungeon.DIRECTIONS:
					var next: Vector2i = cell + direction
					if not reachable.has(next) and game.dungeon.walkable(Vector2(next)):
						reachable[next] = true
						frontier.append(next)
			assert(reachable.has(Vector2i(counter.point.round())), "Every actual business layout must connect its counter to the entrance")
			layouts[place.type + ":" + layout.id] = true
			var initial: Dictionary = game.stores.catalog.initial(counter,game.run_seed)
			assert(initial.stock.size() == game.stores.catalog.data.profiles[counter.profile].selection)
			assert(initial == game.stores.catalog.initial(counter,game.run_seed))
	assert(layouts.size() == 4)
	var shop := {}
	for house in city.houses:
		var place: Dictionary = game.interiors.describe(city,house)
		if place.type == "shop":
			shop = place
			break
	assert(not shop.is_empty())
	game._generate_surface(shop.approach,false)
	game._clear_actors()
	game.interact()
	assert(game.layer == "interior" and game.interiors.current.id == shop.id)
	var source: Dictionary = game.stores.sources()[0]
	assert(source.id == shop.id and game.dungeon.walkable(source.point))
	game.player_point = source.point
	assert(game.interaction_hint().contains("Trade"))
	game.interact()
	assert(game.state == "store")
	assert(game.inventory.add("gold_coin",200))
	var offers: Dictionary = game.stores.offers(source)
	var item: String = offers.keys()[0]
	var price: int = offers[item].buy
	var stock: int = offers[item].count
	var coins: int = game.inventory.count("gold_coin")
	assert(game.stores.buy(item) and game.inventory.count(item) > 0)
	assert(game.inventory.count("gold_coin") == coins - price and game.stores.offers(source)[item].count == stock - 1)
	assert(game.stores.sell(item) and game.stores.offers(source)[item].count == stock)
	assert(game.inventory.count("gold_coin") < coins, "Selling cannot produce a buy/sell arbitrage loop")
	var mapping: String = game.stores.catalog.data.uses[shop.use_id]
	game.stores.catalog.data.uses[shop.use_id] = "smithy"
	var remapped: Dictionary = game.stores.sources()[0]
	assert(remapped.profile == source.profile and game.stores.offers(remapped) == game.stores.offers(source), "A remapped building use must retain its saved trading specialty")
	assert(game.Stores.valid(game.stores.snapshot()))
	game.stores.catalog.data.uses[shop.use_id] = mapping
	var record: Dictionary = game.stores.records[source.id]
	var purse: int = record.purse
	record.purse = 0
	var no_purse: Dictionary = game.inventory.snapshot()
	assert(not game.stores.sell(item) and game.inventory.snapshot() == no_purse)
	record.purse = 999999
	assert(not game.stores.buy(item) and game.inventory.snapshot() == no_purse, "A merchant purse must remain valid for saves")
	record.purse = purse
	var before: Dictionary = game.inventory.snapshot()
	game.inventory.items = {"sanctum_sigil":1,"gold_coin":100,"health_potion":420,"aether_potion":20}
	game.inventory.equipment = {"weapon":"","armor":"","charm":""}
	game.inventory.stolen.clear()
	var full: Dictionary = game.inventory.snapshot()
	var unfamiliar := ""
	for candidate in offers:
		if game.inventory.count(candidate) == 0:
			unfamiliar = candidate
			break
	assert(not unfamiliar.is_empty(), "General stores must offer more than the two starting potions")
	var stock_before: Dictionary = game.stores.snapshot()
	assert(not game.stores.buy(unfamiliar) and game.inventory.snapshot() == full and game.stores.snapshot() == stock_before, "Full backpack must roll back money and stock")
	game.inventory.items.gold_coin = 999
	full = game.inventory.snapshot()
	assert(not game.stores.sell("health_potion") and game.inventory.snapshot() == full and game.stores.snapshot() == stock_before, "Coin-stack overflow must roll back a sale")
	game.inventory.restore(before,game.build.class_id)
	while game.inventory.remove("gold_coin"):
		pass
	for index in range(price):
		assert(game.inventory.add_owned("gold_coin",city.id,city.id + ":test-store-coin:%s" % index))
	var stolen_coins: Dictionary = game.inventory.snapshot()
	assert(not game.stores.buy(item) and game.inventory.snapshot() == stolen_coins and game.stores.snapshot() == stock_before, "City coins cannot buy clean stock")
	game.inventory.restore(before,game.build.class_id)
	var owned: int = game.inventory.count(item)
	while game.inventory.remove(item):
		pass
	assert(game.inventory.add_owned(item,city.id,city.id + ":test-store-item"))
	var stolen: Dictionary = game.inventory.snapshot()
	assert(not game.stores.sell(item) and game.inventory.snapshot() == stolen, "Shops reject stolen-only stock")
	game.inventory.return_origin(city.id + ":test-store-item")
	if owned > 0:
		game.inventory.add(item,owned)
	assert(game.stores.buy(item))
	while game.stores.offers(source)[item].count > 0:
		assert(game.stores.buy(item))
	var exhausted: Dictionary = game.inventory.snapshot()
	assert(not game.stores.buy(item) and game.inventory.snapshot() == exhausted, "Depleted stock cannot be bought again")
	game.stores.close()
	assert(game.use_sanctum_sigil())
	var home_stock: Dictionary = game.stores.snapshot()
	assert(game.use_sanctum_sigil() and game.layer == "interior" and game.stores.snapshot() == home_stock)
	game.player_point = source.point
	game.interact()
	assert(game.state == "store" and game.stores.offers(source)[item].count == 0)
	game.stores.close()
	game.player_point = Vector2(game.dungeon.exit)
	game.interact()
	assert(game.layer == "overworld")
	var market := {}
	for lot in city.outdoor_lots:
		if lot.kind == "market":
			market = lot
			break
	assert(not market.is_empty())
	game._generate_surface(Vector2(market.footprint.position),false)
	game._clear_actors()
	var market_source := {}
	for entry in game.stores.sources():
		if entry.id == market.id:
			market_source = entry
	assert(not market_source.is_empty() and market_source.id != shop.id)
	game.player_point = market_source.point
	game.interact()
	assert(game.state == "store" and game.stores.current.id == market.id)
	var market_offers: Dictionary = game.stores.offers(market_source)
	var market_item: String = market_offers.keys()[0]
	assert(game.stores.buy(market_item))
	var saved: Dictionary = game.stores.snapshot()
	game.stores.close()
	assert(game.save_game(1))
	var payload: Dictionary = game.saves.read(1).data
	assert(game.stores.restore(payload.progress.stores) and game.stores.snapshot() == saved)
	var fresh := Game.new()
	fresh.records_enabled = false
	fresh.save_directory = directory
	fresh.settings_path = directory.path_join("settings.cfg")
	root.add_child(fresh)
	fresh.set_physics_process(false)
	assert(fresh.load_game(1) and fresh.stores.snapshot() == saved)
	var legacy: Dictionary = payload.duplicate(true)
	legacy.progress.erase("stores")
	assert(fresh.Journey.restore(fresh,legacy) and fresh.stores.snapshot().is_empty())
	var invalid: Dictionary = payload.duplicate(true)
	invalid.progress.stores[market.id].stock[market_item] = -1
	assert(not fresh.saves.validate(invalid))
	for house in city.houses:
		if house.get("use_id", "") != "smithy":
			continue
		var workshop: Dictionary = game.interiors.describe(city,house)
		game._generate_surface(workshop.approach,false)
		game.interact()
		var counter: Dictionary = game.stores.sources()[0]
		game.player_point = counter.point
		game.interact()
		assert(game.state == "store" and game.stores.catalog.accepts(counter.profile,"arcane_staff"))
		assert(game.inventory.add("arcane_staff") and game.inventory.equip("arcane_staff",game.build.class_id))
		var equipped: Dictionary = game.inventory.snapshot()
		assert(not game.stores.sell("arcane_staff") and game.inventory.snapshot() == equipped, "An eligible equipped item cannot be sold")
		game.stores.close()
		break
	game.start_run(12345)
	assert(game.stores.snapshot().is_empty())
	print("PASS: actual shop and market E trading, clean coin buy/sell, finite source stock, full-bag atomic rollback, stolen rejection, fresh disk restore, malformed and older save handling")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	quit()
