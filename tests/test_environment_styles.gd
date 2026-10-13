extends SceneTree

const Catalog = preload("res://scripts/world_dressing_catalog.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Construction = preload("res://scripts/world_construction.gd")
const Scenery = preload("res://scripts/scenery.gd")
const View = preload("res://scripts/world_view.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var catalog := Catalog.new()
	check(catalog.error.is_empty() and catalog.styles.error.is_empty(), "The environment family catalogue must load")
	for biome in range(4):
		check(not catalog.styles.allows("unclassified:model", biome), "Unclassified local assets must not qualify as compatible")
		for family in catalog.styles.data.families:
			var id := catalog.styles.native_id(family, "canopy")
			check(catalog.styles.allows(id, biome) == (family == catalog.styles.family_for(biome)), "Compatibility must reject the other family's native geometry")
	check(not catalog.styles.allows(catalog.styles.native_id("block_voxel", "canopy"), -1), "Unknown biomes must not inherit a default family")
	check(not catalog.styles.allows("native_environment:block_voxel:unknown", 0), "Invalid native roles must stay unclassified")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/npc_styles.json"))
	for series in source.families.values():
		for query in series.queries:
			for asset in catalog.registry.find("model", query.tags, query.pack):
				if query.patterns.any(func(pattern): return asset.id.matchn(pattern)):
					check(catalog.styles.family_of(asset.id) == series.environment_family, "Reviewed source-series metadata must classify actual NPC models")
	var invalid := catalog.styles.data.duplicate(true)
	invalid.biomes["0"] = "unknown"
	check(not Styles.valid(invalid), "Unknown biome families must be rejected")
	invalid = catalog.styles.data.duplicate(true)
	invalid.anchors.oak = "unknown_role"
	check(not Styles.valid(invalid), "Unsupported natural roles must be rejected")
	var anchors := ["oak", "tree_a", "pine", "cactus", "rock", "rock_b", "dead_a", "stump", "bush", "flowers", "mushroom", "mushroom_tall", "plant"]
	for biome in range(4):
		var families := {}
		for region in range(64):
			var context := {"biome": biome, "city_type": "city_crossroads", "region_id": "style:%s:%s" % [region - 32, region % 9 - 4]}
			for anchor in anchors:
				var recipe := catalog.recipe_for(anchor, context)
				if recipe.is_empty():
					continue
				var plan := catalog.plan(recipe, context, region * 17 + biome)
				check(not plan.is_empty(), "Every eligible natural anchor needs a supported model or coherent fallback")
				check(not plan.get("visual_family", "").is_empty(), "Biome environment plans need a visual family")
				families[plan.get("visual_family", "")] = true
				for part in plan.get("parts", []):
					check(part.get("visual_family", "") == plan.get("visual_family", ""), "Every natural part must share its biome family")
					check(catalog.styles.family_of(part.asset) == catalog.styles.family_for(biome), "Actual selected assets must belong to the biome family")
				check(plan == catalog.plan(recipe, context, region * 17 + biome), "Style-constrained palettes must replay")
		check(families.size() == 1, "Regions in a biome must share one environment family")
	var scenery := Scenery.new()
	for family in catalog.styles.data.families:
		for role in catalog.styles.data.roles:
			var model := catalog.styles.native_model(role, family, Vector2(.85, .7), 1.25)
			var box := scenery.bounds(model)
			check(is_equal_approx(box.size.x, .85) and is_equal_approx(box.size.z, .7) and is_equal_approx(box.size.y, 1.25) and is_zero_approx(box.position.y), "Fallback geometry must stay grounded and inside its declared footprint")
			check(model.get_meta("visual_family") == family, "Native fallback must retain its style family")
			check(scenery.valid_materials(model), "Fallbacks need actual valid materials")
			model.free()
	var context := {"biome": 0, "region_id": "forced-fallback"}
	var recipe := catalog.recipe_for("oak", context)
	catalog.pools.canopy = catalog.registry.find("model", [], "kenney_nature_kit").map(func(asset): return asset.id)
	var fallback := catalog.plan(recipe, context, 12345)
	check(fallback.parts[0].has("native_role"), "An incompatible role pool must use a same-family fallback")
	var construction := Construction.new()
	var model := construction.build(fallback)
	check(model != null and model.get_meta("visual_family") == catalog.styles.family_for(0), "An empty compatible pool must remain visibly represented")
	if model != null:
		model.free()
	var missing := construction.catalog.plan(construction.catalog.recipe_for("rock", context), context, 12345)
	missing.parts[0].asset = "missing:environment-style-resource"
	model = construction.build(missing)
	check(model != null and catalog.styles.family_of(model.get_meta("parts")[0].asset) == catalog.styles.family_for(0), "An unavailable resource must not fall through to another art family")
	if model != null:
		model.free()
	var view := View.new()
	for biome in range(4):
		for anchor in anchors:
			var key := view._environment_fallback_key(anchor, {"biome": biome})
			check(view.construction.catalog.styles.family_of(key) == catalog.styles.family_for(biome), "Streamed fallback branches must preserve the biome family")
	view.free()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: four biome palettes across 256 regional contexts, actual family eligibility, replay, grounded real fallback meshes, incompatible pools, missing resources and streamed fallback branches" if failures.is_empty() else "FAIL: biome environment families")
	quit(0 if failures.is_empty() else 1)
