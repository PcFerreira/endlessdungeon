extends RefCounted

const STEP := 12
const MARGIN := 48
class RouteGrid extends AStarGrid2D:
	var routing
	var boxes: Array[Rect2]
	func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		var from := Vector2(from_id * STEP)
		var to := Vector2(to_id * STEP)
		if not routing.clear_boxes(from,to,boxes):
			return INF
		if from_id.x != to_id.x and from_id.y != to_id.y and routing.wet_segment(from,to):
			return INF
		return from.distance_to(to)
	func _estimate_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		return Vector2(from_id - to_id).length() * STEP
var provider: WeakRef
var samples := {}
var water_samples := {}
var decks := {}

func _init(world) -> void:
	provider = weakref(world)

func sample(cell: Vector2i) -> Dictionary:
	if not samples.has(cell):
		var world = provider.get_ref()
		if samples.size() >= 65536:
			samples.clear()
		samples[cell] = {"water":water(cell),"height":world._raw_height(cell),"travel":world._travel_base(cell)}
	return samples[cell]

static func clear_segment(from: Vector2, to: Vector2, boxes: Array[Rect2i]) -> bool:
	var grown: Array[Rect2] = []
	for box in boxes:
		grown.append(Rect2(box).grow(1.1))
	return clear_boxes(from,to,grown)

static func clear_boxes(from: Vector2, to: Vector2, boxes: Array[Rect2]) -> bool:
	for box in boxes:
		if maxf(from.x,to.x) < box.position.x or minf(from.x,to.x) > box.end.x or maxf(from.y,to.y) < box.position.y or minf(from.y,to.y) > box.end.y:
			continue
		var enter := 0.0
		var leave := 1.0
		for axis in range(2):
			var delta: float = to[axis] - from[axis]
			if is_zero_approx(delta):
				if from[axis] < box.position[axis] or from[axis] > box.end[axis]:
					leave = -1
					break
				continue
			var first: float = (box.position[axis] - from[axis]) / delta
			var last: float = (box.end[axis] - from[axis]) / delta
			enter = maxf(enter,minf(first,last))
			leave = minf(leave,maxf(first,last))
		if enter <= leave:
			return false
	return true

func water(cell: Vector2i) -> bool:
	if not water_samples.has(cell):
		if water_samples.size() >= 65536:
			water_samples.clear()
		water_samples[cell] = provider.get_ref()._natural_water(cell)
	return water_samples[cell]

func wet_segment(from: Vector2, to: Vector2) -> bool:
	var count := maxi(1,ceili(from.distance_to(to) / 2))
	for index in range(count + 1):
		var point := Vector2i(from.lerp(to,float(index) / count).round())
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			if water(point + offset):
				return true
	return false

func connection(from: Vector2, to: Vector2, boxes: Array[Rect2i]) -> bool:
	return clear_segment(from,to,boxes) and (is_equal_approx(from.x,to.x) or is_equal_approx(from.y,to.y) or not wet_segment(from,to))

func path(from: Vector2i, to: Vector2i, boxes: Array[Rect2i]) -> Array[Vector2i]:
	var bounds := Rect2i(from,Vector2i.ONE).expand(to).grow(MARGIN)
	var graph := RouteGrid.new()
	graph.routing = self
	for box in boxes:
		graph.boxes.append(Rect2(box).grow(1.1))
	var lower := Vector2i(floori(float(bounds.position.x) / STEP),floori(float(bounds.position.y) / STEP))
	var upper := Vector2i(ceili(float(bounds.end.x) / STEP),ceili(float(bounds.end.y) / STEP))
	graph.region = Rect2i(lower,upper - lower)
	graph.cell_size = Vector2.ONE * STEP
	graph.update()
	for x in range(lower.x,upper.x):
		for y in range(lower.y,upper.y):
			var id := Vector2i(x,y)
			var point := id * STEP
			if not clear_boxes(Vector2(point),Vector2(point),graph.boxes):
				graph.set_point_solid(id)
				continue
			var context := sample(point)
			graph.set_point_weight_scale(id,1 + (5 if context.water else 0) + absf(context.height - context.travel) * .2)
	var first := endpoint(graph,from,boxes)
	var last := endpoint(graph,to,boxes)
	if not graph.region.has_point(first) or not graph.region.has_point(last):
		return []
	var points := graph.get_point_path(first,last)
	if points.is_empty():
		return []
	var result: Array[Vector2i] = [from]
	for point in points:
		var cell := Vector2i(point.round())
		if result[-1] != cell:
			result.append(cell)
	if result[-1] != to:
		result.append(to)
	return rounded(compact(result),boxes)

func endpoint(graph: RouteGrid, point: Vector2i, boxes: Array[Rect2i]) -> Vector2i:
	var nearest := Vector2i((Vector2(point) / STEP).round())
	var candidates: Array[Vector2i] = []
	for x in range(-2,3):
		for y in range(-2,3):
			candidates.append(nearest + Vector2i(x,y))
	candidates.sort_custom(func(a,b): return (a * STEP).distance_squared_to(point) < (b * STEP).distance_squared_to(point))
	for candidate in candidates:
		if graph.region.has_point(candidate) and not graph.is_point_solid(candidate) and connection(Vector2(point),Vector2(candidate * STEP),boxes):
			return candidate
	return graph.region.position - Vector2i.ONE

static func compact(points: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for point in points:
		if not result.is_empty() and result[-1] == point:
			continue
		if result.size() >= 2:
			var first := Vector2(result[-1] - result[-2])
			var last := Vector2(point - result[-1])
			if is_zero_approx(first.cross(last)) and first.dot(last) > 0:
				result.remove_at(result.size() - 1)
		result.append(point)
	return result

func rounded(points: Array[Vector2i], boxes: Array[Rect2i]) -> Array[Vector2i]:
	var curve := PackedVector2Array()
	for point in points:
		curve.append(Vector2(point))
	for pass_index in range(2):
		if curve.size() < 3:
			break
		var next := PackedVector2Array([curve[0]])
		for index in range(1,curve.size() - 1):
			var point := curve[index]
			var enter := point.move_toward(curve[index - 1],minf(8,point.distance_to(curve[index - 1]) * .25))
			var leave := point.move_toward(curve[index + 1],minf(8,point.distance_to(curve[index + 1]) * .25))
			if clear_segment(enter,leave,boxes) and not wet_segment(curve[index - 1],curve[index + 1]):
				next.append(enter)
				next.append(leave)
			else:
				next.append(point)
		next.append(curve[-1])
		curve = next
	var result: Array[Vector2i] = []
	for point in curve:
		result.append(Vector2i(point.round()))
	result = compact(result)
	for index in range(1,result.size()):
		if not connection(Vector2(result[index - 1]),Vector2(result[index]),boxes):
			return points
	return result

func protected_water(cell: Vector2i) -> bool:
	if not water(cell):
		return false
	var world = provider.get_ref()
	var plan: Dictionary = world.site_planner.slots(world.SitePlanner.coordinate(cell))
	for site in world.sites_in(plan):
		if site.footprint.has_point(cell) or site.corridors.any(func(box): return box.has_point(cell)):
			return false
	return true

func materialize(route: Dictionary) -> Dictionary:
	if decks.has(route.id):
		return decks[route.id]
	var world = provider.get_ref()
	var path: Array[Vector2i] = world.SitePlanner.raster(route.path)
	var wet: Array[bool] = []
	var axes: Array[Vector2i] = []
	for index in range(path.size()):
		var delta: Vector2i = path[index + 1] - path[index] if index + 1 < path.size() else path[index] - path[index - 1]
		var axis := Vector2i.RIGHT if delta.x != 0 else Vector2i.DOWN
		axes.append(axis)
		var side := Vector2i.DOWN if axis.x != 0 else Vector2i.RIGHT
		var crossing := false
		for offset in range(-1,2):
			crossing = crossing or protected_water(path[index] + side * offset)
		wet.append(crossing)
	var spans: Array[Dictionary] = []
	var bridge_indices := {}
	var cursor := 2
	while cursor < path.size() - 2:
		if not wet[cursor]:
			cursor += 1
			continue
		var first := cursor
		var last := cursor
		var search := cursor + 1
		while search < path.size() - 2 and search <= last + 4:
			if wet[search]:
				last = search
			search += 1
		var begin := maxi(1,first - 1)
		var end := mini(path.size() - 2,last + 1)
		var span := {"id":route.id + ":bridge:" + str(first),"from":path[begin],"to":path[end],"landing_from":path[begin - 1],"landing_to":path[end + 1],"axis":axes[first],"length":end - begin + 1,"path":path.slice(begin,end + 1)}
		spans.append(span)
		for index in range(begin,end + 1):
			bridge_indices[index] = span.id
		cursor = end + 1
	var cells := {}
	for index in range(path.size()):
		var cell: Vector2i = path[index]
		var side := Vector2i.DOWN if axes[index].x != 0 else Vector2i.RIGHT
		var corner := index > 0 and index + 1 < path.size() and path[index] - path[index - 1] != path[index + 1] - path[index]
		var offsets: Array[Vector2i] = [-side,Vector2i.ZERO,side]
		if corner:
			for x in range(-1,2):
				for y in range(-1,2):
					var offset := Vector2i(x,y)
					if offset not in offsets:
						offsets.append(offset)
		for offset in offsets:
			var point: Vector2i = cell + offset
			var bridge: bool = bridge_indices.has(index)
			var record := {"bridge":bridge,"axis":axes[index],"edge":(offset.x * side.x + offset.y * side.y) if not corner else 0,"pier":posmod(point.x + point.y,4) == 0,"route_id":route.id,"centerline":offset == Vector2i.ZERO,"bridge_id":bridge_indices.get(index,"")}
			if cells.has(point):
				record.centerline = record.centerline or cells[point].centerline
				record.bridge = record.bridge or cells[point].bridge
			cells[point] = record
	var result := {"cells":cells,"bridges":spans}
	if decks.size() >= 32:
		decks.erase(decks.keys()[0])
	decks[route.id] = result
	return result
