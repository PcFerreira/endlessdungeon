extends SceneTree

const Planner = preload("res://scripts/site_planner.gd")
const Locations = preload("res://scripts/surface_locations.gd")
const View = preload("res://scripts/surface_location_view.gd")
const Scenery = preload("res://scripts/scenery.gd")

func _init() -> void:
	var view = View.new()
	var scenery := Scenery.new()
	var planner = Planner.new(91)
	var count := 0
	for kind in ["ruin", "castle", "church", "temple"]:
		for facing in Planner.DIRECTIONS:
			for biome in range(4):
				var raw: Dictionary = planner.site("fixture:" + kind, kind, Vector2i.ZERO, Vector2i(64, 64), facing)
				raw.seed = 91
				raw.biome = biome
				raw.height = 2.0
				var site := Locations.compose(raw)
				var model := view.build(site)
				model.rotation.y = atan2(facing.x, facing.y)
				var nodes: Dictionary = model.get_meta("site_models")
				var family: String = view.architecture.styles.family_for(biome)
				for part in site.structures + site.fixtures:
					var node: Node3D = nodes[part.id]
					var bounds := scenery.bounds(node)
					var footprint := Vector2(part.size[0], part.size[1]) - (Vector2.ONE * .1 if part.solid else Vector2.ZERO)
					assert(bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.z > 0)
					assert(is_equal_approx(bounds.size.x, footprint.x) and is_equal_approx(bounds.size.z, footprint.y) and is_equal_approx(bounds.size.y, part.height), "Actual independent models must fit the declared structural/fixture dimensions: " + part.id)
					assert(absf(bounds.position.y) < .001 and is_equal_approx(node.position.y, part.elevation))
					assert(node.get_meta("visual_family") == family and view.architecture.styles.family_of(node.get_meta("asset_id")) == family)
					if part.has("template"):
						assert(not node.get_meta("source_assets").is_empty())
						assert(node.get_meta("representation") == ("voxelized" if family == "block_voxel" else "source"))
					if part.support != "ground":
						var parent: Node3D = nodes[part.support]
						var surface := scenery.bounds(parent)
						assert(is_equal_approx(node.position.y + bounds.position.y, parent.position.y + surface.end.y), "Actual supported goods must touch their real rendered parent")
						assert(Rect2(Vector2(surface.position.x, surface.position.z), Vector2(surface.size.x, surface.size.z)).grow(.001).encloses(Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))))
				count += 1
				model.free()
	print("PASS: ", count, " four-climate/facing surface compositions; actual source/cube identities, exact footprints/heights/ground origin and rendered support containment/contact")
	quit()
