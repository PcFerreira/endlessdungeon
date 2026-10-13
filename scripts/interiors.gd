extends RefCounted

const Rooms = preload("res://scripts/interior_area.gd")
const View = preload("res://scripts/interior_view.gd")
var game
var view := View.new()
var current: Dictionary = {}
var return_journey: Dictionary = {}

static func describe(city: Dictionary, house: Dictionary) -> Dictionary:
	var index: int = city.houses.find(house)
	var definitions: Array = Rooms.content.entries("interiors")
	var definition: Dictionary = definitions[posmod(index, definitions.size())]
	if Rooms.content.get_entry("interiors", house.get("interior_type", "")).size() > 0:
		definition = Rooms.content.get_entry("interiors", house.interior_type)
	var type: String = definition.id
	var footprint: Rect2i = house.footprint
	var id: String = house.get("id", "%s:house:%s" % [city.id, index])
	var names: Array = definition.get("names", [definition.name])
	return {"id": id, "type": type, "use_id": house.get("use_id", ""), "name": house.get("interior_name", names[posmod(hash(id), names.size())]), "city_id": city.id, "city_name": city.name, "city_cell": city.cell, "biome": city.get("biome", 0), "approach": house.get("approach", Vector2(footprint.position) + Vector2((footprint.size.x - 1) * .5, footprint.size.y + 1))}

func target() -> Dictionary:
	if game.layer != "overworld":
		return {}
	var city: Dictionary = game.world.region_at(Vector2i(game.player_point.round())).city
	if city.is_empty():
		return {}
	var result := {}
	var distance := 1.4
	for house in city.houses:
		var place := describe(city, house)
		var delta: float = game.player_point.distance_to(place.approach)
		if delta < distance and game.world.walkable(place.approach) and game.world.line_clear(game.player_point, place.approach):
			result = place
			distance = delta
	return result

func enter(place: Dictionary) -> bool:
	if not game.offline_actions_allowed():
		return false
	if place.is_empty() or game.state != "playing" or game.layer != "overworld" or not game.grounded:
		return false
	if target().get("id", "") != place.get("id", ""):
		return false
	return_journey = game.make_save_data()
	current = place
	game._generate_interior(place)
	for spell in game.cooldowns:
		game.cooldowns[spell] = return_journey.stats.cooldowns[spell]
	game.guard_time = return_journey.stats.guard
	game.notify("Entered %s." % place.name)
	game._auto_save()
	return true

func leave() -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.layer != "interior" or return_journey.is_empty():
		return false
	var resume := return_journey.duplicate(true)
	var state: Dictionary = game.make_save_data()
	for key in ["build", "character", "inventory", "progress", "stats", "rng_state"]:
		resume[key] = state[key]
	if not game.Journey.restore(game, resume):
		game.notify("The outside route could not be restored. Use sanctuary return in the menu.")
		return false
	current.clear()
	return_journey.clear()
	game.notify("Returned to %s." % game.location_name())
	game._auto_save()
	return true

func snapshot() -> Dictionary:
	if game.layer != "interior":
		return {}
	return {"building_id": current.id, "definition_id": current.type, "name": current.name, "zoom": game.camera.size, "layout_id": current.layout_id, "variants": current.variants.duplicate(), "city_cell": game.Journey.pack(Vector2(current.city_cell)), "return_journey": return_journey.duplicate(true)}

static func resolve(world, data: Dictionary) -> Dictionary:
	var cell := Vector2i(data.city_cell[0], data.city_cell[1])
	var city: Dictionary = world.region_at(cell).city
	if city.is_empty() or city.cell != cell:
		return {}
	for house in city.houses:
		var place := describe(city, house)
		if place.id == data.building_id:
			var definition: Dictionary = Rooms.content.get_entry("interiors", data.definition_id)
			if definition.is_empty() or not definition.layouts.any(func(layout): return layout.id == data.layout_id):
				return {}
			place.type = definition.id
			place.name = data.get("name", definition.name)
			place.layout_id = data.layout_id
			place.variants = data.variants.duplicate()
			if data.has("zoom"):
				place.zoom = data.zoom
			return place
	return {}

func hint() -> String:
	if game.player_point.distance_to(game.dungeon.exit) < 1.4:
		return "E: Return to " + current.city_name
	if game.dungeon.rest_point != Vector2.ZERO and game.player_point.distance_to(game.dungeon.rest_point) < 1.2:
		return "E: Rest"
	for book in game.dungeon.readables:
		if game.player_point.distance_to(book.point) < 1.6 and game.dungeon.line_clear(game.player_point, book.point):
			return "E: Read " + game.expansion.Lore.BOOKS[book.book_id].title
	return game.stores.hint()

func interact() -> void:
	if not game.offline_actions_allowed():
		return
	if game.player_point.distance_to(game.dungeon.exit) < 1.4:
		leave()
	elif game.dungeon.rest_point != Vector2.ZERO and game.player_point.distance_to(game.dungeon.rest_point) < 1.2:
		game.hp = game.max_hp
		game.mana = game.max_mana
		game.notify("Rested in %s." % current.name)
		game._auto_save()
	else:
		for book in game.dungeon.readables:
			if game.player_point.distance_to(book.point) < 1.6 and game.dungeon.line_clear(game.player_point, book.point):
				game.expansion.read_book(book.book_id)
				return
		game.stores.interact()
