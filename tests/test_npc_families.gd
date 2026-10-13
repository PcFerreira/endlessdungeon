extends SceneTree

const Actors = preload("res://scripts/actor_models.gd")
const Generator = preload("res://scripts/voxel_character_generator.gd")

func _initialize() -> void:
	var palettes := {}
	for town in range(128):
		var biome := town % 4
		var city_id := "city:%s:%s" % [town - 16, town % 7 - 3]
		var town_palette := ""
		for role in ["fountain_keeper", "milewarden", "relic_mender", "retired_delver"]:
			for index in range(8):
				var context := {"id": city_id + ":npc:%s" % index, "city_id": city_id, "role": role, "biome": biome}
				var style := Actors.style_for(index, context)
				assert(style.family == "generated_voxel" and style.visual_family == "block_voxel")
				assert(style.palette_id in Generator.catalog.data.biomes[str(biome)])
				assert(style == Actors.style_for(index, context))
				if town_palette.is_empty():
					town_palette = style.palette_id
				assert(style.palette_id == town_palette, "Town residents share a coherent local clothing palette")
		for index in range(2):
			var guard := Actors.style_for(index, {"id": "watch:%s:%s:%s" % [town - 16, town % 7 - 3, index], "city_id": city_id, "role": "milewarden", "traveling": true, "biome": biome})
			assert(guard.palette_id == town_palette and guard.outfit == "mail" and guard.accessory == "blade")
		palettes[town_palette] = true
	assert(palettes.size() == Generator.catalog.data.palettes.size())
	print("PASS: 128 coherent generated voxel town populations and guards, actual local palette selection and stable identity")
	quit()
