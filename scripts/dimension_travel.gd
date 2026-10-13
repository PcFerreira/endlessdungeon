extends Node3D

const Catalog = preload("res://scripts/dimension_catalog.gd")
const FiniteWorld = preload("res://scripts/finite_world.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const SurfaceLocations = preload("res://scripts/surface_locations.gd")
const HubWorld = preload("res://scripts/hub_world.gd")
const FloatingHub = preload("res://scripts/floating_hub.gd")
var game
var active := false
var id := ""
var map_revision := 0
var last_point := Vector2.INF
var sanctum_point := Vector2(5, 7)
var hub: Dictionary = {}
var hub_point := Vector2.ZERO
var outside_return: Dictionary = {}
var gate: Node3D
var gate_label: Label3D

static func portal_point() -> Vector2:
	var definition := Catalog.definition()
	return Vector2(definition.sanctum_portal[0], definition.sanctum_portal[1])

static func vector(value) -> bool:
	return value is Array and value.size() == 2 and value.all(func(number): return (number is int or number is float) and is_finite(float(number)))

static func valid_snapshot(data) -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not data.get("id") is String or not data.get("active") is bool or not vector(data.get("last_point")) or not vector(data.get("sanctum_point")):
		return false
	var definition := Catalog.definition(data.id)
	var revision = data.get("map_revision")
	if definition.is_empty() or not Catalog.integer(revision, 1, 99999):
		return false
	if revision != definition.map_version and not definition.get("compatible_revisions", []).any(func(compatible): return compatible == revision):
		return false
	var point := Vector2(data.last_point[0], data.last_point[1])
	var home := Vector2(data.sanctum_point[0], data.sanctum_point[1])
	if not Rect2(Catalog.box(definition.bounds)).has_point(point) or not Catalog.valid_point(data.id, point) or home.distance_to(portal_point()) >= 1.8 or not FloatingHub.valid(data.get("hub", {})) or data.get("hub", {}).is_empty() or not vector(data.get("hub_point")) or not data.get("outside_return", {}) is Dictionary:
		return false
	return Vector2(data.hub_point[0], data.hub_point[1]).distance_to(FloatingHub.portal_point("dimension")) < 1.8

func _ready() -> void:
	gate = Voxels.instance(Voxels.portal())
	gate.scale = Vector3.ONE * .75
	add_child(gate)
	gate_label = Label3D.new()
	gate_label.text = "Lanternwake [E]"
	gate_label.position.y = 1.8
	gate_label.font_size = 32
	gate_label.pixel_size = .006
	gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(gate_label)
	gate.hide()

func _process(_delta: float) -> void:
	if gate == null or game == null:
		return
	gate.visible = active and game.layer == "overworld"
	if gate.visible:
		var point: Vector2 = game.world.return_portal
		gate.position = game.to_world(point)

func reset() -> void:
	active = false
	id = ""
	map_revision = 0
	last_point = Vector2.INF
	hub.clear()
	outside_return.clear()
	if gate != null:
		gate.hide()

func snapshot() -> Dictionary:
	if id.is_empty():
		return {}
	if active and game.layer == "overworld":
		last_point = game.player_point
	return {"version": 1, "id": id, "map_revision": map_revision, "active": active, "last_point": [last_point.x, last_point.y], "sanctum_point": [sanctum_point.x, sanctum_point.y], "hub": hub.duplicate(true), "hub_point": [hub_point.x, hub_point.y], "outside_return": outside_return.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data):
		return false
	reset()
	if data.is_empty():
		return true
	id = data.id
	map_revision = int(Catalog.definition(id).map_version)
	active = data.active
	last_point = Vector2(data.last_point[0], data.last_point[1])
	sanctum_point = Vector2(data.sanctum_point[0], data.sanctum_point[1])
	hub = data.hub.duplicate(true)
	hub_point = Vector2(data.hub_point[0], data.hub_point[1])
	outside_return = data.get("outside_return", {}).duplicate(true)
	return true

func remember_origin(origin: Dictionary, home_point: Vector2) -> void:
	var definition := Catalog.definition()
	if id.is_empty():
		id = definition.id
		map_revision = int(definition.map_version)
		last_point = Vector2(definition.spawn[0], definition.spawn[1])
	outside_return = origin.duplicate(true)
	_strip_dimension(outside_return)
	sanctum_point = home_point
	hub = game.floating_hub.snapshot()
	hub_point = game.floating_hub.portal_point("dimension")

func _strip_dimension(journey: Dictionary) -> void:
	journey.get("progress", {}).erase("dimension")
	for key in ["home", "indoors"]:
		var nested: Dictionary = journey.get(key, {}).get("return_journey", {})
		if not nested.is_empty():
			_strip_dimension(nested)

func enter() -> bool:
	if not game.offline_actions_allowed() or game.state != "playing" or game.layer != "overworld" or not game.world is HubWorld or active or not game.grounded:
		return false
	var entry: Vector2 = game.floating_hub.portal_point("dimension")
	if game.player_point.distance_to(entry) >= 1.8 or not game.dungeon.walkable(game.player_point) or not game.dungeon.line_clear(game.player_point, entry):
		return false
	var definition := Catalog.definition()
	var point := Vector2(definition.spawn[0], definition.spawn[1])
	if id == definition.id and map_revision == definition.map_version and Catalog.valid_point(id, last_point):
		point = last_point
	id = definition.id
	map_revision = int(definition.map_version)
	hub = game.floating_hub.snapshot()
	hub_point = game.player_point
	var cooldowns: Dictionary = game.cooldowns.duplicate()
	var guard: float = game.guard_time
	var world := FiniteWorld.new(id)
	world.generate(game.run_seed, game.world.generator_version)
	active = true
	game.world = world
	game.world_view.reset()
	game.life_view.reset()
	game.life.actors.clear()
	game.active_dungeon.clear()
	game.waypoint.clear()
	game.interiors.current.clear()
	game.interiors.return_journey.clear()
	game.exploration.book_region = ""
	game.exploration.view.hide()
	game.sanctuary = Vector2(world.start)
	game.surface_return_point = point
	game._generate_surface(point, false)
	game.cooldowns = cooldowns
	game.guard_time = guard
	last_point = game.player_point
	game.state = "playing"
	game.notify("%s. Tab opens its map. H returns to Lanternwake." % definition.name)
	game.sound.play_spell("gate")
	game._auto_save()
	return true

func return_to_hub() -> bool:
	if not game.offline_actions_allowed() or not active or hub.is_empty():
		return false
	snapshot()
	game._snapshot_encounters()
	var world := HubWorld.new()
	world.hub.set_theme(hub.theme)
	world.generate(game.run_seed, game.world.generator_version)
	var cooldowns: Dictionary = game.cooldowns.duplicate()
	var guard: float = game.guard_time
	active = false
	game.world = world
	game.world_view.reset()
	game.sanctuary = world.hub.spawn
	game.surface_return_point = hub_point
	game._generate_surface(hub_point, false)
	game.cooldowns = cooldowns
	game.guard_time = guard
	game.state = "playing"
	game.notify("Returned to Lanternwake. The Sanctum gate holds your original return thread.")
	game.sound.play_spell("gate")
	game._auto_save()
	return true

func return_to_sanctum() -> bool:
	return return_to_hub()

func leave_for_hub() -> void:
	snapshot()
	active = false
	if gate != null:
		gate.hide()

func location_name() -> String:
	var definition := Catalog.definition(id)
	var area: Dictionary = game.world.area_at(Vector2i(game.player_point.round()))
	if not area.is_empty():
		return "%s / %s" % [area.name, definition.name]
	return definition.name

func hint() -> String:
	if not game.offline_actions_allowed():
		return ""
	if not active or game.layer != "overworld":
		return ""
	if game.player_point.distance_to(Vector2(game.world.return_portal)) < 1.8:
		return "E: Return to Lanternwake"
	var book: Dictionary = game.expansion.target()
	if book.get("kind") == "book":
		return "E: Read " + game.expansion.Lore.BOOKS[book.book_id].title
	var citizen_hint: String = game.population.hint()
	if not citizen_hint.is_empty():
		return citizen_hint
	var shelter: Dictionary = SurfaceLocations.rest_target(game.world, game.player_point)
	if not shelter.is_empty():
		return "E: Rest at " + shelter.name
	var forage_hint: String = game.foraging.hint()
	if not forage_hint.is_empty():
		return forage_hint
	return "H: Return to Lanternwake / Tab: %s map" % Catalog.definition(id).name

func interact() -> bool:
	if not game.offline_actions_allowed() or game.state != "playing":
		return false
	if not active or game.layer != "overworld":
		return false
	if game.player_point.distance_to(Vector2(game.world.return_portal)) < 1.8 and game.world.line_clear(game.player_point, Vector2(game.world.return_portal)):
		return return_to_hub()
	var book: Dictionary = game.expansion.target()
	if book.get("kind") == "book":
		return game.expansion.read_book(book.book_id)
	if game.population.interact():
		return true
	var shelter: Dictionary = SurfaceLocations.rest_target(game.world, game.player_point)
	var town: Dictionary = game.world.nearest_site(game.player_point, "city")
	var resting: bool = not shelter.is_empty() or not town.is_empty() and game.player_point.distance_to(Vector2(town.cell)) < 2.5
	if resting:
		var problem: String = game.sanctum_problem()
		if not problem.is_empty():
			game.notify(problem)
			return true
		game.hp = game.max_hp
		game.mana = game.max_mana
		var site: Dictionary = shelter if not shelter.is_empty() else town
		game.exploration.knowledge.remember(site, "visited", str(game.run_seed))
		game.notify("Rested at " + site.name)
		game._auto_save()
		return true
	if game.foraging.interact():
		return true
	game.notify("Explore %s. H returns to Lanternwake." % Catalog.definition(id).name)
	return true
