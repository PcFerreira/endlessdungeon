extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-character-inventory-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	assert(game.has_method("use_item"), "The backpack must provide usable items")
	var bag = game.inventory
	assert(bag.count("sanctum_sigil") == 1 and not bag.remove("sanctum_sigil", 1))
	assert(not bag.add("unknown", 1) and not bag.add("health_potion", -1))
	assert(bag.add("ember_shard", 99))
	var before: Dictionary = bag.snapshot()
	assert(not bag.add("oak_chair", 220) and bag.snapshot() == before, "A full-bag failure must be atomic")
	assert(bag.add("traveler_coat", 1) and game.equip_item("traveler_coat"))
	assert(game.max_hp == 120 and not bag.remove("traveler_coat", 1))
	game.hp = 30
	var potions: int = bag.count("health_potion")
	assert(game.use_item("health_potion") and bag.count("health_potion") == potions - 1 and game.hp == 65)
	game.hp = game.max_hp
	assert(not game.use_item("health_potion") and bag.count("health_potion") == potions - 1, "Full vitality must not waste a potion")
	assert(bag.add("iron_sword", 1) and not game.equip_item("iron_sword"), "Mage cannot equip a sword")
	var style := {"name": "Mira", "ancestry": "elf", "skin": 3, "hair": 2, "outfit": 4, "head": "long", "costume": "class_default", "model": "custom"}
	assert(game.customize_character(style))
	assert(not game.customize_character({"name": "bad\nname"}))
	game._drop(game.player_point, "oak_chair")
	game._update_pickups(.01)
	assert(bag.count("oak_chair") == 1)
	assert(game.use_sanctum_sigil())
	assert(game.inventory.add("rune_lantern", 2))
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.load_game(1) and game.layer == "sanctum")
	assert(game.profile.snapshot() == style and game.inventory.count("rune_lantern") == 2)
	assert(game.use_sanctum_sigil() and game.profile.display_name == "Mira" and game.inventory.count("rune_lantern") == 2)
	assert(game.inventory.equipment.armor == "traveler_coat" and game.max_hp == 120)
	var data: Dictionary = game.make_save_data()
	data.inventory.equipment.weapon = "iron_sword"
	assert(not game.saves.validate(data), "Invalid class equipment must be rejected before loading")
	data = game.make_save_data()
	data.erase("inventory")
	data.erase("character")
	assert(game.saves.write(2, data) and game.load_game(2))
	assert(game.profile.display_name == "Wanderer" and game.inventory.count("sanctum_sigil") == 1 and game.max_hp == 100)
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.dungeon_progress[site.id] = site.floors
	game.enter_dungeon(site)
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000)
	game.player_point = Vector2(game.dungeon.exit) + Vector2.DOWN
	game.interact()
	assert(game.pickups.filter(func(pickup): return pickup.kind == "arcane_staff").size() == 1, "Final chests must provide exactly one class weapon")
	print("PASS: atomic stack capacity, bound sigil, equipment/class limits and stats, potion consumption, appearance validation, item collection, fresh-scene saves, sanctum inventory carry, legacy defaults, obtainable chest weapons")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	await create_timer(.15).timeout
	quit()
