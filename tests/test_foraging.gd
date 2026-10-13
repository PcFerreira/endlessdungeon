extends SceneTree

const World = preload("res://scripts/world.gd")
const Biomes = preload("res://scripts/biome_catalog.gd")
const Review = preload("res://tools/biome_review_points.gd")
const Finite = preload("res://scripts/finite_world.gd")
const Hub = preload("res://scripts/hub_world.gd")
var catalog
var controller
var directory := "res://artifacts/foraging/check-%s" % Time.get_ticks_usec()
var examples := {}
var finite_example := {}

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(ResourceLoader.exists("res://scripts/forage_catalog.gd"), "Foraging needs its real biome material catalog")
	catalog = load("res://scripts/forage_catalog.gd")
	assert(ResourceLoader.exists("res://scripts/foraging.gd"), "Foraging needs its real collection controller")
	controller = load("res://scripts/foraging.gd")
	_check_catalog()
	_check_worlds()
	await _check_game()
	print("PASS: 28 real biome materials/icons, actual sparse patches across 14 ecologies and editions 4/5/6, finite/hub exclusions, independent RNG, real E harvesting/rollback/depletion, disk and Sanctum persistence, legacy/malformed saves and profitable clean material sales")
	quit()

func _check_catalog() -> void:
	assert(catalog.DATA.items.size() == 28 and catalog.DATA.biomes.size() == Biomes.DATA.profiles.size())
	var malformed: Dictionary = catalog.DATA.duplicate(true)
	malformed.patch_chance = 0
	assert(not catalog.valid(malformed))
	malformed = catalog.DATA.duplicate(true)
	malformed.biomes.greenwood.entries[0].item = "missing_material"
	assert(not catalog.valid(malformed), "Ecology pools must reference actual defined materials")
	var items = load("res://scripts/item_catalog.gd")
	var stores = load("res://scripts/store_catalog.gd").new()
	var visual = load("res://scripts/forage_visual.gd")
	var icons := {}
	for biome_id in Biomes.DATA.profiles:
		assert(catalog.DATA.biomes.has(biome_id))
		var entries: Array = catalog.DATA.biomes[biome_id].entries
		assert(entries.size() == 2 and entries[0].item != entries[1].item)
		for entry in entries:
			assert(catalog.DATA.items.has(entry.item) and items.definitions.has(entry.item))
			var definition: Dictionary = items.definitions[entry.item]
			assert(definition.name == catalog.DATA.items[entry.item].name, "Gathered material names must survive the actual item display contract")
			assert(definition.kind == "material" and definition.trade_value > 0 and definition.stack > 0)
			assert(not icons.has(definition.icon) and FileAccess.file_exists(definition.icon), "Each gathered material needs its own shipped icon")
			icons[definition.icon] = true
			var icon: Texture2D = items.icon(definition)
			assert(icon != null and icon.get_width() > 0 and icon.get_height() > 0, "Runtime SVG icons must load without an editor import")
			assert(stores.price(entry.item) == int(definition.trade_value), "Foraged material prices must use their economic value")
			for profile in ["market", "provisions", "smithy"]:
				assert(stores.accepts(profile, entry.item))
			for family in ["block_voxel", "flat_lowpoly"]:
				var model: Node3D = visual.model(definition, family)
				assert(model.get_meta("visual_family") == family and model.get_child_count() > 0)
				for mesh in model.get_children():
					var box: AABB = mesh.transform * mesh.mesh.get_aabb()
					assert(box.position.y >= -.001 and box.size.x <= .75 and box.size.z <= .75 and box.size.y > .05, "Gatherable geometry must fit its single clear ground cell")
					for surface in range(mesh.mesh.get_surface_count()):
						var arrays: Array = mesh.mesh.surface_get_arrays(surface)
						assert(not arrays[Mesh.ARRAY_VERTEX].is_empty() and not arrays[Mesh.ARRAY_COLOR].is_empty())
				model.free()
	assert(icons.size() == 28)

func _check_worlds() -> void:
	var started := Time.get_ticks_msec()
	for edition in [4, 5, 6]:
		var world := World.new()
		world.generate(91, edition)
		assert(catalog.scope(world) == "endless:91:%s" % edition)
		if edition == 6:
			var points := Review.find(world)
			for biome_id in Biomes.DATA.profiles:
				var found := _patches(world, points[biome_id].cell, biome_id, 2)
				assert(found.size() == 2, "Both real resources must be discoverable in " + biome_id)
				for record in found:
					_check_patch(world, record)
				examples[biome_id] = found[0]
		else:
			var found := _patches(world, world.start + Vector2i(40, 40), "", 2)
			assert(found.size() == 2, "Legacy worlds must generate real gatherable materials")
			for record in found:
				_check_patch(world, record)
		var city: Dictionary = world.region_at(world.start).city
		var grid := _grid(Vector2(city.cell))
		for x in range(grid.x - 2, grid.x + 3):
			for y in range(grid.y - 2, grid.y + 3):
				assert(catalog.plan(world, Vector2i(x, y)).is_empty(), "Town centers and their approach margin cannot contain forage")
	var hub := Hub.new()
	hub.generate(91, 6)
	var hub_grid := _grid(hub.spawn_point())
	for x in range(hub_grid.x - 3, hub_grid.x + 4):
		for y in range(hub_grid.y - 3, hub_grid.y + 4):
			assert(catalog.plan(hub, Vector2i(x, y)).is_empty(), "Lanternwake must not supply farmable wild patches")
	var realm := Finite.new()
	realm.generate(91, 6)
	assert(catalog.scope(realm) == "realm:%s:%s" % [realm.dimension_id, realm.map_version])
	var finite := _patches(realm, realm.start + Vector2i(20, 20), "", 2)
	assert(finite.size() == 2, "The authored finite world must support real wilderness gathering")
	for record in finite:
		_check_patch(realm, record)
		assert(record.id.begins_with(catalog.scope(realm) + "@"))
	finite_example = finite[0]
	assert(examples.size() == 14)
	print("Foraging real-world allocation: 14 ecologies, both materials each, editions 4/5/6 and Morrowmere, %s ms" % (Time.get_ticks_msec() - started))

func _grid(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / catalog.DATA.spacing), floori(point.y / catalog.DATA.spacing))

func _patches(world, point: Vector2i, biome_id: String, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	var center := _grid(Vector2(point))
	for radius in range(19):
		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):
				if maxi(absi(x - center.x), absi(y - center.y)) != radius:
					continue
				var record: Dictionary = catalog.plan(world, Vector2i(x, y))
				if record.is_empty() or not biome_id.is_empty() and record.biome_id != biome_id or seen.has(record.item):
					continue
				seen[record.item] = true
				result.append(record)
				if result.size() == count:
					return result
	return result

func _check_patch(world, record: Dictionary) -> void:
	assert(record == catalog.plan(world, record.grid), "Patch allocation must be deterministic")
	assert(record.id == "%s@%s,%s" % [catalog.scope(world), record.grid.x, record.grid.y])
	var quantity: Array = catalog.DATA.items[record.item]["yield"]
	assert(_grid(record.point) == record.grid and record.quantity >= quantity[0] and record.quantity <= quantity[1])
	seed(971)
	var expected := randi()
	seed(971)
	catalog.plan(world, record.grid)
	assert(randi() == expected, "Patch allocation must not consume gameplay RNG")
	var info: Dictionary = world.cell_info(Vector2i(record.point.round()))
	assert(info.walkable and info.terrain == "land" and info.get("hub_id", "").is_empty())
	assert(world.city_at(record.point, 4).is_empty())
	assert(catalog.DATA.biomes[record.biome_id].entries.any(func(entry): return entry.item == record.item))
	for site in world.nearby_sites(record.point):
		if site.has("footprint"):
			assert(not site.footprint.grow(2).has_point(Vector2i(record.point.round())), "Patches cannot occupy protected site footprints")
	world.load_around(record.point)
	assert(world.walkable(record.point), "The actual loaded collision map must allow gathering")

func _new_game():
	var game = load("res://scripts/game.gd").new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func _reach(game, record: Dictionary) -> Dictionary:
	game._generate_surface(record.point, false)
	game._clear_actors()
	game.foraging.sync(true)
	assert(game.foraging.nodes.has(record.id) and game.foraging.models.has(record.id))
	assert(game.foraging.nodes.size() <= catalog.DATA.max_nodes)
	var model: Node3D = game.foraging.models[record.id]
	assert(not model.find_children("*", "MeshInstance3D", true, false).is_empty(), "Gathering records must have actual visible geometry")
	var rng_before: int = game.rng.state
	game.world.load_around(record.point + Vector2(16, 0))
	game.foraging.sync(true)
	assert(game.foraging.models[record.id] == model, "A retained patch must keep its model across overlapping chunk windows")
	game.world.load_around(record.point)
	game.foraging.sync(true)
	assert(game.foraging.models[record.id] == model and game.rng.state == rng_before)
	assert(game.foraging.target().get("id", "") == record.id)
	return game.foraging.target().duplicate(true)

func _check_game() -> void:
	var started := Time.get_ticks_msec()
	var game = _new_game()
	game.start_run(91, 6)
	var record: Dictionary = _reach(game, examples.greenwood)
	var initial: Dictionary = game.inventory.snapshot()
	var forged: Dictionary = record.duplicate(true)
	forged.quantity += 1
	assert(not game.foraging.harvest(forged) and game.inventory.snapshot() == initial and game.foraging.snapshot().is_empty(), "Harvest rewards must match the actual allocated patch")
	var bag: Dictionary = game.inventory.snapshot()
	bag.items = {"sanctum_sigil": 1, "health_potion": int(game.Inventory.ITEMS.health_potion.stack) * (game.Inventory.CAPACITY - 1)}
	bag.stolen = {}
	bag.equipment = {"weapon": "", "armor": "", "charm": ""}
	assert(game.inventory.restore(bag, game.build.class_id) and game.inventory.slots_used() == game.Inventory.CAPACITY)
	var full: Dictionary = game.inventory.snapshot()
	assert(not game.foraging.harvest(record) and game.inventory.snapshot() == full and game.foraging.snapshot().is_empty(), "A full backpack must leave the patch and depletion ledger unchanged")
	assert(game.foraging.nodes.has(record.id))
	assert(game.inventory.restore(initial, game.build.class_id))
	for state in ["paused", "inventory"]:
		game.state = state
		assert(not game.foraging.harvest(record))
	game.state = "playing"
	game.grounded = false
	assert(not game.foraging.harvest(record))
	game.grounded = true
	game.online.session = true
	assert(not game.foraging.harvest(record))
	game.online.session = false
	game.player_point = record.point + Vector2(3, 0)
	assert(not game.foraging.harvest(record))
	game.player_point = record.point
	assert(game.interaction_hint() == game.foraging.hint() and not game.foraging.hint().is_empty())
	var rng_state: int = game.rng.state
	game.interact()
	assert(game.inventory.count(record.item) == record.quantity and game.inventory.stolen_count(record.item) == 0)
	assert(game.foraging.harvested.has(record.id) and not game.foraging.nodes.has(record.id) and game.rng.state == rng_state)
	var earned: Dictionary = game.inventory.snapshot()
	assert(not game.foraging.harvest(record) and game.inventory.snapshot() == earned, "A collected patch cannot pay twice")
	var depletion: Dictionary = game.foraging.snapshot()
	assert(controller.valid(depletion, "91"))
	var invalid: Dictionary = depletion.duplicate(true)
	invalid[record.id] = false
	assert(not controller.valid(invalid) and not game.foraging.restore(invalid) and game.foraging.snapshot() == depletion)
	invalid[record.id] = 1
	assert(not controller.valid(invalid), "Depletion flags must be actual booleans")
	invalid[record.id] = false
	for id in ["endless:91:999@0,0", "endless:91:6@0.5,0", "realm:missing:1@0,0", "realm:morrowmere:999@0,0", "endless:91:6@-9223372036854775808,0", "endless:91:6@0,-9223372036854775808", "endless:91:6@-2000001,0", "endless:91:6@0,2000001", "endless:91:6@18446744073709551616,0"]:
		assert(not controller.valid({id: true}), "Malformed or unsupported depletion identity: " + id)
	assert(controller.valid({"endless:91:6@-2000000,2000000": true}, "91"), "Both coordinate boundaries remain valid")
	assert(not controller.valid({"endless:92:6@0,0": true}, "91"))
	var realm_definition: Dictionary = load("res://scripts/dimension_catalog.gd").definition()
	assert(controller.valid({"realm:%s:%s@0,0" % [realm_definition.id, int(realm_definition.map_version)]: true}, "91"))
	for revision in realm_definition.get("compatible_revisions", []):
		assert(controller.valid({"realm:%s:%s@0,0" % [realm_definition.id, int(revision)]: true}, "91"), "Declared compatible realm editions must preserve their depletion records")
	game._generate_surface(record.point + Vector2(90, 90), false)
	game._generate_surface(record.point, false)
	game._clear_actors()
	game.foraging.sync(true)
	assert(not game.foraging.nodes.has(record.id), "Streaming must not respawn a harvested patch")
	assert(game.use_sanctum_sigil() and game.foraging.target().is_empty() and game.foraging.snapshot() == depletion)
	assert(not game.foraging.harvest(record), "Sanctum interiors must not permit wilderness harvesting")
	assert(game.save_game(1))
	var home: Dictionary = game.saves.read(1).data
	assert(home.progress.foraging == depletion)
	var fresh = _new_game()
	assert(fresh.load_game(1) and fresh.layer == "sanctum" and fresh.foraging.snapshot() == depletion)
	assert(fresh.use_sanctum_sigil() and fresh.layer == "overworld" and fresh.player_point.is_equal_approx(record.point))
	fresh._clear_actors()
	fresh.foraging.sync(true)
	assert(not fresh.foraging.nodes.has(record.id) and fresh.inventory.count(record.item) == record.quantity)
	await _sell(fresh, record)
	_check_finite_harvest(fresh, record.id)
	var saved: Dictionary = fresh.make_save_data()
	var bad: Dictionary = saved.duplicate(true)
	bad.progress.foraging = invalid
	assert(not fresh.saves.validate(bad), "Save validation must reject invalid depletion records")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.progress.erase("foraging")
	assert(fresh.saves.validate(legacy) and fresh.Journey.restore(fresh, legacy) and fresh.foraging.snapshot().is_empty(), "Legacy saves must restore an empty depletion ledger")
	fresh.start_run(92, 6)
	assert(fresh.foraging.snapshot().is_empty(), "New Game must reset prior gathering depletion")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	print("Foraging actual Game, rollback, trading and disk/home persistence: %s ms" % (Time.get_ticks_msec() - started))

func _check_finite_harvest(game, outside_id: String) -> void:
	assert(game.use_sanctum_sigil())
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	game.interact()
	assert(game.floating_hub.active())
	game.foraging.sync(true)
	assert(game.foraging.nodes.is_empty())
	game.player_point = game.floating_hub.portal_point("dimension")
	game._snap_camera()
	game.interact()
	assert(game.dimension.active)
	var record: Dictionary = _reach(game, finite_example)
	var quantity: int = game.inventory.count(record.item)
	game.interact()
	assert(game.inventory.count(record.item) == quantity + record.quantity)
	assert(game.foraging.harvested.has(record.id) and game.foraging.harvested.has(outside_id))
	var combined: Dictionary = game.foraging.snapshot()
	assert(game.use_sanctum_sigil() and game.floating_hub.active() and game.foraging.snapshot() == combined)
	assert(game.dimension.enter())
	game.foraging.sync(true)
	assert(not game.foraging.nodes.has(record.id), "Returning to a finite realm must retain its separate depletion scope")
	game._clear_actors()
	assert(game.use_sanctum_sigil() and game.floating_hub.active())
	assert(game.use_sanctum_sigil() and game.layer == "sanctum")
	assert(game.leave_sanctum() and game.layer == "overworld" and game.foraging.snapshot() == combined, "Realm gathering must survive the complete hub and home return thread")

func _sell(game, record: Dictionary) -> void:
	var city: Dictionary = game.world.region_at(game.world.start).city
	var shop := {}
	for house in city.houses:
		if house.use_id == "general_store":
			shop = game.interiors.describe(city, house)
			break
	assert(not shop.is_empty())
	game._generate_surface(shop.approach, false)
	game._clear_actors()
	assert(game.interaction_hint().begins_with("E: Enter"))
	game.interact()
	assert(game.layer == "interior" and game.interiors.current.id == shop.id and game.foraging.target().is_empty())
	var counter: Dictionary = game.stores.sources()[0]
	game.player_point = counter.point
	assert(game.interaction_hint().contains("Trade"))
	game.interact()
	assert(game.state == "store")
	assert(game.stores.offers(counter).keys().all(func(item): return not catalog.DATA.items.has(item)), "Wild gathered materials must not appear in a trader's initial stock")
	var coins: int = game.inventory.count("gold_coin")
	var quantity: int = game.inventory.count(record.item)
	var price: int = maxi(1, floori(game.stores.catalog.price(record.item) * game.stores.catalog.data.buyback_fraction))
	var purse: int = game.stores.records[counter.id].purse
	game.stores.records[counter.id].purse = 0
	var before: Dictionary = game.inventory.snapshot()
	assert(not game.stores.sell(record.item) and game.inventory.snapshot() == before, "A trader without money must not consume gathered resources")
	game.stores.records[counter.id].purse = purse
	assert(game.stores.sell(record.item) and game.inventory.count(record.item) == quantity - 1 and game.inventory.count("gold_coin") == coins + price)
	assert(game.stores.records[counter.id].purse == purse - price and game.inventory.stolen_count("gold_coin") == 0)
	game.stores.close()
	assert(game.interiors.leave())
	await process_frame
