extends SceneTree

const World = preload("res://scripts/world.gd")
const Life = preload("res://scripts/world_life.gd")
const Roamers = preload("res://scripts/wilderness_roamers.gd")
const POINT := Vector2(40, 100)
var failures: Array[String] = []

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	return condition

func bounds(actor: Dictionary) -> Rect2:
	var coordinate := World.chunk_at(actor.origin)
	return Rect2(coordinate * World.CHUNK_SIZE + Vector2i(2, 2), Vector2i(13, 13))

func escaped_point(world, actor: Dictionary) -> Vector2:
	var coordinate := World.chunk_at(actor.origin)
	var center := Vector2(coordinate * World.CHUNK_SIZE + Vector2i(8, 8))
	var hazards := Roamers.grounds(world)
	for x in range(-13, 14):
		for y in range(-13, 14):
			var point := center + Vector2(x, y)
			if World.chunk_at(point) != coordinate and point.distance_to(center) < 14 and Roamers.allowed(world, point, hazards):
				return point
	return Vector2(INF, INF)

func edition_checks(edition: int) -> void:
	var world := World.new()
	world.generate(12345, edition)
	world.load_around(POINT)
	var life := Life.new()
	life.reset(12345)
	life.sync(world, POINT)
	var fractional := false
	for step in range(80):
		life.advance(.1)
		life.step(world, POINT + Vector2(25, 25), .1)
		for actor in life.residents():
			if actor.get("roaming", false) and not actor.point.is_equal_approx(actor.point.round()):
				fractional = true
		if fractional:
			break
	check(fractional, "Actual edition%s roaming must produce a legitimate transient fractional point" % edition)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
	if not check(Life.valid_snapshot(saved, "12345", edition), "Actual edition%s generated fractional save must remain valid" % edition):
		return
	var fresh := Life.new()
	if not check(fresh.restore(saved, 12345), "Actual edition%s generated roster must restore" % edition):
		return
	fresh.sync(world, POINT)
	var tested := false
	for actor in life.residents():
		if not actor.get("roaming", false):
			continue
		var id: String = actor.id
		check(fresh.actors.has(id) and fresh.actors[id].point.is_equal_approx(actor.point), "Legitimate edition%s roster point must survive first restoration: %s" % [edition, id])
		var outside := escaped_point(world, actor)
		if not outside.is_finite():
			continue
		check(not bounds(actor).has_point(outside), "Malformed test point must escape the actual generated routing domain")
		for field in ["point", "target", "path"]:
			var bad := saved.duplicate(true)
			bad.actors[id][field] = [[outside.x, outside.y]] if field == "path" else [outside.x, outside.y]
			check(not Life.valid_snapshot(bad, "12345", edition), "Edition%s saved %s must reject escaped %s at %s" % [edition, id, field, outside])
			var before := fresh.snapshot()
			check(not fresh.restore(bad, 12345), "Edition%s restore must reject escaped %s" % [edition, field])
			check(fresh.snapshot() == before, "Rejected edition%s %s restoration must preserve live progress" % [edition, field])
		print("BOUNDS: ", {"edition": edition, "id": id, "routing": bounds(actor), "escaped": outside, "fractional_generated": fractional})
		tested = true
		break
	check(tested, "Actual edition%s fixture must include a naturally clear escaped roamer position" % edition)

func _init() -> void:
	for edition in [4, 6]:
		edition_checks(edition)
	if failures.is_empty():
		print("PASS: real edition4/6 generated fractional rosters restore, escaped point/target/path saves reject without replacing live progress")
	quit(0 if failures.is_empty() else 1)
