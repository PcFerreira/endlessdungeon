extends SceneTree

const BiomeModels = preload("res://scripts/biome_models.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")

func _init() -> void:
	var models := BiomeModels.new()
	assert(models.error.is_empty(), models.error)
	var count := 0
	var sources := {}
	assert(models.data.roles.giant_mushroom.get("native", false), "Giant mushrooms must use readable wide caps and a distinct stem")
	for role in models.data.roles:
		assert(models.supports(role))
		var profile: Dictionary = models.data.roles[role]
		for biome in range(4):
			var family: String = models.items.styles.family_for(biome)
			for seed_value in range(3):
				var model: Node3D = models.create(role, biome, seed_value)
				assert(model != null, models.error)
				var box := Bounds.bounds(model)
				assert(is_equal_approx(box.size.x, profile.width) and is_equal_approx(box.size.z, profile.width) and is_equal_approx(box.size.y, profile.height), "Biome role must fit its actual authored volume: " + role)
				assert(absf(box.position.y) < .001 and absf(box.get_center().x) < .001 and absf(box.get_center().z) < .001, "Biome role must rest on ground and stay centered: " + role)
				assert(model.get_meta("visual_family") == family and model.get_meta("biome_role") == role)
				assert(model.get_meta("asset_id") == model.get_meta("render_asset"))
				assert(models.items.styles.family_of(model.get_meta("render_asset")) == family)
				var source: String = model.get_meta("source_asset")
				if profile.get("native", false):
					assert(source == "biome_geometry:%s:%s" % [family, role])
					assert(model.get_meta("representation") == "native_biome")
					var cylinders := 0
					var glowing := 0
					var cap_width := 0.0
					var stem_width := 0.0
					for part in model.find_children("*", "MeshInstance3D", true, false):
						assert(part.get_meta("visual_family") == family and part.get_meta("source_asset") == source)
						if part.mesh is CylinderMesh:
							assert(part.mesh.radial_segments == 6)
							cylinders += 1
						if part.get_active_material(0).emission_enabled:
							glowing += 1
						if part.get_meta("biome_part", "") == "cap":
							cap_width = maxf(cap_width, part.mesh.get_aabb().size.x)
						if part.get_meta("biome_part", "") == "stem":
							stem_width = part.mesh.get_aabb().size.x
					assert(cylinders == 0 if family == "block_voxel" else cylinders > 0 or role == "lava_crack")
					assert(glowing == 4 if role == "lava_crack" else glowing == 0)
					if role == "giant_mushroom":
						assert(stem_width > 0 and cap_width > stem_width * 3, "Giant mushrooms need an actual broad cap silhouette above a thin stem")
				else:
					assert(source in profile.sources[family] and models.items.styles.item_sources.has(source))
					assert(models.items.styles.family_of(model.get_meta("render_asset")) == family)
					assert(model.get_meta("representation") in ["direct", "voxelized", "faceted_surface"])
				var repeat: Node3D = models.create(role, biome, seed_value)
				assert(repeat != model and repeat.get_meta("source_asset") == source)
				repeat.free()
				sources[role + family + source] = true
				model.free()
				count += 1
	assert(not models.supports("unknown"))
	print("PASS: ", count, " actual role/climate/seed bodies; grounded fitted volumes, family/source identities, truthful native derivatives and repeatable independent instances; ", sources.size(), " role/family/source selections")
	quit()
