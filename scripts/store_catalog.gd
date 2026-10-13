extends RefCounted

const Items = preload("res://scripts/item_catalog.gd")
var data: Dictionary = {}

func _init() -> void:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://config/stores.json"))
	assert(valid(value), "Invalid stores catalogue")
	data = value

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not Items.definitions.has(value.get("currency", "")):
		return false
	for key in ["profiles", "uses", "interiors", "lots", "prices", "rarity_multipliers", "item_prices"]:
		if not value.get(key) is Dictionary:
			return false
	if not integer(value.get("purse"), 1, 999) or not integer(value.get("stock_limit"), 1, 999) or not value.get("staples") is Array or not numeric(value.get("buyback_fraction")) or value.buyback_fraction <= 0 or value.buyback_fraction >= 1:
		return false
	for profile in value.profiles.values():
		if not profile is Dictionary or not profile.get("name") is String or not profile.get("kinds") is Array or not profile.get("slots") is Array or not integer(profile.get("selection"), 1, 24) or not integer(profile.get("stock"), 1, value.stock_limit):
			return false
		if not profile.kinds.all(func(kind): return kind in ["consumable", "material", "furnishing", "equipment"]) or not profile.slots.all(func(slot): return slot in ["weapon", "armor", "charm"]):
			return false
	for key in ["uses", "lots"]:
		if not value[key].values().all(func(profile): return value.profiles.has(profile)):
			return false
	for interior in value.interiors.values():
		if not interior is Dictionary or not value.profiles.has(interior.get("profile", "")) or not interior.get("point") is Array or interior.point.size() != 2 or not interior.point.all(numeric):
			return false
	for key in ["prices", "rarity_multipliers", "item_prices"]:
		if not value[key].values().all(func(price): return integer(price, 1, 999)):
			return false
	return value.staples.all(func(id): return Items.definitions.has(id)) and value.item_prices.keys().all(func(id): return Items.definitions.has(id))

static func numeric(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func integer(value, minimum: int, maximum: int) -> bool:
	return numeric(value) and value == floorf(value) and value >= minimum and value <= maximum

func accepts(profile: String, id: String) -> bool:
	var item: Dictionary = Items.definitions.get(id, {})
	if item.is_empty() or item.get("retired", false) or item.get("world_prop", false) or id == data.currency or item.get("currency", "") != "":
		return false
	var definition: Dictionary = data.profiles.get(profile, {})
	return not definition.is_empty() and item.kind in definition.kinds and (item.kind != "equipment" or definition.slots.is_empty() or item.slot in definition.slots)

func price(id: String) -> int:
	var item: Dictionary = Items.definitions[id]
	return clampi(int(data.item_prices.get(id, data.prices.get(item.kind, 1))) * int(data.rarity_multipliers.get(item.get("rarity", "common"), 1)), 1, 999)

func initial(source: Dictionary, seed_value: int) -> Dictionary:
	var profile: Dictionary = data.profiles[source.profile]
	var candidates: Array = Items.definitions.keys().filter(func(id): return accepts(source.profile, id))
	candidates.sort()
	var random := RandomNumberGenerator.new()
	random.seed = hash("store:%s:%s" % [seed_value, source.id])
	var stock := {}
	for id in data.staples:
		if accepts(source.profile,id) and stock.size() < profile.selection:
			stock[id] = int(profile.stock)
			candidates.erase(id)
	while stock.size() < profile.selection and not candidates.is_empty():
		var id: String = candidates.pop_at(random.randi_range(0,candidates.size() - 1))
		stock[id] = int(profile.stock)
	return {"profile": source.profile, "stock": stock, "purse": int(data.purse)}
