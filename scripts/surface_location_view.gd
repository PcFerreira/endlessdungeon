extends RefCounted

const Architecture = preload("res://scripts/town_architecture.gd")
const Scenery = preload("res://scripts/scenery.gd")
var architecture := Architecture.new()
var scenery := Scenery.new()

func build(site: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SurfaceLocation"
	root.set_meta("surface_site_id", site.id)
	root.set_meta("site_type", site.type)
	root.set_meta("owner", site.owner)
	root.set_meta("facing", site.facing)
	var family: String = architecture.styles.family_for(site.biome)
	var models := {}
	var parts := []
	var portable_nodes := {}
	for group in ["structures", "fixtures"]:
		for part in site[group]:
			var model: Node3D
			var size := Vector2(part.size[0], part.size[1])
			var footprint := size - Vector2.ONE * .10 if part.solid else size
			if part.has("template"):
				assert(architecture.catalog.data.templates.has(part.template), "Unknown independent-place architecture template")
				var recipe: Dictionary = architecture.catalog.data.templates[part.template].duplicate(true)
				recipe.id = part.template
				recipe.theme = "generic"
				model = architecture.build_template(recipe, footprint, part.height, family)
			else:
				model = architecture.styles.native_model(part.role, family, footprint, part.height)
				model.set_meta("render_asset", architecture.styles.native_id(family, part.role))
			assert(model != null, "An independent structure must render its actual model")
			var asset: String = model.get_meta("render_asset")
			assert(architecture.styles.allows(asset, site.biome), "Independent structures/fixtures must follow their real owning biome")
			model.name = part.id
			model.position = Vector3(part.local_cell.x, part.elevation, part.local_cell.y)
			model.set_meta("asset_id", asset)
			model.set_meta("visual_family", family)
			model.set_meta("site_id", site.id)
			model.set_meta("source_uid", site.id + ":" + part.id)
			model.set_meta("fixed", part.fixed)
			root.add_child(model)
			models[part.id] = model
			if group == "fixtures":
				var bounds := scenery.bounds(model)
				parts.append({"id": part.id, "asset": asset, "visual_family": family, "pool": part.pool, "support": part.support, "bounds": bounds, "fixed": part.fixed})
				portable_nodes[part.id] = model
	root.set_meta("parts", parts)
	root.set_meta("portable_nodes", portable_nodes)
	root.set_meta("site_models", models)
	return root
