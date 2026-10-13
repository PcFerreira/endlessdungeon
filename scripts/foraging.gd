extends Node3D

const Catalog = preload("res://scripts/forage_catalog.gd")
const Visual = preload("res://scripts/forage_visual.gd")
const Styles = preload("res://scripts/environment_styles.gd")
var game
var nodes: Dictionary = {}
var models: Dictionary = {}
var visual_templates: Dictionary = {}
var harvested: Dictionary = {}
var styles := Styles.new()
var marker := Label3D.new()
var view_key := ""
var planned: Dictionary = {}
var plan_context := []
var timer := 0.0

func _ready() -> void:
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 30
	marker.pixel_size = .007
	marker.modulate = Color("d9dfaf")
	add_child(marker)
	marker.hide()

func reset() -> void:
	harvested.clear()
	_clear()

func clear_location() -> void:
	_clear()

func _clear() -> void:
	for model in models.values():
		model.free()
	models.clear()
	nodes.clear()
	planned.clear()
	plan_context.clear()
	view_key = ""
	marker.hide()

func snapshot() -> Dictionary:
	return harvested.duplicate()

static func valid(data, expected_seed: String = "") -> bool:
	if not data is Dictionary or data.size() > Catalog.DATA.ledger_limit:
		return false
	var pattern := RegEx.new()
	pattern.compile("^(endless:-?[0-9]+:[4567]|realm:[a-z0-9_]+:[0-9]+)@(-?[0-9]+),(-?[0-9]+)$")
	var realms := {}
	for id in data:
		if not id is String or id.length() > 160 or not data[id] is bool or not data[id]:
			return false
		var match_value := pattern.search(id)
		if match_value == null or absf(match_value.get_string(2).to_float()) > 2000000 or absf(match_value.get_string(3).to_float()) > 2000000:
			return false
		var identity: PackedStringArray = match_value.get_string(1).split(":")
		if identity[0] == "endless" and not expected_seed.is_empty() and identity[1] != str(expected_seed.to_int()):
			return false
		if identity[0] == "realm":
			if not realms.has(identity[1]):
				var path := "res://config/dimensions/" + identity[1] + ".json"
				var realm = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
				if not realm is Dictionary:
					return false
				realms[identity[1]] = [int(realm.map_version)] + realm.get("compatible_revisions", []).map(func(revision): return int(revision))
			if not realms[identity[1]].has(identity[2].to_int()):
				return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	_clear()
	harvested = data.duplicate()
	return true

func _process(delta: float) -> void:
	if game == null:
		return
	visible = game.layer == "overworld" and game.offline_actions_allowed()
	if not visible or game.state != "playing":
		marker.hide()
		return
	timer -= delta
	if timer <= 0:
		sync()
		timer = .25
	var record := target()
	marker.visible = not record.is_empty()
	if marker.visible:
		marker.text = Catalog.DATA.items[record.item].name + "  [E]"
		marker.position = Vector3(record.point.x,game.world.ground_height(record.point) + .85,record.point.y)

func sync(force: bool = false) -> void:
	if game == null or game.layer != "overworld" or not game.offline_actions_allowed():
		return
	var world = game.world
	var context := [world.get_instance_id(), Catalog.scope(world)]
	var key := "%s:%s:%s" % [context[0],context[1],world.current_chunk]
	if not force and key == view_key:
		return
	if context != plan_context:
		_clear()
		plan_context = context
	view_key = key
	marker.hide()
	var candidates: Array[Dictionary] = []
	var retained := {}
	var step := int(Catalog.DATA.spacing)
	var bounds: Rect2i = world.bounds
	for x in range(floori(float(bounds.position.x) / step),ceili(float(bounds.end.x) / step)):
		for y in range(floori(float(bounds.position.y) / step),ceili(float(bounds.end.y) / step)):
			var grid := Vector2i(x,y)
			var record: Dictionary = planned[grid] if planned.has(grid) else Catalog.plan(world,grid)
			retained[grid] = record
			if not record.is_empty() and bounds.has_point(Vector2i(record.point)) and not harvested.has(record.id):
				candidates.append(record)
	planned = retained
	candidates.sort_custom(func(a,b): return a.point.distance_squared_to(game.player_point) < b.point.distance_squared_to(game.player_point))
	var wanted := {}
	for record in candidates.slice(0,int(Catalog.DATA.max_nodes)):
		wanted[record.id] = record
		if not models.has(record.id):
			var family := styles.family_for(record.biome)
			var template_key: String = record.item + ":" + family
			if not visual_templates.has(template_key):
				visual_templates[template_key] = Visual.model(Catalog.DATA.items[record.item],family)
			var model: Node3D = visual_templates[template_key].duplicate()
			model.position = Vector3(record.point.x,world.ground_height(record.point) + .025,record.point.y)
			model.set_meta("forage_id",record.id)
			add_child(model)
			models[record.id] = model
	for id in models.keys():
		if not wanted.has(id):
			models[id].free()
			models.erase(id)
	nodes = wanted

func target() -> Dictionary:
	if game == null or game.layer != "overworld" or game.state != "playing" or not game.grounded or not game.offline_actions_allowed():
		return {}
	var result := {}
	var distance := float(Catalog.DATA.reach)
	for record in nodes.values():
		var delta: float = game.player_point.distance_to(record.point)
		if delta < distance and absf(game.player_y - game.world.ground_height(record.point)) < .75 and game.dungeon.line_clear(game.player_point,record.point):
			result = record
			distance = delta
	return result

func hint() -> String:
	var record := target()
	return "" if record.is_empty() else "E: Gather " + Catalog.DATA.items[record.item].name

func interact() -> bool:
	var record := target()
	if record.is_empty():
		return false
	harvest(record)
	return true

func harvest(record: Dictionary) -> bool:
	if record.is_empty() or not nodes.has(record.get("id", "")) or nodes[record.id] != record or harvested.has(record.id) or target().get("id", "") != record.id:
		return false
	if harvested.size() >= Catalog.DATA.ledger_limit:
		game.notify("Your gathering ledger is full.")
		return false
	if not game.inventory.add(record.item,int(record.quantity)):
		game.notify("Your backpack is full. Make room before gathering.")
		return false
	harvested[record.id] = true
	models[record.id].free()
	models.erase(record.id)
	nodes.erase(record.id)
	marker.hide()
	game.notify("Gathered %s x%s." % [Catalog.DATA.items[record.item].name,record.quantity])
	game._auto_save()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for model in visual_templates.values():
			model.free()
