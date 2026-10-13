extends SceneTree

const World = preload("res://scripts/world.gd")
const Types = preload("res://scripts/town_types.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Magic = preload("res://scripts/town_magic.gd")
const Style = preload("res://scripts/town_style.gd")

func _init() -> void:
	var seen := {}
	var samples := {}
	assert(Types.valid(Types.DATA))
	for id in ["city_rainwood","city_reedpaper","city_jadebeam","city_porcelain_exchange","city_warmstone","city_moonjar","city_harvestmask","city_candlewake","city_evergreen_hearth","city_giftmakers","city_neon_relay","city_chrome_bazaar","city_spellbinders","city_observatory","city_dewbell","city_petalweave"]:
		assert(Types.DATA.types.has(id),"Requested cultural/festival/fantastic town is missing: " + id)
	for field in ["base","signature_use","weight","biomes","architecture","quarter_uses","farm","magic"]:
		var invalid := Types.DATA.duplicate(true)
		invalid.types.city_grain[field] = null
		assert(not Types.valid(invalid),"Malformed town identity must be rejected: " + field)
	var invalid := Types.DATA.duplicate(true)
	invalid.types.city_grain.architecture.height = [1,4]
	assert(not Types.valid(invalid),"Themes must not move existing structural height anchors")
	invalid = Types.DATA.duplicate(true)
	invalid.types.city_grain.weight = .5
	assert(not Types.valid(invalid),"Weighted selection accepts only whole positive tickets")
	invalid = Types.DATA.duplicate(true)
	invalid.forms.sheaf[0][1] = [0,1,1]
	assert(not Types.valid(invalid))
	invalid = Types.DATA.duplicate(true)
	invalid.types.city_rainwood.exterior_style = "unknown"
	assert(not Types.valid(invalid))
	invalid = Types.DATA.duplicate(true)
	invalid.types.city_rainwood.theme_id = "unknown"
	assert(not Types.valid(invalid))
	for seed_value in range(4):
		var world := World.new()
		world.generate(seed_value)
		var start: Dictionary = world.region_at(world.start).city
		assert(start.settlement_type_id == Areas.DATA.start_city)
		for x in range(-5,6):
			for y in range(-5,6):
				var city: Dictionary = world.region_at(Vector2i(x,y) * World.REGION_SIZE).city
				assert(city.has("settlement_type_id"),"Towns need a stable authored identity beyond six base layouts")
				seen[city.settlement_type_id] = true
				if not samples.has(city.settlement_type_id):
					samples[city.settlement_type_id] = {"seed":seed_value,"coordinate":Vector2i(x,y),"city":city.duplicate(true)}
				if Types.DATA.types.has(city.settlement_type_id):
					var entry: Dictionary = Types.DATA.types[city.settlement_type_id]
					assert(entry.base == city.archetype_id and entry.biomes.any(func(value): return int(value) == city.biome))
					assert(city.magic.profile_id == city.settlement_type_id + ":charm")
					assert(city.magic.profile.custom == entry.magic.custom)
					if entry.has("exterior_style"):
						assert(city.has("exterior_profile"),"Requested themes need actual exterior accents beyond type labels")
					assert(city.houses.any(func(house): return house.get("infill",false) and house.use_id == entry.signature_use))
					assert(city.houses.all(func(house): return house.interior_type in ["home","shop","inn","workshop","shrine"]))
					assert(city.outdoor_lots[0].id == city.id + ":lot:market" and city.outdoor_lots[1].id == city.id + ":lot:farm")
					assert(city.outdoor_lots[1].recipe.crop_shape == entry.farm.crop_shape)
					assert(city.outdoor_lots[0].footprint == Rect2i(city.cell + Vector2i(9,-11),Vector2i(3,3)))
					assert(city.outdoor_lots[1].footprint == Rect2i(city.cell + Vector2i(-11,9),Vector2i(3,3)))
	assert(seen.size() == Areas.CITIES.size() + Types.DATA.types.size(),"Every authored town identity must be reachable")
	for id in samples:
		var sample: Dictionary = samples[id]
		var world := World.new()
		world.generate(sample.seed)
		var city: Dictionary = world.region_at(sample.coordinate * World.REGION_SIZE).city
		assert(city == sample.city,"Eviction/regeneration must retain the complete town identity/plan")
		world.load_around(Vector2(city.cell))
		var reachable := {city.cell + Vector2i(0,3):true}
		var queue := reachable.keys()
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			for direction in World.DIRECTIONS:
				var next: Vector2i = cell + direction
				if not reachable.has(next) and world.can_step(Vector2(cell),Vector2(next)) and world.move_actor(Vector2(cell),Vector2(direction)).is_equal_approx(Vector2(next)):
					reachable[next] = true
					queue.append(next)
		for target in city.houses + city.outdoor_lots + city.books + city.residents:
			assert(reachable.has(Vector2i(target.approach)),"Every identity needs real physical access: " + id)
		var occupied := {}
		for house in city.houses:
			if city.has("exterior_profile"):
				var geometry := Style.plan(house,city.exterior_profile)
				assert(not geometry.solid.is_empty() or not geometry.glow.is_empty())
				var width: float = house.footprint.size.y if house.facing.x != 0 else house.footprint.size.x
				var length: float = house.footprint.size.x if house.facing.x != 0 else house.footprint.size.y
				for box in geometry.solid + geometry.glow:
					var point: Vector3 = box[0]
					var size: Vector3 = box[1]
					assert(absf(point.x) + size.x * .5 <= width * .5 and absf(point.z) + size.z * .5 <= length * .5,"Decorations must stay on their actual house footprint")
					assert(point.y - size.y * .5 >= 0 and point.y + size.y * .5 <= house.height + 1.06,"Decorations must clear ground access and roof charms")
			for x in range(house.footprint.position.x,house.footprint.end.x):
				for y in range(house.footprint.position.y,house.footprint.end.y):
					var cell := Vector2i(x,y)
					assert(not occupied.has(cell) and not city.streets.has(cell))
					occupied[cell] = true
		var magic := Magic.new()
		magic.build(city)
		assert(magic.get_child_count() <= 24)
		assert(magic.floating[0].mesh.get_aabb().position.y + magic.origins[0].y - .07 > 1.4)
		magic.free()
		var style := Style.new()
		style.build(city)
		assert(style.get_child_count() <= city.houses.size() * 2)
		assert(not city.has("exterior_profile") or style.get_child_count() > 0)
		assert(style.get_children().all(func(node): return node is MeshInstance3D and node.has_meta("house_id")))
		style.free()
	print("PASS: %s reachable seeded identities, climate eligibility, signature trades/customs, retained lot IDs, repeatability, physical access and bounded native charms" % seen.size())
	quit()
