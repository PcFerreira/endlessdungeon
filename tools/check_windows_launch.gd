extends SceneTree

var game
var directory := "user://windows-pack-smoke-%s" % Time.get_ticks_usec()

func modern_content() -> bool:
	for path in ["scripts/biome_catalog.gd", "scripts/biome_atmosphere.gd", "scripts/micro_biome_catalog.gd", "scripts/micro_biome_view.gd", "scripts/biome_landmark_catalog.gd", "scripts/biome_landmark_models.gd"]:
		if not ResourceLoader.exists("res://" + path):
			print("FAIL: Windows pack lacks current biome content: " + path)
			return false
	var biomes = load("res://scripts/biome_catalog.gd")
	var atmosphere = load("res://scripts/biome_atmosphere.gd")
	var micro = load("res://scripts/micro_biome_catalog.gd")
	var landmarks = load("res://scripts/biome_landmark_catalog.gd")
	assert(biomes.DATA.size_multiplier == 5 and biomes.DATA.profiles.size() == 14)
	assert(atmosphere.valid(atmosphere.DATA) and atmosphere.DATA.profiles.size() == 14)
	assert(micro.valid(micro.DATA) and micro.profiles.size() == 28)
	assert(landmarks.valid(landmarks.DATA) and landmarks.KINDS.size() == 8)
	var pockets = load("res://scripts/micro_biome_view.gd").new()
	var buildings = load("res://scripts/biome_landmark_models.gd").new()
	for family in ["block_voxel", "flat_lowpoly"]:
		for claimed in [false, true]:
			for id in micro.profiles:
				var body: Node3D = pockets.build(micro.by_id(id), family, claimed)
				assert(body != null)
				body.free()
			for kind in landmarks.KINDS:
				var profile: Dictionary = landmarks.by_id(kind)
				profile.biome_id = "greenwood"
				var body: Node3D = buildings.create(profile, family, claimed)
				assert(body != null and body.get_meta("kind") == kind)
				body.free()
	print("Packed current content: 14 fivefold biomes/atmospheres, 28 micro-biomes, 8 landmarks; both geometry families and claim states")
	return true

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(not DirAccess.dir_exists_absolute("res://scripts/../tools"), "Run against the isolated export")
	if not modern_content():
		quit(1)
		return
	game = load("res://scripts/game.gd").new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.state == "menu" and game.offline_actions_allowed())
	game.new_character()
	game.begin_journey()
	assert(game.state == "playing" and game.world.walkable(game.player_point) and game.world.generator_version == 7)
	assert(game.inventory.ITEMS.oak_chair.name == "Oak Chair")
	assert(game.save_game(1) and game.load_game(1))
	game.set_physics_process(false)
	assert(game.state == "playing" and game.world.walkable(game.player_point))
	game._generate_surface(game.floating_hub.city().hub_portal, false)
	game._clear_actors()
	assert(game.floating_hub.target().get("kind") == "depart" and not game.render_warmup.busy)
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	game._unhandled_key_input(event)
	assert(not game.floating_hub.active() and game.world.generator_version == 7 and game.world.walkable(game.player_point))
	assert(game.exploration.micro.eligible() and game.exploration.landmarks.eligible())
	assert(game.save_game(2) and game.load_game(2))
	game.set_physics_process(false)
	game.toggle_inventory()
	await process_frame
	assert(game.state == "inventory" and game.interface.overlay.visible)
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: isolated Windows embedded pack initializes current content, real Game/menu, fresh edition7 hub/physical Worldgate, inventory and disk save/load on the host engine")
	quit()
