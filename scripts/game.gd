extends Node3D

const Dungeon = preload("res://scripts/dungeon.gd")
const DungeonView = preload("res://scripts/dungeon_view.gd")
const World = preload("res://scripts/world.gd")
const SurfaceLocations = preload("res://scripts/surface_locations.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const Interface = preload("res://scripts/interface.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const WorldAmbience = preload("res://scripts/world_ambience.gd")
const CharacterBuild = preload("res://scripts/character_build.gd")
const ABILITIES = CharacterBuild.ABILITIES
const SaveStore = preload("res://scripts/save_store.gd")
const Journey = preload("res://scripts/journey.gd")
const Sanctum = preload("res://scripts/sanctum.gd")
const SanctumView = preload("res://scripts/sanctum_view.gd")
const Furnishings = preload("res://scripts/furnishings.gd")
const FurnishingEditor = preload("res://scripts/furnishing_editor.gd")
const WorldItems = preload("res://scripts/world_items.gd")
var world_items := WorldItems.new()
const CharacterProfile = preload("res://scripts/character_profile.gd")
const Inventory = preload("res://scripts/inventory.gd")
const CharacterVisual = preload("res://scripts/character_visual.gd")
const Expansion = preload("res://scripts/expansion.gd")
const Exploration = preload("res://scripts/exploration.gd")
var exploration := Exploration.new()
const Areas = preload("res://scripts/area_catalog.gd")
const EnemyCatalog = preload("res://scripts/enemy_catalog.gd")
const EnemyModels = preload("res://scripts/enemy_models.gd")
const Interiors = preload("res://scripts/interiors.gd")
const InteriorArea = preload("res://scripts/interior_area.gd")
var interiors := Interiors.new()
const Stores = preload("res://scripts/stores.gd")
var stores := Stores.new()
const WorldLife = preload("res://scripts/world_life.gd")
const WorldLifeView = preload("res://scripts/world_life_view.gd")
const OnlineClient = preload("res://scripts/online_client.gd")
const FloatingHub = preload("res://scripts/floating_hub.gd")
var floating_hub := FloatingHub.new()
var online := OnlineClient.new()
var offline_generation_calls := 0
var life := WorldLife.new()
var life_view := WorldLifeView.new()
const CityLaw = preload("res://scripts/city_law.gd")
var city_law := CityLaw.new()
var expansion := Expansion.new()
const THEMES := ["The Ashen Crypt", "The Violet Sanctum", "The Verdant Tomb"]
const COLORS := {"bolt": Color("82eadd"), "fire": Color("ffa16b"), "nova": Color("8ecffa"), "blink": Color("bc9af4"), "hostile": Color("e187ad")}
var build := CharacterBuild.new()
var profile := CharacterProfile.new()
var inventory := Inventory.new()
var inventory_return_state := "playing"
var character_return_state := "title"
var ACTION_BAR: Array[String] = []
var claimed_chests: Dictionary = {}
var player_y := 0.0
var vertical_velocity := 0.0
var grounded := true
var guard_time := 0.0
var grimoire_return_state := "playing"
var ENEMY_NAMES: Array = EnemyCatalog.names()
const TARGET_RANGE := 7.5
var dungeon = Dungeon.new()
var dungeon_view = DungeonView.new()
var world = World.new()
var world_view = WorldView.new()
var layer := "overworld"
var active_dungeon: Dictionary = {}
var surface_return_point := Vector2.ZERO
var sanctuary := Vector2.ZERO
var encounter_states: Dictionary = {}
var dungeon_progress: Dictionary = {}
var visited_cities: Dictionary = {}
var waypoint: Dictionary = {}
var sky_environment: Environment
var sunlight: DirectionalLight3D
var interface = Interface.new()
var sound = Soundscape.new()
var ambience := WorldAmbience.new()
var camera := Camera3D.new()
var player := Node3D.new()
var player_mesh: Node3D
var player_light := OmniLight3D.new()
var target_marker := Node3D.new()
var selected_target: Dictionary = {}
var actors := Node3D.new()
var particles := Node3D.new()
var astar := AStar2D.new()
var navigation_ids: Dictionary = {}
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var player_point := Vector2.ZERO
var aim := Vector2.RIGHT
var move_heading := Vector2.RIGHT
var state := "title"
var credits_return_state := "title"
var music_timer := 0.0
var depth := 1
var run_seed := 0
var hp := 100.0
var max_hp := 100.0
var mana := 100.0
var max_mana := 100.0
var mana_regen := 9.0
var damage_multiplier := 1.0
var invulnerable := 0.0
var kills := 0
var best_depth := 1
var records_enabled := true
var elapsed := 0.0
var notification := ""
var notification_time := 0.0
var time := 0.0
var shake := 0.0
var rng := RandomNumberGenerator.new()
var saves := SaveStore.new()
var save_directory := "user://saves"
var settings_path := "user://settings.cfg"
var has_journey := false
var autosave_timer := 0.0
var dungeon_discovery: Dictionary = {}
var view_key := ""
var menu_notice := ""
var browser_return_state := "menu"
var options_return_state := "menu"
var windowed_resolution := Vector2i(1280,800)
var fullscreen_requested := false
const RESOLUTIONS := [Vector2i(1024,640), Vector2i(1024,768), Vector2i(1152,720), Vector2i(1280,720), Vector2i(1280,800), Vector2i(1366,768), Vector2i(1440,900), Vector2i(1600,900), Vector2i(1680,1050), Vector2i(1920,1080), Vector2i(1920,1200), Vector2i(2560,1440), Vector2i(2560,1600), Vector2i(3440,1440), Vector2i(3840,2160)]
var pending_exit := "quit"
var camera_yaw := PI / 4
var target_yaw := PI / 4
var camera_focus := Vector3.ZERO
var surface_zoom := 19.0
var dungeon_zoom := 15.0
var rotating_camera := false
var camera_sensitivity := .01
var sanctum_view := SanctumView.new()
var sanctum_return: Dictionary = {}
var furnishings := Furnishings.new()
var furnishing_editor := FurnishingEditor.new()
var world_ground: MeshInstance3D

func _ready() -> void:
	if OS.has_feature("web"):
		world = online.RemoteWorld.new()
		world.generate(0)
		dungeon = world
	saves.directory = save_directory
	saves.reset_expansion()
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(quit_game)
	build.reset("mage")
	ACTION_BAR = build.action_bar
	for spell in ABILITIES:
		cooldowns[spell] = 0.0
	_setup_inputs()
	_setup_world()
	add_child(dungeon_view)
	add_child(world_view)
	world_view.living_residents = true
	add_child(life_view)
	city_law.game = self
	add_child(city_law)
	add_child(sanctum_view)
	sanctum_view.visible = false
	interiors.game = self
	add_child(interiors.view)
	interiors.view.visible = false
	add_child(actors)
	add_child(particles)
	player_mesh = CharacterVisual.new()
	player.add_child(player_mesh)
	_update_character_mesh()
	player_light.position = Vector3(0, 1.8, 0)
	player_light.light_color = Color("84d9d5")
	player_light.light_energy = 1.0
	player_light.omni_range = 4.0
	player.add_child(player_light)
	add_child(player)
	add_child(sound)
	add_child(ambience)
	sound.spell_played.connect(func(spell):
		if spell in ["bolt", "fire", "nova", "blink", "gate"]:
			ambience.react(sound))
	_load_settings()
	interface.game = self
	add_child(interface)
	expansion.game = self
	add_child(expansion)
	stores.game = self
	add_child(stores)
	exploration.game = self
	add_child(exploration)
	furnishing_editor.game = self
	add_child(furnishing_editor)
	world_items.game = self
	add_child(world_items)
	online.game = self
	add_child(online)
	floating_hub.game = self
	add_child(floating_hub)
	var record := ConfigFile.new()
	if records_enabled and record.load("user://records.cfg") == OK:
		best_depth = record.get_value("run", "best_depth", 1)
	var seed_value := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed_value = argument.trim_prefix("--seed=").to_int()
	if not OS.has_feature("web"):
		start_run(seed_value)
	has_journey = false
	state = "menu"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--class="):
			state = "title"
			choose_class(argument.trim_prefix("--class="))
	if "--play" in OS.get_cmdline_user_args() and not OS.has_feature("web"):
		begin_journey()
	if OS.has_feature("web"):
		online.open_lobby()
		print("ONLINE_WEB_READY offline_generation_calls=%s chunks=%s" % [offline_generation_calls, world.chunks.size()])
	_update_music(0)

func _process(delta: float) -> void:
	ambience.update(self, delta)
	life_view.process_mode = Node.PROCESS_MODE_INHERIT if state == "playing" and layer == "overworld" and not online.session else Node.PROCESS_MODE_DISABLED
	music_timer += delta
	if music_timer >= .25:
		_update_music(music_timer)
		music_timer = 0

func _update_music(delta: float) -> void:
	var menu_state := credits_return_state if state == "credits" else state
	if menu_state == "options":
		menu_state = options_return_state
	if menu_state == "menu" or menu_state == "title" or not has_journey:
		menu_state = "title"
	if layer == "dungeon":
		sound.update_context(menu_state, layer, Areas.DUNGEONS[dungeon.family].palette, false, delta)
		return
	if layer == "sanctum":
		sound.update_context(menu_state, layer, 0, false, delta, false, "%s:sanctum" % run_seed)
		return
	if floating_hub.active():
		sound.update_context(menu_state, "sanctum", 0, false, delta, false, "%s:lanternwake" % run_seed)
		return
	if layer == "interior":
		sound.update_context(menu_state, "overworld", 0, true, delta)
		return
	var cell := Vector2i(player_point.round())
	var info: Dictionary = world.cell_info(cell)
	var region: Dictionary = world.region_at(cell)
	var city: Dictionary = world.city_at(player_point)
	var in_city := not city.is_empty()
	var coast := false
	if not in_city:
		for direction in World.DIRECTIONS:
			if world.cell_info(cell + direction * 2).terrain == "water":
				coast = true
	var identity: String = region.city.get("id", "region:%s:%s:%s" % [world.generator_version, region.coordinate.x, region.coordinate.y])
	sound.update_context(menu_state, layer, info.biome, in_city, delta, coast, "%s:%s" % [run_seed,identity], city.archetype_id if in_city else "")

func show_credits() -> void:
	credits_return_state = state
	state = "credits"

func close_credits() -> void:
	state = credits_return_state

func begin_journey() -> void:
	if not offline_actions_allowed():
		return
	if not has_journey:
		floating_hub.start()
	has_journey = true
	state = "playing"
	_auto_save()

func continue_journey() -> void:
	if not offline_actions_allowed():
		return
	if has_journey:
		state = "dead" if hp <= 0 else "playing"
	else:
		var slot := saves.latest_slot()
		if slot >= 0:
			load_game(slot)

func make_save_data() -> Dictionary:
	if not offline_actions_allowed():
		return {}
	return Journey.capture(self)

func save_game(slot: int) -> bool:
	if not offline_actions_allowed():
		return false
	if not has_journey:
		menu_notice = "Begin a journey before saving."
		return false
	var success := saves.write(slot, make_save_data())
	menu_notice = "Journey saved to %s." % ("autosave" if slot == 0 else "slot %s" % slot) if success else saves.last_error
	interface.previous_state = ""
	if slot != 0 and state == "playing":
		notify(menu_notice)
	return success

func load_game(slot: int) -> bool:
	if not offline_actions_allowed():
		return false
	var result := saves.read(slot)
	if result.data.is_empty():
		menu_notice = result.error
		interface.previous_state = ""
		return false
	if not Journey.restore(self, result.data):
		menu_notice = "This save's location could not be restored."
		interface.previous_state = ""
		return false
	menu_notice = "Recovered a backup save." if result.recovered else "Journey loaded."
	notify(menu_notice)
	return true

func _auto_save() -> bool:
	if not offline_actions_allowed():
		return false
	if not records_enabled or not has_journey:
		return true
	var success := save_game(0)
	if not success:
		notify(menu_notice)
	autosave_timer = 0
	return success

func open_save_menu(loading: bool) -> void:
	if not offline_actions_allowed():
		return
	browser_return_state = state
	menu_notice = ""
	state = "load" if loading else "save"
	rotating_camera = false

func close_save_menu() -> void:
	state = browser_return_state

func open_options() -> void:
	if not is_fullscreen() and DisplayServer.get_name() != "headless" and valid_resolution(get_window().size):
		windowed_resolution = get_window().size
	options_return_state = state
	state = "options"
	rotating_camera = false

func close_options() -> void:
	_save_settings()
	state = options_return_state

func set_fullscreen(enabled: bool) -> void:
	if enabled and not is_fullscreen() and DisplayServer.get_name() != "headless" and valid_resolution(get_window().size):
		windowed_resolution = get_window().size
	fullscreen_requested = enabled
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
		if not enabled:
			_apply_windowed_resolution()
	interface.previous_state = ""

func is_fullscreen() -> bool:
	return fullscreen_requested if DisplayServer.get_name() == "headless" else get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

static func valid_resolution(size: Vector2i) -> bool:
	return size.x >= 1024 and size.y >= 640 and size.x <= 7680 and size.y <= 4320

func resolution_choices() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(RESOLUTIONS)
	if windowed_resolution not in result:
		result.append(windowed_resolution)
	result.sort_custom(func(a, b): return a.y < b.y if a.x == b.x else a.x < b.x)
	return result

func window_resolution_limit() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i(7680,4320)
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_OF_MAIN_WINDOW)
	return usable.size - Vector2i(16,48)

func resolution_fits(size: Vector2i) -> bool:
	var limit := window_resolution_limit()
	return size.x <= limit.x and size.y <= limit.y

func set_resolution(size: Vector2i) -> bool:
	if not valid_resolution(size):
		return false
	windowed_resolution = size
	if not is_fullscreen():
		_apply_windowed_resolution()
	interface.previous_state = ""
	return true

func _apply_windowed_resolution() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var limit := window_resolution_limit()
	if limit.x > 0 and limit.y > 0:
		windowed_resolution = windowed_resolution.min(limit)
	get_window().size = windowed_resolution
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_OF_MAIN_WINDOW)
	get_window().position = usable.position + Vector2i((usable.size - windowed_resolution) * .5)

func _load_settings() -> void:
	if not records_enabled:
		return
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	sound.set_music_level(config.get_value("audio", "music", .7))
	sound.set_sfx_level(config.get_value("audio", "effects", 1.0))
	sound.set_ambience_level(config.get_value("audio", "ambience", .65))
	if config.get_value("audio", "muted", false):
		sound.toggle_mute()
	var resolution = config.get_value("video", "resolution", windowed_resolution)
	if resolution is Vector2i and valid_resolution(resolution):
		set_resolution(resolution)
	set_fullscreen(config.get_value("video", "fullscreen", false))

func _save_settings() -> void:
	if not records_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "music", sound.music_level)
	config.set_value("audio", "effects", sound.sfx_level)
	config.set_value("audio", "ambience", sound.ambience_level)
	config.set_value("audio", "muted", sound.muted)
	if not is_fullscreen() and DisplayServer.get_name() != "headless" and valid_resolution(get_window().size):
		windowed_resolution = get_window().size
	config.set_value("video", "fullscreen", is_fullscreen())
	config.set_value("video", "resolution", windowed_resolution)
	config.save(settings_path)

func return_to_menu() -> void:
	request_exit("menu")

func quit_game() -> void:
	request_exit("quit")

func request_exit(action: String) -> void:
	if online.session or state == "online_lobby":
		online.disconnect_world()
		if action == "quit":
			get_tree().quit()
		return
	rotating_camera = false
	pending_exit = action
	if not _auto_save():
		state = "save_failed"
		return
	finish_exit()

func finish_exit() -> void:
	_save_settings()
	if pending_exit == "quit":
		get_tree().quit()
	else:
		state = "menu"

func return_to_sanctuary() -> void:
	if not offline_actions_allowed():
		return
	sanctum_return.clear()
	_generate_surface(sanctuary)
	state = "playing"
	invulnerable = 1.5
	notify("Returned to your sanctuary.")
	_auto_save()

func sanctum_problem() -> String:
	if not offline_actions_allowed():
		return "Sanctums are forthcoming in the public world."
	if state != "playing":
		return "Resume your journey to use the sigil."
	if layer == "sanctum":
		return "" if not sanctum_return.is_empty() else "The return thread is missing. Use the sanctuary return in the menu."
	if not grounded:
		return "Stand on solid ground to open the sanctum."
	if city_law.danger():
		return "The town watch is too close to open the sanctum."
	for shot in projectiles:
		if shot.hostile:
			return "The sigil cannot open while danger is near."
	for enemy in enemies:
		if enemy.point.distance_to(player_point) < 8.5 and dungeon.line_clear(player_point, enemy.point):
			return "Move away from enemies to open the sanctum."
	return ""

func use_sanctum_sigil() -> bool:
	if not offline_actions_allowed():
		return false
	var problem := sanctum_problem()
	if not problem.is_empty():
		notify(problem)
		return false
	if layer == "sanctum":
		return leave_sanctum()
	sanctum_return = make_save_data()
	_generate_sanctum()
	for spell in cooldowns:
		cooldowns[spell] = sanctum_return.stats.cooldowns[spell]
	notify("Your Sanctum. B arranges furnishings; E rests at the hearth; H returns.")
	sound.play_spell("gate")
	_auto_save()
	return true

func _generate_sanctum(point: Vector2 = Vector2(10, 15)) -> void:
	if not offline_actions_allowed():
		return
	_clear_actors()
	view_key = ""
	layer = "sanctum"
	dungeon = Sanctum.new()
	furnishings.apply(dungeon)
	sanctum_view.build(dungeon)
	world_items.register_location()
	world_view.visible = false
	dungeon_view.visible = false
	_lighting(false)
	sanctum_view.visible = true
	sky_environment.background_color = Color("171628")
	world_ground.visible = false
	_rebuild_navigation()
	player_point = dungeon.safe_position(point)
	if not dungeon.walkable(player_point):
		player_point = Vector2(dungeon.start)
	_snap_camera()
	sanctum_view.update_camera(camera_yaw)

func refresh_sanctum_furnishings() -> void:
	if layer != "sanctum":
		return
	dungeon = Sanctum.new()
	furnishings.apply(dungeon)
	sanctum_view.refresh_furnishings(dungeon)
	var portable = get("world_items")
	if portable != null:
		portable.sync_placed()
	_rebuild_navigation()

func leave_sanctum() -> bool:
	if not offline_actions_allowed():
		return false
	if layer != "sanctum" or sanctum_return.is_empty():
		return false
	var resume := sanctum_return.duplicate(true)
	resume.build = build.snapshot()
	resume.character = profile.snapshot()
	resume.inventory = inventory.snapshot()
	resume.progress.lore = expansion.snapshot()
	resume.progress.exploration = exploration.snapshot()
	resume.progress.life = life.snapshot()
	resume.progress.furnishings = furnishings.snapshot()
	resume.progress.world_items = world_items.snapshot()
	resume.progress.stores = stores.snapshot()
	resume.stats.hp = hp
	resume.stats.mana = mana
	resume.stats.elapsed = elapsed
	resume.stats.cooldowns = cooldowns.duplicate()
	if not Journey.restore(self, resume):
		notify("The return thread could not be restored. Use the sanctuary return in the menu.")
		return false
	sanctum_return.clear()
	invulnerable = maxf(invulnerable, 1.25)
	notify("Returned to the place you left. Your journey awaits.")
	sound.play_spell("gate")
	_auto_save()
	return true

func rotate_camera(step: float) -> void:
	if state == "playing":
		target_yaw = wrapf(target_yaw + step, -PI, PI)

func screen_movement(direction: Vector2) -> Vector2:
	return (Vector2(cos(camera_yaw), -sin(camera_yaw)) * direction.x + Vector2(sin(camera_yaw), cos(camera_yaw)) * direction.y).normalized()

func _update_camera(delta: float) -> void:
	camera_yaw = lerp_angle(camera_yaw, target_yaw, 1.0 - exp(-9.0 * delta))
	camera_focus = camera_focus.lerp(to_world(player_point), 1.0 - exp(-7.0 * delta))
	camera.position = camera_focus + Vector3(sin(camera_yaw) * 20, 14, cos(camera_yaw) * 20)
	camera.look_at(camera_focus)
	if layer == "dungeon":
		dungeon_view.update_camera(camera_yaw)
	elif layer == "sanctum":
		sanctum_view.update_camera(camera_yaw)

func _setup_world() -> void:
	add_child(target_marker)
	for index in range(20):
		var angle := index * TAU / 20.0
		var marker := Voxels.cube(Vector3(.10, .025, .10), Color("ebc77d"), true)
		marker.position = Vector3(cos(angle) * .48, .065, sin(angle) * .48)
		target_marker.add_child(marker)
	target_marker.visible = false
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101a24")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8babc1")
	environment.ambient_light_energy = .70
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	sky_environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_color = Color("ffe4c6")
	light.light_energy = 1.45
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 65
	add_child(light)
	sunlight = light
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.far = 160.0
	camera.current = true
	add_child(camera)
	var ground := Voxels.cube(Vector3(160, .1, 160), Color("14202a"))
	world_ground = ground
	var ground_material := StandardMaterial3D.new()
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_material.albedo_color = Color("101a24")
	ground.material_override = ground_material
	ground.position = Vector3(20, -.45, 20)
	add_child(ground)

func _setup_inputs() -> void:
	var bindings := {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)

func start_run(seed_value: int = -1, edition: int = World.GENERATOR_VERSION) -> void:
	if not offline_actions_allowed():
		return
	offline_generation_calls += 1
	stores.reset()
	floating_hub.close()
	world_items.reset()
	city_law.reset()
	furnishing_editor.stop()
	furnishings.reset()
	expansion.reset()
	exploration.reset()
	interiors.current.clear()
	interiors.return_journey.clear()
	has_journey = true
	menu_notice = ""
	autosave_timer = 0
	view_key = ""
	dungeon_discovery.clear()
	sanctum_return.clear()
	run_seed = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system()) ^ randi()
	rng.seed = run_seed
	depth = 1
	build.reset(build.class_id)
	profile = CharacterProfile.new()
	inventory.reset()
	_update_character_mesh()
	ACTION_BAR = build.action_bar
	_apply_build()
	hp = max_hp
	mana = max_mana
	kills = 0
	elapsed = 0.0
	invulnerable = 0.0
	aim = Vector2.RIGHT
	move_heading = Vector2.RIGHT
	state = "playing"
	encounter_states.clear()
	dungeon_progress.clear()
	claimed_chests.clear()
	visited_cities.clear()
	active_dungeon = {}
	world = World.new()
	world.generate(run_seed, edition)
	life.reset(run_seed)
	life_view.reset()
	world_view.reset()
	sanctuary = Vector2(world.start)
	_generate_surface(sanctuary, false)
	var city: Dictionary = world.nearest_site(player_point, "city")
	visited_cities[city.id] = true
	exploration.knowledge.remember(city, "visited", str(run_seed))
	waypoint = {}
	notify("Follow the roads. Tab opens your atlas. E interacts.")

func choose_class(id: String) -> void:
	if not offline_actions_allowed():
		return
	if state != "title" or not CharacterBuild.CLASSES.has(id):
		return
	build.reset(id)
	profile.costume = profile.clothing_for(id)
	ACTION_BAR = build.action_bar
	_apply_build()
	hp = max_hp
	mana = max_mana
	_update_character_mesh()
	interface.previous_state = ""

func new_character() -> void:
	if not offline_actions_allowed():
		return
	start_run(-1, World.NEW_JOURNEY_EDITION)
	has_journey = false
	state = "title"

func _apply_build() -> void:
	var data: Dictionary = CharacterBuild.CLASSES[build.class_id]
	max_hp = data.hp + build.ranks.get("vitality", 0) * 20 + inventory.bonus("hp")
	max_mana = data.mana + build.ranks.get("reserve", 0) * 20 + inventory.bonus("mana")
	mana_regen = data.regen + build.ranks.get("reserve", 0) * 2
	damage_multiplier = 1.0 + build.ranks.get("power", 0) * .15 + inventory.bonus("power")

func _update_character_mesh() -> void:
	player_mesh.configure(build.class_id, profile)

func customize_character(changes: Dictionary) -> bool:
	if not offline_actions_allowed():
		return false
	var data := profile.snapshot()
	data.merge(changes, true)
	var candidate := CharacterProfile.new()
	if not candidate.restore(data, build.class_id):
		notify("Use a name of 1-24 characters and valid appearance options.")
		return false
	profile = candidate
	_update_character_mesh()
	return true

func open_character_menu() -> void:
	if not offline_actions_allowed():
		return
	if state in ["title", "paused", "playing"]:
		character_return_state = state
		state = "character"
		rotating_camera = false

func close_character_menu() -> void:
	state = character_return_state
	if has_journey:
		_auto_save()

func toggle_inventory() -> void:
	if not offline_actions_allowed():
		return
	if state == "inventory":
		state = inventory_return_state
	elif state in ["playing", "paused"]:
		inventory_return_state = state
		state = "inventory"
		rotating_camera = false

func use_item(id: String) -> bool:
	if not offline_actions_allowed():
		return false
	if state not in ["playing", "inventory"] or inventory.count(id) < 1:
		return false
	if id == "sanctum_sigil":
		if state == "inventory":
			state = "playing"
		return use_sanctum_sigil()
	var item: Dictionary = Inventory.ITEMS[id]
	if not Inventory.Catalog.can_use(item, hp, max_hp, mana, max_mana):
		notify("This item cannot be used now.")
		return false
	if not inventory.remove(id, 1):
		notify("Return stolen goods to their city, or place them without losing their ownership.")
		return false
	hp = minf(max_hp, hp + float(item.get("restore_health", 0)))
	mana = minf(max_mana, mana + float(item.get("restore_mana", 0)))
	interface.previous_state = ""
	notify("Used %s." % Inventory.ITEMS[id].name)
	_auto_save()
	return true

func equip_item(id: String) -> bool:
	if not offline_actions_allowed():
		return false
	if not inventory.equip(id, build.class_id):
		return false
	_refresh_equipment()
	return true

func unequip_item(slot: String) -> void:
	if not offline_actions_allowed():
		return
	if inventory.unequip(slot):
		_refresh_equipment()

func _refresh_equipment() -> void:
	_apply_build()
	hp = minf(hp, max_hp)
	mana = minf(mana, max_mana)
	interface.previous_state = ""
	_auto_save()

func discard_item(id: String) -> bool:
	if not offline_actions_allowed():
		return false
	if not inventory.remove(id, 1):
		return false
	interface.previous_state = ""
	_auto_save()
	return true

func learn_skill(id: String) -> bool:
	if not offline_actions_allowed():
		return false
	var old_hp := max_hp
	var old_mana := max_mana
	if not build.learn(id):
		return false
	_apply_build()
	hp += max_hp - old_hp
	mana += max_mana - old_mana
	interface.previous_state = ""
	_auto_save()
	return true

func equip_ability(spell: String, slot: int) -> void:
	if not offline_actions_allowed():
		return
	if build.equip(spell, slot):
		interface.previous_state = ""
		_auto_save()

func toggle_grimoire() -> void:
	if not offline_actions_allowed():
		return
	if state == "grimoire":
		state = grimoire_return_state
	elif state in ["playing", "paused"]:
		grimoire_return_state = state
		state = "grimoire"

func jump() -> void:
	if not offline_actions_allowed():
		return
	if state == "playing" and grounded:
		vertical_velocity = 7.2
		grounded = false

func _update_vertical(delta: float) -> void:
	var floor_y: float = dungeon.clearance_height(player_point)
	if grounded and player_y - floor_y <= .51:
		player_y = floor_y
		return
	grounded = false
	vertical_velocity -= 20 * delta
	player_y += vertical_velocity * delta
	if player_y <= floor_y and vertical_velocity <= 0:
		player_y = floor_y
		vertical_velocity = 0
		grounded = true

func _clear_actors() -> void:
	world_items.clear_location()
	life_view.visible = false
	guard_time = 0
	clear_target()
	for child in actors.get_children():
		actors.remove_child(child)
		child.queue_free()
	for child in particles.get_children():
		particles.remove_child(child)
		child.queue_free()
	enemies.clear()
	projectiles.clear()
	effects.clear()
	pickups.clear()
	for spell in cooldowns:
		cooldowns[spell] = 0.0

func _snapshot_encounters() -> void:
	if not offline_actions_allowed():
		return
	for enemy in enemies:
		if not enemy.id.is_empty():
			encounter_states[enemy.id] = {"hp": enemy.hp, "point": enemy.point, "slow": enemy.slow, "attack": enemy.attack, "windup": maxf(0, enemy.windup), "active": enemy.active, "species": enemy.species, "variant": enemy.variant}

func _snapshot_discovery() -> void:
	if not offline_actions_allowed():
		return
	if not view_key.is_empty():
		dungeon_discovery[view_key] = dungeon_view.explored.keys().duplicate()

func _lighting(surface: bool) -> void:
	sanctum_view.visible = false
	interiors.view.visible = false
	world_ground.visible = true
	sky_environment.background_color = Color("101a24")
	sky_environment.ambient_light_color = Color("8babc1")
	sky_environment.ambient_light_energy = .80 if surface else .70
	sunlight.light_energy = 1.25 if surface else 1.45
	camera.size = surface_zoom if surface else dungeon_zoom
	player_light.light_energy = .25 if surface else 1.0

func _rebuild_navigation() -> void:
	astar.clear()
	navigation_ids.clear()
	for cell in dungeon.tiles:
		if not dungeon.walkable(Vector2(cell)):
			continue
		var id := navigation_ids.size()
		navigation_ids[cell] = id
		astar.add_point(id, Vector2(cell))
	for cell in dungeon.tiles:
		if not navigation_ids.has(cell):
			continue
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if navigation_ids.has(next) and dungeon.can_step(Vector2(cell), Vector2(next)):
				astar.connect_points(navigation_ids[cell], navigation_ids[next])

func _snap_camera() -> void:
	player_y = dungeon.ground_height(player_point)
	vertical_velocity = 0
	grounded = true
	player.position = to_world(player_point)
	camera_focus = player.position
	_update_camera(0.0)

func _generate_surface(point: Vector2, save_encounters: bool = true) -> void:
	if save_encounters:
		_snapshot_encounters()
		_snapshot_discovery()
	view_key = ""
	_clear_actors()
	layer = "overworld"
	depth = 1
	dungeon = world
	world.load_around(point)
	point = world.safe_position(point)
	if not world.walkable(point):
		world.load_around(sanctuary)
		point = world.safe_position(sanctuary)
		world.load_around(point)
	world_view.sync(world)
	world_items.register_location()
	var in_hub: bool = world.cell_info(Vector2i(point.round())).get("hub_id", "") == FloatingHub.City.data.id
	if not online.session and not in_hub:
		life.sync(world, point)
	elif in_hub:
		life_view.reset()
		life.actors.clear()
	world_view.visible = true
	dungeon_view.visible = false
	_lighting(true)
	_rebuild_navigation()
	player_point = point
	if not online.session and not in_hub:
		life_view.sync(self)
	_snap_camera()
	floating_hub.apply_lighting()
	world_view.update_visibility(player_point, player_y, camera_yaw)
	_sync_surface_enemies()

func _sync_surface_enemies() -> void:
	if not offline_actions_allowed():
		return
	var wanted := {}
	for chunk in world.chunks.values():
		for spawn in chunk.spawns:
			wanted[spawn.id] = spawn
	var existing := {}
	for enemy in enemies.duplicate():
		if wanted.has(enemy.id) or (enemy.active and enemy.point.distance_to(player_point) < 12 and world.bounds.has_point(Vector2i(enemy.point.round()))):
			if wanted.has(enemy.id):
				enemy.grounds = wanted[enemy.id]
			existing[enemy.id] = true
			continue
		if not enemy.id.is_empty():
			encounter_states[enemy.id] = {"hp": enemy.hp, "point": enemy.point, "species": enemy.species, "variant": enemy.variant}
		if enemy == selected_target:
			clear_target()
		enemy.node.queue_free()
		enemies.erase(enemy)
	for id in wanted:
		if existing.has(id):
			continue
		var spawn: Dictionary = wanted[id]
		var saved: Dictionary = encounter_states.get(id, {})
		if not saved.is_empty() and saved.hp <= 0:
			continue
		var point := Vector2(spawn.cell)
		if not saved.is_empty() and world.walkable(saved.point) and world.bounds.has_point(Vector2i(saved.point.round())):
			point = saved.point
		_spawn_enemy(point, spawn.kind, id, saved)
		enemies[-1].grounds = spawn

func _refresh_surface() -> void:
	if world.load_around(player_point):
		world_view.sync(world)
		world_items.register_location()
		if not floating_hub.active():
			life.sync(world, player_point)
		_rebuild_navigation()
		_sync_surface_enemies()

func enter_dungeon(site: Dictionary) -> void:
	if not offline_actions_allowed():
		return
	if layer != "overworld" or site.type != "dungeon":
		return
	exploration.knowledge.remember(site, "visited", str(run_seed))
	active_dungeon = site
	surface_return_point = Vector2(site.get("approach", site.cell + Vector2i(0, 2)))
	depth = mini(dungeon_progress.get(site.id, 1), site.floors)
	var base: Dictionary = world_items.state.bases.get(site.id, {})
	if not base.is_empty() and int(base.floor) <= site.floors:
		depth = int(base.floor)
	else:
		base = {}
	layer = "dungeon"
	_generate_floor()
	if not base.is_empty():
		player_point = dungeon.safe_position(WorldItems.position(base))
		if not dungeon.walkable(player_point):
			player_point = Vector2(dungeon.start)
		_snap_camera()
	notify("%s. E at the stairs or F returns to the world." % site.name)
	_auto_save()

func return_to_surface() -> void:
	if not offline_actions_allowed():
		return
	if layer == "interior":
		interiors.leave()
		return
	if layer != "dungeon":
		return
	expansion.record_return(active_dungeon)
	_generate_surface(surface_return_point)
	state = "playing"
	notify("Returned to the world. Your dungeon progress is kept.")
	_auto_save()

func respawn() -> void:
	if not offline_actions_allowed():
		return
	if state != "dead":
		return
	hp = max_hp
	mana = max_mana
	invulnerable = 1.5
	var at_base := world_items.respawn_at_base()
	if not at_base:
		_generate_surface(sanctuary)
	state = "playing"
	notify("Your light returns at your base." if at_base else "Your light returns at the sanctuary.")
	_auto_save()

func toggle_map() -> void:
	if layer == "sanctum":
		notify("Your home chart is on the HUD. H returns to your journey.")
	elif layer != "overworld":
		notify("The atlas charts the surface. F returns to the world.")
	elif state == "playing":
		state = "map"
	elif state == "map":
		state = "playing"

func interaction_hint() -> String:
	var hub_hint: String = floating_hub.hint()
	if not hub_hint.is_empty():
		return hub_hint
	if online.session:
		return "Shared exploration / Esc: world menu"
	var base_hint := world_items.rest_hint()
	if not base_hint.is_empty():
		return base_hint
	if layer == "interior":
		return interiors.hint()
	if layer == "sanctum":
		if player_point.distance_to(dungeon.hearth) < 2:
			return "E: Rest at your hearth"
		if player_point.distance_to(dungeon.exit) < 1.8:
			return "E: Return to your journey"
		return "B: Arrange furnishings"
	if layer == "overworld":
		if not city_law.target().is_empty():
			return "E: Return city property to the watch"
		var shelter: Dictionary = SurfaceLocations.rest_target(world, player_point)
		if not shelter.is_empty():
			return "E: Rest at " + shelter.name
		var entrance: Dictionary = interiors.target()
		if not entrance.is_empty():
			return "E: Enter " + entrance.name
		var site: Dictionary = world.nearest_site(player_point)
		if player_point.distance_to(site.cell) < 2.5 and site.type in ["city", "dungeon"]:
			return "E: Rest at %s" % site.name if site.type == "city" else "E: Enter %s" % site.name
		var hint: String = expansion.hint()
		if not hint.is_empty():
			return hint
		var store_hint: String = stores.hint()
		return store_hint if not store_hint.is_empty() else exploration.hint()
	if player_point.distance_to(dungeon.start) < 1.7:
		return "E: Return to the world"
	if player_point.distance_to(dungeon.exit) < 1.6:
		if not enemies.is_empty():
			return "%s wardens seal the %s" % [enemies.size(), "chest" if depth == active_dungeon.floors else "gate"]
		if depth == active_dungeon.floors:
			return "Chest claimed. F: Return to the world" if claimed_chests.has(active_dungeon.id) else "E: Open the chest / +1 skill point"
		return "E: Descend to floor %s / %s" % [depth + 1, active_dungeon.floors]
	return expansion.hint()

func location_name() -> String:
	if OS.has_feature("web") and not online.session:
		return "The public world"
	if layer == "interior":
		return "%s / %s" % [interiors.current.name, interiors.current.city_name]
	if layer == "sanctum":
		return "The Inner Sanctum"
	if layer == "dungeon":
		var family_name: String = Areas.DUNGEONS[dungeon.family].name
		return active_dungeon.name if active_dungeon.name == family_name else "%s / %s" % [active_dungeon.name, family_name]
	var city: Dictionary = world.city_at(player_point)
	if not city.is_empty():
		return city.name
	for site in world.region_at(Vector2i(player_point.round())).get("locations", []):
		if site.footprint.has_point(Vector2i(player_point.round())):
			return site.name
	if online.session:
		return World.Biomes.name_for(world.cell_info(Vector2i(player_point.round())))
	for grounds in world.MonsterAreas.plans(world, world.region_at(Vector2i(player_point.round()))):
		if player_point.distance_to(grounds.cell) <= grounds.radius:
			return grounds.label + " / " + World.Biomes.name_for(world.cell_info(Vector2i(player_point.round())))
	var info: Dictionary = world.cell_info(Vector2i(player_point.round()))
	if info.has("biome_id"):
		return World.Biomes.name_for(info)
	if not info.facet.is_empty():
		return Areas.DATA.facets[info.facet].name
	return World.BIOMES[info.biome]

func _generate_floor(snapshot_existing: bool = true) -> void:
	if not offline_actions_allowed():
		return
	if snapshot_existing:
		_snapshot_encounters()
		_snapshot_discovery()
	_clear_actors()
	dungeon = Dungeon.new()
	dungeon.generate(active_dungeon.seed, depth, active_dungeon.get("family", "dungeon_ashen_crypt"), world._biome_at(active_dungeon.cell))
	if depth == active_dungeon.floors:
		dungeon.obstacles.append(Rect2(Vector2(dungeon.exit) - Vector2(.45, .31), Vector2(.90, .62)))
	dungeon_view.build(dungeon, depth, depth == active_dungeon.floors, claimed_chests.has(active_dungeon.id))
	view_key = "%s:floor%s" % [active_dungeon.id, depth]
	world_items.register_location()
	for cell in dungeon_discovery.get(view_key, []):
		if dungeon_view.cell_nodes.has(cell):
			dungeon_view.explored[cell] = true
			dungeon_view.cell_nodes[cell].visible = true
	dungeon_view.visible = true
	world_view.visible = false
	_lighting(false)
	_rebuild_navigation()
	player_point = Vector2(dungeon.start)
	_snap_camera()
	dungeon_view.reveal(dungeon, player_point)
	for index in range(dungeon.spawns.size()):
		var spawn: Dictionary = dungeon.spawns[index]
		var id := "%s:floor%s:enemy%s" % [active_dungeon.id, depth, index]
		var saved: Dictionary = encounter_states.get(id, {})
		if not saved.is_empty() and saved.hp <= 0:
			continue
		var point: Vector2 = dungeon.safe_position(saved.get("point", Vector2(spawn.cell)))
		_spawn_enemy(point, spawn.kind, id, saved)
	if depth > best_depth:
		best_depth = depth
		if records_enabled:
			var record := ConfigFile.new()
			record.set_value("run", "best_depth", best_depth)
			record.save("user://records.cfg")

func _generate_interior(place: Dictionary, point: Vector2 = Vector2.INF) -> void:
	if not offline_actions_allowed():
		return
	_clear_actors()
	view_key = ""
	layer = "interior"
	interiors.current = place
	dungeon = InteriorArea.new()
	dungeon.generate(place)
	interiors.view.build(dungeon)
	world_items.register_location()
	world_view.visible = false
	dungeon_view.visible = false
	_lighting(false)
	interiors.view.visible = true
	sky_environment.background_color = Color("171d28")
	world_ground.visible = false
	camera.size = place.get("zoom", maxf(15, maxf(dungeon.bounds.size.x, dungeon.bounds.size.y) * 1.15))
	_rebuild_navigation()
	player_point = Vector2(dungeon.start) if point == Vector2.INF else dungeon.safe_position(point)
	_snap_camera()
	interiors.view.update_camera(camera_yaw)

func _spawn_enemy(point: Vector2, kind: int, id: String = "", saved: Dictionary = {}) -> void:
	if not offline_actions_allowed():
		return
	kind = EnemyCatalog.index_of(saved.get("species", ""), kind)
	var definition: Dictionary = EnemyCatalog.TYPES[kind]
	var root := Node3D.new()
	root.position = to_world(point)
	root.visible = enemy_render_visible(point)
	var biome: int = dungeon.biome if layer == "dungeon" else world.cell_info(Vector2i(point.round())).biome
	var model := EnemyModels.create(kind, hash("%s:%s" % [run_seed, id if not id.is_empty() else point]), saved.get("variant", ""), biome, layer == "dungeon")
	var base_scale := model.scale
	root.add_child(model)
	var health := Voxels.cube(Vector3(.65, .055, .055), Color("c17a7a"), true)
	health.position.y = 1.25
	health.visible = false
	root.add_child(health)
	actors.add_child(root)
	var maximum: float = definition.hp * (1.0 + minf(depth - 1, 1000) * .13)
	enemies.append({"id": id, "point": point, "kind": kind, "species": definition.id, "variant": model.get_meta("asset_id"), "base_scale": base_scale, "hp": minf(saved.get("hp", maximum), maximum), "max_hp": maximum, "node": root, "model": model, "bar": health, "slow": saved.get("slow", 0.0), "attack": saved.get("attack", rng.randf_range(.3, 1.5)), "windup": saved.get("windup", 0.0), "path_time": 0.0, "path": [], "active": saved.get("active", false), "flash": 0.0})

func _physics_process(delta: float) -> void:
	if online.session:
		online.step(delta)
		return
	if state != "playing":
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var logical := screen_movement(direction)
	player_point = dungeon.move_actor(player_point, logical * 3.8 * delta, player_y, not grounded)
	if logical.length() > 0:
		move_heading = logical
		aim = logical
	simulate(delta)
	player_mesh.animate(direction.length() > 0, grounded)
	player_mesh.position.y = 0 if player_mesh.imported else (sin(time * 11) * .035 if direction.length() > 0 else sin(time * 2) * .015)

func simulate(delta: float) -> void:
	if not offline_actions_allowed():
		return
	if layer in ["overworld", "dungeon"]:
		life.advance(delta)
	if layer == "overworld":
		_refresh_surface()
		if not floating_hub.active():
			city_law.step(delta)
			if state == "guard_demand":
				return
			life.step(world, player_point, delta)
			life_view.sync(self)
	time += delta
	elapsed += delta
	notification_time = maxf(0, notification_time - delta)
	invulnerable = maxf(0, invulnerable - delta)
	guard_time = maxf(0, guard_time - delta)
	shake = maxf(0, shake - delta * .8)
	mana = minf(max_mana, mana + mana_regen * delta)
	for spell in cooldowns:
		cooldowns[spell] = maxf(0, cooldowns[spell] - delta)
	_update_vertical(delta)
	player.position = Vector3(player_point.x, player_y, player_point.y)
	if layer == "overworld":
		world_view.update_visibility(player_point, player_y, camera_yaw)
	player.rotation.y = atan2(aim.x, aim.y)
	player_mesh.visible = invulnerable <= 0 or int(time * 16) % 2 == 0
	_update_camera(delta)
	camera.position += Vector3(sin(time * 71), 0, cos(time * 59)) * shake * .045
	if layer == "dungeon":
		dungeon_view.reveal(dungeon, player_point)
		dungeon_view.animate(delta, enemies.is_empty())
	elif layer == "sanctum":
		sanctum_view.animate(delta)
	elif layer == "interior":
		interiors.view.update_camera(camera_yaw)
	_update_enemies(delta)
	_update_target()
	_update_projectiles(delta)
	_update_effects(delta)
	_update_pickups(delta)
	autosave_timer += delta
	if autosave_timer >= 30:
		_auto_save()

func cast(spell: String) -> void:
	if not offline_actions_allowed():
		return
	if state != "playing" or not build.unlocked.has(spell) or cooldowns[spell] > 0:
		return
	var ability: Dictionary = ABILITIES[spell]
	if ability.range > 0:
		var problem := target_problem(ability.range)
		if not problem.is_empty():
			notify(problem)
			return
	if mana < ability.cost:
		notify("Gather more %s." % CharacterBuild.CLASSES[build.class_id].resource.to_lower())
		return
	if ability.kind == "move":
		var landing := player_point
		for step in range(1, 17):
			var candidate := player_point + move_heading * step * .18
			if not dungeon.can_step(landing, candidate):
				break
			landing = candidate
		if landing.distance_to(player_point) < .2:
			notify("The terrain blocks your passage.")
			return
		_burst(player_point, ability.color, 10, .7)
		player_point = landing
		player_y = dungeon.ground_height(player_point)
		invulnerable = .4
		_burst(player_point, ability.color, 12, .7)
	elif ability.kind in ["area", "cleave"]:
		_ring(player_point, ability.color, ability.radius)
		for enemy in enemies.duplicate():
			var direction: Vector2 = (enemy.point - player_point).normalized()
			if enemy.point.distance_to(player_point) <= ability.radius and dungeon.line_clear(player_point, enemy.point) and (ability.kind != "cleave" or direction.dot(aim) >= -.1):
				if spell == "nova":
					enemy.slow = 3.5
				_hit_enemy(enemy, ability.damage * damage_multiplier)
	elif ability.kind in ["melee", "target"]:
		var point: Vector2 = selected_target.point
		var damage: float = ability.damage * damage_multiplier
		if spell == "execute" and selected_target.hp < selected_target.max_hp * .5:
			damage *= 2
		if spell in ["runeblade", "storm"]:
			selected_target.slow = 3.0
		aim = (point - player_point).normalized()
		_ring(point, ability.color, maxf(.5, ability.radius))
		_burst(point, ability.color, 14, .75)
		if ability.radius > 0:
			for enemy in enemies.duplicate():
				if enemy.point.distance_to(point) <= ability.radius and dungeon.line_clear(point, enemy.point):
					_hit_enemy(enemy, damage)
		else:
			_hit_enemy(selected_target, damage)
	elif ability.kind == "guard":
		guard_time = 3.0
		_ring(player_point, ability.color, .8)
	elif ability.kind == "heal":
		if hp >= max_hp:
			notify("Vitality is already full.")
			return
		hp = minf(max_hp, hp + ability.damage)
		_burst(player_point, ability.color, 15, .8)
	else:
		aim = (selected_target.point - player_point).normalized()
		_shoot(player_point, aim, spell, false, selected_target)
	mana -= ability.cost
	cooldowns[spell] = ability.recharge
	sound.play_spell(spell if spell in sound.NOTES else ("impact" if ability.kind in ["melee", "cleave"] else "nova"))

func cast_slot(index: int) -> void:
	if not offline_actions_allowed():
		return
	if state != "playing" or index < 0 or index >= ACTION_BAR.size():
		return
	var spell := ACTION_BAR[index]
	if spell.is_empty():
		notify("Slot %s is empty." % ((index + 1) % 10))
		return
	cast(spell)

func valid_enemy(enemy: Dictionary) -> bool:
	return not enemy.is_empty() and enemies.has(enemy) and enemy.hp > 0 and is_instance_valid(enemy.node)

func target_problem(reach: float = TARGET_RANGE) -> String:
	if not valid_enemy(selected_target):
		return "Select an enemy first."
	var altitude: float = dungeon.ground_height(selected_target.point) - player_y
	if selected_target.point.distance_squared_to(player_point) + altitude * altitude > reach * reach:
		return "Target is out of range."
	if not dungeon.line_clear(player_point, selected_target.point):
		return "Target is out of sight."
	return ""

func enemy_at_screen(point: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(point)
	var ray := camera.project_ray_normal(point)
	var closest: Dictionary = {}
	var nearest := INF
	for enemy in enemies:
		if not enemy.node.visible or not dungeon.line_clear(player_point, enemy.point):
			continue
		var bounds := AABB(enemy.node.global_position + Vector3(-.35, 0, -.35), Vector3(.70, 1.18, .70))
		var hit = bounds.intersects_ray(origin, ray)
		if hit != null:
			var distance: float = origin.distance_squared_to(hit)
			if distance < nearest:
				nearest = distance
				closest = enemy
	return closest

func select_target(enemy: Dictionary) -> void:
	selected_target = enemy if valid_enemy(enemy) else {}
	if not selected_target.is_empty():
		aim = (selected_target.point - player_point).normalized()
	_update_target()

func clear_target() -> void:
	selected_target = {}
	target_marker.visible = false

func _update_target() -> void:
	if not valid_enemy(selected_target):
		clear_target()
		return
	target_marker.position = to_world(selected_target.point)
	target_marker.visible = selected_target.node.visible and state == "playing"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		rotating_camera = false

func _unhandled_input(event: InputEvent) -> void:
	if state == "world_items":
		world_items.handle_mouse(event)
		return
	if state == "furnishing":
		furnishing_editor.handle_mouse(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rotating_camera = event.pressed and state == "playing"
	if state == "playing" and event is InputEventMouseMotion and rotating_camera:
		target_yaw = wrapf(target_yaw - event.relative.x * camera_sensitivity, -PI, PI)
	if state == "playing" and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var amount := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		if layer == "interior":
			camera.size = clampf(camera.size + amount, 10, 30)
			return
		if layer == "overworld":
			surface_zoom = clampf(surface_zoom + amount, 12, 24)
		else:
			dungeon_zoom = clampf(dungeon_zoom + amount, 10, 22)
		camera.size = surface_zoom if layer == "overworld" else dungeon_zoom
	if state == "playing" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_target(enemy_at_screen(event.position))

func _shoot(point: Vector2, direction: Vector2, spell: String, hostile: bool, target: Dictionary = {}, damage: float = 10.0) -> void:
	if not offline_actions_allowed():
		return
	var size := .23 if spell == "fire" else .13
	var node := Voxels.cube(Vector3(size, size, size), COLORS[spell], true)
	node.position = to_world(point, .55)
	if not hostile:
		node.position.y = player_y + .55
	particles.add_child(node)
	projectiles.append({"point": point, "height": node.position.y, "direction": direction, "spell": spell, "hostile": hostile, "target": target, "node": node, "life": 1.8, "trail": 0.0, "damage": damage})

func _update_projectiles(delta: float) -> void:
	for shot in projectiles.duplicate():
		if not shot.hostile:
			if not valid_enemy(shot.target):
				shot.node.queue_free()
				projectiles.erase(shot)
				continue
			shot.direction = (shot.target.point - shot.point).normalized()
		shot.life -= delta
		shot.trail -= delta
		var speed := 6.0 if shot.hostile else 11.0
		var target_y: float = player_y + .55 if shot.hostile else dungeon.ground_height(shot.target.point) + .55
		shot.height = move_toward(shot.height, target_y, speed * delta)
		var steps := maxi(1, ceili(speed * delta / .15))
		var impacted := false
		for index in range(steps):
			shot.point += shot.direction * speed * delta / steps
			if not dungeon.walkable(shot.point, .04) or dungeon.ground_height(shot.point) > shot.height:
				impacted = true
			elif shot.hostile:
				if shot.point.distance_to(player_point) < .38 and absf(shot.height - player_y - .55) < .5:
					_hurt_player(shot.get("damage", 10.0) * (1.0 + minf(depth - 1, 80) * .07))
					impacted = true
			else:
				if shot.point.distance_to(shot.target.point) < .42:
					if shot.spell != "fire":
						_hit_enemy(shot.target, 20.0 * damage_multiplier)
					impacted = true
			if impacted:
				break
		shot.node.position = Vector3(shot.point.x, shot.height, shot.point.y)
		shot.node.rotation += Vector3(3, 4, 2) * delta
		if shot.trail <= 0:
			shot.trail = .055
			_particle(shot.node.position, COLORS[shot.spell], Vector3.ZERO, .22, .075)
		if impacted or shot.life <= 0:
			if shot.spell == "fire":
				_explode(shot.point)
			else:
				_burst(shot.point, COLORS[shot.spell], 5, .3)
			shot.node.queue_free()
			projectiles.erase(shot)

func _explode(point: Vector2) -> void:
	if not offline_actions_allowed():
		return
	_burst(point, COLORS.fire, 22, 1.4)
	_ring(point, COLORS.fire, 2.0)
	shake = .5
	for enemy in enemies.duplicate():
		if enemy.point.distance_to(point) <= 2.0 and dungeon.line_clear(point, enemy.point):
			_hit_enemy(enemy, 58.0 * damage_multiplier)
	sound.play_spell("impact")

func enemy_render_visible(point: Vector2) -> bool:
	return layer != "dungeon" or dungeon_view.explored.has(Vector2i(point.round()))

func _update_enemies(delta: float) -> void:
	if not offline_actions_allowed():
		return
	var safe := false
	if layer == "overworld":
		safe = not world.city_at(player_point).is_empty()
	for enemy in enemies.duplicate():
		var definition: Dictionary = EnemyCatalog.TYPES[enemy.kind]
		var distance: float = enemy.point.distance_to(player_point)
		enemy.node.visible = enemy_render_visible(enemy.point)
		if layer == "overworld" and enemy.has("grounds") and _return_to_grounds(enemy, delta):
			continue
		if safe:
			enemy.active = false
			enemy.windup = 0.0
		if not safe and distance < 7.5 and dungeon.line_clear(player_point, enemy.point):
			enemy.active = true
		if not enemy.active:
			continue
		enemy.slow = maxf(0, enemy.slow - delta)
		enemy.attack = maxf(0, enemy.attack - delta)
		enemy.path_time -= delta
		enemy.flash = maxf(0, enemy.flash - delta)
		enemy.model.scale = enemy.base_scale * (1.08 if enemy.flash > 0 else 1.0)
		enemy.bar.visible = enemy.hp < enemy.max_hp or enemy == selected_target
		enemy.bar.scale.x = maxf(.01, enemy.hp / enemy.max_hp)
		var ranged: bool = definition.ranged
		var attack_range: float = definition.reach
		var can_attack: bool = distance < attack_range and dungeon.line_clear(enemy.point, player_point)
		if enemy.windup > 0:
			enemy.windup -= delta
			enemy.model.position.y = .04 + sin(time * 28) * .03
			if enemy.windup <= 0:
				if ranged:
					_shoot(enemy.point, (player_point - enemy.point).normalized(), "hostile", true, {}, definition.damage)
				elif distance < attack_range + .25 and absf(player_y - dungeon.ground_height(enemy.point)) < 1.0:
					_hurt_player(definition.damage * (1.0 + minf(depth - 1, 80) * .07))
				enemy.attack = definition.period
		elif can_attack and enemy.attack <= 0:
			enemy.windup = definition.windup
			_ring(enemy.point, COLORS.hostile, .55)
		elif not can_attack or (not ranged and distance > .65):
			if enemy.path_time <= 0:
				enemy.path_time = .45
				var from_cell := Vector2i(enemy.point.round())
				var to_cell := Vector2i(player_point.round())
				enemy.path = astar.get_point_path(navigation_ids[from_cell], navigation_ids[to_cell]) if navigation_ids.has(from_cell) and navigation_ids.has(to_cell) else []
			if enemy.path.size() > 1:
				var target := Vector2(enemy.path[1])
				var direction: Vector2 = (target - enemy.point).normalized()
				var speed: float = definition.speed * (.38 if enemy.slow > 0 else 1.0)
				var movement := direction * speed * delta
				for other in enemies:
					if other == enemy:
						continue
					var separation: Vector2 = enemy.point - other.point
					if separation.length() > .01 and separation.length() < .45:
						movement += separation.normalized() * delta * .7
				var next: Vector2 = dungeon.move_actor(enemy.point, movement)
				if layer != "overworld" or not enemy.has("grounds") or next.distance_to(enemy.grounds.home) <= enemy.grounds.radius + 3:
					enemy.point = next
				enemy.model.position.y = sin(time * 8.0) * .025
		enemy.node.position = to_world(enemy.point)
		var facing: Vector2 = player_point - enemy.point
		enemy.node.rotation.y = atan2(facing.x, facing.y)
		EnemyModels.animate(enemy.model, "attack" if enemy.windup > 0 else ("walk" if not can_attack else "idle"))

func _return_to_grounds(enemy: Dictionary, delta: float) -> bool:
	var home: Vector2 = enemy.grounds.home
	var guard_near: bool = life.residents().any(func(actor): return actor.role == "guard" and actor.point.distance_to(enemy.point) < 3.5)
	if player_point.distance_to(home) <= enemy.grounds.radius + 5 and not guard_near and not enemy.get("returning", false):
		return false
	enemy.active = false
	enemy.windup = 0.0
	enemy.returning = true
	var goal: Vector2 = world.safe_position(home, enemy.grounds.radius)
	if enemy.point.distance_to(goal) < 1:
		enemy.returning = false
		return true
	enemy.path_time -= delta
	if enemy.path_time <= 0:
		enemy.path_time = .75
		var from := Vector2i(enemy.point.round())
		var to := Vector2i(goal.round())
		enemy.path = astar.get_point_path(navigation_ids[from], navigation_ids[to]) if navigation_ids.has(from) and navigation_ids.has(to) else []
	if enemy.path.size() > 1:
		var direction: Vector2 = (Vector2(enemy.path[1]) - enemy.point).normalized()
		enemy.point = world.move_actor(enemy.point, direction * EnemyCatalog.TYPES[enemy.kind].speed * delta)
		enemy.node.position = to_world(enemy.point)
		enemy.node.rotation.y = atan2(direction.x, direction.y)
		EnemyModels.animate(enemy.model, "walk")
	return true

func _hit_enemy(enemy: Dictionary, damage: float) -> void:
	if not offline_actions_allowed():
		return
	enemy.hp -= damage
	enemy.flash = .15
	enemy.active = true
	_burst(enemy.point, Color("e8d1ab"), 4, .3)
	if enemy.hp > 0:
		return
	_burst(enemy.point, COLORS.bolt, 10, .6)
	kills += 1
	if not enemy.id.is_empty():
		encounter_states[enemy.id] = {"hp": 0.0, "point": enemy.point, "species": enemy.species, "variant": enemy.variant}
	_drop(enemy.point, "health" if kills % 3 == 0 else "mana")
	var context := {"class": build.class_id, "biome": -1, "family": "", "facet": ""}
	if layer == "overworld":
		var habitat := world.cell_info(Vector2i(enemy.point.round()))
		context.biome = habitat.biome
		context.facet = habitat.facet
	else:
		context.family = active_dungeon.family
		if layer == "dungeon":
			context.biome = dungeon.biome
	var item_id := Inventory.Catalog.enemy_reward(run_seed, kills, EnemyCatalog.TYPES[enemy.kind], context)
	if not item_id.is_empty():
		_drop(enemy.point + Vector2(.4, .2), item_id)
	if Inventory.Catalog.should_drop_shard(run_seed, kills):
		_drop(enemy.point + Vector2(-.3, .2), "ember_shard")
	_drop(enemy.point + Vector2(.2, -.3), "gold_coin")
	enemy.node.queue_free()
	enemies.erase(enemy)
	if selected_target == enemy:
		clear_target()
	if layer == "dungeon" and enemies.is_empty():
		notify("The chest is unsealed. Claim your skill point." if depth == active_dungeon.floors else "The seal is broken. Enter the descent gate.")
		sound.play_spell("gate")

func _hurt_player(damage: float, town_guard: bool = false) -> void:
	if not offline_actions_allowed():
		return
	if invulnerable > 0 or state != "playing" or layer == "sanctum":
		return
	if layer == "overworld" and not town_guard and not world.city_at(player_point).is_empty():
		return
	hp = maxf(0, hp - damage * (.35 if guard_time > 0 else 1.0))
	invulnerable = .8
	shake = .9
	if town_guard:
		_ring(player_point, Color("df8888"), .25)
	else:
		_burst(player_point, Color("df8888"), 8, .5)
	sound.play_spell("hurt")
	if hp <= 0:
		state = "dead"
		clear_target()
		notify("Your light fades in the hollow.")

func _drop(point: Vector2, kind: String) -> void:
	if not offline_actions_allowed():
		return
	point = _loot_point(point)
	var biome: int = world.cell_info(Vector2i(point.round())).biome if layer == "overworld" else (dungeon.biome if layer in ["dungeon", "interior"] else 0)
	var visual = preload("res://scripts/item_visual.gd")
	var family: String = visual.families.styles.family_for(biome)
	var node: Node3D
	if Inventory.ITEMS.has(kind):
		node = visual.model(Inventory.ITEMS[kind], .42, family, kind)
	elif kind in ["health", "mana"]:
		node = preload("res://scripts/native_reward_models.gd").model(kind, family)
		node.set_meta("render_asset", node.get_meta("asset_id"))
		node.set_meta("representation", "native_reward")
	if node == null:
		push_error("Reward requires a valid family-aware body: " + kind + " / " + visual.families.error)
		return
	particles.add_child(node)
	node.position = to_world(point, .32)
	pickups.append({"point": point, "kind": kind, "node": node})

func _loot_point(point: Vector2) -> Vector2:
	if dungeon.walkable(point):
		return point
	for radius in range(1, 5):
		for offset in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			var candidate: Vector2 = Vector2(point.round()) + offset * radius
			if dungeon.walkable(candidate):
				return candidate
	return player_point

func _update_pickups(delta: float) -> void:
	if not offline_actions_allowed():
		return
	for pickup in pickups.duplicate():
		var distance: float = pickup.point.distance_to(player_point)
		if distance < 2.2:
			pickup.point = pickup.point.move_toward(player_point, delta * 5)
		pickup.node.position = to_world(pickup.point, .32 + sin(time * 3.0) * .07)
		pickup.node.rotation.y += delta * 2
		if distance < .45:
			if pickup.kind == "health":
				hp = minf(max_hp, hp + 18)
			elif pickup.kind == "mana":
				mana = minf(max_mana, mana + 22)
			elif not inventory.add(pickup.kind, 1):
				if not pickup.get("notified", false):
					notify("Backpack full. I opens your inventory; this item stays here.")
					pickup.notified = true
				continue
			else:
				notify("Collected %s. I opens your inventory." % Inventory.ITEMS[pickup.kind].name)
			pickup.node.queue_free()
			pickups.erase(pickup)
			sound.play_spell("pickup")

func _particle(position_3d: Vector3, color: Color, velocity: Vector3, duration: float, size: float) -> void:
	if effects.size() >= 240:
		return
	var node := Voxels.cube(Vector3.ONE * size, color, true)
	node.position = position_3d
	particles.add_child(node)
	effects.append({"node": node, "velocity": velocity, "life": duration, "duration": duration})

func _burst(point: Vector2, color: Color, count: int, radius: float) -> void:
	for index in range(count):
		var angle := rng.randf() * TAU
		var velocity := Vector3(cos(angle) * radius * 2, rng.randf_range(.3, 1.8), sin(angle) * radius * 2)
		_particle(to_world(point, .45), color, velocity, rng.randf_range(.25, .6), rng.randf_range(.055, .12))

func _ring(point: Vector2, color: Color, radius: float) -> void:
	for index in range(28):
		var angle := index * TAU / 28.0
		var outward := Vector3(cos(angle), 0, sin(angle))
		_particle(to_world(point, .12) + outward * .2, color, outward * radius * 2, .5, .09)

func _update_effects(delta: float) -> void:
	for effect in effects.duplicate():
		effect.life -= delta
		effect.node.position += effect.velocity * delta
		effect.node.scale = Vector3.ONE * maxf(.01, effect.life / effect.duration)
		if effect.life <= 0:
			effect.node.queue_free()
			effects.erase(effect)

func interact() -> void:
	if floating_hub.interact():
		return
	if not offline_actions_allowed():
		return
	if state != "playing":
		return
	var watch := city_law.target()
	if not watch.is_empty():
		city_law.demand(watch)
		return
	if world_items.rest():
		return
	if layer == "overworld":
		var shelter: Dictionary = SurfaceLocations.rest_target(world, player_point)
		if not shelter.is_empty():
			var problem := sanctum_problem()
			if problem.is_empty():
				hp = max_hp
				mana = max_mana
				exploration.knowledge.remember(shelter, "visited", str(run_seed))
				notify("Rested at %s." % shelter.name)
				_auto_save()
			else:
				notify(problem)
			return
	if layer == "interior":
		interiors.interact()
		return
	if layer == "sanctum":
		if player_point.distance_to(dungeon.hearth) < 2:
			hp = max_hp
			mana = max_mana
			notify("Rested at your hearth. The world waits beyond the portal.")
			_auto_save()
		elif player_point.distance_to(dungeon.exit) < 1.8:
			leave_sanctum()
		else:
			notify("E at the hearth rests. H returns to your journey.")
		return
	if layer == "overworld":
		var entrance: Dictionary = interiors.target()
		if not entrance.is_empty():
			interiors.enter(entrance)
			return
		var site: Dictionary = world.nearest_site(player_point)
		if player_point.distance_to(site.cell) > 2.5 or site.type not in ["city", "dungeon"]:
			if not expansion.interact() and not stores.interact() and not exploration.interact():
				notify("Follow a road to a city or ruin. Tab opens the atlas.")
		elif site.type == "dungeon":
			enter_dungeon(site)
		else:
			hp = max_hp
			mana = max_mana
			sanctuary = Vector2(site.cell) + Vector2(0, 3)
			visited_cities[site.id] = true
			exploration.knowledge.remember(site, "visited", str(run_seed))
			notify("Rested at %s. This city is your sanctuary." % site.name)
			_auto_save()
		return
	if player_point.distance_to(dungeon.start) < 1.7:
		return_to_surface()
		return
	if player_point.distance_to(dungeon.exit) > 1.6:
		if not expansion.interact():
			notify("Find the stone gate marked on your map.")
	elif not enemies.is_empty():
		notify("%s wardens still bind the gate." % enemies.size())
	else:
		if depth == active_dungeon.floors:
			if claimed_chests.has(active_dungeon.id):
				notify("This chest has been claimed. F returns to the world.")
				return
			claimed_chests[active_dungeon.id] = true
			build.skill_points += 1
			var furnishing: String = ["oak_chair", "rune_lantern", "wool_rug"][absi(hash(active_dungeon.id)) % 3]
			_drop(Vector2(dungeon.exit) + Vector2.DOWN, furnishing)
			_drop(Vector2(dungeon.exit) + Vector2.LEFT, "traveler_coat" if build.class_id == "mage" else "silver_charm")
			_drop(Vector2(dungeon.exit) + Vector2.RIGHT, "arcane_staff" if build.class_id == "mage" else "iron_sword")
			for index in range(int(Inventory.Catalog.policy.chest_catalogue_items)):
				var ordinal := claimed_chests.size() * int(Inventory.Catalog.policy.chest_catalogue_items) - index
				_drop(Vector2(dungeon.exit) + Vector2(0, .3 * index), Inventory.Catalog.loot(run_seed, ordinal, "chest"))
			dungeon_view.open_chest()
			sound.play_spell("gate")
			_burst(Vector2(dungeon.exit), Color("edce7b"), 24, 1.2)
			notify("+1 skill point. G opens your grimoire. F returns to the world.")
			_auto_save()
		else:
			descend()

func descend() -> void:
	if not offline_actions_allowed():
		return
	if state != "playing" or layer != "dungeon" or depth >= active_dungeon.floors or not enemies.is_empty():
		return
	depth += 1
	dungeon_progress[active_dungeon.id] = depth
	hp = minf(max_hp, hp + max_hp * .25)
	mana = max_mana
	invulnerable = 1.0
	_generate_floor()
	notify("Floor %s / %s: %s" % [depth, active_dungeon.floors, Areas.DUNGEONS[dungeon.family].name])
	_auto_save()

func toggle_pause() -> void:
	rotating_camera = false
	if state == "playing":
		state = "paused"
	elif state == "paused":
		state = "playing"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if state == "hub_board":
		if event.physical_keycode == KEY_ESCAPE:
			floating_hub.close()
		return
	if state == "hub_travel_loading":
		return
	if online.session:
		match event.physical_keycode:
			KEY_E:
				interact()
			KEY_ESCAPE:
				if state == "options":
					close_options()
				elif state == "map":
					state = "playing"
				else:
					toggle_pause()
			KEY_TAB:
				toggle_map()
			KEY_F11:
				set_fullscreen(not is_fullscreen())
			KEY_M:
				sound.toggle_mute()
		return
	if state == "online_lobby":
		if event.physical_keycode == KEY_ESCAPE:
			online.disconnect_world("")
		return
	if state == "world_items":
		world_items.handle_key(event)
		return
	if state == "furnishing":
		furnishing_editor.handle_key(event)
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if state == "inventory":
				toggle_inventory()
			elif state == "character":
				close_character_menu()
			elif state == "credits":
				close_credits()
			elif state in ["load", "save"]:
				close_save_menu()
			elif state == "options":
				close_options()
			elif state == "title":
				state = "menu"
			elif state == "grimoire":
				toggle_grimoire()
			elif state == "map":
				state = "playing"
			elif state == "playing" and not selected_target.is_empty():
				clear_target()
			else:
				toggle_pause()
		KEY_ENTER:
			if state == "title":
				begin_journey()
			elif state == "dead":
				respawn()
		KEY_TAB:
			toggle_map()
		KEY_F:
			if state == "playing":
				return_to_surface()
		KEY_E:
			interact()
		KEY_R:
			if state == "dead":
				respawn()
		KEY_F5:
			if state in ["playing", "paused"]:
				save_game(1)
		KEY_F9:
			var slot := saves.latest_slot()
			if slot >= 0:
				load_game(slot)
		KEY_F11:
			set_fullscreen(not is_fullscreen())
		KEY_M:
			sound.toggle_mute()
		KEY_G:
			toggle_grimoire()
		KEY_I:
			toggle_inventory()
		KEY_B:
			if layer == "sanctum":
				furnishing_editor.open()
			else:
				world_items.open_placement()
		KEY_V:
			world_items.open_placement()
		KEY_T:
			if state == "playing":
				world_items.take_nearest()
		KEY_C:
			open_character_menu()
		KEY_H:
			use_sanctum_sigil()
		KEY_SPACE:
			jump()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			if state == "playing":
				cast_slot(9 if event.physical_keycode == KEY_0 else event.physical_keycode - KEY_1)

func notify(message: String) -> void:
	notification = message
	notification_time = 3.5

func to_world(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x, dungeon.ground_height(point) + height, point.y)

func offline_actions_allowed() -> bool:
	return not OS.has_feature("web") and not online.session and state != "online_lobby"

func begin_online(message: Dictionary, server_build, server_inventory, server_world) -> void:
	_clear_actors()
	life_view.reset()
	city_law.reset()
	stores.reset()
	world_items.reset()
	furnishing_editor.stop()
	expansion.reset()
	exploration.reset()
	interiors.current.clear()
	interiors.return_journey.clear()
	interiors.view.visible = false
	sanctum_return.clear()
	encounter_states.clear()
	dungeon_progress.clear()
	claimed_chests.clear()
	visited_cities.clear()
	waypoint.clear()
	active_dungeon.clear()
	build = server_build
	inventory = server_inventory
	profile = CharacterProfile.new()
	profile.restore(message.player.profile, build.class_id)
	ACTION_BAR = build.action_bar
	_apply_build()
	_update_character_mesh()
	hp = max_hp
	mana = max_mana
	player_y = 0
	vertical_velocity = 0
	grounded = true
	invulnerable = 0
	run_seed = message.world.seed.to_int()
	world = server_world
	world_view.reset()
	life.reset(run_seed)
	sanctuary = Vector2(world.start)
	_generate_surface(Vector2(message.player.position[0], message.player.position[1]), false)
	life_view.visible = false
	layer = "overworld"
	player_point = Vector2(message.player.position[0], message.player.position[1])
	player_y = world.ground_height(player_point)
	player.position = Vector3(player_point.x, player_y, player_point.y)
	player.show()
	_snap_camera()
	has_journey = true
	state = "playing"
	interface.previous_state = ""
