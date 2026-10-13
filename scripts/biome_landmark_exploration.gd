extends Node3D

const Catalog = preload("res://scripts/biome_landmark_catalog.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const Micro = preload("res://scripts/micro_biome_catalog.gd")
const IntegerText = preload("res://scripts/integer_text.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const MAX_MARKERS := 6
const LEDGER_LIMIT := 4096
var game
var seen := {}
var claimed := {}
var nearby := {}
var planned := {}
var markers := {}
var styles := Styles.new()
var models
var context: Array = []
var timer := 0.0

func eligible() -> bool:
	return game != null and game.has_journey and game.layer == "overworld" and game.offline_actions_allowed() and game.world.generator_version == 7 and Micro.nature_world(game.world, Vector2i(game.player_point.round()))

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
	for model in markers.values():
		model.get_node("Name").visible = Vector2(model.position.x, model.position.z).distance_to(game.player_point) < 9

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
	if not expected_seed.is_empty() and not IntegerText.valid(expected_seed):
		return false
	for ledger in [data.seen, data.claimed]:
		for id in ledger:
			if not id is String or id.length() > 180 or not ledger[id] is bool or ledger[id] != true:
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
	if models == null:
		models = load("res://scripts/biome_landmark_models.gd").new()
	var biome: int = int(game.world.cell_info(record.point).biome)
	var model: Node3D = models.create(record, styles.family_for(biome), claimed.has(record.id))
	model.position = Vector3(record.center.x, record.height, record.center.y)
	model.rotation.y = int(record.turn) * PI / 2
	model.set_meta("landmark_id", record.id)
	for part in model.find_children("*", "MeshInstance3D", true, false):
		if part.get_meta("obstructing", false):
			for surface in part.mesh.get_surface_count():
				var original = part.get_active_material(surface)
				if original is StandardMaterial3D and not original.emission_enabled:
					part.set_surface_override_material(surface, game.world_view._cutaway_material(original))
	var label := Label3D.new()
	label.name = "Name"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.text = record.name + (" / visited" if claimed.has(record.id) else "  [E]")
	label.font_size = 26
	label.pixel_size = .009
	label.modulate = Color("dec999")
	label.position = Vector3(record.door_local.x, 1.2, record.door_local.y)
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
	var action := "Rest at " if record.interaction == "well" else ("Read " if record.interaction == "story" or claimed.has(record.id) else "Search ")
	return "E: " + action + record.name

func claim(record: Dictionary) -> bool:
	if record.is_empty() or target().get("id", "") != record.get("id", "") or not nearby.has(record.id) or nearby[record.id] != record or claimed.has(record.id) or seen.size() >= LEDGER_LIMIT and not seen.has(record.id):
		return false
	if Catalog.plan(game.world, Composition.feature(game.run_seed, record.center)) != record:
		return false
	if record.interaction in ["story", "well"] and not game.sanctum_problem().is_empty():
		return false
	if record.interaction == "cache":
		var before: Dictionary = game.inventory.snapshot()
		if not game.inventory.add(record.reward_item, int(record.quantity)) or not game.inventory.add("gold_coin", int(record.coins)):
			game.inventory.restore(before, game.build.class_id)
			game.notify("Your backpack is full. Make room before searching the cache.")
			return false
	seen[record.id] = true
	claimed[record.id] = true
	if record.interaction == "cache":
		game.notify("%s: %s x%s and %s coins." % [record.name, game.inventory.ITEMS[record.reward_item].name, record.quantity, record.coins])
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
	if record.interaction in ["story", "well"] and not game.sanctum_problem().is_empty():
		game.notify("Find safe ground before resting or reading here.")
		return true
	var visited := claimed.has(record.id)
	if not visited and not claim(record):
		return true
	if record.interaction == "well":
		game.hp = game.max_hp
		game.mana = game.max_mana
		game.notify(record.name + ": health and mana restored.")
		game._auto_save()
	elif record.interaction == "story" or visited:
		game.exploration.open_landmark(record)
	return true

func close() -> void:
	game.exploration.close()

func saved_record(id: String) -> Dictionary:
	var fields := Catalog.fields(id)
	var feature := Composition.feature(fields.seed, fields.grid * Composition.FEATURE_SIZE + Vector2i.ONE * 32)
	var biome: Dictionary = game.world.biome_at(feature.center)
	var profile := Catalog.profile_for(fields.seed, feature.id, biome.biome_id)
	if profile.is_empty() or profile.kind != fields.kind:
		profile = Catalog.by_id(fields.kind)
	profile.id = id
	return profile

func open_saved(id: String) -> void:
	if game.state != "journal" or not seen.has(id):
		return
	game.expansion.overlay.hide()
	game.exploration.open_landmark(saved_record(id), "journal")

func journal_rows(parent: VBoxContainer) -> void:
	game.interface._label(parent, "Wild constructions / %s discovered" % seen.size(), 17, Color("c3a576"))
	if seen.is_empty():
		game.interface._label(parent, "Look for old stones, wells and towers in clearings beyond the roads.", 14)
	var ids: Array = seen.keys().slice(-64)
	ids.reverse()
	for id in ids:
		var profile := saved_record(id)
		var row: VBoxContainer = game.interface._vbox(parent, 4)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game.interface._button(row, "%s / %s" % [profile.name, "Visited" if claimed.has(id) else "Discovered"], open_saved.bind(id), Vector2(0, 40))
		var story: Label = game.interface._label(row, profile.flavor, 14)
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if seen.size() > 64:
		game.interface._label(parent, "Showing your latest 64 constructions; all visits remain recorded.", 14)
