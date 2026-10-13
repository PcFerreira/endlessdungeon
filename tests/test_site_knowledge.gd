extends SceneTree

const Knowledge = preload("res://scripts/site_knowledge.gd")
const Game = preload("res://scripts/game.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const Map = preload("res://scripts/minimap.gd")
var directory := "user://test-site-knowledge-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.exploration.set_process(false)
	return game

func checks() -> void:
	var site := {"id": "temple:example", "name": "Old Temple", "type": "temple", "cell": Vector2i(-42, 70)}
	var ledger := Knowledge.new()
	assert(ledger.remember(site, "rumor", "91"))
	assert(ledger.state(site.id) == "rumor")
	assert(ledger.remember(site, "seen", "91"))
	assert(not ledger.remember(site, "rumor", "91"), "Reports must never downgrade an actual sighting")
	assert(ledger.remember(site, "visited", "91"))
	var saved: Dictionary = ledger.snapshot()
	var copy := Knowledge.new()
	assert(copy.restore(JSON.parse_string(JSON.stringify(saved)), "91"))
	assert(copy.snapshot() == saved, "Negative coordinates and knowledge stages must round-trip")
	assert(not copy.restore(saved, "92"))
	assert(copy.snapshot() == saved, "Invalid restores cannot replace known places")
	var corrupt := saved.duplicate(true)
	corrupt.sites[site.id].state = "all"
	assert(not Knowledge.valid_snapshot(corrupt, "91"))
	corrupt = saved.duplicate(true)
	corrupt.sites[site.id].cell[0] = INF
	assert(not Knowledge.valid_snapshot(corrupt, "91"))
	var game = fresh()
	game.start_run(91)
	game._clear_actors()
	var region: Dictionary = game.world.region_at(game.world.start)
	var unseen: Dictionary = region.dungeons[0]
	assert(game.waypoint.is_empty(), "Starting a journey must not select an undiscovered dungeon")
	assert(game.exploration.knowledge.state(region.city.id) == "visited")
	assert(game.exploration.knowledge.state(unseen.id).is_empty())
	var map := Map.new()
	map.game = game
	map.world_map_mode = true
	assert(not map.map_sites().any(func(entry): return entry.id == unseen.id), "Unknown sites cannot be drawn or selected through the map")
	map.map_bounds = Rect2i(Vector2i.ZERO, Vector2i.ONE * game.world.REGION_SIZE)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = map._map_point(Vector2(unseen.cell))
	game.state = "map"
	map._gui_input(click)
	assert(game.waypoint.is_empty() and game.state == "map", "Clicking an unknown marker location must not reveal it")
	game.state = "playing"
	var marker: Dictionary = Sites.plan(game.world, region, game.exploration.catalog)
	assert(not marker.is_empty())
	game._generate_surface(Vector2(marker.approach[0], marker.approach[1]), false)
	game._clear_actors()
	var rng_before: int = game.rng.state
	var slots_before: int = game.inventory.slots_used()
	assert(game.exploration.interact(), "An actual roadside clue must open its reader")
	assert(not game.exploration.knowledge.state(marker.site_id).is_empty(), "Reading real directions must report their actual target")
	game.exploration.close()
	game.exploration.mark_site(marker.id)
	assert(game.waypoint.id == marker.site_id)
	assert(map.map_sites().any(func(entry): return entry.id == marker.site_id))
	assert(game.rng.state == rng_before and game.inventory.slots_used() == slots_before)
	game._generate_surface(Vector2(unseen.cell) + Vector2(0, 2), false)
	game._clear_actors()
	game.exploration.observe_sites()
	assert(game.exploration.knowledge.state(unseen.id) == "seen", "A clear nearby loaded entrance must be seen before entry")
	game.enter_dungeon(unseen)
	assert(game.exploration.knowledge.state(unseen.id) == "visited")
	game._clear_actors()
	assert(game.save_game(1))
	var other = fresh()
	assert(other.load_game(1))
	assert(other.exploration.knowledge.snapshot() == game.exploration.knowledge.snapshot())
	assert(other.use_sanctum_sigil())
	assert(other.leave_sanctum())
	assert(other.exploration.knowledge.snapshot() == game.exploration.knowledge.snapshot())
	var legacy: Dictionary = game.make_save_data()
	legacy.progress.exploration.erase("knowledge")
	assert(Game.Journey.restore(other, legacy), "Older current-generation saves must recover actual recorded visits and clues")
	assert(other.exploration.knowledge.state(unseen.id) == "visited")
	assert(not other.exploration.knowledge.state(marker.site_id).is_empty())
	var before: Dictionary = other.exploration.knowledge.snapshot()
	corrupt = other.make_save_data()
	corrupt.progress.exploration.knowledge.seed = "92"
	assert(not Game.Journey.restore(other, corrupt))
	assert(other.exploration.knowledge.snapshot() == before)
	other.start_run(92)
	assert(other.exploration.knowledge.state(unseen.id).is_empty(), "Knowledge must reset with a new journey")
	map.free()
	game.queue_free()
	other.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: progressive actual-site reports/sightings/visits, hidden map targets, clue routes, isolated RNG/inventory, disk/home/legacy carry and invalid-save rejection")
	quit()
