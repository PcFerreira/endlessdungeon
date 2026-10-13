extends RefCounted

const Areas = preload("res://scripts/area_catalog.gd")
const Style = preload("res://scripts/town_style.gd")
const PATH := "res://config/town_types.json"
static var DATA: Dictionary = _read()

static func _read() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(document),"Invalid town identities: " + PATH)
	return document

static func _text(value) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _color(value) -> bool:
	return value is String and value.length() == 6 and value.is_valid_hex_number()

static func _weight(value) -> bool:
	return Areas._number(value) and value == int(value) and value >= 1 and value <= 32

static func magic_profile(entry: Dictionary, document: Dictionary = DATA) -> Dictionary:
	var result: Dictionary = entry.magic.duplicate(true)
	result.erase("form")
	result.roof_charm_cap = 8
	result.rune_distances = [5,10]
	result.pieces = []
	for piece in document.forms[entry.magic.form]:
		result.pieces.append({"point":piece[0],"size":piece[1],"color":piece[2]})
	return result

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not _weight(document.get("base_weight")) or not document.get("types") is Dictionary or document.types.is_empty() or not document.get("forms") is Dictionary:
		return false
	for id in document.types:
		var entry = document.types[id]
		if not _text(id) or Areas.CITIES.has(id) or not entry is Dictionary or not _text(entry.get("name")) or not _text(entry.get("trade")) or not Areas.CITIES.has(entry.get("base")) or not _weight(entry.get("weight")) or not Areas._biomes(entry.get("biomes")):
			return false
		if not entry.biomes.all(func(biome): return Areas.CITIES[entry.base].biomes.has(int(biome))) or not Areas.DATA.building_uses.has(entry.get("signature_use")):
			return false
		if entry.has("exterior_style") and (entry.exterior_style not in Style.STYLES or entry.get("theme_id") not in ["japanese","chinese","korean","halloween","christmas","cyberpunk","mage","fairy"]):
			return false
		var architecture = entry.get("architecture")
		if not architecture is Dictionary or architecture.keys().any(func(key): return key not in ["wall_color","roof_colors","roof_shape"]) or not _color(architecture.get("wall_color")) or architecture.get("roof_shape") not in ["gable","hip","flat"] or not architecture.get("roof_colors") is Array or architecture.roof_colors.is_empty() or not architecture.roof_colors.all(_color):
			return false
		if not entry.get("quarters") is Array or entry.quarters.size() != 4 or not entry.quarters.all(_text) or not entry.get("quarter_uses") is Array or entry.quarter_uses.size() != 4:
			return false
		for uses in entry.quarter_uses:
			if not uses is Array or uses.is_empty() or not uses.all(func(use_id): return use_id is String and Areas.DATA.building_uses.has(use_id)):
				return false
		var farm = entry.get("farm")
		if not _text(entry.get("market")) or not farm is Dictionary or farm.keys().any(func(key): return key not in ["name","color","crop_shape"]) or not _text(farm.get("name")) or not _color(farm.get("color")) or farm.get("crop_shape") not in ["grain","leaf","mushroom","root"]:
			return false
		var magic = entry.get("magic")
		if not magic is Dictionary or not document.forms.has(magic.get("form")) or not document.forms[magic.form] is Array:
			return false
		for piece in document.forms[magic.form]:
			if not piece is Array or piece.size() != 3:
				return false
		if not Areas._magic_valid(magic_profile(entry,document)):
			return false
	return true

static func select(base: String, biome: int, seed_value: int) -> String:
	var pool: Array[String] = []
	for index in int(DATA.base_weight):
		pool.append(base)
	for id in DATA.types:
		var entry: Dictionary = DATA.types[id]
		if entry.base == base and entry.biomes.any(func(value): return int(value) == biome):
			for index in int(entry.weight):
				pool.append(id)
	return pool[posmod(seed_value,pool.size())]

static func apply(city: Dictionary, definition: Dictionary, seed_value: int, starting: bool = false) -> Dictionary:
	var id: String = city.archetype_id if starting else select(city.archetype_id,city.biome,seed_value)
	city.settlement_type_id = id
	city.settlement_type_name = Areas.CITIES[id].name if Areas.CITIES.has(id) else DATA.types[id].name
	if not DATA.types.has(id):
		return definition
	var entry: Dictionary = DATA.types[id]
	city.local_trade = entry.trade
	if entry.has("exterior_style"):
		city.exterior_profile = {"style":entry.exterior_style,"color":entry.magic.color,"accent":entry.magic.accent}
		city.theme_id = entry.theme_id
	var result: Dictionary = definition.duplicate(true)
	result.architecture.merge(entry.architecture,true)
	result.density.required_uses = ["charmwright"]
	if entry.signature_use != "charmwright":
		result.density.required_uses.append(entry.signature_use)
	for index in range(4):
		var quarter: Dictionary = result.density.quarters[["nw","ne","sw","se"][index]]
		quarter.name = entry.quarters[index]
		quarter.uses = entry.quarter_uses[index].duplicate()
	for house in city.houses:
		house.architecture = house.architecture.duplicate(true)
		house.architecture.merge(entry.architecture,true)
	for lot in city.outdoor_lots:
		lot.recipe = lot.recipe.duplicate(true)
		if lot.kind == "farm":
			lot.recipe.merge(entry.farm,true)
		else:
			lot.recipe.name = entry.market
			lot.recipe.color = entry.magic.accent
		lot.name = lot.recipe.name
	return result

static func profile_for(city: Dictionary, definition: Dictionary) -> Dictionary:
	var id: String = city.settlement_type_id
	if DATA.types.has(id):
		return {"id":id + ":charm","profile":magic_profile(DATA.types[id])}
	return {"id":definition.magic_profile,"profile":Areas.DATA.magic_profiles[definition.magic_profile]}
