extends RefCounted

const Content = preload("res://scripts/world_content.gd")
const Bundles = preload("res://scripts/bundle_catalog.gd")
static var content := Content.new()
static var TYPES: Array = _types()

static func _types() -> Array:
	var entries := content.entries("enemies").duplicate()
	entries.sort_custom(func(a, b): return int(a.get("legacy_kind", 100)) < int(b.get("legacy_kind", 100)))
	entries.append_array(Bundles.entries("enemies"))
	return entries

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

static func surface_pool(biome: int, facet: String = "") -> Array:
	var pool := []
	var special := not facet.is_empty() and TYPES.any(func(entry): return facet in entry.habitat.get("facets", []))
	for index in range(TYPES.size()):
		var habitat: Dictionary = TYPES[index].habitat
		if "*" in habitat.get("facets", []) or (special and facet in habitat.get("facets", [])) or (not special and habitat.get("biomes", []).any(func(value): return int(value) == biome)):
			for repeat in range(int(TYPES[index].weight)):
				pool.append(index)
	return pool

static func dungeon_pool(family: String) -> Array:
	var pool := []
	for index in range(TYPES.size()):
		if family in TYPES[index].habitat.get("families", []) or "*" in TYPES[index].habitat.get("families", []):
			for repeat in range(int(TYPES[index].weight)):
				pool.append(index)
	return pool
