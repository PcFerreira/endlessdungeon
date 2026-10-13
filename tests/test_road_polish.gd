extends SceneTree

const World = preload("res://scripts/world.gd")
const Planner = preload("res://scripts/site_planner.gd")
const Life = preload("res://scripts/world_life.gd")
const Travel = preload("res://scripts/surface_travel.gd")

func _initialize() -> void:
	var diagonal := false
	var spans := 0
	for seed_value in [0,91,12345]:
		var world := World.new()
		world.generate(seed_value,6)
		var region: Dictionary = world.region_at(world.start)
		for route in region.routes:
			var canonical: Array = world.site_planner.routes[route.id]
			assert(route.path == canonical)
			for index in range(1,route.path.size()):
				var step: Vector2i = route.path[index] - route.path[index - 1]
				diagonal = diagonal or (step.x != 0 and step.y != 0)
			var boxes: Array[Rect2i] = world.site_planner.obstacles(route.path,[route.from_id,route.to_id])
			for point in Planner.raster(route.path):
				assert(not boxes.any(func(box): return box.has_point(point)),"Routes cannot cut through unrelated landmark footprints")
				if Planner.coordinate(point) == region.coordinate:
					assert(region.roads.has(point) and region.roads[point].centerline and world.cell_info(point).walkable,"Every declared centerline must exist and remain walkable")
		for bridge in region.bridges.values():
			assert(bridge.has("landing_from") and bridge.has("landing_to"),"Bridge spans must name both bank approaches")
			assert(bridge.from != bridge.to and bridge.length >= 2,"A crossing must be a continuous span, not isolated deck tiles")
			for bank in [bridge.landing_from,bridge.landing_to]:
				assert(not world.site_planner.routing.protected_water(bank),"Bridge approaches must reach dry natural ground or a protected entrance foundation")
			var crossing: Array[Vector2i] = [bridge.landing_from]
			crossing.append_array(bridge.path)
			crossing.append(bridge.landing_to)
			for reverse in [false,true]:
				if reverse:
					crossing.reverse()
				world.load_around(Vector2(crossing[0]))
				for index in range(1,crossing.size()):
					world.load_around(Vector2(crossing[index]))
					assert(world.can_step(Vector2(crossing[index - 1]),Vector2(crossing[index])))
					assert(world.move_actor(Vector2(crossing[index - 1]),Vector2(crossing[index] - crossing[index - 1])).is_equal_approx(Vector2(crossing[index])),"Every full bridge and both banks must carry the real footprint in both directions")
			spans += 1
		for connection in world.site_planner.connections(Vector2i.ZERO):
			var path: Array[Vector2i] = Planner.raster(world.site_planner.path(connection.from,connection.to))
			assert(not path.is_empty())
			world.load_around(Vector2(path[0]))
			for index in range(1,path.size()):
				world.load_around(Vector2(path[index]))
				assert(world.can_step(Vector2(path[index - 1]),Vector2(path[index])),"Bridge banks and rounded roads must have walkable grades")
				assert(world.move_actor(Vector2(path[index - 1]),Vector2(path[index] - path[index - 1])).is_equal_approx(Vector2(path[index])),"The real hero footprint must traverse every connector")
		for coordinate in [Vector2i(-1,-1),Vector2i(1,0)]:
			var adjacent: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
			for route in adjacent.routes:
				var blocked: Array[Rect2i] = world.site_planner.obstacles(route.path,[route.from_id,route.to_id])
				for point in Planner.raster(route.path):
					assert(not blocked.any(func(box): return box.has_point(point)))
					if Planner.coordinate(point) == coordinate:
						assert(adjacent.roads.has(point) and adjacent.roads[point].centerline and world.cell_info(point).walkable)
			for span in adjacent.bridges.values():
				assert(not world.site_planner.routing.protected_water(span.landing_from) and not world.site_planner.routing.protected_water(span.landing_to))
		var replay := World.new()
		replay.generate(seed_value,6)
		replay.region_at(Vector2i(-128,128))
		assert(replay.region_at(replay.start) == region,"Roads/decks cannot depend on streamed region order")
		assert(world.site_planner.routing.samples.size() <= 65536 and world.site_planner.routing.water_samples.size() <= 65536 and world.site_planner.routing.decks.size() <= 32)
	var legacy := Planner.new(91)
	var edge: Dictionary = legacy.backbone(Vector2i.ZERO)[0]
	var id := Travel.identity(edge.from.id,edge.to.id,0)
	var old_route := Travel.resolve(legacy,id)
	var position := Travel.at_distance(old_route.points,24,false)
	var record := {"point":[position.point.x,position.point.y],"target":[position.point.x,position.point.y],"heading":[0,1],"path":[],"activity":"travel","next_tick":0,"rest_until":0,"waypoint":position.waypoint,"road_direction":1}
	var old_save := {"version":1,"tick":0,"fraction":0,"context":{"edition":6,"seed":"91"},"actors":{id:record}}
	assert(Life.valid_snapshot(old_save,"91",6),"Old edition6 traveler snapshots without route metadata must remain readable")
	var current := World.new()
	current.generate(91,6)
	current.load_around(Vector2(current.start))
	var restored := Life.new()
	assert(restored.restore(old_save,91))
	restored.sync(current,Vector2(current.start))
	assert(restored.actors.has(id),"The saved nearby traveler must survive the road upgrade")
	var current_route := Travel.resolve(current.site_planner,id)
	assert(Travel.near_path(restored.actors[id].point,current_route.points,.01))
	assert(restored.snapshot().context.roads == 2 and Life.valid_snapshot(restored.snapshot(),"91",6))
	var bad := restored.snapshot()
	bad.context.roads = 3
	assert(not Life.valid_snapshot(bad,"91",6),"Unsupported road revisions must reject before restore")
	assert(diagonal,"Modern wilderness routes must include natural diagonal/rounded turns instead of only axis-aligned doglegs")
	assert(spans > 0)
	assert(Planner.raster([Vector2i.ZERO,Vector2i(10,3)])[5] == Vector2i(5,2),"Diagonal rasterization must follow the segment slope instead of diagonal-then-straight doglegs")
	print("PASS: terrain-aware canonical roads, obstacle clearance, continuous bridge banks, real footprint traversal, diagonal rasterization, positive/negative regions, stream-order replay and legacy traveler-save migration")
	quit()
