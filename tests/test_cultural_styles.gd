extends SceneTree

const Catalog = preload("res://scripts/world_dressing_catalog.gd")
const Construction = preload("res://scripts/world_construction.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Visual = preload("res://scripts/item_visual.gd")
const Furniture = preload("res://scripts/furnishing_catalog.gd")
const Models = preload("res://scripts/enemy_models.gd")
const View = preload("res://scripts/world_view.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog := Catalog.new()
	var construction := Construction.new()
	var scenery := Scenery.new()
	check(catalog.error.is_empty(), "Cultural catalogue and reviewed style queries must load")
	var architecture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/town_architecture.json"))
	for id in architecture.templates:
		for part in architecture.templates[id].parts:
			if part.has("asset"):
				check(catalog.styles.family_of(part.asset) == "flat_lowpoly", "Architecture sources must retain their actual faceted family before conversion")
		for biome in range(4):
			var family: String = catalog.styles.family_for(biome)
			check(catalog.styles.allows("town_architecture:%s:%s" % [family, id], biome), "Known architecture derivatives must classify by declared rendered family")
			var other := "flat_lowpoly" if family == "block_voxel" else "block_voxel"
			check(not catalog.styles.allows("town_architecture:%s:%s" % [other, id], biome), "Architecture derivatives must not bypass the owning biome gate")
	check(catalog.styles.family_of("town_architecture:block_voxel:unknown_template").is_empty(), "Unknown derivative templates must remain unclassified")
	var view := View.new()
	var parent := Node3D.new()
	for biome in range(4):
		for key in ["banner_blue", "banner_red", "stag", "arch", "torch", "book", "signpost", "chair", "pot", "sack", "chest", "training_dummy", "fountain", "cart"]:
			var direct := view._place(parent, key, .8, Vector3.ZERO, .7, biome)
			check(catalog.styles.allows(direct.get_meta("asset_id"), biome) and direct.get_meta("visual_family") == catalog.styles.family_for(biome), "Direct local scenery and civic fixtures must preserve the owning biome family")
			direct.free()
	parent.free()
	view.free()
	var plans := 0
	for biome in range(4):
		for recipe in catalog.data.recipes:
			if recipe.has("biomes") and not recipe.biomes.any(func(value): return int(value) == biome):
				continue
			var context := {"biome": biome, "city_type": recipe.get("city_types", ["city_market"])[0], "family": recipe.get("families", [""])[0], "region_id": "cultural:%s" % biome}
			var plan := catalog.plan(recipe, context, 12345)
			check(not plan.is_empty(), "Every eligible ensemble needs compatible parts: " + recipe.id)
			if plan.is_empty():
				continue
			plans += 1
			check(plan == catalog.plan(recipe, context, 12345), "Cultural style choices must replay")
			for part in plan.parts:
				check(part.visual_family == catalog.styles.family_for(biome) and catalog.styles.allows(part.asset, biome), "Every actual cultural part and primitive must follow the biome family")
			var model := construction.build(plan)
			check(model != null, "Style adaptation must retain complete visible ensembles")
			if model == null:
				continue
			var bounds := scenery.bounds(model)
			check(bounds.size.x <= recipe.footprint[0] + .005 and bounds.size.z <= recipe.footprint[1] + .005 and absf(bounds.position.y) < .005, "Family-adapted ensembles must preserve reserved ground footprints")
			for part in model.get_meta("parts"):
				check(catalog.styles.allows(part.asset, biome), "Resolved source metadata must name the actual compatible model")
				if part.support != "ground":
					var support: Dictionary = model.get_meta("parts").filter(func(value): return value.id == part.support)[0]
					check(absf(part.bounds.position.y - support.bounds.end.y) < .005, "Family-adapted goods must touch their actual supports")
			model.free()
	for family in catalog.styles.data.families:
		for role in catalog.styles.data.cultural_roles:
			var id: String = catalog.styles.native_id(family, role)
			var model := catalog.styles.native_model(role, family, Vector2(.83, .61), .92)
			var bounds := scenery.bounds(model)
			check(model.get_child_count() > 0 and scenery.valid_materials(model), "Purposeful native cultural roles must contain real visible valid meshes")
			check(is_equal_approx(bounds.size.x, .83) and is_equal_approx(bounds.size.z, .61) and is_equal_approx(bounds.size.y, .92) and absf(bounds.position.y) < .005, "Native cultural roles must fit exact grounded dimensions")
			model.free()
			var item: String = Items.for_asset(id)
			check(not item.is_empty() and Items.definitions.has(item), "Native source goods must retain portable item identity")
			if item.is_empty():
				continue
			var preview := Visual.model(Items.definitions[item], .5)
			check(preview != null and Models.bounds(preview).size.length() > 0, "Native carried source objects need actual matching rendered models")
			if preview != null:
				if role in ["plate", "book", "rug_floor"]:
					var box := Models.bounds(preview)
					check(box.size.y < maxf(box.size.x, box.size.z) * .4, "Native inventory previews must retain the thin role's real proportions")
				preview.free()
		var table: String = Items.for_asset(catalog.styles.native_id(family, "table"))
		var spec := Furniture.definition(table)
		check(not spec.is_empty() and spec.get("surface", false), "A native portable table must remain a real furnishing support")
	var context := {"biome": 0, "region_id": "missing-cultural-resource"}
	var recipe := catalog.recipe_for("lot_market", context)
	var plan := catalog.plan(recipe, context, 12345)
	var part: Dictionary = plan.parts.filter(func(value): return value.get("pool") == "fruit")[0]
	part.erase("native_role")
	part.asset = "missing:cultural-resource"
	var model := construction.build(plan)
	check(model != null, "Unavailable cultural resources must use a same-role same-family fallback")
	if model != null:
		var resolved: Dictionary = model.get_meta("parts").filter(func(value): return value.id == part.id)[0]
		check(resolved.asset == catalog.styles.native_id("block_voxel", "fruit"), "Missing resource descriptors must retain actual native source identity")
		model.free()
	check(catalog.plan(recipe, {"biome": -1}, 12345).is_empty(), "Cultural selection must reject an unsupported owning biome")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: %s family-adapted cultural ensembles; all native roles, actual primitive/model identity, exact bounds, supports, portable previews and missing-resource fallback" % plans if failures.is_empty() else "FAIL: cultural style families")
	quit(0 if failures.is_empty() else 1)
