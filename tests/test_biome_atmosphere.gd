extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not FileAccess.file_exists("res://scripts/biome_atmosphere.gd"):
		check(false, "Named biome atmosphere must resolve all ecology profiles")
		quit(1)
		return
	var Atmosphere = load("res://scripts/biome_atmosphere.gd")
	var Ambience = load("res://scripts/world_ambience.gd")
	var Biomes = load("res://scripts/biome_catalog.gd")
	var registry = load("res://scripts/asset_registry.gd").new()
	var source_pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_construction/catalog.json")).roles
	check(Atmosphere.valid(Atmosphere.DATA), "Atmosphere catalogue must validate")
	var appearances := {}
	for id in Biomes.DATA.profiles:
		var profile: Dictionary = Atmosphere.sample([{"id": id, "weight": 1.0}])
		check(profile.id == id and profile.wisps <= Ambience.WISP_CAP, "Every named ecology has bounded atmosphere: " + id)
		check(profile.ambient_energy >= .72 and profile.ambient_energy <= 1.08 and profile.sun_energy >= .72 and profile.sun_energy <= 1.08, "Biome lighting must preserve ground readability: " + id)
		for source in source_pools[profile.bed_pool]:
			check(registry.resource(source) is AudioStream, "Named bed must resolve an actual licensed audio resource: " + source)
		if profile.cue.begins_with("pool:"):
			for source in source_pools[profile.cue.trim_prefix("pool:")]:
				check(registry.resource(source) is AudioStream, "Named cue must resolve an actual licensed audio resource: " + source)
		appearances[profile.ambient.to_html()] = true
		var actual: Dictionary = Ambience.profile_for("overworld", 0, false, false, [{"id": id, "weight": 1.0}])
		check(actual.atmosphere.id == id and actual.bed_pool == profile.bed_pool, "Runtime dispatch must use named ecology: " + id)
	check(appearances.size() == Biomes.DATA.profiles.size(), "All fourteen ecologies need distinct authored atmosphere")
	var first: Dictionary = Atmosphere.sample([{"id": "haunted_hollows", "weight": 1.0}])
	var last: Dictionary = Atmosphere.sample([{"id": "meadows", "weight": 1.0}])
	for step in range(17):
		var weight := step / 16.0
		var mixture := [{"id": "haunted_hollows", "weight": 1.0 - weight}, {"id": "meadows", "weight": weight}]
		var profile: Dictionary = Atmosphere.sample(mixture)
		check(profile.ambient.is_equal_approx(first.ambient.lerp(last.ambient, weight)), "Ecotone tint must blend continuously")
		check(is_equal_approx(profile.sun_energy, lerpf(first.sun_energy, last.sun_energy, weight)), "Ecotone lighting must blend continuously")
		mixture.reverse()
		check(Atmosphere.sample(mixture) == profile, "Mixture order cannot change atmosphere")
	var invalid: Dictionary = Atmosphere.DATA.duplicate(true)
	invalid.profiles.marsh.wisps = 80
	check(not Atmosphere.valid(invalid), "Unbounded particles must be rejected")
	invalid = Atmosphere.DATA.duplicate(true)
	invalid.profiles.volcanic_wastes.ambient_energy = .1
	check(not Atmosphere.valid(invalid), "Unreadably dark biome lighting must be rejected")
	var mixture := [{"id": "haunted_hollows", "weight": 1.0}]
	check(Ambience.profile_for("overworld", 0, true, true, mixture).bed == "amb_fountain", "Town atmosphere overrides named wilderness and water")
	check(not Ambience.profile_for("overworld", 0, true, true, mixture).has("atmosphere"), "Town lighting remains authoritative")
	check(Ambience.profile_for("overworld", 0, false, true, mixture).bed == "amb_water", "Water bed overrides named wilderness")
	check(Ambience.profile_for("interior", 0, false, false, mixture).wisps == 0, "Room overrides cannot inherit named wilderness motes")
	check(not Ambience.named_surface(load("res://scripts/hub_world.gd").new()), "Authored floating hub keeps its own atmosphere")
	check(not Ambience.named_surface(load("res://scripts/finite_world.gd").new("morrowmere")), "Authored finite dimension keeps its own atmosphere")
	check(Ambience.named_surface(load("res://scripts/remote_world.gd").new()), "Remote authority ecology can supply named atmosphere")
	var Game = load("res://scripts/game.gd")
	var game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-biome-atmosphere-%s" % OS.get_process_id()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_run(91, 6)
	game.state = "playing"
	var points: Dictionary = load("res://tools/biome_review_points.gd").find(game.world)
	var rng_before: int = game.rng.state
	var seed_before: int = game.world.run_seed
	game.sound.muted = true
	game.sound.set_ambience_level(.35)
	for id in points:
		game.player_point = Vector2(points[id].cell)
		game.ambience.context_timer = 0
		game.ambience.update(game, .5)
		check(game.ambience.profile.has("atmosphere"), "Actual wilderness receives named atmosphere: " + id)
		check(game.ambience.profile.atmosphere == Atmosphere.sample(game.world.cell_info(points[id].cell).biome_mix), "Actual wilderness uses its authoritative mixture: " + id)
		check(game.ambience.wisps.size() <= Ambience.WISP_CAP, "Actual named mote count remains bounded")
	check(game.rng.state == rng_before and game.world.run_seed == seed_before, "Atmosphere cannot consume combat or generation randomness")
	check(game.sound.muted and is_equal_approx(game.sound.ambience_level, .35), "Atmosphere cannot overwrite mute or volume settings")
	var pause_color: Color = game.sky_environment.ambient_light_color
	game.state = "menu"
	game.ambience.update(game, 10)
	check(game.sky_environment.ambient_light_color == pause_color, "Paused ambience must leave lighting stable")
	game.state = "playing"
	var site: Dictionary = game.world.region_at(game.world.start).dungeons[0]
	game.enter_dungeon(site)
	game.ambience.update(game, .5)
	check(game.sky_environment.ambient_light_color == Color("8babc1") and is_equal_approx(game.sky_environment.ambient_light_energy, .70), "Dungeon layer keeps its own lighting after wilderness tint")
	check(game.sunlight.light_color == Color("ffe4c6"), "Wilderness sun tint must restore on layer exit")
	game.new_character()
	game.choose_class("mage")
	game.begin_journey()
	check(game.floating_hub.active() and game.world.generator_version == 7, "Actual fresh journey reaches its authored floating hub")
	game.ambience.update(game, .5)
	check(not game.ambience.profile.has("atmosphere"), "Authored hub island keeps its own atmosphere")
	game._clear_actors()
	var hub: Dictionary = game.floating_hub.city()
	game.player_point = hub.hub_portal
	game.grounded = true
	game.interact()
	check(not game.floating_hub.active() and game.world.get_script().resource_path == "res://scripts/hub_world.gd", "Physical Worldgate departure retains HubWorld outside the island")
	var exterior_points: Dictionary = load("res://tools/biome_review_points.gd").find(game.world)
	game.player_point = Vector2(exterior_points.haunted_hollows.cell)
	game.ambience.context_timer = 0
	game.ambience.update(game, .5)
	check(game.ambience.profile.has("atmosphere"), "Actual fresh journey gets named biome atmosphere beyond the hub island")
	var directory: String = game.save_directory
	game.queue_free()
	await process_frame
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)
	print("Biome atmosphere checks: ", failures.size(), " failures")
	if failures.is_empty():
		print("PASS: all fourteen named atmospheres, continuous ecotones, location overrides, bounded actual motes, independent RNG, pause and audio settings")
	quit(0 if failures.is_empty() else 1)
