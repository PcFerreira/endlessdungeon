extends RefCounted

const World = preload("res://scripts/world.gd")
const Targets = preload("res://scripts/regional_targets.gd")
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

static func _salt(seed_value: int, text: String) -> int:
	return hash("exploration:%s:%s" % [seed_value, text]) & 0x7fffffff

static func region_key(world, region: Dictionary) -> String:
	return "region:%s:%s:%s:%s" % [world.generator_version, world.run_seed, region.coordinate.x, region.coordinate.y]

static func plan(world, region: Dictionary, catalog) -> Dictionary:
	if world.generator_version >= 5:
		return _independent_plan(world, region, catalog)
	if region.get("city", {}).is_empty():
		return {}
	var key := region_key(world, region)
	var salt := _salt(world.run_seed, key)
	if region.coordinate != Vector2i.ZERO and salt % 4 == 0:
		return {}
	var center: Vector2i = region.city.cell
	var candidates: Array[Dictionary] = []
	for direction in DIRECTIONS:
		var sideways := Vector2i(-direction.y, direction.x)
		for distance in [16, 18, 20, 22, 24]:
			for side in [-1, 1]:
				var approach: Vector2i = center + direction * distance + sideways * side
				var point: Vector2i = approach + sideways * side
				if Vector2i(floori(float(point.x) / World.REGION_SIZE), floori(float(point.y) / World.REGION_SIZE)) != region.coordinate:
					continue
				var road: Dictionary = world.cell_info(approach)
				var ground: Dictionary = world.cell_info(point)
				if not road.walkable or road.terrain not in ["road", "bridge", "paving"]:
					continue
				if not ground.walkable or ground.terrain in ["road", "bridge", "paving", "water"] or not ground.prop.is_empty() or not ground.detail.is_empty():
					continue
				if absf(ground.height - road.height) > .5:
					continue
				var clear := true
				for site in region.dungeons:
					clear = clear and Vector2(point).distance_to(site.cell) >= 5
				if clear:
					candidates.append({"point": point, "approach": approach, "height": ground.height, "biome": ground.biome})
	if candidates.is_empty() or region.dungeons.is_empty():
		return {}
	var anchor: Dictionary = candidates[salt % candidates.size()]
	var definitions: Array = catalog.eligible(anchor.biome)
	if definitions.is_empty():
		return {}
	var definition: Dictionary = definitions[_salt(world.run_seed, key + ":definition") % definitions.size()]
	var pool: Array = catalog.models(definition)
	var asset: Dictionary = pool[_salt(world.run_seed, key + ":model") % pool.size()]
	var site: Dictionary = region.dungeons[_salt(world.run_seed, key + ":site") % region.dungeons.size()]
	return _entry(world, key, anchor, definition, asset, region.city, site)

static func _independent_plan(world, region: Dictionary, catalog) -> Dictionary:
	var key := region_key(world, region)
	var salt := _salt(world.run_seed, key)
	if World.sites_in(region).is_empty() or (region.coordinate != Vector2i.ZERO and salt % 4 == 0):
		return {}
	var sites := Targets.dungeons(world, region)
	if sites.is_empty():
		return {}
	var cells: Array = region.roads.keys()
	cells.sort_custom(func(a, b): return a.x < b.x if a.y == b.y else a.y < b.y)
	var candidates: Array[Dictionary] = []
	for cell in cells:
		if not region.roads[cell].get("centerline", false) or _salt(world.run_seed, key + str(cell)) % 8 != 0:
			continue
		for direction in DIRECTIONS:
			var approach: Vector2i = cell + direction
			var point: Vector2i = cell + direction * 2
			if Targets.Planner.coordinate(point) != region.coordinate:
				continue
			if World.sites_in(region).any(func(site): return site.footprint.grow(3).has_point(point)):
				continue
			var road: Dictionary = world.cell_info(approach)
			var ground: Dictionary = world.cell_info(point)
			if not road.walkable or road.terrain not in ["road", "bridge", "paving"] or not ground.walkable or ground.terrain in ["road", "bridge", "paving", "water"] or not ground.prop.is_empty() or not ground.detail.is_empty() or absf(ground.height - road.height) > .5:
				continue
			candidates.append({"point": point, "approach": approach, "height": ground.height, "biome": ground.biome})
	if candidates.is_empty():
		return {}
	var anchor: Dictionary = candidates[salt % candidates.size()]
	var definitions: Array = catalog.eligible(anchor.biome)
	if definitions.is_empty():
		return {}
	var definition: Dictionary = definitions[_salt(world.run_seed, key + ":definition") % definitions.size()]
	var pool: Array = catalog.models(definition)
	var asset: Dictionary = pool[_salt(world.run_seed, key + ":model") % pool.size()]
	var city: Dictionary = region.city if not region.city.is_empty() else world.nearest_site(Vector2(anchor.point), "city")
	if city.is_empty():
		return {}
	return _entry(world, key, anchor, definition, asset, city, sites[0])

static func _entry(world, key: String, anchor: Dictionary, definition: Dictionary, asset: Dictionary, city: Dictionary, site: Dictionary) -> Dictionary:
	var text: String = definition.text.replace("{city_name}", city.name).replace("{dungeon_name}", site.name)
	var author: String = definition.author.replace("{city_name}", city.name).replace("{dungeon_name}", site.name)
	if text.contains("{") or author.contains("{"):
		return {}
	var id := "discovery:%s:%s@%s" % [key, definition.id, int(definition.version)]
	return {"id": id, "region_id": key, "run_seed": str(world.run_seed), "generator_version": world.generator_version, "template_id": definition.id, "template_version": int(definition.version), "family": definition.family, "title": definition.title, "author": author, "text": text, "marker_label": definition.marker_label, "model_id": asset.id, "marker_width": definition.marker_width, "marker_height": definition.marker_height, "point": [anchor.point.x, anchor.point.y], "approach": [anchor.approach.x, anchor.approach.y], "ground_height": anchor.height, "biome": anchor.biome, "city_id": city.id, "city_name": city.name, "site_id": site.id, "site_name": site.name, "site_cell": [site.cell.x, site.cell.y]}
