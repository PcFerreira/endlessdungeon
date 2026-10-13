extends RefCounted

const World = preload("res://scripts/world.gd")
const HubWorld = preload("res://scripts/hub_world.gd")
var thread := Thread.new()
var mutex := Mutex.new()
var semaphore := Semaphore.new()
var pending := {}
var completed := []
var signature := ""
var stopping := false

static func supports(world, point: Vector2) -> bool:
	return world.get_script() == World or (world.get_script() == HubWorld and not world.hub.reserved.has_point(Vector2i(point.round())))

func request(token: int, seed_value: int, edition: int, coordinates: Array, warm_regions: bool = false, hub_theme: String = "") -> void:
	var key := str([token, seed_value, edition, coordinates, warm_regions, hub_theme])
	if coordinates.is_empty() or key == signature:
		return
	signature = key
	mutex.lock()
	pending = {"token":token, "seed":seed_value, "edition":edition, "coordinates":coordinates.duplicate(), "warm_regions":warm_regions, "hub_theme":hub_theme}
	mutex.unlock()
	if not thread.is_started():
		var start_error := thread.start(_work)
		if start_error != OK:
			signature = ""
			mutex.lock()
			pending = {}
			mutex.unlock()
			push_error("Cannot start chunk worker: %s" % start_error)
			return
	semaphore.post()

func take(token: int, regions: Dictionary = {}, seed_value = null, edition: int = 0, world = null) -> Dictionary:
	var result := {}
	mutex.lock()
	for batch in completed:
		if batch.token == token and (seed_value == null or batch.seed == seed_value) and (edition == 0 or batch.edition == edition):
			result.merge(batch.chunks)
			for coordinate in batch.regions:
				if not regions.has(coordinate):
					regions[coordinate] = batch.regions[coordinate]
			_trim(regions, batch.regions, 32)
			if world != null:
				world.route_plans.merge(batch.route_plans)
				_trim(world.route_plans, batch.route_plans, 128)
				if world.site_planner != null:
					world.site_planner.plans.merge(batch.plans)
					world.site_planner.routes.merge(batch.routes)
					_trim(world.site_planner.plans, batch.plans, 128)
					_trim(world.site_planner.routes, batch.routes, 128)
	completed.clear()
	mutex.unlock()
	return result

func _trim(cache: Dictionary, incoming: Dictionary, limit: int) -> void:
	for key in cache.keys():
		if cache.size() <= limit:
			return
		if not incoming.has(key):
			cache.erase(key)

func stop() -> void:
	if not thread.is_started():
		return
	mutex.lock()
	stopping = true
	mutex.unlock()
	semaphore.post()
	thread.wait_to_finish()

func _work() -> void:
	var world = null
	var token := -1
	var hub_theme := ""
	while true:
		semaphore.wait()
		mutex.lock()
		var done := stopping
		var job: Dictionary = pending
		pending = {}
		mutex.unlock()
		if done:
			return
		if job.is_empty():
			continue
		if world == null or token != job.token or world.run_seed != job.seed or world.generator_version != job.edition or hub_theme != job.hub_theme:
			world = World.new() if job.hub_theme.is_empty() else HubWorld.new()
			if not job.hub_theme.is_empty():
				world.hub = HubWorld.City.new(job.hub_theme)
			world.generate(job.seed, job.edition)
			token = job.token
			hub_theme = job.hub_theme
		if world.regions.size() > 128:
			world.generate(job.seed, job.edition)
		var chunks := {}
		for coordinate in job.coordinates:
			chunks[coordinate] = world._build_chunk(coordinate).duplicate(true)
		_publish(job, world, chunks)
		if job.warm_regions:
			var warmed := {}
			for coordinate in job.coordinates:
				var region: Vector2i = Vector2i(floori(float(coordinate.x * World.CHUNK_SIZE) / World.REGION_SIZE), floori(float(coordinate.y * World.CHUNK_SIZE) / World.REGION_SIZE))
				if not warmed.has(region):
					world.nearby_sites(Vector2(region * World.REGION_SIZE))
					warmed[region] = true
			_publish(job, world, {})

func _publish(job: Dictionary, world, chunks: Dictionary) -> void:
	var regions: Dictionary = world.regions.duplicate(true)
	var route_plans: Dictionary = world.route_plans.duplicate(true)
	var plans: Dictionary = {} if world.site_planner == null else world.site_planner.plans.duplicate(true)
	var routes: Dictionary = {} if world.site_planner == null else world.site_planner.routes.duplicate(true)
	mutex.lock()
	# A batch owns its dictionaries; the worker never reads them again.
	completed.append({"token":job.token, "seed":job.seed, "edition":job.edition, "chunks":chunks, "regions":regions, "route_plans":route_plans, "plans":plans, "routes":routes})
	if completed.size() > 4:
		completed.pop_front()
	mutex.unlock()
