extends RefCounted

const Content = preload("res://scripts/world_content.gd")
const Bundles = preload("res://scripts/bundle_catalog.gd")
const Edits = preload("res://scripts/content_edits.gd")
const Wonder = preload("res://scripts/wonder_catalog.gd")
static var content := Content.new()
static var TYPES: Array = _types()

static func _types(apply_edits: bool = true) -> Array:
	var entries := content.entries("enemies").duplicate()
	entries.sort_custom(func(a, b): return int(a.get("legacy_kind", 100)) < int(b.get("legacy_kind", 100)))
	entries.append_array(Bundles.entries("enemies"))
	entries.append_array(Wonder.enemy_definitions())
	return Edits.enemies(entries) if apply_edits else entries

static func source_types() -> Array:
	return _types(false)

static func combat_stats(definition: Dictionary, depth: int) -> Dictionary:
	return Edits.combat_stats(definition, depth)

static func should_engage(definition: Dictionary, active: bool, in_sight: bool) -> bool:
	if not definition.get("aggressive", true) and not definition.get("retaliates", true):
		return false
	return active or (definition.get("aggressive", true) and in_sight)

static func after_hit(definition: Dictionary, active: bool) -> bool:
	return should_engage(definition, active, false) or definition.get("retaliates", true)

static func refresh(path: String = Content.PATH) -> bool:
	if not content.reload(path):
		return false
	TYPES = _types()
	return true

static func names() -> Array:
	return TYPES.map(func(entry): return entry.name)

static func index_of(id: String, fallback: int = 0) -> int:
	for index in range(TYPES.size()):
		if TYPES[index].id == id:
			return index
	return fallback

static func surface_pool(biome: int, facet: String = "", ecology_id: String = "") -> Array:
	var pool := []
	var special := not facet.is_empty() and TYPES.any(func(entry): return entry.get("enabled", true) and facet in entry.habitat.get("facets", []))
	for index in range(TYPES.size()):
		var habitat: Dictionary = TYPES[index].habitat
		if not TYPES[index].get("enabled", true):
			continue
		if TYPES[index].has("wonder_id") and habitat.has("biome_ids"):
			if ecology_id in habitat.get("biome_ids", []):
				for repeat in range(int(TYPES[index].weight)):
					pool.append(index)
			continue
		if "*" in habitat.get("facets", []) or (special and facet in habitat.get("facets", [])) or (not special and habitat.get("biomes", []).any(func(value): return int(value) == biome)):
			for repeat in range(int(TYPES[index].weight)):
				pool.append(index)
	return pool

static func dungeon_pool(family: String) -> Array:
	var pool := []
	for index in range(TYPES.size()):
		if not TYPES[index].get("enabled", true):
			continue
		if family in TYPES[index].habitat.get("families", []) or "*" in TYPES[index].habitat.get("families", []):
			for repeat in range(int(TYPES[index].weight)):
				pool.append(index)
	return pool
