extends Node3D

const Catalog = preload("res://scripts/micro_biome_catalog.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const View = preload("res://scripts/micro_biome_view.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const MAX_MARKERS := 8
const LEDGER_LIMIT := 4096
const MILESTONE_STEP := 4
var game
var seen := {}
var claimed := {}
var nearby := {}
var planned := {}
var markers := {}
var view := View.new()
var styles := Styles.new()
var context: Array = []
var timer := 0.0

func eligible() -> bool:
	return game != null and game.has_journey and game.layer == "overworld" and game.offline_actions_allowed() and game.world.generator_version == 7 and Catalog.nature_world(game.world, Vector2i(game.player_point.round()))

func _process(delta: float) -> void:
	visible = eligible()
	if not visible:
		if not markers.is_empty():
			clear_location()
		return
	if game.state != "playing":
		for model in markers.values():
			model.get_node("Name").hide()
		return
	timer -= delta
	if timer <= 0:
		timer = .25
		sync()
		observe()
	for id in markers:
		var model: Node3D = markers[id]
		model.get_node("Name").visible = Vector2(model.position.x, model.position.z).distance_to(game.player_point) < 7

func clear_location() -> void:
	for model in markers.values():
		model.free()
	markers.clear()
	nearby.clear()
	planned.clear()
	context.clear()

func reset() -> void:
	clear_location()
	seen.clear()
	claimed.clear()
	timer = 0

func snapshot() -> Dictionary:
	return {"version": 1, "seen": seen.duplicate(), "claimed": claimed.duplicate()}

static func valid(data, expected_seed: String = "") -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not data.get("seen") is Dictionary or not data.get("claimed") is Dictionary or data.seen.size() > LEDGER_LIMIT or data.claimed.size() > LEDGER_LIMIT:
		return false
	if not expected_seed.is_empty() and not Catalog.IntegerText.valid(expected_seed):
		return false
	for ledger in [data.seen, data.claimed]:
		for id in ledger:
			if not id is String or id.length() > 180 or ledger[id] != true or not ledger[id] is bool:
				return false
			var fields := Catalog.fields(id)
			if fields.is_empty() or (not expected_seed.is_empty() and fields.seed != expected_seed.to_int()):
				return false
	for id in data.claimed:
		if not data.seen.has(id):
			return false
	return true

func restore(data: Dictionary, expected_seed: String = "") -> bool:
	if not valid(data, expected_seed):
		return false
	reset()
	seen = data.get("seen", {}).duplicate()
	claimed = data.get("claimed", {}).duplicate()
	return true

func sync(force: bool = false) -> void:
	if not eligible():
		clear_location()
		return
	var world = game.world
	var current: Array = [world.get_instance_id(), world.run_seed, world.generator_version, world.current_chunk]
	if not force and current == context:
		return
	var previous := planned
	if context.is_empty() or context.slice(0, 3) != current.slice(0, 3):
		previous = {}
	context = current
	planned = {}
	var candidates: Array = []
	var bounds: Rect2i = world.bounds
	for x in range(floori(float(bounds.position.x) / Composition.FEATURE_SIZE), ceili(float(bounds.end.x) / Composition.FEATURE_SIZE)):
		for y in range(floori(float(bounds.position.y) / Composition.FEATURE_SIZE), ceili(float(bounds.end.y) / Composition.FEATURE_SIZE)):
			var feature := Composition.feature(world.run_seed, Vector2i(x, y) * Composition.FEATURE_SIZE + Vector2i.ONE * 32)
			if not bounds.has_point(feature.center):
				continue
			var record: Dictionary = previous[feature.id] if previous.has(feature.id) else Catalog.plan(world, feature)
			planned[feature.id] = record
			if not record.is_empty():
				candidates.append(record)
	candidates.sort_custom(func(a, b): return a.point.distance_squared_to(game.player_point) < b.point.distance_squared_to(game.player_point))
	var wanted := {}
	for record in candidates.slice(0, MAX_MARKERS):
		wanted[record.id] = record
		if not markers.has(record.id):
			create_marker(record)
	for id in markers.keys():
		if not wanted.has(id):
			markers[id].free()
			markers.erase(id)
	nearby = wanted

func create_marker(record: Dictionary) -> void:
	var biome: int = int(game.world.cell_info(record.point).biome)
	var model: Node3D = view.build(record, styles.family_for(biome), claimed.has(record.id))
	if model == null:
		return
	model.position = Vector3(record.point.x, game.world.ground_height(Vector2(record.point)), record.point.y)
	model.set_meta("micro_id", record.id)
	var label := Label3D.new()
	label.name = "Name"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.text = record.name + (" / studied" if claimed.has(record.id) else "  [E]")
	label.font_size = 26
	label.pixel_size = .009
	label.modulate = Color("dec999")
	label.position.y = .85
	label.hide()
	model.add_child(label)
	add_child(model)
	markers[record.id] = model

func observe() -> void:
	if not eligible() or game.state != "playing" or not game.grounded:
		return
	var changed := false
	for record in nearby.values():
		if not seen.has(record.id) and seen.size() < LEDGER_LIMIT and game.player_point.distance_to(Vector2(record.point)) <= 8 and game.world.line_clear(game.player_point, Vector2(record.point)):
			seen[record.id] = true
			game.notify("Discovered " + record.name)
			changed = true
	if changed:
		game._auto_save()

func target() -> Dictionary:
	if not eligible() or game.state != "playing" or not game.grounded:
		return {}
	sync()
	var closest := 1.85
	var result := {}
	for record in nearby.values():
		var point := Vector2(record.point)
		var distance: float = game.player_point.distance_to(point)
		if distance < closest and absf(game.player_y - game.world.ground_height(point)) <= .75 and game.world.line_clear(game.player_point, point):
			closest = distance
			result = record
	return result

func hint() -> String:
	var record := target()
	if record.is_empty():
		return ""
	return "E: " + ("Read " if claimed.has(record.id) else "Explore ") + record.name

func distinct_claims() -> Dictionary:
	var result := {}
	for id in claimed:
		var fields := Catalog.fields(id)
		if not fields.is_empty():
			result[fields.profile_id] = true
	return result

func claim(record: Dictionary) -> bool:
	if record.is_empty() or target().get("id", "") != record.get("id", "") or not nearby.has(record.id) or nearby[record.id] != record or claimed.has(record.id) or seen.size() >= LEDGER_LIMIT and not seen.has(record.id):
		return false
	var feature := Composition.feature(game.run_seed, record.center)
	if Catalog.plan(game.world, feature) != record:
		return false
	var before: Dictionary = game.inventory.snapshot()
	if not game.inventory.add(record.reward_item, int(record.quantity)) or not game.inventory.add("gold_coin", int(record.coins)):
		game.inventory.restore(before, game.build.class_id)
		game.notify("Your backpack is full. Make room before exploring the cache.")
		return false
	var kinds := distinct_claims()
	seen[record.id] = true
	claimed[record.id] = true
	var milestone: bool = not kinds.has(record.profile_id) and (kinds.size() + 1) % MILESTONE_STEP == 0
	if milestone:
		game.build.skill_points += 1
	game.notify("%s: %s x%s and %s coins.%s" % [record.name, game.inventory.ITEMS[record.reward_item].name, record.quantity, record.coins, " Exploration earned a skill point." if milestone else ""])
	if markers.has(record.id):
		markers[record.id].free()
		markers.erase(record.id)
	create_marker(record)
	game._auto_save()
	return true

func interact() -> bool:
	var record := target()
	if record.is_empty():
		return false
	if claimed.has(record.id):
		game.notify(record.name + ": " + record.flavor + " Already studied.")
	else:
		claim(record)
	return true

func journal_rows(parent: VBoxContainer) -> void:
	var types := distinct_claims().size()
	game.interface._label(parent, "Small wild places / %s discovered / %s types studied" % [seen.size(), types], 17, Color("c3a576"))
	game.interface._label(parent, "Explore four different types to earn one skill point. A studied cache stays claimed.", 14)
	if seen.is_empty():
		game.interface._label(parent, "Look for fairy rings, sheltered groves and small caches beyond the roads.", 14)
	var ids: Array = seen.keys().slice(-64)
	ids.reverse()
	for id in ids:
		var fields := Catalog.fields(id)
		var profile := Catalog.by_id(fields.profile_id)
		game.interface._label(parent, "%s / %s\n%s" % [profile.name, "Studied" if claimed.has(id) else "Discovered", profile.flavor], 14)
	if seen.size() > 64:
		game.interface._label(parent, "Showing your latest 64 discoveries; all claims remain recorded.", 14)
