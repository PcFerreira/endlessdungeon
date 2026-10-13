extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-independent-game-%s" % OS.get_process_id()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	call_deferred("run_checks")

func run_checks() -> void:
	game.start_run(91, 5)
	assert(game.world.generator_version == 5 and game.world.GENERATOR_VERSION == 4)
	var town := {}
	var wild := {}
	var entry := {}
	for x in range(-2, 3):
		for y in range(-2, 3):
			var region: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE)
			if not region.city.is_empty() and region.coordinate != Vector2i.ZERO:
				town = region.city
			if region.city.is_empty():
				wild = region
				if not region.dungeons.is_empty():
					entry = region.dungeons[0]
	assert(not town.is_empty() and not wild.is_empty() and not entry.is_empty())
	game._generate_surface(Vector2(town.approach), false)
	assert(game.world.city_at(game.player_point).id == town.id and game.location_name() == town.name)
	assert(game.life.cities.has(town.id) and game.WorldLife.valid_snapshot(game.life.snapshot()), "Jittered resident/watch saves need their actual home context")
	assert(game.save_game(1))
	var town_life: Dictionary = game.life.snapshot()
	game.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.load_game(1) and game.world.generator_version == 5 and game.location_name() == town.name)
	assert(game.life.snapshot() == town_life, "A fresh scene restores real jittered residents/watch exactly")
	game.state = "playing"
	game._generate_surface(Vector2(entry.approach), false)
	assert(game.world.region_at(entry.cell).city.is_empty() and game.world.city_at(game.player_point).is_empty())
	assert(game.stores.sources().is_empty() and game.interiors.target().is_empty())
	assert(not game.location_name().is_empty())
	game._update_music(.5)
	game.ambience.update(game, .5)
	game._clear_actors()
	game.invulnerable = 0
	var hp: float = game.hp
	game._hurt_player(1)
	assert(game.hp == hp - 1, "Town-free ground must not invent sanctuary protection")
	game.player_point = Vector2(entry.cell)
	game.grounded = true
	game.interact()
	assert(game.layer == "dungeon" and game.active_dungeon.id == entry.id, "Actual E enters the independent dungeon")
	assert(game.location_name().count(entry.name) == 1, "A family-named site must not repeat its name in the HUD")
	assert(game.surface_return_point == Vector2(entry.approach), "Return uses the actual oriented approach")
	assert(game.save_game(2))
	assert(game.load_game(2) and game.world.generator_version == 5 and game.active_dungeon.id == entry.id)
	game.return_to_surface()
	assert(game.player_point.is_equal_approx(Vector2(entry.approach)))
	var city: Dictionary = game.world.nearest_site(game.player_point, "city")
	assert(game.expansion.ruin_returns.get(city.id) == entry.id)
	game._clear_actors()
	assert(game.use_sanctum_sigil() and game.save_game(3))
	var optional_life: Dictionary = game.make_save_data()
	optional_life.progress.erase("life")
	optional_life.home.return_journey.progress.erase("life")
	assert(game.saves.write(3, optional_life), "Life remains optional in supported envelopes")
	assert(game.load_game(3) and game.layer == "sanctum" and game.world.generator_version == 5)
	assert(game.saves.validate(game.make_save_data()), "Missing optional life initializes the real edition even inside home")
	assert(game.leave_sanctum() and game.world.generator_version == 5)
	assert(game.world.region_at(entry.cell).city.is_empty(), "Disk/home return cannot synthesize a missing town")
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: actual edition-5 Game, jittered resident/watch fresh disk restore, town-free view/audio/store/sanctuary, oriented E dungeon/return, actual town account and nested home save")
	quit()
