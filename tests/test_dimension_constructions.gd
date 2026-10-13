extends SceneTree

const Constructions = preload("res://scripts/dimension_constructions.gd")
const View = preload("res://scripts/surface_location_view.gd")
const Grid = preload("res://scripts/grid_area.gd")
const Scenery = preload("res://scripts/scenery.gd")

func base(kind: String, facing: Vector2i, biome: int = 0) -> Dictionary:
	var profile := Constructions.profile(kind)
	var center := Vector2i(64, 64)
	return {"id": "dimension:fixture:site:test", "type": kind, "cell": center, "facing": facing, "height": 2.0, "biome": biome, "area_id": "whisperwood", "seed": 71, "radius": profile.radius, "footprint": Rect2i(center - Vector2i.ONE * int(profile.radius), Vector2i.ONE * (int(profile.radius) * 2 + 1))}

func hash_meshes(node: Node, transform: Transform3D, digest: HashingContext) -> void:
	var current: Transform3D = transform * node.transform if node is Node3D else transform
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			digest.update((current * vertices).to_byte_array())
	for child in node.get_children():
		hash_meshes(child, current, digest)

func _initialize() -> void:
	assert(Constructions.valid(Constructions.DATA))
	assert(Constructions.DATA.constructions.size() >= 12)
	var towers := {"prism_bastion": {"west_tower": "castle_hexagonal_watch", "east_tower": "castle_square_library"}, "north_watch": {"watch_bell": "castle_hexagonal_watch"}}
	for id in towers:
		var definition: Dictionary = Constructions.DATA.constructions[id]
		for part in definition.structures:
			if towers[id].has(part.id):
				assert(not part.has("town_voxel") and part.get("template") == towers[id][part.id], "Castle towers must have tower geometry instead of seasonal decorative landmarks")
		var prior := definition.duplicate(true)
		for part in prior.structures:
			if towers[id].has(part.id):
				part.erase("template")
				part.town_voxel = "$theme_landmark"
		var original := Constructions._compile(base("castle", Vector2i.DOWN), prior, id, "fairy", Constructions.profile("castle"))
		var replacement := Constructions.compose(base("castle", Vector2i.DOWN), {"construction_id": id})
		for field in ["solid_cells", "walks", "doors", "books", "rest_point", "resident_anchors"]:
			assert(original[field] == replacement[field], "Tower model substitutions must preserve physical placement/access: " + field)
	assert(Constructions.valid_site_recipe({"type": "city"}) and Constructions.valid_site_recipe({"type": "church"}))
	assert(not Constructions.valid_site_recipe({"type": "woodland_house", "construction_id": "prism_bastion"}))
	assert(not Constructions.valid_site_recipe({"type": "village", "theme_id": "missing"}))
	assert(Constructions.valid_site_recipe({"type": "village", "residents": [{"offset": [4, 7], "route": [[4, 7], [4, 8], [3, 8]]}]}))
	assert(not Constructions.valid_site_recipe({"type": "woodland_house", "construction_id": "hollow_home", "residents": [{"offset": [-2, -2]}]}), "Authored residents cannot start inside structural collision")
	assert(not Constructions.valid_site_recipe({"type": "woodland_house", "construction_id": "hollow_home", "residents": [{"offset": [0, 1], "route": [[3, -3]]}]}), "Authored resident segments cannot cross a wall")
	var bad := Constructions.DATA.duplicate(true)
	bad.constructions.lantern_court.structures.append({"id": "blocked_reader", "role": "stone_block", "cell": [-2, 3], "size": [1, 1], "height": 1})
	assert(not Constructions.valid(bad), "A accepted layout must preserve its reading approach")
	bad = Constructions.DATA.duplicate(true)
	bad.constructions.hollow_home.structures[0].town_voxel = "unknown_house"
	assert(not Constructions.valid(bad))
	bad = Constructions.DATA.duplicate(true)
	bad.constructions.hollow_home = 7
	assert(not Constructions.valid(bad), "Malformed default records must reject without accessing unavailable fields")
	bad = Constructions.DATA.duplicate(true)
	bad.constructions.hollow_home.structures[0].solid_offsets = []
	assert(not Constructions.valid(bad), "Source collision overrides cannot erase physical shell walls")
	bad = Constructions.DATA.duplicate(true)
	bad.constructions.lantern_court.resident_spots[0].point = [-10, -5]
	assert(not Constructions.valid(bad), "Resident points cannot be soft-shifted out of a wall after authoring")
	var view := View.new()
	var scenery := Scenery.new()
	var signatures := {}
	var rendered_signatures := {}
	var count := 0
	for id in Constructions.DATA.constructions:
		var definition: Dictionary = Constructions.DATA.constructions[id]
		for facing in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
			var site := Constructions.compose(base(definition.kind, facing), {"construction_id": id})
			var grid := Grid.new()
			for cell in site.walks:
				grid.tiles[cell] = true
			assert(grid.walkable(Vector2(site.approach)))
			assert(grid.line_clear(site.books[0].approach, site.books[0].approach) and grid.walkable(site.rest_point))
			for cell in site.solid_cells:
				assert(site.footprint.has_point(cell) and not grid.walkable(Vector2(cell)))
			for door in site.doors:
				assert(grid.walkable(door.point) and grid.walkable(door.approach) and grid.walkable(door.inside))
				assert(grid.move_actor(door.approach, door.inside - door.approach).is_equal_approx(door.inside), "Open native entrances require actual traversable shell collision")
			for anchor in site.resident_anchors:
				assert(grid.walkable(anchor.point) and grid.walkable(anchor.approach))
				for index in range(anchor.route.size() - 1):
					assert(grid.move_actor(anchor.route[index], anchor.route[index + 1] - anchor.route[index]).is_equal_approx(anchor.route[index + 1]))
			assert(site.resident_anchors.size() == (4 if site.type == "village" else 1))
			if site.type == "village":
				for anchor in site.resident_anchors:
					assert(anchor.point.distance_to(site.rest_point) >= 2, "A village citizen cannot intercept E exactly at the rest point")
			if facing == Vector2i.DOWN:
				signatures[JSON.stringify([site.structures, site.solid_cells])] = true
			count += 1
		for biome in range(4):
			var site := Constructions.compose(base(definition.kind, Vector2i.DOWN, biome), {"construction_id": id})
			var model := view.build(site)
			if biome == 0:
				var digest := HashingContext.new()
				digest.start(HashingContext.HASH_SHA256)
				hash_meshes(model, Transform3D.IDENTITY, digest)
				rendered_signatures[digest.finish().hex_encode()] = true
			var nodes: Dictionary = model.get_meta("site_models")
			var family: String = view.architecture.styles.family_for(biome)
			for part in site.structures + site.fixtures:
				var node: Node3D = nodes[part.id]
				var bounds := scenery.bounds(node)
				var expected := Vector2(part.size[0], part.size[1]) - (Vector2.ONE * .1 if part.solid else Vector2.ZERO)
				assert(is_equal_approx(bounds.size.x, expected.x) and is_equal_approx(bounds.size.z, expected.y) and is_equal_approx(bounds.size.y, part.height), "Actual model must fit its full declared footprint and height")
				assert(absf(bounds.position.y) < .001 and is_equal_approx(node.position.y, part.elevation))
				assert(node.get_meta("visual_family") == family and view.architecture.styles.family_of(node.get_meta("asset_id")) == family)
				if part.has("town_voxel"):
					assert(node.has_meta("town_voxel_id") and node.get_meta("representation") == ("native_voxel" if family == "block_voxel" else "faceted_surface"))
				if part.has("template"):
					assert(node.get_meta("template_id") == part.template and not node.get_meta("source_assets").is_empty())
					assert(node.get_meta("representation") == ("voxelized" if family == "block_voxel" else "source"))
				if part.support != "ground":
					var parent: Node3D = nodes[part.support]
					var support := scenery.bounds(parent)
					assert(is_equal_approx(node.position.y, parent.position.y + support.end.y))
			model.free()
	assert(signatures.size() == Constructions.DATA.constructions.size(), "Every layout must have distinct actual geometry and collision")
	assert(rendered_signatures.size() == Constructions.DATA.constructions.size(), "Twelve original layouts must have distinct real mesh bodies, independently of names and colours")
	var house := Constructions.compose(base("woodland_house", Vector2i.DOWN), {"construction_id": "hollow_home"})
	var alternate := Constructions.compose(base("woodland_house", Vector2i.DOWN), {"construction_id": "hollow_home", "theme_id": "japanese"})
	assert(house.structures[0].town_voxel != alternate.structures[0].town_voxel and house.solid_cells == alternate.solid_cells, "Regional models vary without changing the protected doorway contract")
	print("PASS: ", count, " cardinal construction layouts; 12 distinct geometries, real shell/gate movement, fixed NPC routes, native/faceted rendered bounds and supported fixtures")
	quit()
