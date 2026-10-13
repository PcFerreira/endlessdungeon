extends SceneTree

const World = preload("res://scripts/finite_world.gd")
const Catalog = preload("res://scripts/dimension_catalog.gd")
const Constructions = preload("res://scripts/dimension_constructions.gd")

func _initialize() -> void:
	var world := World.new()
	world.generate(12345, 6)
	var data := world.definition
	assert(data.sites.size() >= 56, "Morrowmere needs new villages, homes, graves and classic landmarks")
	var kinds := {}
	var citizens := 0
	for recipe in data.sites:
		kinds[recipe.type] = int(kinds.get(recipe.type, 0)) + 1
		citizens += recipe.get("residents", []).size()
	for kind in ["village", "graveyard", "woodland_house"]:
		assert(kinds.get(kind, 0) >= 8)
	assert(kinds.castle >= 6 and kinds.temple >= 9 and kinds.ruin >= 7)
	assert(citizens >= 64 and data.encounters.size() >= 16)
	assert(Catalog.valid(data))
	var bad := data.duplicate(true)
	bad.content_version = 1.5
	assert(not Catalog.valid(bad))
	bad = data.duplicate(true)
	var inhabited: Array = bad.sites.filter(func(site): return not site.get("residents", []).is_empty())
	inhabited[1].residents[0].id = inhabited[0].residents[0].id
	assert(not Catalog.valid(bad), "Resident identities must be unique across communities")
	bad = data.duplicate(true)
	bad.encounters[0].members[0].enemy_id = "unknown_monster"
	assert(not Catalog.valid(bad))
	bad = data.duplicate(true)
	bad.encounters[0].cell = bad.spawn
	assert(not Catalog.valid(bad), "Authoring cannot place a hostile ground at arrival")
	var resident_ids := {}
	for site in world.authored_sites():
		assert(world.map_extent.encloses(site.footprint))
		for book in site.books:
			assert(world.cell_info(Vector2i(book.approach)).walkable)
		if site.has("rest_point"):
			assert(world.cell_info(Vector2i(site.rest_point)).walkable)
		for resident in site.get("population_residents", []):
			assert(not resident_ids.has(resident.id))
			resident_ids[resident.id] = true
			var home: Vector2i = site.cell + Vector2i(resident.offset[0], resident.offset[1])
			assert(world.cell_info(home).walkable)
			for offset in resident.route:
				assert(world.cell_info(site.cell + Vector2i(offset[0], offset[1])).walkable)
			var xs: Array = resident.route.map(func(point): return point[0])
			var ys: Array = resident.route.map(func(point): return point[1])
			assert(xs.max() - xs.min() >= 2 and ys.max() - ys.min() >= 1, "Residents need open-area movement in both axes")
			for index in range(resident.route.size()):
				var from := Vector2(resident.route[index][0], resident.route[index][1])
				var next: int = (index + 1) % resident.route.size()
				var to := Vector2(resident.route[next][0], resident.route[next][1])
				for step in range(21):
					var point := Vector2(site.cell) + from.lerp(to, step / 20.0)
					assert(world._supported(point))
					if site.has("rest_point"):
						assert(point.distance_to(site.rest_point) >= 2)
					for book in site.books:
						assert(point.distance_to(book.approach) >= 2)
	world.load_around(world.spawn_point())
	assert(world.chunks.size() <= 25 and world.chunks.values().all(func(chunk): return chunk.spawns.is_empty()), "The arrival clearing must remain peaceful")
	var population := 0
	var ids := {}
	for ground in data.encounters:
		world.load_around(Vector2(ground.cell[0], ground.cell[1]))
		for chunk in world.chunks.values():
			assert(chunk.spawns.size() <= 2, "Authored encounters must respect the existing streaming combatant cap")
			for spawn in chunk.spawns:
				assert(spawn.id.begins_with("dimension:morrowmere:grounds:"))
				assert(world.cell_info(spawn.cell).walkable and world.city_at(Vector2(spawn.cell), 18).is_empty())
				assert(Vector2(spawn.cell).distance_to(world.spawn_point()) > 24 and Vector2(spawn.cell).distance_to(Vector2(world.return_portal)) > 24)
				ids[spawn.id] = true
		population += ground.members.size()
	assert(population >= 48 and ids.size() == population, "Every authored monster must actually enter a streamed chunk")
	var original: Dictionary = Constructions.DATA.duplicate(true)
	Constructions.DATA.profiles["shrine"] = Constructions.DATA.profiles.temple.duplicate(true)
	Constructions.DATA.defaults["shrine"] = ["future_shrine"]
	Constructions.DATA.constructions["future_shrine"] = Constructions.DATA.constructions.wild_court.duplicate(true)
	Constructions.DATA.constructions.future_shrine.kind = "shrine"
	assert(Constructions.valid(Constructions.DATA))
	var future := data.duplicate(true)
	future.id = "future_content_probe"
	future.default = false
	future.sites[0].type = "shrine"
	future.sites[0].construction_id = "future_shrine"
	assert(Catalog.valid(future), "A data-defined construction category cannot need another catalogue branch")
	Catalog.records[future.id] = future
	var expanded := World.new(future.id)
	expanded.generate(12345, 6)
	assert(expanded.authored_sites()[0].construction_id == "future_shrine")
	assert(expanded.cell_info(Vector2i(expanded.authored_sites()[0].books[0].approach)).walkable)
	Constructions.DATA = original
	print("PASS: authored Morrowmere structures, citizens, peaceful arrival and real bounded monster chunks")
	quit()
