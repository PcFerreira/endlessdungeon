extends SceneTree

const World = preload("res://scripts/world.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const Catalog = preload("res://scripts/discovery_catalog.gd")
const Exploration = preload("res://scripts/exploration.gd")
const Game = preload("res://scripts/game.gd")
var directory := "user://test-exploration-%s" % Time.get_ticks_usec()

func _init() -> void:
	call_deferred("run_checks")

func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file in DirAccess.get_files_at("res://lore/content/discoveries"):
		if file.ends_with(".json"):
			result.append(JSON.parse_string(FileAccess.get_file_as_string("res://lore/content/discoveries/" + file)))
	return result

func run_checks() -> void:
	var catalog := Catalog.new(definitions())
	assert(catalog.errors.is_empty(), str(catalog.errors))
	assert(catalog.entries.size() >= 4)
	var families := {}
	var landmarks := 0
	var quiet := 0
	for seed_value in [91, 2048, 7763]:
		var world := World.new()
		world.generate(seed_value)
		for coordinate in [Vector2i.ZERO, Vector2i(-1,0), Vector2i(0,-1), Vector2i(2,2), Vector2i(-3,-2), Vector2i(20,-17)]:
			var region: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
			var first: Dictionary = Sites.plan(world, region, catalog)
			var again: Dictionary = Sites.plan(world, region, catalog)
			assert(first == again, "Discovery plans must not depend on call order")
			if first.is_empty():
				quiet += 1
				continue
			landmarks += 1
			families[first.family] = true
			assert(not first.text.contains("{") and not first.author.contains("{"))
			assert(first.city_id == region.city.id and first.city_name == region.city.name)
			assert(first.run_seed == str(seed_value))
			var linked := false
			for site in region.dungeons:
				linked = linked or (first.site_id == site.id and first.site_name == site.name)
			assert(linked, "A clue must point to a real owning-region ruin")
			var point := Vector2(first.point[0], first.point[1])
			var approach := Vector2(first.approach[0], first.approach[1])
			assert(world.cell_info(Vector2i(point)).walkable)
			assert(world.cell_info(Vector2i(approach)).walkable)
			assert(world.cell_info(Vector2i(approach)).terrain in ["road", "paving", "bridge"])
			assert(world.cell_info(Vector2i(point)).terrain not in ["road", "paving", "bridge", "water"])
			assert(approach.distance_to(point) < 2)
			assert(reachable(world, region, Vector2i(approach)), "Physical walking must reach the approach from its sanctuary")
			assert(Exploration.valid_snapshot({"version": 1, "entries": {first.id: first}}, str(seed_value)))
	assert(landmarks > 0 and quiet > 0 and families.size() > 1)
	var state := Exploration.new()
	var world := World.new()
	world.generate(91)
	var entry := Sites.plan(world, world.region_at(world.start), catalog)
	assert(not entry.is_empty(), "The starter region must teach discovery")
	assert(state.remember(entry))
	assert(not state.remember(entry), "Repeated visits must not duplicate a discovery")
	var saved: Dictionary = state.snapshot()
	var fresh := Exploration.new()
	assert(fresh.restore(saved, "91"))
	assert(fresh.snapshot() == saved)
	assert(not fresh.restore(saved, "92"), "Discovery records cannot cross journey seeds")
	assert(fresh.snapshot() == saved, "An invalid restore must preserve the previous collection")
	var corrupt := saved.duplicate(true)
	corrupt.entries[entry.id].text = "Unresolved {missing_place}"
	assert(not Exploration.valid_snapshot(corrupt, "91"))
	assert(Exploration.valid_snapshot({}, "91"), "Existing saves need an empty optional collection")
	state.free()
	fresh.free()
	await check_game()
	print("PASS: discovery definitions, deterministic/quiet regions, real bound clues, walkable roadside anchors, persistent deduplicated collections")
	quit()

func reachable(world, region: Dictionary, destination: Vector2i) -> bool:
	world.load_around(Vector2(region.city.cell))
	var origin: Vector2i = region.city.cell + Vector2i(0,3)
	var seen := {origin: true}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		if cell == destination:
			return true
		for direction in World.DIRECTIONS:
			var next: Vector2i = cell + direction
			if seen.has(next) or not world.tiles.has(next) or not world.can_step(Vector2(cell), Vector2(next)):
				continue
			if world.move_actor(Vector2(cell), Vector2(direction)).is_equal_approx(Vector2(next)):
				seen[next] = true
				queue.append(next)
	return false

func new_game():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func check_game() -> void:
	var game = new_game()
	game.start_run(91)
	game._clear_actors()
	game.exploration.sync()
	var region: Dictionary = game.world.region_at(game.world.start)
	var entry: Dictionary = Sites.plan(game.world, region, game.exploration.catalog)
	assert(not entry.is_empty())
	var approach := Vector2(entry.approach[0], entry.approach[1])
	game._generate_surface(approach, false)
	game._clear_actors()
	game.player_point = approach
	game.grounded = true
	game.exploration.sync()
	assert(game.exploration.view.markers.has(entry.id))
	assert(game.exploration.plans.size() <= 9 and game.exploration.view.markers.size() <= 9)
	assert(game.interaction_hint().begins_with("E: Read "))
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	var rng_before: int = game.rng.state
	var slots_before: int = game.inventory.slots_used()
	game._unhandled_key_input(event)
	assert(game.state == "discovery_reader", "Actual E must open the discovery reader")
	assert(game.exploration.entries.size() == 1)
	assert(game.rng.state == rng_before, "Discoveries must not consume combat randomness")
	assert(game.inventory.slots_used() == slots_before, "Collection records need no backpack slots")
	game.exploration.close()
	game._unhandled_key_input(event)
	assert(game.exploration.entries.size() == 1)
	game.exploration.mark_site(entry.id)
	assert(game.waypoint.id == entry.site_id)
	game.exploration.close()
	game.expansion.toggle_journal()
	assert(game.state == "journal")
	game.exploration.read_saved(entry.id)
	assert(game.state == "discovery_reader")
	game.exploration.close()
	assert(game.state == "journal")
	game.expansion.close_lore()
	var snapshot: Dictionary = game.make_save_data()
	assert(game.saves.validate(snapshot))
	assert(game.save_game(1))
	var fresh = new_game()
	assert(fresh.load_game(1))
	assert(fresh.exploration.snapshot() == game.exploration.snapshot(), "Discovery text and place bindings must survive disk JSON")
	var legacy := snapshot.duplicate(true)
	legacy.progress.erase("exploration")
	assert(Game.Journey.restore(fresh, legacy))
	assert(fresh.exploration.entries.is_empty(), "Older current-generation saves get an empty collection")
	assert(Game.Journey.restore(fresh, snapshot))
	fresh._clear_actors()
	assert(fresh.use_sanctum_sigil())
	assert(fresh.leave_sanctum())
	assert(fresh.exploration.snapshot() == snapshot.progress.exploration)
	fresh.player_point = Vector2(region.city.cell)
	fresh.hp = 1
	fresh.interact()
	assert(fresh.hp == fresh.max_hp, "Fountain interaction retains priority")
	fresh._generate_surface(approach, false)
	fresh._clear_actors()
	fresh.player_point = approach
	fresh.grounded = false
	fresh.interact()
	assert(fresh.state == "playing", "Airborne reading must be blocked")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
