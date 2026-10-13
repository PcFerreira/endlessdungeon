extends SceneTree

const Catalog = preload("res://scripts/world_life_catalog.gd")
const Actors = preload("res://scripts/actor_models.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var catalog := Catalog.new()
	assert(catalog.error.is_empty(), catalog.error)
	assert(catalog.data.species.size() >= 9)
	var animated := 0
	for definition in catalog.data.species:
		assert(not catalog.model_choices[definition.id].is_empty())
		var model := catalog.registry.instantiate(catalog.model_choices[definition.id][0].id)
		assert(model != null and Actors._bounds(model, Transform3D.IDENTITY).size.y > 0, "Missing geometry: " + definition.id)
		if not model.find_children("*", "AnimationPlayer", true, false).is_empty():
			animated += 1
		model.free()
	assert(animated >= 9)
	var seen := {}
	for habitat in ["town", "wild", "water"]:
		for biome in range(4):
			for salt_value in range(256):
				var species := catalog.species_for(habitat, biome, salt_value)
				if not species.is_empty():
					assert(habitat in species.habitats and biome in species.biomes)
					assert(catalog.registry.get_asset(species.asset_id).kind == "model")
					seen[species.id] = true
	assert(seen.size() == catalog.data.species.size())
	var changed: Dictionary = catalog.data.duplicate(true)
	changed.species[0].id = "new_neighbor"
	changed.episodes[0].id = "lantern_meal"
	assert(Catalog.valid(changed), "New content identities must be data-driven")
	changed.species.append(changed.species[0].duplicate())
	assert(not Catalog.valid(changed))
	changed = catalog.data.duplicate(true)
	changed.episodes[1].start_seconds = 1
	assert(not Catalog.valid(changed), "Overlapping episodes must be rejected")
	changed = catalog.data.duplicate(true)
	changed.species[0].weight = 0
	assert(not Catalog.valid(changed))
	print("PASS: data-defined fauna/routines/events, registry model queries, actual animated species, eligibility/weights and invalid definitions")
	quit()
