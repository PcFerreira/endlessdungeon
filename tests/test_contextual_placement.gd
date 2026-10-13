extends SceneTree

const Content = preload("res://scripts/world_content.gd")
const Rooms = preload("res://scripts/interior_area.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Profiles = preload("res://scripts/asset_profiles.gd")
const Placement = preload("res://scripts/contextual_placement.gd")
const World = preload("res://scripts/world.gd")
var failures: Array[String] = []
var models_checked := 0

func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _initialize() -> void:
	var content := Content.new()
	var scenery := Scenery.new()
	for id in Inventory.ITEMS:
		check(load(Inventory.ITEMS[id].icon) is Texture2D, "Missing item icon: " + id)
	for definition in content.entries("interiors"):
		for layout in definition.layouts:
			var area := Rooms.new()
			area.generate({"id": "audit:" + definition.id, "type": definition.id, "layout_id": layout.id})
			var replay := Rooms.new()
			replay.generate(area.place.duplicate(true))
			check(area.props == replay.props, "Furniture replay changed: " + definition.id)
			var specs: Array = content.data.interior_defaults.props + layout.props
			for index in range(specs.size()):
				var spec: Dictionary = specs[index]
				var prop: Dictionary = area.props[index]
				var candidates: Array = content.models(spec.query) if spec.has("query") else [{"id": spec.fallback}]
				if candidates.is_empty():
					candidates = [{"id": spec.fallback}]
				for asset in candidates:
					var model := scenery.fitted_model(asset.id, prop.footprint, prop.height, prop.yaw)
					var box := scenery.bounds(model)
					var footprint := Rect2(Vector2(box.position.x, box.position.z) + prop.point, Vector2(box.size.x, box.size.z))
					var label: String = definition.id + "/" + layout.id + ": " + asset.id
					check(area.obstacles[index].grow(.001).encloses(footprint), "Geometry outside collision: " + label)
					check(Rect2(.57, .57, area.bounds.size.x - 2.14, area.bounds.size.y - 2.14).encloses(footprint), "Furniture outside walls: " + label)
					check(scenery.valid_materials(model), "Invalid furniture material: " + label)
					if spec.fallback in ["bookcase", "wall_shelf"]:
						var gap := minf(minf(footprint.position.x - .5, footprint.position.y - .5), minf(area.bounds.size.x - 1.5 - footprint.end.x, area.bounds.size.y - 1.5 - footprint.end.y))
						check(gap >= .065 and gap <= .16, "Shelf lacks nearby wall: " + label)
					models_checked += 1
					model.free()
				for previous in range(index):
					check(not area.obstacles[index].grow(.05).intersects(area.obstacles[previous]), "Furniture overlaps: " + definition.id + "/" + layout.id)
			var seen := {area.start: true}
			var queue := [area.start]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for direction in area.DIRECTIONS:
					var next: Vector2i = cell + direction
					if not seen.has(next) and area.walkable(Vector2(next)):
						seen[next] = true
						queue.append(next)
			check(seen.has(area.exit), "Room exit unreachable: " + definition.id)
			for readable in area.readables:
				check(seen.has(Vector2i(readable.approach)), "Book unreachable: " + definition.id)
			if area.rest_point != Vector2.ZERO:
				check(area.walkable(area.rest_point), "Rest blocked: " + definition.id)
	var invalid := content.data.duplicate(true)
	invalid.interior_defaults.props[0].point = [5, 5]
	check(not Content.valid(invalid), "Catalogue accepts shelf detached from wall")
	invalid = content.data.duplicate(true)
	invalid.interiors[0].layouts[0].props[0].point = [-2, 2]
	check(not Content.valid(invalid), "Catalogue accepts furniture outside room")
	invalid = content.data.duplicate(true)
	invalid.interiors[0].layouts[0].props[1].point = invalid.interiors[0].layouts[0].props[0].point.duplicate()
	check(not Content.valid(invalid), "Catalogue accepts overlapping furniture")
	invalid = content.data.duplicate(true)
	invalid.interior_defaults.props[0].facing = [0, -1]
	check(not Content.valid(invalid), "Catalogue accepts shelf facing its wall")
	invalid = content.data.duplicate(true)
	invalid.interior_defaults.readable.point = [7, 7]
	check(not Content.valid(invalid), "Catalogue accepts unsupported readable book")
	invalid = content.data.duplicate(true)
	invalid.interiors[0].layouts[0].props[2].face = [5, 5]
	check(not Content.valid(invalid), "Catalogue accepts chair aimed at absent table")
	invalid = content.data.duplicate(true)
	invalid.interiors[0].layouts[0].props[-1].elevation = 0
	check(not Content.valid(invalid), "Catalogue accepts wall shelf standing on floor")
	var dungeon_models := {}
	for family in Areas.DUNGEONS:
		for seed_value in range(12):
			for depth in [1, 8, 20]:
				var dungeon := Dungeon.new()
				dungeon.generate(seed_value, depth, family)
				var replay := Dungeon.new()
				replay.generate(seed_value, depth, family)
				check(dungeon.decorations == replay.decorations and dungeon.torch_mounts == replay.torch_mounts, "Dungeon dressing replay changed: " + family)
				for prop in dungeon.decorations:
					var box := Rect2(prop.point - prop.footprint * .5, prop.footprint)
					check(dungeon.obstacles.has(box), "Dungeon model lacks collision: " + family)
					var model_key: String = str([prop.model_id, prop.footprint, prop.yaw])
					if not dungeon_models.has(model_key):
						var model := scenery.fitted_model(prop.model_id, prop.footprint, prop.height, prop.yaw)
						var bounds := scenery.bounds(model)
						check(is_equal_approx(bounds.size.x, prop.footprint.x) and is_equal_approx(bounds.size.z, prop.footprint.y), "Dungeon geometry exceeds collision: " + prop.kind)
						model.free()
						dungeon_models[model_key] = true
					if prop.has("wall"):
						check_mount(dungeon, prop, "Furniture: " + family)
				for mount in dungeon.torch_mounts:
					check_mount(dungeon, mount, "Torch: " + family)
					var box := Rect2(mount.point - mount.footprint * .5, mount.footprint)
					check(not dungeon.obstacles.any(func(obstacle): return box.intersects(obstacle)), "Torch intersects furniture: " + family)
				var seen := {dungeon.start: true}
				var queue := [dungeon.start]
				while not queue.is_empty():
					var cell: Vector2i = queue.pop_back()
					for direction in dungeon.DIRECTIONS:
						var next: Vector2i = cell + direction
						if not seen.has(next) and dungeon.walkable(Vector2(next)):
							seen[next] = true
							queue.append(next)
				check(seen.has(dungeon.exit), "Dressing disconnects dungeon exit: " + family)
				for book in dungeon.readables:
					check(seen.has(Vector2i(book.approach)), "Dressing disconnects dungeon book: " + family)
				for spawn in dungeon.spawns:
					check(seen.has(spawn.cell), "Dressing disconnects enemy: " + family)
	check_world()
	for failure in failures:
		print("FAIL: " + failure)
	if failures.is_empty():
		print("PASS: all ten room layouts, %s furniture variants, item icons, collision/wall/overlap/access rules, invalid placement rejection and 216 seeded family floors" % models_checked)
	quit(0 if failures.is_empty() else 1)

func check_mount(area, prop: Dictionary, label: String) -> void:
	check(prop.wall != Vector2i.ZERO and not area.tiles.has(prop.cell + prop.wall), "Missing actual wall: " + label)
	var normal := Vector2(prop.wall)
	var edge: Vector2 = prop.point + normal * (prop.footprint.x if prop.wall.x != 0 else prop.footprint.y) * .5
	check(is_equal_approx((Vector2(prop.cell) + normal * .5 - edge).dot(normal), Placement.GAP), "Wrong wall gap: " + label)
	check(Vector2(sin(prop.yaw), cos(prop.yaw)).dot(-normal) > .99, "Facing wall: " + label)
	check(prop.point.distance_to(Vector2(area.start)) > 1 and prop.point.distance_to(Vector2(area.exit)) > 1, "Wall prop blocks portal: " + label)

func check_world() -> void:
	for seed_value in range(4):
		var world := World.new()
		world.generate(seed_value)
		for x in range(-1, 2):
			for y in range(-1, 2):
				var region: Dictionary = world.region_at(Vector2i(x, y) * World.REGION_SIZE)
				for prop in region.city.decorations:
					check(not region.city.streets.has(prop.cell), "Town prop obstructs street: " + region.city.id)
					check(prop.kind == "bookstand" or prop.kind in Areas.CITIES[region.city.archetype_id].props, "Town prop outside contextual pool: " + prop.kind)
					for house in region.city.houses:
						check(not house.footprint.has_point(prop.cell) and prop.cell != Vector2i(house.approach), "Town prop blocks house: " + house.id)
				for offset_x in range(-16, 17, 4):
					for offset_y in range(-16, 17, 4):
						var info: Dictionary = world.cell_info(region.city.cell + Vector2i(offset_x, offset_y))
						if not info.prop.is_empty():
							var pool: Array = Areas.DATA.facets[info.facet].props if not info.facet.is_empty() else Areas.DATA.biomes[str(info.biome)].props
							check(info.prop in pool and info.terrain == "land", "Wilderness prop outside biome/facet land pool: " + info.prop)
