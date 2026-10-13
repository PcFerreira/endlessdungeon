extends SceneTree

const Inventory = preload("res://scripts/inventory.gd")
const Sanctum = preload("res://scripts/sanctum.gd")
const Scenery = preload("res://scripts/scenery.gd")

func _initialize() -> void:
	var script = load("res://scripts/furnishings.gd")
	assert(script != null, "Sanctum placement must have a transactional saved furnishing state")
	var furniture = script.new()
	for location in [Vector2(8, 11), Vector2(12, 12), Vector2(10, 3), Vector2(6, 16)]:
		assert(furniture.candidate("oak_chair", location, 0).problem.is_empty(), "Furniture must use clear floor throughout the island")
	assert(not furniture.candidate("wool_rug", Vector2(10, 17), 0).problem.is_empty(), "Even rugs must leave the portal clear")
	assert(not furniture.candidate("wool_rug", Vector2(1, 6), 0).problem.is_empty(), "The entire footprint must stay on island floor")
	var malformed: Dictionary = furniture.Catalog.data.duplicate(true)
	malformed.profiles.wall_shelf.elevation = 1.6
	assert(not furniture.Catalog.valid(malformed), "Wall profiles must fit their actual supporting walls")
	var bag := Inventory.new()
	assert(bag.add("oak_chair", 2) and bag.add("wool_rug") and bag.add("rune_lantern"))
	assert(not furniture.place("oak_chair", Vector2(10, 17), 0, bag), "The return portal must stay clear")
	assert(bag.count("oak_chair") == 2 and furniture.records.is_empty())
	assert(not furniture.place("oak_chair", Vector2(4, 10), 0, bag, Vector2(4, 10)), "Furniture must not trap the current character")
	assert(furniture.place("oak_chair", Vector2(4, 10), 0, bag))
	var chair: String = furniture.records[0].uid
	assert(bag.count("oak_chair") == 1)
	assert(not furniture.place("oak_chair", Vector2(4, 10), 0, bag), "Solid furniture cannot overlap")
	assert(bag.count("oak_chair") == 1)
	assert(furniture.place("wool_rug", Vector2(4, 10), 0, bag), "A rug can lie under floor furniture")
	assert(furniture.place("rune_lantern", Vector2(5.5, 11.5), 0, bag))
	assert(furniture.move(chair, Vector2(5.5, 9.5), 1))
	assert(bag.count("oak_chair") == 1, "Moving must not consume a second item")
	var saved: Dictionary = furniture.snapshot()
	var fresh = script.new()
	assert(fresh.restore(JSON.parse_string(JSON.stringify(saved))))
	assert(fresh.snapshot() == saved)
	var home := Sanctum.new()
	fresh.apply(home)
	assert(not home.walkable(Vector2(5.5, 9.5)))
	assert(home.walkable(Vector2(home.start)) and home.walkable(Vector2(home.exit)))
	assert(home.walkable(home.hearth + Vector2.DOWN))
	var invalid := saved.duplicate(true)
	invalid.placed[0].point = [10, 17]
	assert(not fresh.restore(invalid) and fresh.snapshot() == saved)
	invalid = saved.duplicate(true)
	invalid.placed[0].rotation = 4
	assert(not fresh.restore(invalid))
	invalid = saved.duplicate(true)
	invalid.placed[0].item = "health_potion"
	assert(not fresh.restore(invalid))
	assert(fresh.remove(chair, bag))
	assert(bag.count("oak_chair") == 2)
	assert(not fresh.remove(chair, bag), "Picking up twice must not duplicate items")
	var portable: Array[Rect2] = [Rect2(3.85, 9.85, .3, .3)]
	assert(not furniture.candidate("oak_chair", Vector2(4, 10), 0, "", Vector2.INF, portable).problem.is_empty())
	assert(furniture.candidate("oak_chair", Vector2(4.5, 12), 0, "", Vector2.INF, portable).problem.is_empty(), "A portable object on a rug must not prevent unrelated furniture placement")
	var profiles := {}
	for id in Inventory.ITEMS:
		var spec: Dictionary = furniture.Catalog.definition(id)
		if not spec.is_empty():
			profiles[spec.profile] = id
	for profile in ["table", "wall_shelf", "display"]:
		assert(profiles.has(profile), "The shipped models must offer floor, wall and surface furniture")
	var table: String = profiles.table
	var display: String = profiles.display
	var shelf: String = profiles.wall_shelf
	assert(bag.add(table) and bag.add(display) and bag.add(shelf))
	assert(not fresh.place(display, Vector2(15, 12), 0, bag), "Small display objects need furniture support")
	assert(fresh.place(table, Vector2(15.5, 10.5), 0, bag))
	var table_uid: String = fresh.records[-1].uid
	assert(fresh.place(display, Vector2(15.5, 10.5), 0, bag))
	var display_uid: String = fresh.records[-1].uid
	assert(fresh.records[-1].parent == table_uid)
	assert(is_equal_approx(fresh.elevation(fresh.records[-1], fresh.records), .78))
	var supported_snapshot: Dictionary = fresh.snapshot()
	assert(not fresh.remove(table_uid, bag) and not fresh.move(table_uid, Vector2(14.5, 11), 1))
	assert(fresh.snapshot() == supported_snapshot, "Moving/removing support must not leave a floating display")
	assert(fresh.place(shelf, Vector2(4, 9), 0, bag))
	var shelf_uid: String = fresh.records[-1].uid
	assert(absf(fresh.records[-1].point[1] - 8.85) < .001)
	assert(fresh.move(shelf_uid, Vector2(3, 11), 1), "Quarter-turn rotation must snap to the west support")
	assert(absf(fresh.records[-1].point[0] - 2.85) < .001)
	var full := Inventory.new()
	while full.slots_used() < full.CAPACITY:
		assert(full.add("ember_shard", 99))
	var before_full: Dictionary = fresh.snapshot()
	assert(not fresh.remove(shelf_uid, full) and fresh.snapshot() == before_full, "Full backpacks must not delete furniture")
	assert(fresh.remove(display_uid, bag) and fresh.move(table_uid, Vector2(15, 11), 1))
	assert(script.valid(JSON.parse_string(JSON.stringify(fresh.snapshot()))))
	for record in fresh.records:
		var model: Node3D = fresh.Catalog.model(record)
		assert(model != null and model.get_child_count() > 0)
		assert(Scenery.new().valid_materials(model), "Furniture must keep valid source/default materials")
		model.free()
	assert(fresh.restore({}) and fresh.records.is_empty(), "Older saves get an empty home")
	print("PASS: furniture ownership/movement/refund transactions, full backpacks, rug layering, floor/wall/tabletop support, real models, home access and corrupt/legacy JSON state")
	quit()
