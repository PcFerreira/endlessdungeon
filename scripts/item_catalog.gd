extends RefCounted

const Bundles = preload("res://scripts/bundle_catalog.gd")
const Portable = preload("res://scripts/portable_catalog.gd")
const EnemyLoot = preload("res://scripts/enemy_loot.gd")
const Text = preload("res://scripts/player_text.gd")
static var definitions: Dictionary = _definitions()
static var bundles: Dictionary = _bundles()
static var contexts: Dictionary = _contexts()
static var policy: Dictionary = _policy()
static var icon_cache: Dictionary = {}

static func _definitions() -> Dictionary:
	var base = JSON.parse_string(FileAccess.get_file_as_string("res://config/items.json"))
	var result: Dictionary = base.items.duplicate(true)
	for entry in Bundles.entries("items"):
		EnemyLoot.apply_rarity(entry)
		result[entry.id] = entry
	Portable.extend(result)
	for id in result:
		Text.apply_item(id, result[id])
	return result

static func for_asset(model_id: String) -> String:
	return Portable.for_asset(model_id)

static func _bundles() -> Dictionary:
	var result := {}
	for entry in Bundles.entries("items"):
		if not result.has(entry.source_pack):
			result[entry.source_pack] = []
		result[entry.source_pack].append(entry.id)
	return result

static func _contexts() -> Dictionary:
	var result := {"enemy": {}, "chest": {}}
	for entry in Bundles.entries("items"):
		for source in entry.get("loot_sources", ["enemy", "chest"]):
			if not result[source].has(entry.source_pack):
				result[source][entry.source_pack] = []
			result[source][entry.source_pack].append(entry.id)
	return result

static func _policy() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://config/loot.json"))
	assert(valid_policy(value), "Invalid loot policy")
	return value

static func valid_policy(value) -> bool:
	if not value is Dictionary or value.get("version") != 1:
		return false
	for key in ["enemy_item_chance", "enemy_shard_chance"]:
		if not Bundles.number(value.get(key)) or value[key] < 0 or value[key] > 1:
			return false
	return Bundles.number(value.get("chest_catalogue_items")) and value.chest_catalogue_items >= 0 and value.chest_catalogue_items <= 4 and value.chest_catalogue_items == int(value.chest_catalogue_items)

static func should_drop(seed_value: int, ordinal: int) -> bool:
	return _chance(seed_value, ordinal, "item-chance", float(policy.enemy_item_chance))

static func should_drop_shard(seed_value: int, ordinal: int) -> bool:
	return _chance(seed_value, ordinal, "shard-chance", float(policy.enemy_shard_chance))

static func _chance(seed_value: int, ordinal: int, seed_namespace: String, probability: float) -> bool:
	var random := RandomNumberGenerator.new()
	random.seed = hash("%s:%s:%s" % [seed_namespace, seed_value, ordinal])
	return random.randf() < probability

static func enemy_reward(seed_value: int, ordinal: int, enemy: Dictionary, context: Dictionary) -> String:
	return EnemyLoot.reward(seed_value, ordinal, enemy, context, definitions) if should_drop(seed_value, ordinal) else ""

static func loot(seed_value: int, ordinal: int, source: String = "any") -> String:
	# Visit every source bundle, then every member, without consuming combat RNG.
	var eligible: Dictionary = bundles if source == "any" else contexts.get(source, {})
	var packs: Array = eligible.keys()
	packs.sort()
	if packs.is_empty():
		return "ember_shard"
	var step := maxi(0, ordinal - 1)
	var pack: String = packs[posmod(step + seed_value, packs.size())]
	var pool: Array = eligible[pack]
	var visit := floori(float(step) / packs.size())
	return pool[posmod(visit + (hash(pack + str(seed_value)) & 0x7fffffff), pool.size())]

static func icon(item: Dictionary) -> Texture2D:
	var key: String = item.icon + str(item.get("icon_region", []))
	if not icon_cache.has(key):
		var texture: Texture2D
		if item.icon == "res://assets/items/gold_coin.svg":
			var image := Image.new()
			assert(image.load_svg_from_string(FileAccess.get_file_as_string(item.icon)) == OK)
			texture = ImageTexture.create_from_image(image)
		else:
			texture = load(item.icon)
		if item.has("icon_region"):
			var region: Array = item.icon_region
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(region[0], region[1], region[2], region[3])
			texture = atlas
		icon_cache[key] = texture
	return icon_cache[key]

static func can_use(item: Dictionary, hp: float, max_hp: float, mana: float, max_mana: float) -> bool:
	return item.kind == "consumable" and ((float(item.get("restore_health", 0)) > 0 and hp < max_hp) or (float(item.get("restore_mana", 0)) > 0 and mana < max_mana))
