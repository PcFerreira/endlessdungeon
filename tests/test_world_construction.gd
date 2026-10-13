extends SceneTree

const Catalog = preload("res://scripts/world_dressing_catalog.gd")
const Construction = preload("res://scripts/world_construction.gd")
const Scenery = preload("res://scripts/scenery.gd")
const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_view.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var catalog := Catalog.new()
	assert(catalog.error.is_empty())
	assert(Catalog.valid(catalog.data))
	var broken := catalog.data.duplicate(true)
	broken.recipes[0].parts[1].support = "missing_counter"
	assert(not Catalog.valid(broken), "Goods need a real support, not free placement")
	broken = catalog.data.duplicate(true)
	broken.recipes[0].parts[1].point = [2,2]
	assert(not Catalog.valid(broken), "Supported goods must stay inside their supporting surface")
	broken = catalog.data.duplicate(true)
	var market: Dictionary = broken.recipes.filter(func(recipe): return recipe.id == "market_fruit_lot")[0]
	var right: Dictionary = market.parts.filter(func(part): return part.id == "post_right")[0]
	right.support = "counter"
	right.point = [.39,-.28]
	assert(not Catalog.valid(broken), "Canopy posts must have equal resolved top elevations")
	broken = catalog.data.duplicate(true)
	market = broken.recipes.filter(func(recipe): return recipe.id == "market_fruit_lot")[0]
	var canopy: Dictionary = market.parts.filter(func(part): return part.has("span"))[0]
	canopy.span = ["post_right", "post_right"]
	assert(not Catalog.valid(broken), "A span needs distinct supports including its primary support")
	var view := View.new()
	var materials: Array[StandardMaterial3D] = []
	for color in [Color.RED, Color.GREEN]:
		var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
		image.fill(color)
		var material := StandardMaterial3D.new()
		material.albedo_texture = ImageTexture.create_from_image(image)
		materials.append(material)
		var shader := view._cutaway_material(material)
		assert(shader.get_shader_parameter("albedo_tex") == material.albedo_texture, "Embedded textures without paths must stay distinct")
	view.free()
	if "--schema-only" in OS.get_cmdline_user_args():
		print("PASS: contextual construction schema, source role pools, support/footprint rejection and view compilation")
		quit()
		return
	var construction := Construction.new()
	var scenery := Scenery.new()
	for recipe in catalog.data.recipes:
		var context := {"city_type": recipe.get("city_types", ["city_market"])[0], "biome": recipe.get("biomes", [1])[0], "family": recipe.get("families", [""])[0], "region_id": "fixture"}
		var plan := catalog.plan(recipe, context, 12345)
		assert(plan == catalog.plan(recipe, context, 12345), "Assemblies must be deterministic")
		var model := construction.build(plan)
		assert(model != null, recipe.id + ": " + construction.error + " / plan " + str(plan))
		var bounds := scenery.bounds(model)
		var allowed := Vector2(recipe.footprint[0], recipe.footprint[1])
		assert(bounds.size.x <= allowed.x + .005 and bounds.size.z <= allowed.y + .005)
		assert(absf(bounds.position.y) < .005)
		for part in model.get_meta("parts"):
			if part.support != "ground":
				var support: Dictionary = model.get_meta("parts").filter(func(item): return item.id == part.support)[0]
				assert(absf(part.bounds.position.y - support.bounds.end.y) < .005)
		model.free()
	var frost := catalog.recipe_for("pine", {"biome": 3})
	assert(not frost.is_empty() and frost.id == "evergreen")
	assert(catalog.recipe_for("cactus", {"biome": 0}).is_empty(), "Desert dressing must not enter woodland")
	var world := World.new()
	world.generate(12345)
	world.load_around(Vector2(world.start))
	var city: Dictionary = world.region_at(world.start).city
	for lot in city.outdoor_lots:
		var context := {"city_type": city.archetype_id, "biome": city.biome, "region_id": city.id}
		var recipe := catalog.recipe_for("lot_" + lot.kind, context)
		assert(not recipe.is_empty())
		var model := construction.build(catalog.plan(recipe, context, 12345))
		var allowed := Vector2(lot.footprint.size)
		var box := scenery.bounds(model)
		assert(box.size.x <= allowed.x and box.size.z <= allowed.y)
		assert(world.walkable(lot.approach))
		model.free()
	print("PASS: source-driven contextual recipes, supported table goods, no orphan/overhanging items, deterministic biome palettes, reserved market/farm footprints and clear approaches")
	quit()
