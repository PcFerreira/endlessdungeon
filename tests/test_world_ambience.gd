extends SceneTree

const Ambience = preload("res://scripts/world_ambience.gd")
const Actors = preload("res://scripts/actor_models.gd")
const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-ambience-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	assert(Ambience.Catalog.valid(Ambience.catalog))
	assert(Ambience.weather_for(12345, "region:test", 0) == Ambience.weather_for(12345, "region:test", 0))
	assert(Ambience.weather_for(12345, "region:test", 3) == "clear", "Rain must follow the allowed climate")
	var invalid := Ambience.catalog.duplicate(true)
	invalid.surface[0].wisps = 500
	assert(not Ambience.Catalog.valid(invalid), "Unbounded visual recipes must be rejected")
	invalid = Ambience.catalog.duplicate(true)
	invalid.npc_roles.relic_mender = "missing_recipe"
	assert(not Ambience.Catalog.valid(invalid), "Dangling role recipes must be rejected")
	for role in Ambience.catalog.npc_roles:
		assert(Actors.Generator.catalog.data.roles.has(role), "Every ambient NPC role needs a generated outfit recipe")
	for record in Ambience.catalog.surface + Ambience.catalog.locations.values():
		assert(record.wisps >= 0 and record.wisps <= Ambience.WISP_CAP)
		assert(Color.html_is_valid(record.color))
		assert(record.bed == "aether" or Actors.registry.resource(record.bed) is AudioStream)
		assert(record.cue == "wonder" or Actors.registry.resource(record.cue) is AudioStream)
	var beds := {}
	for biome in range(4):
		var profile := Ambience.profile_for("overworld", biome, false, false)
		beds[profile.bed] = true
		assert(profile.wisps <= Ambience.WISP_CAP)
	assert(beds.size() == 4, "Biomes need distinct ambient beds")
	assert(Ambience.profile_for("overworld", 0, true, false).bed == "amb_fountain")
	assert(Ambience.profile_for("overworld", 0, false, true).bed == "amb_water")
	assert(Ambience.profile_for("dungeon", 0, false, false).bed == "amb_dungeon")
	assert(Ambience.profile_for("interior", 0, false, false).wisps == 0)
	var variants := {}
	for index in range(12):
		var context := {"id": "resident:%s" % index, "role": ["fountain_keeper", "milewarden", "relic_mender", "retired_delver"][index % 4]}
		var style := Actors.style_for(index, context)
		assert(style == Actors.style_for(index, context), "NPC looks must be stable")
		variants[str(style)] = true
		var actor := Actors.create(index, context)
		assert(actor.get_meta("style") == style)
		assert(actor.find_children("*", "CollisionObject3D", true, false).is_empty(), "Cosmetic accents must not block paths")
		var box := Actors._bounds(actor, Transform3D.IDENTITY)
		assert(box.position.y >= -.04 and box.size.y < 1.7)
		actor.free()
	assert(variants.size() >= 8)
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.has_journey = true
	game.state = "playing"
	var combat_rng: int = game.rng.state
	game.ambience.update(game, .25)
	assert(game.ambience.wisps.size() <= Ambience.WISP_CAP)
	assert(game.ambience.active)
	var clock: float = game.ambience.clock
	game.state = "menu"
	game.ambience.update(game, .25)
	assert(not game.ambience.active and game.ambience.clock == clock)
	game.state = "playing"
	game.ambience.update(game, .25)
	assert(game.rng.state == combat_rng, "Cosmetics must not consume combat randomness")
	game.sound.set_ambience_level(.35)
	assert(is_equal_approx(game.sound.ambience_level, .35))
	game.settings_path = directory + "/settings.cfg"
	game.records_enabled = true
	game._save_settings()
	game.sound.set_ambience_level(.05)
	game._load_settings()
	assert(is_equal_approx(game.sound.ambience_level, .35), "Ambient volume must persist in isolated settings")
	game.records_enabled = false
	game.layer = "interior"
	game.ambience.update(game, .25)
	assert(not game.ambience.wisp_root.visible)
	game.layer = "overworld"
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	if folder != null:
		for file in folder.get_files():
			folder.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: distinct biome/room soundscapes, bounded noncolliding wisps, stable varied NPC accents, pause behavior, independent RNG and ambience volume")
	quit()
