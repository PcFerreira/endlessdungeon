extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
const Catalog = preload("res://scripts/wonder_catalog.gd")
static var DATA: Dictionary = Catalog.DATA

static func valid(value) -> bool:
	return Catalog.valid(value)

static func npc(id: String) -> Dictionary:
	return DATA.npcs.get(id,{})

static func npc_for(biome_id: String, seed_value: int) -> String:
	var candidates: Array = DATA.npcs.keys().filter(func(id): return biome_id in DATA.npcs[id].biomes)
	if candidates.is_empty():
		return ""
	candidates.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return candidates[rng.randi_range(0,candidates.size() - 1)]
