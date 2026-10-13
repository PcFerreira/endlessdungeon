extends RefCounted

const PATH := "res://config/content_edits.json"
const ITEM_FIELDS := ["name", "description", "enabled", "removed", "kind", "stack", "level", "icon", "icon_region", "asset_id", "source_asset", "source_pack", "slot", "classes", "restore_health", "restore_mana", "hp", "mana", "power", "rarity", "loot_sources"]
const ENEMY_FIELDS := ["name", "enabled", "hp", "damage", "speed", "reach", "windup", "period", "height", "weight", "ranged", "aggressive", "retaliates", "level", "level_mode", "hp_growth", "damage_growth", "facing_degrees", "visual_mode", "animations", "habitat", "visual", "source_asset", "source_pack", "drops"]
static var data: Dictionary = read_document(PATH)

static func empty_document() -> Dictionary:
	return {"version": 1, "items": {}, "enemies": {}, "add_items": [], "add_enemies": []}

static func read_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return empty_document()
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(document):
		push_error("Invalid content edits: " + path)
		return empty_document()
	return document

static func number(value, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(value) and value >= low and value <= high

static func strings(value) -> bool:
	return value is Array and value.all(func(part): return part is String and part.length() <= 512)

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("items") is Dictionary or not document.get("enemies") is Dictionary or not document.get("add_items") is Array or not document.get("add_enemies") is Array:
		return false
	for section in ["items", "enemies"]:
		for id in document[section]:
			if (not id is String and not id is StringName) or id.is_empty() or not patch_valid(document[section][id], section):
				return false
		var seen := {}
		for entry in document["add_" + section]:
			if not entry is Dictionary or not entry.get("id") is String or not entry.id.begins_with("editor:") or seen.has(entry.id):
				return false
			seen[entry.id] = true
			var patch: Dictionary = entry.duplicate(true)
			patch.erase("id")
			if not patch_valid(patch, section) or not entry.get("name") is String or entry.name.is_empty():
				return false
			if section == "items" and (not entry.has("kind") or not entry.has("stack") or not entry.has("icon") or not entry.has("description")):
				return false
			if section == "items" and (not entry.get("source_pack") is String or entry.source_pack.strip_edges().is_empty()):
				return false
			if section == "items" and entry.kind == "equipment" and (entry.get("slot") not in ["weapon", "armor", "charm"] or not strings(entry.get("classes")) or entry.classes.is_empty()):
				return false
			if section == "enemies" and not ["hp", "damage", "speed", "reach", "windup", "period", "height", "weight", "ranged", "habitat", "visual"].all(func(key): return entry.has(key)):
				return false
	return true

static func patch_valid(patch, section: String) -> bool:
	if not patch is Dictionary:
		return false
	var allowed: Array = ITEM_FIELDS if section == "items" else ENEMY_FIELDS
	for key in patch:
		var value = patch[key]
		if key not in allowed:
			return false
		if key in ["name", "description", "asset_id", "source_asset", "source_pack", "icon"] and (not value is String or value.length() > 4096):
			return false
		if key == "name" and value.strip_edges().is_empty():
			return false
		if key == "icon" and (not value.begins_with("res://") or ".." in value.split("/")):
			return false
		if key in ["enabled", "removed", "ranged", "aggressive", "retaliates"] and not value is bool:
			return false
		if key in ["hp", "damage", "speed", "reach", "windup", "period", "height", "weight", "stack", "restore_health", "restore_mana", "mana", "power", "level", "hp_growth", "damage_growth", "facing_degrees"]:
			var minimum := 0.0 if key in ["restore_health", "restore_mana", "mana", "power", "hp_growth", "damage_growth"] or (section == "items" and key == "hp") else .01
			if key == "facing_degrees":
				minimum = -360
			var maximum := 100000.0
			if key == "power":
				maximum = 100
			elif key == "stack":
				maximum = 99
			elif key == "weight":
				maximum = 100
			elif key in ["hp_growth", "damage_growth"]:
				maximum = 10
			elif key == "facing_degrees":
				maximum = 360
			if not number(value, minimum, maximum) or (key in ["stack", "weight", "level"] and (value != int(value) or value < 1)):
				return false
		if key == "kind" and value not in ["bound", "material", "consumable", "equipment", "furnishing"]:
			return false
		if key == "slot" and value not in ["weapon", "armor", "charm"]:
			return false
		if key == "rarity" and value not in ["common", "uncommon", "rare"]:
			return false
		if key == "classes" and (not strings(value) or value.is_empty() or not value.all(func(part): return part in ["mage", "sword", "spellsword"])):
			return false
		if key == "loot_sources" and (not strings(value) or not value.all(func(part): return part in ["enemy", "chest"])):
			return false
		if key == "level_mode" and value not in ["depth", "fixed"]:
			return false
		if key == "visual_mode" and value not in ["automatic", "imported", "generated"]:
			return false
		if key == "icon_region" and value != null and (not value is Array or value.size() != 4 or not value.all(func(part): return number(part, 0, 100000)) or value[2] <= 0 or value[3] <= 0):
			return false
		if key == "habitat":
			if not value is Dictionary or not value.get("biomes") is Array or not value.biomes.all(func(part): return number(part, 0, 3) and part == int(part)) or not strings(value.get("facets")) or not strings(value.get("families")):
				return false
		if key == "visual":
			if not value is Dictionary or not strings(value.get("patterns")) or value.patterns.is_empty() or not strings(value.get("tags", [])) or not value.get("pack", "") is String:
				return false
		if key == "animations" and (not value is Dictionary or not value.keys().all(func(part): return part in ["idle", "walk", "attack"]) or not value.values().all(func(part): return part is String and part.length() <= 256)):
			return false
		if key == "drops" and not drops_valid(value):
			return false
	return true

static func drops_valid(value) -> bool:
	if not value is Dictionary or not value.keys().all(func(key): return key in ["coins", "item_chance", "shard_chance", "orb_chance", "orb_mode", "entries"]):
		return false
	for key in ["item_chance", "shard_chance", "orb_chance"]:
		if value.has(key) and not number(value[key], 0, 1):
			return false
	if value.get("orb_mode", "legacy") not in ["legacy", "none", "health", "mana"]:
		return false
	if value.has("coins") and (not number(value.coins, 0, 10) or value.coins != int(value.coins)):
		return false
	if not value.get("entries", []) is Array or value.get("entries", []).size() > 128:
		return false
	for entry in value.get("entries", []):
		if not entry is Dictionary or not entry.get("item") is String or entry.item.is_empty() or not number(entry.get("weight"), 1, 10000) or entry.weight != int(entry.weight):
			return false
	return true

static func items(source: Dictionary, document: Dictionary = data) -> Dictionary:
	var result := source.duplicate(true)
	for entry in document.add_items:
		if not result.has(entry.id):
			result[entry.id] = entry.duplicate(true)
	for id in document.items:
		if result.has(id):
			result[id].merge(document.items[id], true)
			if document.items[id].has("icon_region") and document.items[id].icon_region == null:
				result[id].erase("icon_region")
	return result

static func enemies(source: Array, document: Dictionary = data) -> Array:
	var result: Array = source.duplicate(true)
	var ids := {}
	for entry in result:
		ids[entry.id] = true
		if document.enemies.has(entry.id):
			entry.merge(document.enemies[entry.id], true)
	for entry in document.add_enemies:
		if not ids.has(entry.id):
			var added: Dictionary = entry.duplicate(true)
			added.merge(document.enemies.get(entry.id, {}), true)
			result.append(added)
	return result

static func combat_stats(definition: Dictionary, depth: int) -> Dictionary:
	var level: int = int(definition.get("level", 1)) + (maxi(0, depth - 1) if definition.get("level_mode", "depth") == "depth" else 0)
	return {"level": level, "hp": definition.hp * (1 + mini(level - 1, 1000) * float(definition.get("hp_growth", .13))), "damage": definition.damage * (1 + mini(level - 1, 80) * float(definition.get("damage_growth", .07)))}
