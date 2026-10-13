extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
var data: Dictionary = {}
var families: Dictionary = {}
var classified: Dictionary = {}
var errors: Array[String] = []

func _init(registry = null, path: String = "res://config/npc_styles.json") -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(document):
		errors.append("Invalid NPC visual-family definitions")
		return
	data = document
	if registry == null:
		registry = Registry.new()
	for family in data.families:
		var pool: Array[Dictionary] = []
		var seen := {}
		for query in data.families[family].queries:
			for asset in registry.find("model", query.tags, query.pack):
				if seen.has(asset.id) or not query.patterns.any(func(pattern): return asset.id.matchn(pattern)):
					continue
				if classified.has(asset.id):
					errors.append("NPC belongs to multiple visual families: " + asset.id)
					continue
				seen[asset.id] = true
				classified[asset.id] = family
				pool.append(asset)
		pool.sort_custom(func(a, b): return a.id < b.id)
		families[family] = pool
		if pool.is_empty():
			errors.append("Empty NPC visual family: " + family)

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("families") is Dictionary or document.families.is_empty():
		return false
	for family in document.families.values():
		if not family is Dictionary or not family.get("name") is String or family.name.is_empty() or not family.get("queries") is Array or family.queries.is_empty():
			return false
		if family.has("environment_family") and (not family.environment_family is String or family.environment_family.is_empty()):
			return false
		var animations = family.get("animations", {})
		if not animations is Dictionary:
			return false
		for action in animations:
			if not action is String or action.is_empty() or not animations[action] is Array or animations[action].is_empty() or not animations[action].all(func(clip): return clip is String and not clip.is_empty()):
				return false
		for query in family.queries:
			if not query is Dictionary or not query.get("pack") is String or not query.get("tags") is Array or not query.tags.all(func(value): return value is String) or not query.get("patterns") is Array or query.patterns.is_empty() or not query.patterns.all(func(value): return value is String):
				return false
	for kind in ["town_families", "road_families"]:
		if not document.get(kind) is Array or document[kind].is_empty() or not document[kind].all(func(id): return id is String and document.families.has(id)):
			return false
	return true

func select(kind: String, identity: String, visual_family: String = "") -> String:
	var choices: Array = data[kind + "_families"].filter(func(id): return not families[id].is_empty() and (visual_family.is_empty() or data.families[id].get("environment_family", "") == visual_family))
	assert(not choices.is_empty(), "NPC family selection needs classified assets")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("npc-family:%s:%s" % [kind, identity])
	return choices[rng.randi_range(0, choices.size() - 1)]

func family_of(asset_id: String) -> String:
	return classified.get(asset_id, "")
