extends CanvasLayer

const City = preload("res://scripts/floating_city.gd")
const HubWorld = preload("res://scripts/hub_world.gd")
var game
var current: Dictionary = {}
var overlay := Control.new()
var was_active := false

func _ready() -> void:
	layer = 8
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()

func active() -> bool:
	return game.layer == "overworld" and game.world.cell_info(Vector2i(game.player_point.round())).get("hub_id", "") == City.data.id

func city() -> Dictionary:
	if not active():
		return {}
	return game.world.region_at(Vector2i(game.player_point.round())).city

func start() -> void:
	var world := HubWorld.new()
	world.generate(game.run_seed, game.world.generator_version)
	game.world = world
	game.world_view.reset()
	game.life_view.reset()
	game.life.actors.clear()
	game.visited_cities.clear()
	game.exploration.knowledge.reset()
	game.sanctuary = world.hub.spawn
	game._generate_surface(world.hub.spawn, false)
	game.visited_cities[City.data.id] = true
	game.exploration.knowledge.remember(world.hub.city_record(), "visited", str(game.run_seed))
	apply_lighting()
	game.notify("Welcome to Lanternwake. Meet at the Commons, visit the guilds and market, or take the Worldgate to the lands below.")

func snapshot() -> Dictionary:
	if not game.world is HubWorld:
		return {}
	return {"version": 1, "id": City.data.id, "theme": game.world.hub.theme}

static func valid(data) -> bool:
	return data is Dictionary and (data.is_empty() or data.get("version") == 1 and data.get("id") == City.data.id and City.data.themes.has(data.get("theme", "")))

func target() -> Dictionary:
	if game.layer != "overworld":
		return {}
	var local := city()
	if not local.is_empty():
		if game.player_point.distance_to(local.hub_portal) < 1.8:
			return {"kind": "depart", "name": "Worldgate", "point": local.hub_portal}
		for hall in local.houses:
			if game.player_point.distance_to(hall.approach) < 1.6:
				var record: Dictionary = hall.duplicate()
				record.kind = "guild"
				record.name = hall.use_name
				return record
		for market in local.outdoor_lots:
			if game.player_point.distance_to(market.approach) < 1.6:
				return {"kind": "market", "name": market.name, "point": market.approach}
		if game.player_point.distance_to(local.hub_spawn) < 2:
			return {"kind": "commons", "name": "Lanternwake Commons", "point": local.hub_spawn}
	else:
		var region: Dictionary = game.world.region_at(Vector2i(game.player_point.round()))
		var gate: Vector2 = region.get("hub_world_gate", Vector2.INF)
		if game.player_point.distance_to(gate) < 1.8:
			return {"kind": "return", "name": "Lanternwake Worldgate", "point": gate}
	return {}

func hint() -> String:
	var source := target()
	if source.is_empty():
		return ""
	if source.kind == "depart":
		return "E: Depart through the Worldgate"
	if source.kind == "return":
		return "E: Return to Lanternwake"
	if source.kind == "market":
		return "E: Visit " + source.name if game.online.session else "E: Trade at " + source.name
	return "E: Read the " + source.name + (" charter" if source.kind == "guild" else " arrival board")

func interact() -> bool:
	if game.state != "playing":
		return false
	var source := target()
	if source.is_empty():
		return false
	if source.kind in ["depart", "return"]:
		if game.online.session:
			game.online.send({"type": "hub_travel", "destination": "world" if source.kind == "depart" else "hub"})
		elif game.grounded:
			game._generate_surface(Vector2(game.world.start) if source.kind == "depart" else game.world.hub.spawn)
			apply_lighting()
			game._auto_save()
		return true
	if source.kind == "market" and not game.online.session:
		return game.stores.interact()
	current = source
	game.state = "hub_board"
	game.rotating_camera = false
	_show()
	return true

func recall() -> bool:
	if not game.offline_actions_allowed() or not game.world is HubWorld or game.state not in ["playing", "paused"]:
		return false
	if not game.sanctum_problem().is_empty():
		game.notify("Find safe ground before returning to Lanternwake.")
		return false
	game.state = "playing"
	game._generate_surface(game.world.hub.spawn)
	apply_lighting()
	game._auto_save()
	return true

func set_theme(season: String) -> bool:
	if not game.offline_actions_allowed() or not game.world is HubWorld or not game.world.hub.set_theme(season):
		return false
	game.world.regions.clear()
	game.world_view.reset()
	game.world_view.sync(game.world)
	apply_lighting()
	game._auto_save()
	return true

func close() -> void:
	if game.state == "hub_board":
		game.state = "playing"
	current.clear()
	overlay.hide()

func enter_hall() -> void:
	var source := current.duplicate()
	close()
	var local := city()
	if not game.online.session and not local.is_empty():
		game.interiors.enter(game.interiors.describe(local, source))

func join_public_world() -> void:
	close()
	game.online.open_lobby()

func show_travel(destination: String) -> void:
	current = {"kind": "travel", "name": "Crossing the Worldgate", "charter": "Following the lanterns to Lanternwake..." if destination == "hub" else "Stepping into the wandering lands..."}
	_show()

func _show() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(.04, .025, .07, .87)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = game.interface._panel(center, Vector2(680, 0), Color("9774b2"))
	var box = game.interface._vbox(panel, 16)
	game.interface._label(box, current.name, 28, Color("e7c997"), true)
	var text: String = current.get("charter", "Lanternwake floats above the wandering lands. The Commons welcome new arrivals and companions. Guild halls stand along the Moonlit Walk; traders keep the Ember Market. Take the Worldgate at the southern dock when you are ready to explore.")
	if current.kind == "market":
		text = "The Ember Market brings provisions, curios and travelers together beneath the lantern awnings. Meet fellow travelers here before setting out from the Worldgate."
	var body = game.interface._label(box, text, 17, Color("d8d0e5"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 620
	if current.kind == "guild" and not game.online.session:
		game.interface._button(box, "Enter the hall", enter_hall)
	if current.kind == "commons":
		if game.online.session:
			game.interface._label(box, "Nearby travelers", 18, Color("bfa5e1"), true)
			for player in game.online.players.values():
				game.interface._label(box, player.username, 16, Color("ddd6e5"))
		else:
			game.interface._button(box, "Join the public world", join_public_world)
	if current.kind != "travel":
		game.interface._button(box, "Close [Esc]", close)
	overlay.show()

func apply_lighting() -> void:
	if not active():
		return
	var local := city()
	var profile: Dictionary = City.data.themes[local.get("theme", City.data.default_theme)]
	game.world_ground.hide()
	game.sky_environment.background_color = Color(profile.sky)
	game.sky_environment.ambient_light_color = Color("b6a4cc")
	game.sky_environment.ambient_light_energy = .85
	game.sunlight.light_energy = .95
	was_active = true

func _process(_delta: float) -> void:
	if game == null:
		return
	if game.state not in ["hub_board", "hub_travel_loading"]:
		overlay.hide()
	if game.layer != "overworld":
		was_active = false
		return
	if active():
		apply_lighting()
	elif was_active:
		game._lighting(true)
		was_active = false
