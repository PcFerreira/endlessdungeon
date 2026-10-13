extends RefCounted

const Bundles = preload("res://scripts/bundle_catalog.gd")
static var data: Dictionary = _read()
static var choices: Dictionary = {}

static func _read() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://config/loot_pools.json"))
	assert(valid(value), "Invalid enemy loot source pools")
	return value

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("pools") is Dictionary or value.pools.is_empty() or not value.get("profiles") is Array or value.profiles.is_empty() or not value.get("contexts") is Array or not value.get("rarity_rules") is Array or not value.get("rarity_weights") is Dictionary:
		return false
	for weight in value.rarity_weights.values():
		if not positive_weight(weight):
			return false
	if value.rarity_weights.size() != 3 or not ["common", "uncommon", "rare"].all(func(tier): return value.rarity_weights.has(tier)):
		return false
	for query in value.pools.values():
		if not query is Dictionary or not strings(query.get("kinds")) or not strings(query.get("packs")) or not strings(query.get("names")):
			return false
		for kind in query.kinds:
			if kind not in ["material", "consumable", "equipment"]:
				return false
	for profile in value.profiles + value.contexts:
		var weights = profile.get("weights", profile.get("add_weights", {}))
		if not weights is Dictionary or weights.is_empty():
			return false
		for pool in weights:
			if not value.pools.has(pool) or not positive_weight(weights[pool]):
				return false
	for profile in value.profiles:
		if not profile.get("id") is String or not strings(profile.get("enemies")):
			return false
	for rule in value.rarity_rules:
		if not rule is Dictionary or rule.get("rarity") not in value.rarity_weights or not strings(rule.get("kinds")) or not strings(rule.get("names")):
			return false
	for bonuses in value.get("rarity_bonuses", {}).values():
		if not bonuses is Dictionary:
			return false
		for key in bonuses:
			if key not in ["power", "hp", "mana"] or not Bundles.number(bonuses[key]) or bonuses[key] <= 0 or bonuses[key] > (1 if key == "power" else 100):
				return false
	return true

static func strings(value) -> bool:
	return value is Array and not value.is_empty() and value.all(func(text): return text is String and not text.is_empty() and text.length() <= 512)

static func positive_weight(value) -> bool:
	return Bundles.number(value) and value > 0 and value <= 1000 and value == int(value)

static func matches(text: String, patterns: Array) -> bool:
	return patterns.any(func(pattern): return text.matchn(str(pattern)))

static func rarity(item: Dictionary) -> String:
	var result := "common"
	for rule in data.rarity_rules:
		if item.kind in rule.kinds and matches(item.get("classification_name", item.name), rule.names):
			result = rule.rarity
	return result

static func apply_rarity(item: Dictionary) -> void:
	if item.kind != "equipment":
		return
	item.rarity = rarity(item)
	var bonuses: Dictionary = data.get("rarity_bonuses", {}).get(item.rarity, {})
	for key in ["power", "hp", "mana"]:
		if item.has(key) and bonuses.has(key):
			item[key] = bonuses[key]
	var effects := []
	if item.has("power"):
		effects.append("+%s%% ability damage" % roundi(float(item.power)*100))
	if item.has("hp"):
		effects.append("+%s maximum vitality" % int(item.hp))
	if item.has("mana"):
		effects.append("+%s maximum aether or stamina" % int(item.mana))
	item.description = item.rarity.capitalize() + " " + item.slot + ". " + ", ".join(effects) + ". " + ", ".join(item.classes.map(func(value): return str(value).capitalize())) + "."

static func pool(name: String, class_id: String, definitions: Dictionary) -> Array:
	var key := name + ":" + class_id
	if not choices.has(key):
		var query: Dictionary = data.pools[name]
		var result := []
		for id in definitions:
			var item: Dictionary = definitions[id]
			if item.kind not in query.kinds or (item.kind == "equipment" and class_id not in item.classes):
				continue
			if item.get("retired", false) or item.has("currency") or str(id).begins_with("world_"):
				continue
			if id in query.get("base_items", []) or ("enemy" in item.get("loot_sources", []) and matches(item.get("source_pack", ""), query.packs) and matches(item.get("classification_name", item.name), query.names)):
				result.append(id)
		result.sort()
		choices[key] = result
	return choices[key]

static func table(enemy: Dictionary, context: Dictionary) -> Dictionary:
	var weights := {}
	for profile in data.profiles:
		if matches(enemy.name + " " + enemy.id, profile.enemies):
			weights = profile.weights.duplicate()
			break
	for rule in data.contexts:
		var hit: bool = (context.get("family", "") in rule.get("families", [])) or (context.get("facet", "") in rule.get("facets", [])) or rule.get("biomes", []).any(func(biome): return int(biome) == int(context.get("biome", -1)))
		if not hit:
			continue
		if rule.has("weights"):
			weights = rule.weights.duplicate()
		for name in rule.get("add_weights", {}):
			weights[name] = weights.get(name, 0) + rule.add_weights[name]
	return weights

static func weighted(weights: Dictionary, random: RandomNumberGenerator) -> String:
	var total := 0
	for value in weights.values():
		total += int(value)
	if total <= 0:
		return ""
	var roll := random.randi_range(0, total - 1)
	for key in weights:
		roll -= int(weights[key])
		if roll < 0:
			return key
	return ""

static func reward(seed_value: int, ordinal: int, enemy: Dictionary, context: Dictionary, definitions: Dictionary) -> String:
	var weights := table(enemy, context)
	var class_id: String = context.get("class", "mage")
	for name in weights.keys():
		if pool(name, class_id, definitions).is_empty():
			weights.erase(name)
	if weights.is_empty():
		return ""
	var random := RandomNumberGenerator.new()
	random.seed = hash("enemy-item:%s:%s:%s:%s" % [seed_value, ordinal, enemy.id, context.get("family", "")])
	var pool_name := weighted(weights, random)
	var available := pool(pool_name, class_id, definitions)
	var rarities := {}
	for id in available:
		rarities[rarity(definitions[id])] = data.rarity_weights[rarity(definitions[id])]
	var selected_rarity := weighted(rarities, random)
	var candidates := available.filter(func(id): return rarity(definitions[id]) == selected_rarity)
	return candidates[random.randi_range(0, candidates.size() - 1)]
