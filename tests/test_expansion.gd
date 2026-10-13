extends SceneTree

const World = preload("res://scripts/world.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Lore = preload("res://scripts/lore_catalog.gd")
const Game = preload("res://scripts/game.gd")
const Store = preload("res://scripts/save_store.gd")
const Actors = preload("res://scripts/actor_models.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Profiles = preload("res://scripts/asset_profiles.gd")
var game
var directory := "user://test-expansion-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var cities := {}
	var families := {}
	var facets := {}
	for seed_value in range(32):
		var world := World.new()
		world.generate(seed_value)
		assert(world.region_at(world.start).city.archetype_id == "city_crossroads")
		for x in range(-3, 4):
			for y in range(-3, 4):
				var region: Dictionary = world.region_at(Vector2i(x, y) * World.REGION_SIZE)
				cities[region.city.archetype_id] = true
				assert(region.city.residents.size() == 2)
				assert(region.city.houses.size() >= 6)
				for resident in region.city.residents:
					assert(world.cell_info(Vector2i(resident.approach)).walkable)
				for book in region.city.books:
					assert(world.cell_info(Vector2i(book.approach)).walkable)
				assert(region.dungeons.size() == 2)
				for site in region.dungeons:
					families[site.family] = true
					assert(site.floors >= 1 and site.floors <= 20)
				facets[region.facet] = true
				var repeated := World.new()
				repeated.generate(seed_value)
				assert(region == repeated.region_at(Vector2i(x, y) * World.REGION_SIZE))
	assert(cities.size() == 6 and families.size() == 6)
	assert(facets.has("surface_mycelium_downs") and facets.has("surface_cinder_verge"))
	for family in Areas.DUNGEONS:
		for depth in [1, 3, 20]:
			var dungeon := Dungeon.new()
			dungeon.generate(834, depth, family)
			var seen := {dungeon.start: true}
			var queue := [dungeon.start]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for step in dungeon.DIRECTIONS:
					var next: Vector2i = cell + step
					if dungeon.tiles.has(next) and not seen.has(next):
						seen[next] = true
						queue.append(next)
			assert(seen.size() == dungeon.tiles.size() and seen.has(dungeon.exit))
			var reachable := {dungeon.start: true}
			queue = [dungeon.start]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for step in dungeon.DIRECTIONS:
					var next: Vector2i = cell + step
					if dungeon.walkable(Vector2(next)) and not reachable.has(next):
						reachable[next] = true
						queue.append(next)
			for cell in dungeon.tiles:
				assert(not dungeon.walkable(Vector2(cell)) or reachable.has(cell), "Dressing must not disconnect walking routes")
			for spawn in dungeon.spawns:
				assert(reachable.has(spawn.cell))
			assert(dungeon.family == family and dungeon.readables.size() >= 1)
			for book in dungeon.readables:
				assert(reachable.has(Vector2i(book.approach)) and Lore.BOOKS.has(book.book_id))
	var scenery := Scenery.new()
	for key in Profiles.MODELS:
		var model := scenery.profiled(key)
		var bounds := scenery.bounds(model)
		assert(bounds.size.y > 0 and absf(bounds.position.y) < .001)
		assert(is_equal_approx(maxf(bounds.size.x, bounds.size.z), Profiles.MODELS[key][1]))
		assert(scenery.valid_materials(model))
		model.free()
	var once := Lore.line("retired_delver", "topic_companions", {}, [], 0)
	assert(not once.id.is_empty())
	assert(Lore.line("retired_delver", "topic_companions", {}, [once.id], 0).id.is_empty())
	Lore.LINES.append({"id": "unsupported", "speaker": "test", "event": "greeting", "condition": "Unknown condition", "text": "Do not show"})
	assert(Lore.line("test", "greeting", {}, [], 0).id.is_empty())
	Lore.LINES.pop_back()
	var actor := Actors.create(0)
	root.add_child(actor)
	assert(Actors._bounds(actor.get_child(0), Transform3D.IDENTITY).size.y > 0)
	var animations := actor.find_children("*", "AnimationPlayer", true, false)
	assert(not animations.is_empty())
	for player in animations:
		assert(not Actors.animation_key(player, "Idle").is_empty())
	actor.queue_free()
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	var city: Dictionary = game.world.region_at(game.world.start).city
	var resident: Dictionary = city.residents[0]
	game.player_point = resident.approach
	game.interact()
	assert(game.state == "dialogue" and game.expansion.met_speakers.has(resident.id))
	assert(not game.expansion.dialogue_text.contains("{"))
	game.expansion.close_lore()
	for id in Lore.BOOKS:
		assert(game.expansion.read_book(id))
		assert(game.expansion.read_book(id))
		game.expansion.close_lore()
	assert(game.expansion.read_books.size() == 6)
	game.expansion.toggle_journal()
	assert(game.state == "journal")
	assert(game.expansion.read_book("book_waiting_cup"))
	game.expansion.close_lore()
	assert(game.state == "journal")
	game.expansion.close_lore()
	assert(game.save_game(1))
	var site: Dictionary = game.world.region_at(game.world.start).dungeons[1]
	game.enter_dungeon(site)
	game.player_point = game.dungeon.readables[0].approach
	game._snap_camera()
	assert(game.player_point.distance_to(game.dungeon.start) >= 1.7)
	game.interact()
	assert(game.state == "reader", "The book must be readable through E without returning upstairs")
	game.expansion.close_lore()
	game.return_to_surface()
	assert(game.expansion.ruin_returns[city.id] == site.id)
	game.player_point = resident.approach
	game.expansion.open_dialogue(resident)
	game.expansion.talk("greeting")
	assert(not game.expansion.dialogue_text.contains("{"))
	var other_greetings: Array = Lore.LINES.filter(func(entry): return entry.speaker == resident.role and entry.event == "greeting" and not entry.condition.contains("returned")).map(func(entry): return entry.id)
	var returned := Lore.line(resident.role, "greeting", {"met": true, "returned": true, "city_name": city.name, "dungeon_name": site.name}, other_greetings, 0)
	assert(not returned.id.is_empty() and returned.text.contains(site.name) and not returned.text.contains("{"))
	game.expansion.talk("farewell")
	var farewells: Array = Lore.LINES.filter(func(entry): return entry.speaker == resident.role and entry.event == "farewell" and entry.condition == "Any").map(func(entry): return entry.text)
	assert(game.expansion.dialogue_text in farewells)
	game.expansion.close_lore()
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.load_game(1) and game.expansion.read_books.size() == 6)
	assert(game.expansion.met_speakers.has(resident.id))
	assert(game.expansion.ruin_returns[city.id] == site.id)
	assert(game.use_sanctum_sigil())
	assert(game.save_game(2) and game.load_game(2))
	assert(game.leave_sanctum() and game.expansion.read_books.size() == 6)
	game.dungeon_progress[site.id] = site.floors
	game.enter_dungeon(site)
	for enemy in game.enemies.duplicate():
		game._hit_enemy(enemy, 100000)
	game.player_point = Vector2(game.dungeon.exit) + Vector2.DOWN
	game.interact()
	assert(game.pickups.filter(func(pickup): return pickup.kind == "arcane_staff").size() == 1)
	game.interact()
	assert(game.pickups.filter(func(pickup): return pickup.kind == "arcane_staff").size() == 1)
	game.return_to_surface()
	game._spawn_enemy(game.player_point + Vector2(0,2), 0)
	assert(not game.expansion.read_book("book_waiting_cup"))
	game.new_character()
	assert(game.expansion.read_books.is_empty() and game.expansion.met_speakers.is_empty())
	var store := Store.new()
	store.directory = directory + "-legacy"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store.directory))
	for slot in range(4):
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			FileAccess.open(store.slot_path(slot) + suffix, FileAccess.WRITE).store_string("Old world")
	for file in ["settings.cfg", "records.cfg"]:
		FileAccess.open(store.directory.path_join(file), FileAccess.WRITE).store_string("Keep")
	assert(store.reset_expansion())
	for slot in range(4):
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			assert(FileAccess.get_file_as_string(store.slot_path(slot) + suffix) == "Old world", "Edition initialization preserves existing journeys")
	for file in ["settings.cfg", "records.cfg"]:
		assert(FileAccess.get_file_as_string(store.directory.path_join(file)) == "Keep")
	game.begin_journey()
	assert(store.write(1, game.make_save_data()))
	assert(not store.reset_expansion() and FileAccess.file_exists(store.slot_path(1)))
	game.queue_free()
	await process_frame
	for path in [directory, directory + "-legacy"]:
		var folder := DirAccess.open(path)
		for file in folder.get_files():
			folder.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: six area families and cities; deterministic facets; connected dungeons; animated NPCs; dialogue/books/journal; persistence/home; combat gating; non-destructive edition initialization")
	quit()
