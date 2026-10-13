extends RefCounted

const PATH := "res://config/world_areas.json"
static var DATA: Dictionary = _read()
static var CITIES: Dictionary = DATA.cities
static var DUNGEONS: Dictionary = DATA.dungeons

static func _read() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(document), "Invalid area catalogue: " + PATH)
	for section in ["cities","dungeons","facets"]:
		for entry in document[section].values():
			entry.biomes = entry.biomes.map(func(value): return int(value))
			if entry.has("weight"):
				entry.weight = int(entry.weight)
	return document

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1:
		return false
	for section in ["cities","dungeons","biomes","facets","transitions","building_uses"]:
		if not document.get(section) is Dictionary or document[section].is_empty():
			return false
	var geography = document.get("geography")
	if not geography is Dictionary or not _number(geography.get("town_spacing")) or geography.town_spacing < 128 or geography.town_spacing > 512 or int(geography.town_spacing) % 32 != 0 or geography.town_spacing != int(geography.town_spacing):
		return false
	for use in document.building_uses.values():
		if not use is Dictionary or not use.get("name") is String or use.get("interior_type") not in ["home","inn","shop","workshop","shrine"] or not use.get("architecture",{}) is Dictionary:
			return false
	if document.has("magic_profiles"):
		if not document.magic_profiles is Dictionary or document.magic_profiles.is_empty():
			return false
		for profile in document.magic_profiles.values():
			if not _magic_valid(profile):
				return false
	if not document.cities.has(document.get("start_city")) or not document.get("start_families") is Array or document.start_families.size() != 2:
		return false
	for id in document.start_families:
		if not document.dungeons.has(id):
			return false
	for id in document.cities:
		var entry = document.cities[id]
		if not entry is Dictionary or not entry.get("name") is String or not entry.get("role") is String or not entry.get("book") is String or not entry.get("architecture") is Dictionary:
			return false
		if entry.has("magic_profile") and not document.get("magic_profiles",{}).has(entry.magic_profile):
			return false
		if entry.has("density"):
			var density = entry.density
			if not density is Dictionary or not _pair(density.get("additional_buildings")) or density.additional_buildings[0] < 0 or density.additional_buildings[1] < density.additional_buildings[0] or density.additional_buildings[1] > 16 or not density.additional_buildings.all(func(value): return value == int(value)) or not _strings(density.get("required_uses")) or not density.get("quarters") is Dictionary:
				return false
			if density.required_uses.size() > density.additional_buildings[0] or not density.required_uses.all(func(id): return document.building_uses.has(id)):
				return false
			for quarter_id in ["nw","ne","sw","se"]:
				var quarter = density.quarters.get(quarter_id)
				if not quarter is Dictionary or not quarter.get("name") is String or not _strings(quarter.get("uses")) or quarter.uses.is_empty() or not quarter.uses.all(func(use_id): return document.building_uses.has(use_id)):
					return false
		if not _strings(entry.get("props")) or entry.props.is_empty() or not _pair(entry.get("house_count")) or entry.house_count[0] < 1 or entry.house_count[1] < entry.house_count[0]:
			return false
		if not _strings(entry.get("required_buildings")) or entry.required_buildings.is_empty() or entry.required_buildings.size() > entry.house_count[0] or not _strings(entry.get("extra_buildings")) or entry.extra_buildings.is_empty():
			return false
		for use_id in entry.required_buildings + entry.extra_buildings:
			if not document.building_uses.has(use_id):
				return false
			var architecture: Dictionary = entry.architecture.duplicate(true)
			architecture.merge(document.building_uses[use_id].get("architecture",{}),true)
			if not _pair(architecture.get("height")) or architecture.height[0] <= 0 or architecture.height[1] < architecture.height[0] or architecture.get("roof_shape") not in ["gable","hip","flat"]:
				return false
			if architecture.has("roof_colors") and (not _strings(architecture.roof_colors) or architecture.roof_colors.is_empty()):
				return false
		var lots: Array[Rect2i] = []
		var lot_ids := {}
		if not entry.get("outdoor_lots") is Array:
			return false
		for lot in entry.outdoor_lots:
			if not lot is Dictionary or not lot.get("id") is String or lot_ids.has(lot.id) or lot.get("kind") not in ["market","farm"] or not lot.get("name") is String or not lot.get("color") is String or not _pair(lot.get("position")) or not _pair(lot.get("size")) or lot.size[0] != 3 or lot.size[1] != 3:
				return false
			lot_ids[lot.id] = true
			if lot.kind == "farm" and lot.get("crop_shape") not in ["grain","leaf","mushroom","root"]:
				return false
			var origin := Vector2i(lot.position[0],lot.position[1])
			if lot.position[0] != origin.x or lot.position[1] != origin.y or origin.x < -11 or origin.y < -11 or origin.x > 10 or origin.y > 10 or (origin.x < 4 and origin.x + 3 > -3) or (origin.y < 4 and origin.y + 3 > -3):
				return false
			var plot := Rect2i(origin,Vector2i(3,3))
			if plot.intersects(Rect2i(8,8,3,3)) or lots.any(func(previous): return previous.intersects(plot)):
				return false
			lots.append(plot)
		if not _pair(entry.architecture.get("height")) or entry.architecture.height[0] <= 0 or entry.architecture.height[1] < entry.architecture.height[0] or entry.architecture.get("roof_shape") not in ["gable","hip","flat"]:
			return false
		if entry.architecture.has("roof_colors") and (not _strings(entry.architecture.roof_colors) or entry.architecture.roof_colors.is_empty()):
			return false
		if not _biomes(entry.get("biomes")) or not _number(entry.get("weight")) or entry.weight < 1 or entry.weight > 32 or entry.weight != int(entry.weight):
			return false
		if not entry.get("layouts") is Array or entry.layouts.is_empty():
			return false
		var ids := {}
		for layout in entry.layouts:
			if not layout is Dictionary or not layout.get("id") is String or ids.has(layout.id) or not layout.get("plots") is Array or layout.plots.size() < entry.house_count[1]:
				return false
			ids[layout.id] = true
			var plots: Array[Rect2i] = []
			for position in layout.plots:
				if not _pair(position) or position[0] != int(position[0]) or position[1] != int(position[1]):
					return false
				var origin := Vector2i(position[0],position[1])
				var plot := Rect2i(origin,Vector2i(3,3))
				if origin.x < -11 or origin.y < -11 or plot.end.x > 13 or plot.end.y > 13 or (origin.x < 2 and plot.end.x > -1) or (origin.y < 2 and plot.end.y > -1):
					return false
				if plot.intersects(Rect2i(8,8,3,3)):
					return false
				if lots.any(func(lot): return lot.intersects(plot)):
					return false
				for previous in plots:
					if previous.intersects(plot):
						return false
				for anchor in [Vector2i(3,-3),Vector2i(2,-3),Vector2i(3,3),Vector2i(2,3),Vector2i(-3,3),Vector2i(-2,3)]:
					if plot.has_point(anchor):
						return false
				plots.append(plot)
			if entry.has("density"):
				if not layout.get("infill_plots") is Array or layout.infill_plots.size() < entry.density.additional_buildings[0]:
					return false
				var infill: Array[Rect2i] = []
				for position in layout.infill_plots:
					if not _pair(position) or not position.all(func(value): return value == int(value)):
						return false
					var origin := Vector2i(position[0],position[1])
					var plot := Rect2i(origin,Vector2i(2,2))
					if origin.x < -11 or origin.y < -11 or plot.end.x > 12 or plot.end.y > 12 or plot.intersects(Rect2i(-1,-12,3,25)) or plot.intersects(Rect2i(-12,-1,25,3)) or plot.intersects(Rect2i(-3,-3,7,7)) or plot.intersects(Rect2i(8,8,3,3)) or plot.has_point(Vector2i(-12,2)):
						return false
					if plots.any(func(primary): return primary.grow(1).intersects(plot)) or lots.any(func(lot): return lot.intersects(plot)) or infill.any(func(previous): return previous.grow(1).intersects(plot)):
						return false
					infill.append(plot)
	for id in document.dungeons:
		var entry = document.dungeons[id]
		if not entry is Dictionary or not entry.get("name") is String or not entry.get("book") is String or not _number(entry.get("palette")) or entry.palette < 0 or entry.palette > 2 or entry.palette != int(entry.palette) or not _strings(entry.get("roles")) or entry.roles.is_empty() or not _strings(entry.get("props")) or entry.props.is_empty() or not _biomes(entry.get("biomes")) or not _number(entry.get("weight")) or entry.weight < 1 or entry.weight > 32 or entry.weight != int(entry.weight):
			return false
		if entry.has("required_facet") and not document.facets.has(entry.required_facet):
			return false
	for biome in range(4):
		if not document.cities.values().any(func(entry): return entry.biomes.any(func(value): return int(value) == biome)) or not document.dungeons.values().any(func(entry): return not entry.has("required_facet") and entry.biomes.any(func(value): return int(value) == biome)):
			return false
		var entry = document.biomes.get(str(biome))
		if not entry is Dictionary or not entry.get("color") is String or not _number(entry.get("density")) or entry.density < 0 or entry.density > 1000 or not _strings(entry.get("props")) or entry.props.is_empty() or not _strings(entry.get("details")):
			return false
	for id in document.facets:
		var entry = document.facets[id]
		if not entry is Dictionary or not entry.get("name") is String or not entry.get("color") is String or not _biomes(entry.get("biomes")) or not _strings(entry.get("city_types",[])) or not _strings(entry.get("props")) or entry.props.is_empty() or not document.dungeons.has(entry.get("family")) or not document.transitions.has(entry.get("transition")):
			return false
		if not _number(entry.get("radius")) or not _number(entry.get("margin")) or entry.radius <= 0 or entry.margin < entry.radius or entry.margin > 30:
			return false
	return true

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _triple(value) -> bool:
	return value is Array and value.size() == 3 and value.all(_number)

static func _magic_valid(profile) -> bool:
	if not profile is Dictionary or not profile.get("name") is String or not profile.get("account") is String or not profile.get("custom") is String or not profile.get("color") is String or not profile.get("accent") is String or not profile.color.is_valid_hex_number() or profile.color.length() != 6 or not profile.accent.is_valid_hex_number() or profile.accent.length() != 6:
		return false
	if not _number(profile.get("roof_charm_cap")) or profile.roof_charm_cap != int(profile.roof_charm_cap) or profile.roof_charm_cap < 0 or profile.roof_charm_cap > 12 or not profile.get("rune_distances") is Array or profile.rune_distances.is_empty() or profile.rune_distances.size() > 3 or not profile.rune_distances.all(func(value): return _number(value) and value == int(value) and value >= 4 and value <= 11):
		return false
	if not profile.get("pieces") is Array or profile.pieces.is_empty() or profile.pieces.size() > 24:
		return false
	for piece in profile.pieces:
		if not piece is Dictionary or not _triple(piece.get("point")) or not _triple(piece.get("size")) or not piece.size.all(func(value): return value > 0 and value <= 1.2) or not piece.point.all(func(value): return absf(value) <= .75) or piece.get("color") not in ["color","accent"]:
			return false
	return true

static func _pair(value) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])

static func _strings(value) -> bool:
	return value is Array and value.all(func(item): return item is String)

static func _biomes(value) -> bool:
	return value is Array and not value.is_empty() and value.all(func(item): return _number(item) and item == int(item) and item >= 0 and item <= 3)

static func city_type(biome: int, seed_value: int) -> String:
	var pool: Array[String] = []
	for id in CITIES:
		if CITIES[id].biomes.any(func(value): return int(value) == biome):
			for index in range(int(CITIES[id].weight)):
				pool.append(id)
	return pool[posmod(seed_value, pool.size())]

static func family_type(biome: int, facet: String, seed_value: int) -> String:
	var pool: Array[String] = []
	for id in DUNGEONS:
		var entry: Dictionary = DUNGEONS[id]
		if biome in entry.biomes and (not entry.has("required_facet") or entry.required_facet == facet):
			for index in int(entry.weight):
				pool.append(id)
	return pool[posmod(seed_value, pool.size())]
