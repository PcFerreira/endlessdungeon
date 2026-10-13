extends SceneTree

const World = preload("res://scripts/world.gd")
const Life = preload("res://scripts/world_life.gd")
const Roamers = preload("res://scripts/wilderness_roamers.gd")

func _initialize() -> void:
	var catalogue := Roamers.new()
	assert(Roamers.valid(catalogue.data))
	var bad := catalogue.data.duplicate(true)
	bad.profiles[0].role = "guard"
	assert(not Roamers.valid(bad))
	var escaped := {"version": Life.VERSION, "tick": 0, "fraction": 0.0, "actors": {"roamer:2:6:0": {"point": [28,111], "target": [28,111], "heading": [0,1], "path": [], "activity": "roam", "next_tick": 0}}}
	assert(not Life.valid_snapshot(escaped), "An adjacent-chunk position outside the actual routing envelope must reject")
	escaped.actors["roamer:2:6:0"].point = [40,104]
	assert(not Life.valid_snapshot(escaped), "An escaped target must reject")
	escaped.actors["roamer:2:6:0"].target = [40,104]
	escaped.actors["roamer:2:6:0"].path = [[28,111]]
	assert(not Life.valid_snapshot(escaped), "An escaped path must reject")
	var profiles := {}
	for edition in [4, 6]:
		var world := World.new()
		world.generate(12345, edition)
		var life := Life.new()
		life.reset(12345)
		for point in [Vector2(40,100), Vector2(-96,35), Vector2(208,-120)]:
			world.load_around(point)
			life.sync(world, point)
			var walkers: Array = life.residents().filter(func(actor): return actor.get("roaming", false))
			assert(not walkers.is_empty(), "Wilderness must stream peaceful roaming NPCs, not only monsters and animals")
			assert(walkers.size() <= 4 and life.actors.size() <= Life.MAX_ACTORS)
			var starts := {}
			var explored := {}
			for actor in walkers:
				starts[actor.id] = actor.point
				profiles[actor.roaming_profile] = true
				assert(actor.role != "guard" and actor.role != "merchant" and not actor.get("traveling", false))
				assert(actor.spots.size() >= 3, "Open-area roamers need several distinct destinations")
				assert(actor.spots.any(func(spot): return absf(spot.x - actor.origin.x) >= 1 and absf(spot.y - actor.origin.y) >= 1), "Roamers must explore open ground beyond four cardinal lanes")
				assert(actor.spots.any(func(spot): return not is_zero_approx((Vector2(spot) - actor.origin).cross(actor.spots[1] - actor.origin))), "Open-area destinations must span an area rather than one straight line")
			for frame in range(240):
				life.advance(.1)
				life.step(world, point + Vector2(25,25), .1)
				assert(life.route_requests <= 1, "Wilderness walkers must share the existing route budget")
				for actor in walkers:
					var offset: Vector2 = actor.point - starts[actor.id]
					var extent: Vector2 = explored.get(actor.id,Vector2.ZERO)
					explored[actor.id] = Vector2(maxf(extent.x,absf(offset.x)),maxf(extent.y,absf(offset.y)))
					assert(world.walkable(actor.point) and world.cell_info(Vector2i(actor.point.round())).terrain == "land")
					assert(world.city_at(actor.point, 4).is_empty())
					assert(Roamers.allowed(world,actor.point,Roamers.grounds(world)), "Peaceful paths must remain outside monster grounds")
			assert(walkers.any(func(actor): return actor.point.distance_to(starts[actor.id]) > 1), "Peaceful walkers must actually move")
			assert(walkers.any(func(actor): return explored[actor.id].x > .75 and explored[actor.id].y > .75), "Open-area roaming must physically cover both axes")
			var walker: Dictionary = walkers[0]
			var paused: Vector2 = walker.point
			life.advance(.1)
			life.step(world, walker.point + Vector2(.5,0), .1)
			assert(walker.point.is_equal_approx(paused), "A nearby peaceful walker must stop for conversation")
			var saved: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
			assert(Life.valid_snapshot(saved, "12345", edition))
			var restored := Life.new()
			assert(restored.restore(saved,12345))
			restored.sync(world, point)
			assert(restored.actors[walker.id].point.is_equal_approx(walker.point))
			var invalid := saved.duplicate(true)
			invalid.actors[walker.id].point = [99999,0]
			assert(not Life.valid_snapshot(invalid,"12345",edition))
			invalid = saved.duplicate(true)
			for actor_id in invalid.actors.keys():
				if actor_id.begins_with("roamer:"):
					invalid.actors.erase(actor_id)
			for index in range(5):
				var record: Dictionary = saved.actors[walker.id].duplicate(true)
				record.point = [index * 16 + 8,8]
				record.target = record.point.duplicate()
				record.path = []
				invalid.actors["roamer:%s:0:0" % index] = record
			assert(not Life.valid_snapshot(invalid,"12345",edition), "Saved roamers must respect the four-actor budget")
	assert(profiles.size() >= 4, "Wilderness encounters need varied ordinary occupations")
	print("PASS: peaceful varied wilderness NPCs in editions4/6, actual movement, terrain/town bounds, bounded actor/route budgets, conversation pause, JSON restoration and rejected escaped positions")
	quit()
