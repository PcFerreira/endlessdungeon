extends SceneTree

const Architecture = preload("res://scripts/town_architecture.gd")
const Layout = preload("res://scripts/town_voxel_layout.gd")
const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_view.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Game = preload("res://scripts/game.gd")
var architecture := Architecture.new()
var scenery := Scenery.new()
var directory := "user://test-town-voxel-integration-%s" % Time.get_ticks_usec()
var game_verified := false

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	if "--game-only" not in OS.get_cmdline_user_args():
		check_models()
		check_layout()
	await check_game()
	assert(game_verified,"Gameplay acceptance did not complete")
	print("PASS: themed market theft/restitution and disk-restored shop" if "--game-only" in OS.get_cmdline_user_args() else "PASS: eight native town themes, 52 runtime identities in both truthful families, aligned usable doors, bounded fitting, safe gate collisions, real portable goods and disk-restored themed shop")
	quit()

func check_models() -> void:
	var reached := {}
	for theme in Layout.THEMES:
		for biome in [0,2]:
			var family: String = architecture.styles.family_for(biome)
			var city := {"id":"voxel-city:" + theme,"theme_id":theme,"archetype_id":"city_crossroads","biome":biome}
			for id in architecture.native_town.data.templates:
				if architecture.native_town.data.templates[id].theme != theme:
					continue
				var model := architecture.native_town.fitted(id,Vector2(2.9,1.9),3.2,family)
				assert(model != null,architecture.native_town.error)
				assert(architecture.styles.family_of(model.get_meta("render_asset")) == family)
				var angled := false
				for mesh in model.get_children():
					for normal in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
						assert(normal.is_finite())
						if maxf(absf(normal.x),maxf(absf(normal.y),absf(normal.z))) < .999:
							angled = true
				assert(angled == (family == "flat_lowpoly"),"Rendered family must describe actual geometry")
				model.free()
				reached[id] = true
			for facing in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
				for size in [Vector2i(2,2),Vector2i(3,2),Vector2i(2,3)]:
					for use_id in ["home","scribe"]:
						var house := {"id":"fit:" + theme,"use_id":use_id,"footprint":Rect2i(Vector2i.ZERO,size),"height":1.3,"facing":facing}
						var center: Vector2i = house.footprint.get_center()
						house.door = Vector2i(house.footprint.end.x if facing.x > 0 else -1,center.y) if facing.x else Vector2i(center.x,house.footprint.end.y if facing.y > 0 else -1)
						var before: Dictionary = house.duplicate(true)
						seed(278)
						var expected := randi()
						seed(278)
						var model: Node3D = architecture.build(house,city)
						assert(randi() == expected and house == before,"Fitting must preserve plans and gameplay RNG")
						assert(model != null and model.has_meta("town_voxel_id"))
						var bounds := scenery.bounds(model)
						var fit := Vector2(size.y,size.x) if facing.x else Vector2(size)
						assert(bounds.size.x <= fit.x - .09 and bounds.size.z <= fit.y - .09 and bounds.end.y <= 2.301)
						var base := Vector2(house.footprint.position) + (Vector2(size) - Vector2.ONE) * .5
						var socket: Vector3 = Basis(Vector3.UP,atan2(facing.x,facing.y)) * model.get_meta("door_socket")
						var difference := Vector2(socket.x,socket.z) + base - Vector2(house.door)
						assert(absf(difference.dot(Vector2(-facing.y,facing.x))) < .001,"Door must align with the generated approach axis")
						assert(model.get_meta("door_clearance").x >= .8 and model.get_meta("door_clearance").y >= 1.5)
						check_aperture(model)
						model.free()
			for index in range(40):
				city.id = "civic:%s:%s" % [theme,index]
				var civic := architecture.civic(city)
				assert(civic != null and scenery.bounds(civic).size.x <= 2.701 and scenery.bounds(civic).end.y <= 3.801)
				civic.free()
	assert(reached.size() == 52)
	assert(architecture.native_town.templates.size() <= architecture.native_town.CACHE_LIMIT)
	assert(architecture.native_town.fitted("missing",Vector2.ONE,2,"block_voxel") == null)
	assert(architecture.native_town.fitted("japanese_house",Vector2.ONE,1.0,"block_voxel") == null)
	assert(architecture.native_town.fitted("japanese_house",Vector2.ONE,2.3,"block_voxel",.5) == null)
	print("CHECK: all resources, purposes, rectangular plots and cardinal entrance axes")

func check_aperture(model: Node3D) -> void:
	var door: Vector3 = model.get_meta("door_socket")
	for mesh in model.get_children():
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index in range(0,points.size(),3):
			var center := (points[index] + points[index + 1] + points[index + 2]) / 3
			assert(not (absf(center.x - door.x) < .30 and center.y > .20 and center.y < 1.50 and center.z > door.z - .13),"Entrance corridor contains facade triangles")

func check_layout() -> void:
	var themes := {}
	var view := View.new()
	for edition in [4,5,6]:
		var world := World.new()
		world.generate(0,edition)
		var tested := 0
		for x in range(-4,5):
			for y in range(-4,5):
				var region: Dictionary = world.region_at(Vector2i(x,y) * World.REGION_SIZE)
				var city: Dictionary = region.city
				if city.is_empty() or city.get("gateway",{}).is_empty():
					continue
				themes[city.theme_id] = true
				for post in city.gateway.solid_cells:
					assert(not world.cell_info(post).walkable)
					assert(not region.roads.has(post) and not city.streets.has(post))
				for offset in [-1,0,1]:
					assert(world.cell_info(city.gateway.cell + Vector2i(0,offset)).walkable,"Gate must preserve all three road cells")
				var before: Dictionary = city.duplicate(true)
				var parent := Node3D.new()
				view._build_town_gateway(parent,city)
				assert(parent.get_child_count() == 1 and city == before)
				assert(parent.get_child(0).get_meta("door_clearance").x >= 3.0)
				var gate: Node3D = parent.get_child(0)
				for mesh in gate.get_children():
					for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
						var point: Vector3 = gate.transform * (mesh.transform * vertex)
						if point.y < city.height + .9:
							assert(city.gateway.solid_cells.any(func(cell): return absf(point.x - cell.x) <= .501 and absf(point.z - cell.y) <= .501),"Every low gateway surface must lie inside a blocked post cell")
				var blocked := city.duplicate(true)
				blocked.streets[blocked.gateway.solid_cells[0]] = true
				assert(Layout.gateway(blocked,region.roads).is_empty())
				parent.free()
				tested += 1
				if (edition == 4 and themes.size() == 8) or (edition > 4 and tested >= 3):
					break
			if (edition == 4 and themes.size() == 8) or (edition > 4 and tested >= 3):
				break
		assert(tested > 0)
	view.free()
	assert(themes.size() == 8,"Every theme must have a reachable gate")
	print("CHECK: editions4/5/6 preserve roads and block gateway posts")

func check_game() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(0)
	var city := {}
	for x in range(-5,6):
		for y in range(-5,6):
			var candidate: Dictionary = game.world.region_at(Vector2i(x,y) * World.REGION_SIZE).city
			if candidate.get("theme_id", "") == "japanese":
				city = candidate.duplicate(true)
				break
		if not city.is_empty():
			break
	assert(not city.is_empty())
	game.begin_journey()
	game._generate_surface(Vector2(city.cell) + Vector2(0,3),false)
	game._clear_actors()
	game.world_items.register_location()
	assert(game.world.region_at(city.cell).city == city)
	assert(game.world_view.find_children("*","Node3D",true,false).any(func(node): return node.get_meta("town_voxel_shelter", "") == "japanese/market"))
	var goods := {}
	for entry in game.world_items.registered.values():
		if entry.record.uid.begins_with(city.id + ":lot:market:") and entry.record.uid.contains("goods"):
			goods = entry
			break
	assert(not goods.is_empty(),"The native shelter must preserve registered market wares")
	var uid: String = goods.record.uid
	var item: String = goods.record.item
	game.player_point = game.world.safe_position(game.world_items.position(goods.record))
	assert(game.world_items.pickup(uid) and not goods.node.visible and game.inventory.stolen_count(item) == 1)
	assert(game.save_game(1) and game.load_game(1))
	assert(game.world_items.registered.has(uid) and not game.world_items.registered[uid].node.visible)
	assert(game.world_items.return_stolen(city.id))
	assert(game.world_items.registered[uid].node.visible)
	var shop := {}
	for house in city.houses:
		var place: Dictionary = game.interiors.describe(city,house)
		if place.type == "shop":
			shop = place
			break
	assert(not shop.is_empty())
	game._generate_surface(shop.approach,false)
	game._clear_actors()
	game.interact()
	assert(game.layer == "interior" and game.interiors.current.id == shop.id)
	var counter: Dictionary = game.stores.sources()[0]
	assert(counter.id == shop.id and game.dungeon.walkable(counter.point))
	game.player_point = counter.point
	game.interact()
	assert(game.state == "store")
	assert(game.inventory.add("gold_coin",200))
	var offers: Dictionary = game.stores.offers(counter)
	var stock_item: String = offers.keys()[0]
	var old_stock: int = offers[stock_item].count
	var coins: int = game.inventory.count("gold_coin")
	assert(game.stores.buy(stock_item))
	assert(game.inventory.count("gold_coin") == coins - offers[stock_item].buy)
	assert(game.stores.offers(counter)[stock_item].count == old_stock - 1)
	game.stores.close()
	var trade: Dictionary = game.stores.snapshot()
	assert(game.save_game(2))
	var fresh := Game.new()
	fresh.records_enabled = false
	fresh.save_directory = directory
	fresh.settings_path = directory.path_join("settings.cfg")
	root.add_child(fresh)
	fresh.set_physics_process(false)
	assert(fresh.load_game(2) and fresh.interiors.current.id == shop.id)
	assert(fresh.stores.snapshot() == trade)
	assert(fresh.interiors.leave() and fresh.player_point.is_equal_approx(shop.approach))
	assert(fresh.world.region_at(city.cell).city == city)
	game.queue_free()
	fresh.queue_free()
	await process_frame
	game_verified = true
	print("CHECK: real themed market theft/restitution, shop E, fresh save/load and original return")
