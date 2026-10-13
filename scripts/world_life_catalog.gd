extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Bundles = preload("res://scripts/bundle_catalog.gd")
const CreatureModels = preload("res://scripts/creature_models.gd")
static var creatures := CreatureModels.new()
var registry := Registry.new()
var data: Dictionary = {}
var model_choices: Dictionary = {}
var error := ""

func _init(path: String = "res://config/world_life.json") -> void:
	reload(path)

func reload(path: String) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid(parsed):
		error = "Invalid living-world catalogue: " + path
		return false
	data = parsed
	var existing_models := {}
	for species in data.species:
		for model in registry.find("model", species.models.tags, species.models.get("pack", "")):
			if species.models.patterns.any(func(pattern): return model.id.matchn(pattern)):
				existing_models[model.id] = true
	for species in Bundles.entries("animals"):
		if not existing_models.has(species.source_asset):
			data.species.append(species)
	model_choices.clear()
	for species in data.species:
		species.biomes = species.biomes.map(func(biome): return int(biome))
		var query: Dictionary = species.models
		var choices: Array = []
		if species.has("source_asset"):
			var model := registry.get_asset(species.source_asset)
			if model.get("kind") == "model":
				choices.append(model)
		else:
			choices = registry.find("model", query.tags, query.get("pack", ""))
			choices = choices.filter(func(model): return query.patterns.any(func(pattern): return model.id.to_lower().match(pattern.to_lower())))
		model_choices[species.id] = choices
	error = ""
	return true

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not _number(value.get("cycle_seconds")) or value.cycle_seconds < 30 or value.cycle_seconds > 3600:
		return false
	if not value.get("routines") is Dictionary or not value.routines.has("default") or not value.get("species") is Array or value.species.size() > 1024 or not value.get("episodes") is Array or value.episodes.size() > 16:
		return false
	for routine in value.routines.values():
		if not routine is Dictionary:
			return false
		for key in ["dwell_seconds", "phase_seconds", "speed"]:
			if not _number(routine.get(key)) or routine[key] < .5 or routine[key] > 30:
				return false
	var ids := {}
	var previous_end := 0.0
	for episode in value.episodes:
		if not episode is Dictionary or not episode.get("id") is String or episode.id.is_empty() or ids.has(episode.id) or not episode.get("label") is String or episode.get("visual") not in ["meal", "crates"]:
			return false
		for key in ["start_seconds", "finish_seconds", "end_seconds"]:
			if not _number(episode.get(key)):
				return false
		if episode.start_seconds < previous_end or episode.finish_seconds <= episode.start_seconds or episode.end_seconds <= episode.finish_seconds or episode.end_seconds > value.cycle_seconds:
			return false
		previous_end = episode.end_seconds
		ids[episode.id] = true
	ids.clear()
	for species in value.species:
		if not species is Dictionary or not species.get("id") is String or species.id.is_empty() or ids.has(species.id) or not species.get("habitats") is Array or not species.get("biomes") is Array:
			return false
		ids[species.id] = true
		for habitat in species.habitats:
			if habitat not in ["town", "wild", "water"]:
				return false
		if species.get("medium", "land") not in ["land", "water", "air"]:
			return false
		for biome in species.biomes:
			if not _number(biome) or biome < 0 or biome > 3 or biome != floorf(biome):
				return false
		for key in ["weight", "height", "speed"]:
			if not _number(species.get(key)) or species[key] <= 0 or species[key] > 10:
				return false
		if species.weight != floorf(species.weight) or not species.get("idle") is String or not species.get("walk") is String or not species.get("models") is Dictionary:
			return false
		var query: Dictionary = species.models
		if not query.get("tags") is Array or not query.get("patterns") is Array or query.patterns.is_empty() or query.patterns.size() > 32 or not query.get("pack", "") is String:
			return false
		for pattern in query.patterns:
			if not pattern is String or pattern.length() > 512:
				return false
		for tag in query.tags:
			if not tag is String:
				return false
	return true

func routine(role: String) -> Dictionary:
	return data.routines.get(role, data.routines.default)

func species_for(habitat: String, biome: int, salt: int) -> Dictionary:
	var pool := []
	var total := 0
	for species in data.species:
		if habitat in species.habitats and biome in species.biomes and not model_choices[species.id].is_empty():
			pool.append(species)
			total += int(species.weight)
	if pool.is_empty():
		return {}
	var selected := posmod(salt, total)
	for species in pool:
		selected -= int(species.weight)
		if selected < 0:
			var result: Dictionary = species.duplicate(true)
			var choices: Array = model_choices[species.id]
			result.asset_id = creatures.choose(choices.map(func(model): return model.id), salt, "", biome)
			return result
	return {}

func species(id: String) -> Dictionary:
	for entry in data.species:
		if entry.id == id:
			return entry
	return {}
