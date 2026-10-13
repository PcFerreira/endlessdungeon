extends SceneTree

const Items = preload("res://scripts/world_items.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Area = preload("res://scripts/grid_area.gd")

class RaisedFloor extends Area:
	var start := Vector2i(0, 0)
	var exit := Vector2i(10, 10)
	var rest_point := Vector2.ZERO
	var readables: Array = []
	func _init() -> void:
		bounds = Rect2i(-1, -1, 13, 13)
		for x in range(-1, 12):
			for y in range(-1, 12):
				tiles[Vector2i(x, y)] = true
	func ground_height(_point: Vector2) -> float:
		return .75

class Fixture extends Node3D:
	var layer := "interior"
	var state := "playing"
	var grounded := true
	var player_point := Vector2(3, 5)
	var enemies: Array = []
	var interiors := {"current": {"id": "stack-fixture"}}
	var dungeon := RaisedFloor.new()
	var inventory := Inventory.new()
	func to_world(point: Vector2, height: float = 0) -> Vector3:
		return Vector3(point.x, dungeon.ground_height(point) + height, point.y)
	func _rebuild_navigation() -> void:
		pass
	func _auto_save() -> void:
		pass
	func notify(_message: String) -> void:
		pass

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var fixture := Fixture.new()
	root.add_child(fixture)
	var items := Items.new()
	items.game = fixture
	fixture.add_child(items)
	fixture.inventory.items.clear()
	assert(fixture.inventory.add("health_potion", 5))
	var point := Vector2(5, 5)
	assert(items.place("health_potion", point))
	var bottom: Dictionary = items.state.placed[0]
	assert(is_equal_approx(items.placed_nodes[bottom.uid].position.y, .75), "Terrain height must be added exactly once")
	var bounds := Items.visual_bounds(items.placed_nodes[bottom.uid])
	assert(is_equal_approx(bounds.position.y, .75) and is_equal_approx(bounds.size.y, .45), "Rendered geometry must touch its saved ground and match the stacking height")
	for sprite in items.placed_nodes[bottom.uid].find_children("*", "Sprite3D", true, false):
		assert(sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Placed icons must stay upright so camera tilt cannot lift their bottom from the ground")
	var rotated := items.model({"item": "health_potion", "rotation": 1, "height": .45})
	var rotated_bounds := Items.visual_bounds(rotated)
	assert(is_equal_approx(rotated_bounds.size.x, .35) and is_equal_approx(rotated_bounds.size.y, .45), "Billboard rotation must preserve its grounded footprint")
	rotated.free()
	for level in range(1, 4):
		assert(items.place("health_potion", point), "Repeated placement must stack on the highest supported item")
		var record: Dictionary = items.state.placed[-1]
		assert(record.parent == items.state.placed[level - 1].uid)
		assert(is_equal_approx(record.elevation, level * .45))
		assert(is_equal_approx(items.placed_nodes[record.uid].position.y, .75 + level * .45))
	var snapshot := items.snapshot()
	assert(not items.place("health_potion", point) and items.snapshot() == snapshot and fixture.inventory.count("health_potion") == 1, "A fifth item must be rejected without consuming inventory")
	assert(not items.pickup(bottom.uid), "A stack's support cannot be picked up first")
	assert(Items.State.valid(JSON.parse_string(JSON.stringify(snapshot))), "Stacks must survive JSON saves")
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt.placed[0].parent = corrupt.placed[-1].uid
	assert(not Items.State.valid(corrupt), "Cyclic stacks must be rejected")
	corrupt = snapshot.duplicate(true)
	corrupt.placed[-1].scope = "interior:other"
	assert(not Items.State.valid(corrupt), "Stack supports must belong to the same location")
	corrupt = snapshot.duplicate(true)
	corrupt.placed[-1].elevation += .1
	assert(not Items.State.valid(corrupt), "Saved items cannot float above their support")
	corrupt = snapshot.duplicate(true)
	var fifth: Dictionary = corrupt.placed[-1].duplicate(true)
	fifth.uid = "p:5"
	fifth.parent = "p:4"
	fifth.elevation = 1.8
	corrupt.placed.append(fifth)
	corrupt.next_id = 6
	assert(not Items.State.valid(corrupt), "A forged fifth layer cannot bypass the save validator")
	var restored := Items.State.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(snapshot))) and restored.placed.size() == 4)
	for index in range(4):
		assert(restored.placed[index].parent == snapshot.placed[index].parent and is_equal_approx(restored.placed[index].elevation, snapshot.placed[index].elevation))
	items.state = restored
	items.sync_placed()
	assert(items.nearby()[0].uid == restored.placed[-1].uid, "Nearest pickup must choose the top of a stack")
	assert(items.pickup(items.state.placed[-1].uid) and items.place("health_potion", point), "Saved stacks must allow replacing the top item")
	for level in range(3, -1, -1):
		assert(items.pickup(items.state.placed[-1].uid))
	assert(fixture.inventory.count("health_potion") == 5)
	for other_city in [false, true]:
		var state := Items.State.new()
		var bag := Inventory.new()
		bag.items.clear()
		var source := {"uid": "fixture:base", "item": "health_potion", "scope": "overworld", "point": [5, 5], "parent": "", "owner": "city:a"}
		assert(state.pickup(source, bag) and state.place(source.item, "overworld", point, 0, bag, {"height": .45, "elevation": 0.0, "footprint": [.35, .35]}))
		var base_uid: String = state.placed[0].uid
		if other_city:
			var foreign := source.duplicate(true)
			foreign.uid = "fixture:foreign"
			foreign.owner = "city:b"
			assert(state.pickup(foreign, bag))
		else:
			assert(bag.add("health_potion"))
		assert(state.place("health_potion", "overworld", point, 0, bag, {"parent": base_uid, "height": .45, "elevation": .45, "footprint": [.35, .35]}))
		var before := state.snapshot()
		var bag_before := bag.snapshot()
		assert(not state.return_stolen("city:a", bag) and state.snapshot() == before and bag.snapshot() == bag_before, "Restitution must preserve clean and other-city stack children atomically")
		assert(state.pickup(state.placed[-1], bag) and state.return_stolen("city:a", bag))
	var same_city := Items.State.new()
	var owned := Inventory.new()
	owned.items.clear()
	for index in range(2):
		var source := {"uid": "fixture:city:%s" % index, "item": "health_potion", "scope": "overworld", "point": [5, 5], "parent": "", "owner": "city:a"}
		assert(same_city.pickup(source, owned))
		var extra := {"height": .45, "elevation": index * .45, "footprint": [.35, .35], "parent": "" if index == 0 else same_city.placed[0].uid}
		assert(same_city.place(source.item, "overworld", point, 0, owned, extra))
	assert(same_city.return_stolen("city:a", owned) and same_city.placed.is_empty() and same_city.removed.is_empty(), "Same-city stolen stacks must return together")
	fixture.queue_free()
	await process_frame
	print("PASS: raised-ground placement, four-item support stacks, fifth-item rollback, top-first pickup and saved parent validation")
	quit()
