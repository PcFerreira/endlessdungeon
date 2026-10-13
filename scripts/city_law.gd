extends CanvasLayer

const PATH := "res://config/city_law.json"
const MODES := ["guard_demand", "guard_pursuit", "guard_return"]
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
var game
var guard_id := ""
var city_id := ""
var overlay := Control.new()
var demand_text := ""

func _ready() -> void:
	assert(valid_config(config), "Invalid city law configuration")
	layer = 6
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.hide()

static func valid_config(value) -> bool:
	if not value is Dictionary or value.get("version") != 1:
		return false
	for key in ["notice_radius", "pursuit_radius", "demand_distance", "reach", "speed", "damage", "period_seconds", "windup_seconds"]:
		var number = value.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or number <= 0:
			return false
	return value.notice_radius <= value.pursuit_radius and value.pursuit_radius <= 18 and value.demand_distance <= 3.5 and value.reach < value.demand_distance and value.speed <= 4 and value.damage <= 30 and value.period_seconds >= .5 and value.period_seconds <= 12 and value.windup_seconds <= value.period_seconds

func reset() -> void:
	guard_id = ""
	city_id = ""
	_clear()

func _clear() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.hide()

func _items():
	return game.get("world_items") if game != null else null

func wanted(id: String) -> Dictionary:
	var items = _items()
	return items.wanted(id) if items != null else {}

func mode(guard: Dictionary, claim: Dictionary, player: Vector2) -> String:
	var engaged: bool = guard.get("law_mode", "patrol") in MODES
	var returning: String = "guard_return" if engaged and guard.point.distance_to(guard.origin + Vector2(1,1)) > 1.2 else "patrol"
	if claim.is_empty() or claim.get("count", 0) <= 0:
		return returning
	if player.distance_to(guard.origin) > config.pursuit_radius:
		return returning
	if not engaged and guard.point.distance_to(player) > config.notice_radius:
		return "patrol"
	return "guard_pursuit" if claim.get("hostile", false) else "guard_demand"

func direct(world, guard: Dictionary, next_mode: String, player: Vector2) -> void:
	var previous: String = guard.get("law_mode", "patrol")
	guard.law_mode = next_mode
	guard.law_speed = config.speed if next_mode == "guard_pursuit" else guard.routine.speed
	if previous != next_mode:
		guard.path.clear()
		guard.rest_until = 0
		guard.next_tick = 0
		guard.law_windup_tick = 0
		if next_mode == "patrol":
			guard.waypoint = 0
			guard.target = guard.point
			guard.activity = "patrol"
	if next_mode == "patrol":
		return
	guard.activity = next_mode
	var destination: Vector2 = guard.origin + Vector2(1,1) if next_mode == "guard_return" else player
	var toward: Vector2 = destination - guard.point
	var target: Vector2 = world.safe_position(guard.point + toward.limit_length(3), 2)
	if target.distance_to(guard.origin) > 20 or not world.walkable(target):
		return
	if target.distance_to(guard.target) > 1 or guard.path.is_empty():
		guard.target = target
		guard.path.clear()

func step(_delta: float) -> void:
	if game != null and not game.offline_actions_allowed():
		return
	if game.state != "playing" or game.layer != "overworld":
		return
	var claims := {}
	for guard in game.life.residents():
		if guard.role != "guard":
			continue
		if not claims.has(guard.city_id):
			claims[guard.city_id] = wanted(guard.city_id)
		var claim: Dictionary = claims[guard.city_id]
		var next_mode := mode(guard, claim, game.player_point)
		if next_mode in ["guard_demand", "guard_pursuit"] and guard.get("law_mode", "patrol") == "patrol" and not game.world.line_clear(guard.point,game.player_point):
			next_mode = "patrol"
		direct(game.world, guard, next_mode, game.player_point)
		if next_mode == "guard_pursuit":
			_attack(guard)
		elif next_mode == "guard_demand" and guard.point.distance_to(game.player_point) <= config.demand_distance:
			if demand(guard):
				return

func danger() -> bool:
	if game == null or game.layer != "overworld":
		return false
	return game.life.residents().any(func(guard): return guard.role == "guard" and wanted(guard.city_id).get("hostile", false) and guard.point.distance_to(game.player_point) < 8.5 and game.world.line_clear(guard.point,game.player_point))

func target() -> Dictionary:
	if game.layer != "overworld":
		return {}
	var nearest := {}
	var distance: float = config.demand_distance
	for guard in game.life.residents():
		if guard.role != "guard" or wanted(guard.city_id).is_empty():
			continue
		var next: float = guard.point.distance_to(game.player_point)
		if next <= distance and game.world.line_clear(guard.point,game.player_point):
			nearest = guard
			distance = next
	return nearest

func _attack(guard: Dictionary) -> void:
	if game != null and not game.offline_actions_allowed():
		return
	var tick: int = game.life.tick
	var windup: int = guard.get("law_windup_tick", 0)
	var can_hit: bool = guard.point.distance_to(game.player_point) <= config.reach and game.world.line_clear(guard.point,game.player_point) and absf(game.player_y - game.world.ground_height(guard.point)) < 1
	if windup > 0:
		if tick >= windup:
			guard.law_windup_tick = 0
			guard.law_cooldown_tick = tick + ceili(config.period_seconds * 2)
			if can_hit:
				game._hurt_player(config.damage, true)
	elif can_hit and tick >= guard.get("law_cooldown_tick", 0):
		guard.law_windup_tick = tick + maxi(1,ceili(config.windup_seconds * 2))
		game._ring(guard.point, Color("d79367"), .55)

func demand(guard: Dictionary) -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	if game.state != "playing" or game.layer != "overworld" or not game.grounded or wanted(guard.city_id).is_empty() or guard.point.distance_to(game.player_point) > config.demand_distance or not game.world.line_clear(guard.point,game.player_point):
		return false
	if game.enemies.any(func(enemy): return enemy.active and enemy.point.distance_to(game.player_point) < 8.5):
		return false
	guard_id = guard.id
	city_id = guard.city_id
	demand_text = "Property taken from %s remains in your possession. Return it, and the watch will stand down. Refuse, and the guards will pursue you within the town approaches." % guard.city_name
	game.state = "guard_demand"
	game.rotating_camera = false
	_show()
	return true

func _show() -> void:
	_clear()
	overlay.show()
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = game.interface._panel(center,Vector2(650,0),Color("766950"))
	var box = game.interface._vbox(panel,12)
	game.interface._label(box,"The watch demands restitution",25,Color("e5e0d5"),true)
	var text = game.interface._label(box,demand_text,18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 590
	game.interface._label(box,"Outstanding city property: %s" % wanted(city_id).get("count",0),14,Color("c3a576"))
	game.interface._button(box,"Return stolen property",restitute)
	game.interface._button(box,"Refuse and leave  [Esc]",refuse)

func restitute() -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	if game.state != "guard_demand" or city_id.is_empty():
		return false
	if not _items().return_stolen(city_id):
		demand_text = "The property could not be returned. Your debt to the town remains."
		_show()
		return false
	close()
	for guard in game.life.residents():
		if guard.role == "guard":
			direct(game.world,guard,mode(guard,wanted(guard.city_id),game.player_point),game.player_point)
	game.life_view.sync(game)
	game.notify("Property returned. The watch stands down.")
	game._auto_save()
	return true

func refuse() -> void:
	if game != null and not game.offline_actions_allowed():
		return
	if game.state != "guard_demand" or city_id.is_empty():
		return
	_items().refuse_return(city_id)
	close()
	game.notify("The town watch will pursue you. Return the property to end the dispute.")
	game._auto_save()

func close() -> void:
	reset()
	if game.state == "guard_demand":
		game.state = "playing"

func _input(event: InputEvent) -> void:
	if game != null and game.state == "guard_demand" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		refuse()
		get_viewport().set_input_as_handled()
