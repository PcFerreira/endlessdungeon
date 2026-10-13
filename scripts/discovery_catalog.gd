extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const CAPABILITIES := ["read_discovery"]
var registry := Registry.new()
var entries: Array[Dictionary] = []
var errors: Array[String] = []
var model_pools: Dictionary = {}

func _init(definitions: Array = []) -> void:
	var source: Array = registry.find("text", ["discovery"]) if definitions.is_empty() else definitions
	for definition in source:
		if not _valid(definition):
			errors.append("Invalid discovery definition: " + str(definition.get("id", "unknown") if definition is Dictionary else "unknown"))
			continue
		var duplicate := false
		for existing in entries:
			duplicate = duplicate or existing.id == definition.id
		if duplicate:
			errors.append("Duplicate discovery ID: " + definition.id)
			continue
		entries.append(definition.duplicate(true))
	entries.sort_custom(func(a, b): return a.id < b.id)

func _valid(entry) -> bool:
	if not entry is Dictionary:
		return false
	for key in ["id", "family", "title", "author", "text", "marker_label"]:
		if not entry.get(key) is String or entry[key].strip_edges().is_empty():
			return false
		if entry[key].length() > (4000 if key == "text" else 512):
			return false
	var version = entry.get("version")
	if not _number(version) or version < 1 or version != floorf(version):
		return false
	for key in ["marker_width", "marker_height"]:
		if not _number(entry.get(key)) or entry[key] <= 0 or entry[key] > 1.5:
			return false
	if not entry.get("biomes") is Array or not entry.get("requires") is Array:
		return false
	for biome in entry.biomes:
		if not _number(biome) or biome != floorf(biome) or biome < 0 or biome > 3:
			return false
	for capability in entry.requires:
		if capability not in CAPABILITIES:
			return false
	var query = entry.get("model_query")
	if not query is Dictionary or not query.get("pack") is String or not query.get("patterns") is Array or not query.get("tags") is Array:
		return false
	for tag in query.tags:
		if not tag is String:
			return false
	for pattern in query.patterns:
		if not pattern is String:
			return false
	return true

func models(entry: Dictionary) -> Array[Dictionary]:
	var key := JSON.stringify(entry.model_query)
	if not model_pools.has(key):
		var result: Array[Dictionary] = []
		for asset in registry.find("model", entry.model_query.tags, entry.model_query.pack):
			if entry.model_query.patterns.any(func(pattern): return asset.id.matchn(pattern)):
				result.append(asset)
		model_pools[key] = result
	return model_pools[key]

func eligible(biome: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		if (entry.biomes.is_empty() or entry.biomes.any(func(value): return int(value) == biome)) and not models(entry).is_empty():
			result.append(entry)
	return result

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))
