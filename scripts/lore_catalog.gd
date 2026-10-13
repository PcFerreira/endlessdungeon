extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
static var BOOKS: Dictionary = Registry.new().books()
static var LINES: Array = Registry.new().dialogue_lines()
const ROLE_NAMES := {"fountain_keeper": "Fountain keeper", "milewarden": "Milewarden", "relic_mender": "Relic mender", "retired_delver": "Retired delver"}
const LIFE_CONDITIONS := {"Town supper active": ["supper", "active"], "Town supper finished": ["supper", "aftermath"], "Local delivery active": ["delivery", "active"], "Local delivery finished": ["delivery", "aftermath"]}

static func line(role: String, event: String, context: Dictionary, heard: Array, salt: int) -> Dictionary:
	var pool: Array[Dictionary] = []
	var heard_groups := {}
	for entry in LINES:
		if entry.id in heard:
			heard_groups[entry.get("variant_group", entry.id)] = true
	for entry in LINES:
		if entry.speaker != role or entry.event != event:
			continue
		var condition: String = entry.condition
		if condition not in ["Any", "First meeting", "Met speaker; returned from a linked ruin", "Once per speaker", "Greenwood", "Sunlit Meadows", "Amber Wastes", "Frostlands", "Mage or Spellsword", "Sword", "City name available", "Linked actual ruin", "Local activity"] and not LIFE_CONDITIONS.has(condition):
			continue
		if condition == "Local activity" and (entry.get("life_kind", "").is_empty() or entry.get("life_kind") != context.get("life_kind", "") or entry.get("life_phase", "") != context.get("life_phase", "")):
			continue
		if LIFE_CONDITIONS.has(condition) and (context.get("life_kind", "") != LIFE_CONDITIONS[condition][0] or context.get("life_phase", "") != LIFE_CONDITIONS[condition][1]):
			continue
		if condition == "City name available" and context.get("city_name", "").is_empty():
			continue
		if condition == "Linked actual ruin" and context.get("dungeon_name", "").is_empty():
			continue
		var biomes: Array = entry.get("biomes", [])
		if not biomes.is_empty() and context.get("biome_label", "") not in biomes:
			continue
		if condition.contains("First meeting") and context.get("met", false):
			continue
		if condition.contains("Met speaker") and not context.get("met", false):
			continue
		if condition.contains("returned") and not context.get("returned", false):
			continue
		if condition.contains("Once") and heard_groups.has(entry.get("variant_group", entry.id)):
			continue
		if condition.contains("Future"):
			continue
		if condition in ["Greenwood", "Sunlit Meadows", "Amber Wastes", "Frostlands"] and condition != context.get("biome_label", ""):
			continue
		if condition == "Mage or Spellsword" and context.get("player_class", "") not in ["mage", "spellsword"]:
			continue
		if condition == "Sword" and context.get("player_class", "") != "sword":
			continue
		var result: Dictionary = entry.duplicate()
		for key in ["city_name", "dungeon_name", "biome_label"]:
			result.text = result.text.replace("{%s}" % key, context.get(key, ""))
		if result.text.contains("{") or (entry.text.contains("{dungeon_name}") and context.get("dungeon_name", "").is_empty()):
			continue
		pool.append(result)
	var fresh: Array[Dictionary] = []
	for entry in pool:
		if entry.id not in heard:
			fresh.append(entry)
	if not fresh.is_empty():
		pool = fresh
	if pool.is_empty():
		var neutral_event: String = event if event in ["greeting", "farewell"] else "topic_unknown"
		var neutral: Array = LINES.filter(func(entry): return entry.speaker == "citizen_fallback" and entry.event == neutral_event and entry.condition == "Any")
		if not neutral.is_empty():
			var result: Dictionary = neutral[posmod(salt, neutral.size())].duplicate()
			result.id = ""
			return result
		return {"id": "", "text": "Safe travels." if event == "farewell" else ("Good to see a traveler." if event == "greeting" else "I don't know enough to tell you.")}
	return pool[posmod(salt, pool.size())]

static func topics(role: String) -> Array[String]:
	var result: Array[String] = []
	for entry in LINES:
		if entry.speaker == role and entry.event.begins_with("topic_") and entry.event not in result:
			result.append(entry.event)
	return result
