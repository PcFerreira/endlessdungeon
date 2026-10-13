extends SceneTree

const World = preload("res://scripts/world.gd")
const Life = preload("res://scripts/world_life.gd")
const Travel = preload("res://scripts/surface_travel.gd")

func _init() -> void:
	var counts := {"turns": 0, "moves": 0, "restored": 0}
	for seed_value in [0, 91]:
		var world = World.new()
		world.generate(seed_value, 5)
		world.load_around(Vector2(world.start))
		var life = Life.new()
		life.reset(seed_value)
		life.sync(world, Vector2(world.start))
		var merchants: Array = life.residents().filter(func(actor): return actor.role == "merchant" and actor.id.begins_with("road5:"))
		assert(not merchants.is_empty(), "Actual town routes must stream travelers naturally")
		var actor: Dictionary = merchants[0]
		var route := Travel.resolve(world.site_planner, actor.id)
		assert(not route.is_empty() and actor.waypoints == route.points and route.points.size() > 2)
		assert(Travel.resolve(world.site_planner, "road5:0:0:999:999:0").is_empty(), "A pair of arbitrary towns is not an authored road")
		var forward_end: Vector2 = actor.waypoints[-1]
		var last_waypoint: int = actor.waypoint
		var stalled := 0
		var saved_once := false
		for index in range(20000):
			world.load_around(actor.point)
			life.advance(.1)
			var before: Vector2 = actor.point
			life._move_road(world, actor, actor.point + Vector2(4, 4), .1)
			assert(world.walkable(actor.point) and world.can_step(before, actor.point), "The real traveler must remain physically supported through every turn/bridge")
			stalled = stalled + 1 if actor.point.is_equal_approx(before) and life.tick >= actor.rest_until else 0
			if stalled >= 100:
				print("STALL: ", {"seed": seed_value, "id": actor.id, "point": actor.point, "goal": actor.waypoints[actor.waypoint], "waypoint": actor.waypoint, "points": actor.waypoints, "height": world.ground_height(actor.point), "clearance": world.clearance_height(actor.point), "target": actor.target, "target_height": world.ground_height(actor.target), "target_clearance": world.clearance_height(actor.target), "target_walkable": world.walkable(actor.target)})
				print("RAW PATH: ", world.site_planner.path(route.from, route.to))
				for x in range(-1, 2):
					for y in range(-1, 2):
						var cell := Vector2i(actor.target.round()) + Vector2i(x, y)
						print(cell, " ", world.cell_info(cell), " road ", world.region_at(cell).roads.get(cell, {}))
			assert(stalled < 100, "A curved itinerary must not stall at " + str(actor.point))
			counts.moves += int(not actor.point.is_equal_approx(before))
			if actor.waypoint != last_waypoint:
				counts.turns += 1
				last_waypoint = actor.waypoint
				if not saved_once:
					var saved: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
					assert(Life.valid_snapshot(saved, str(seed_value), 5))
					var restored = Life.new()
					assert(restored.restore(saved, seed_value))
					restored.sync(world, actor.point)
					assert(restored.actors.has(actor.id) and restored.actors[actor.id].point.is_equal_approx(actor.point))
					assert(restored.actors[actor.id].waypoint == actor.waypoint and restored.actors[actor.id].road_direction == actor.road_direction)
					var bad: Dictionary = saved.duplicate(true)
					bad.actors[actor.id].point = [actor.point.x + 100, actor.point.y + 100]
					assert(not Life.valid_snapshot(bad, str(seed_value), 5))
					bad = saved.duplicate(true)
					bad.context.seed = str(seed_value + 1)
					assert(not Life.valid_snapshot(bad, str(seed_value), 5))
					bad = saved.duplicate(true)
					bad.actors[actor.id].waypoint = route.points.size()
					assert(not Life.valid_snapshot(bad, str(seed_value), 5))
					assert(not Life.valid_snapshot(saved, str(seed_value), 4))
					counts.restored += 1
					saved_once = true
			if actor.road_direction == -1 and actor.point.distance_to(forward_end) > 3:
				break
		assert(actor.road_direction == -1 and actor.point.distance_to(forward_end) > 3 and saved_once, "Actual itinerary reaches its endpoint, rests and returns along the route")
	assert(counts.turns >= 4 and counts.restored == 2)
	print("PASS: real canonical town travelers; complete curved/bridge itineraries, endpoint rest/reversal, physical streaming and JSON restore, off-route/foreign-seed/edition/waypoint rejection; ", JSON.stringify(counts))
	quit()
