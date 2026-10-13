extends SceneTree

const Catalog = preload("res://scripts/dimension_catalog.gd")
const Terrain = preload("res://scripts/dimension_terrain.gd")
var definition: Dictionary
var terrain
var plots: Array[Rect2i] = []

func _initialize() -> void:
	definition = Catalog.definition()
	terrain = Terrain.new(definition)
	var additions: Array = JSON.parse_string(FileAccess.get_file_as_string("/tmp/morrowmere-new-sites.json"))
	var ids := additions.map(func(site): return site.id)
	definition.routes = definition.routes.filter(func(route): return not ids.any(func(id): return route.id == "branch_" + id))
	var all_sites: Array = definition.sites.filter(func(site): return site.id not in ids)
	all_sites.append_array(additions)
	for site in all_sites:
		var cell := Catalog.point(site.cell)
		var radius: int = Catalog.site_profile(site.type).radius
		plots.append(Rect2i(cell - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1)))
	var routes: Array[Dictionary] = []
	for site in additions:
		var from := Catalog.point(site.cell) + Vector2i.DOWN * int(Catalog.site_profile(site.type).approach)
		var to := road_connection(from)
		assert(to != Vector2i(-1,-1), "No existing road connector")
		var path := build_path(from, to)
		assert(path.size() > 1, "No physical path for " + site.id)
		var encoded := []
		for cell in path:
			encoded.append([cell.x, cell.y])
		routes.append({"id": "branch_" + site.id, "width":3, "path":encoded})
	var file := FileAccess.open("/tmp/morrowmere-new-routes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(routes, "\t"))
	file.close()
	print("PASS: %s authored approach paths join the existing network around protected construction footprints" % routes.size())
	quit()

func blocked(cell: Vector2i) -> bool:
	return plots.any(func(plot): return plot.grow(1).has_point(cell))

func road_connection(from: Vector2i) -> Vector2i:
	var closest := Vector2i(-1,-1)
	var distance := INF
	for route in definition.routes:
		for index in range(route.path.size() - 1):
			var a := Catalog.point(route.path[index])
			var b := Catalog.point(route.path[index + 1])
			var length := maxi(absi(b.x - a.x), absi(b.y - a.y))
			for step in range(0, length + 1, 4):
				var cell := Vector2i(Vector2(a).lerp(Vector2(b), float(step) / maxi(1,length)).round())
				var delta := cell.distance_squared_to(from)
				if delta < distance and not blocked(cell):
					distance = delta
					closest = cell
	return closest

func build_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var start := Vector2i((Vector2(from) / 4).round())
	var end := Vector2i((Vector2(to) / 4).round())
	var limits := Rect2i(start, Vector2i.ONE).expand(end).grow(32)
	var grid := AStarGrid2D.new()
	grid.region = limits
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(limits.position.x, limits.end.x):
		for y in range(limits.position.y, limits.end.y):
			var id := Vector2i(x,y)
			var cell := id * 4
			grid.set_point_solid(id, not Catalog.box(definition.bounds).has_point(cell) or blocked(cell))
			grid.set_point_weight_scale(id, 1.0 + terrain.raw_height_at(cell) * .06 if terrain.land_at(cell) else 5.0)
	grid.set_point_solid(start, false)
	grid.set_point_solid(end, false)
	var raw := grid.get_id_path(start, end)
	var result: Array[Vector2i] = [from]
	for id in raw:
		var cell: Vector2i = id * 4
		if cell == result[-1]:
			continue
		if result.size() >= 2 and Vector2(cell - result[-1]).normalized() == Vector2(result[-1] - result[-2]).normalized():
			result[-1] = cell
		else:
			result.append(cell)
	if result[-1] != to:
		result.append(to)
	return result
