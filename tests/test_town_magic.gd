extends SceneTree

const World = preload("res://scripts/world.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Magic = preload("res://scripts/town_magic.gd")

func _init() -> void:
	var invalid: Dictionary = Areas.DATA.duplicate(true)
	invalid.cities[invalid.start_city].layouts[0].infill_plots[0] = [0,0]
	assert(not Areas.valid(invalid))
	invalid = Areas.DATA.duplicate(true)
	invalid.magic_profiles[invalid.cities[invalid.start_city].magic_profile].roof_charm_cap = 100
	assert(not Areas.valid(invalid))
	invalid = Areas.DATA.duplicate(true)
	invalid.cities[invalid.start_city].density.quarters.nw.uses = ["unknown"]
	assert(not Areas.valid(invalid))
	var profiles := {}
	var infill_total := 0
	var footprint_total := 0
	var primary_total := 0
	for seed_value in range(8):
		var world := World.new()
		world.generate(seed_value)
		for coordinate in [Vector2i.ZERO,Vector2i(-1,1),Vector2i(2,-1),Vector2i(-3,-2)]:
			var city: Dictionary = world.region_at(coordinate * World.REGION_SIZE).city
			assert(city.houses.size() >= 12,"Towns need at least twelve buildings with safe infill")
			assert(city.has("magic"),"Each town needs a civic charm tied to its actual features")
			profiles[city.magic.profile_id] = true
			world.load_around(Vector2(city.cell))
			var seen := {city.cell + Vector2i(0,3): true}
			var queue := seen.keys()
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for direction in World.DIRECTIONS:
					var next: Vector2i = cell + direction
					if not seen.has(next) and world.can_step(Vector2(cell),Vector2(next)) and world.move_actor(Vector2(cell),Vector2(direction)).is_equal_approx(Vector2(next)):
						seen[next] = true
						queue.append(next)
			var occupied := {}
			for house in city.houses:
				assert(seen.has(Vector2i(house.approach)),"Dense housing must preserve physical front-door access")
				for x in range(house.footprint.position.x,house.footprint.end.x):
					for y in range(house.footprint.position.y,house.footprint.end.y):
						var cell := Vector2i(x,y)
						assert(not occupied.has(cell) and not city.streets.has(cell))
						occupied[cell] = true
				if house.get("infill",false):
					infill_total += 1
				else:
					primary_total += house.footprint.get_area()
			footprint_total += occupied.size()
			for cell in city.magic.rune_cells:
				assert(city.streets.has(cell) and world.walkable(Vector2(cell)))
			assert(city.magic.roof_charms.size() <= city.magic.profile.roof_charm_cap)
			for lot in city.outdoor_lots:
				assert(seen.has(Vector2i(lot.approach)))
	for record in JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/town-primary-anchors.json")):
		var world := World.new()
		world.generate(int(record.seed))
		var region: Dictionary = world.region_at(Vector2i(record.coordinate[0],record.coordinate[1]) * World.REGION_SIZE)
		for original in record.houses:
			var found: Array = region.city.houses.filter(func(house): return house.id == original.id)
			assert(found.size() == 1)
			var house: Dictionary = found[0]
			assert(house.footprint == Rect2i(original.footprint[0],original.footprint[1],original.footprint[2],original.footprint[3]))
			assert(house.door == Vector2(original.door[0],original.door[1]) and house.facing == Vector2i(original.facing[0],original.facing[1]))
		for cell in record.streets:
			assert(region.city.streets.has(Vector2i(cell[0],cell[1])),"Existing streets must stay reserved")
		for original in record.ruins:
			var site: Dictionary = region.dungeons.filter(func(candidate): return candidate.id == original.id)[0]
			assert(site.cell == Vector2i(original.cell[0],original.cell[1]) and is_equal_approx(site.height,original.height))
	assert(infill_total >= 192 and footprint_total > primary_total * 1.4)
	var world := World.new()
	world.generate(12345)
	var city: Dictionary = world.region_at(world.start).city.duplicate(true)
	for profile_id in Areas.DATA.magic_profiles:
		city.magic = Magic.plan(city,profile_id,Areas.DATA.magic_profiles[profile_id],12345)
		var magic := Magic.new()
		magic.build(city)
		assert(magic.floating.size() == city.magic.roof_charms.size() + 1)
		var bottom: float = magic.floating[0].mesh.get_aabb().position.y + magic.origins[0].y - .07
		assert(bottom > 1.4,"Floating civic shapes need clearance above the fountain")
		var point: Vector3 = magic.floating[0].position
		magic._process(.4)
		assert(not magic.floating[0].position.is_equal_approx(point))
		assert(magic.get_child_count() <= 24)
		magic.free()
	print("PASS: dense connected towns, retained primary foundations/doors/streets/ruins, supported civic magic; building footprint increase %.2fx" % (float(footprint_total) / primary_total))
	quit()
