extends RefCounted

const Scenery = preload("res://scripts/scenery.gd")
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/world_items.json"))

static func register(view, world, registrar: Callable, item_for_model: Callable, scope: String) -> void:
	for coordinate in view.chunk_nodes:
		var region: Dictionary = world.region_at(coordinate * world.CHUNK_SIZE)
		var city: Dictionary = region.get("city", {})
		if city.is_empty() or world.chunk_at(Vector2(city.cell)) != coordinate:
			continue
		var root: Node3D = view.chunk_nodes[coordinate]
		for decoration in city.decorations:
			var point := Vector3(decoration.cell.x, city.height, decoration.cell.y) - root.position
			var uid: String = "%s:decoration:%s:%s" % [city.id, decoration.cell.x, decoration.cell.y]
			for child in root.get_children():
				if child is Node3D and child.position.is_equal_approx(point):
					if child.has_meta("parts"):
						register_parts(child, uid, city, world, registrar, item_for_model, scope, [decoration.cell])
					elif decoration.kind in rules.movable_decorations and child.get_child_count() > 0:
						var item: String = item_for_model.call(child.get_meta("asset_id", decoration.kind))
						if not item.is_empty():
							publish(child, Scenery.new().bounds(child), uid, item, "", city, world, registrar, scope, [decoration.cell])
		for lot in city.outdoor_lots:
			var center: Vector2i = lot.footprint.get_center()
			var point := Vector3(center.x, city.height, center.y) - root.position
			for child in root.get_children():
				if child is Node3D and child.position.is_equal_approx(point) and child.has_meta("parts"):
					register_parts(child, lot.id, city, world, registrar, item_for_model, scope, lot.solid_cells)
	register_locations(view, world, registrar, item_for_model, scope)

static func register_locations(view, world, registrar: Callable, item_for_model: Callable, scope: String) -> void:
	for coordinate in view.chunk_nodes:
		var region: Dictionary = world.region_at(coordinate * world.CHUNK_SIZE)
		for site in region.get("locations", []):
			if world.chunk_at(Vector2(site.cell)) != coordinate:
				continue
			for child in view.chunk_nodes[coordinate].get_children():
				if child is Node3D and child.get_meta("surface_site_id", "") == site.id:
					register_parts(child, site.id, site, world, registrar, item_for_model, scope, site.solid_cells)

static func wrappers(model: Node3D) -> Dictionary:
	if model.has_meta("portable_nodes"):
		return model.get_meta("portable_nodes")
	var parts: Array = model.get_meta("parts", [])
	var nodes := {}
	for part in parts:
		var wrapper := Node3D.new()
		wrapper.name = "Part_" + part.id
		wrapper.set_meta("asset_id", part.asset)
		wrapper.set_meta("visual_family", part.get("visual_family", ""))
		model.add_child(wrapper)
		nodes[part.id] = wrapper
	for mesh in model.get_children():
		if not mesh is MeshInstance3D:
			continue
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		var chosen := ""
		var volume := INF
		for part in parts:
			var box: AABB = part.bounds
			if box.grow(.005).encloses(bounds) and box.get_volume() < volume:
				chosen = part.id
				volume = box.get_volume()
		if not chosen.is_empty():
			model.remove_child(mesh)
			nodes[chosen].add_child(mesh)
	model.set_meta("portable_nodes", nodes)
	return nodes

static func register_parts(model: Node3D, uid: String, city: Dictionary, world, registrar: Callable, item_for_model: Callable, scope: String, blocked: Array) -> void:
	var nodes := wrappers(model)
	var eligible := {}
	for part in model.get_meta("parts", []):
		if part.pool in rules.movable_pools and not part.get("fixed", false) and part.id not in rules.fixed_parts and nodes[part.id].get_child_count() > 0:
			var item: String = item_for_model.call(part.asset)
			if not item.is_empty():
				eligible[part.id] = item
	for part in model.get_meta("parts", []):
		if not eligible.has(part.id):
			continue
		var parent: String = uid + ":" + part.support if eligible.has(part.support) else ""
		var cells: Array = blocked if part.support == "ground" else []
		var access: Array = blocked
		if model.has_meta("surface_site_id"):
			var ground: Dictionary = part
			while ground.support != "ground":
				ground = model.get_meta("parts").filter(func(value): return value.id == ground.support)[0]
			var bounds: AABB = nodes[ground.id].global_transform * ground.bounds
			var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(.1)
			access = blocked.filter(func(cell): return footprint.has_point(Vector2(cell)))
		publish(nodes[part.id], part.bounds, uid + ":" + part.id, eligible[part.id], parent, city, world, registrar, scope, cells, access)

static func publish(node: Node3D, local_bounds: AABB, uid: String, item: String, parent: String, city: Dictionary, world, registrar: Callable, scope: String, blocked: Array, access: Array = []) -> void:
	var bounds: AABB = node.global_transform * local_bounds
	var point := Vector2(bounds.get_center().x, bounds.get_center().z)
	if city.books.any(func(book): return Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(.05).has_point(book.point)):
		return
	var cells: Array[Vector2i] = []
	for cell in blocked:
		if Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(.1).has_point(Vector2(cell)):
			cells.append(cell)
	registrar.call({"uid": uid, "item": item, "model_id": node.get_meta("asset_id", ""), "visual_family": node.get_meta("visual_family", ""), "point": point, "owner": city.get("owner", city.id), "scope": scope, "parent": parent, "footprint": Vector2(bounds.size.x, bounds.size.z), "height": bounds.size.y, "elevation": maxf(0, bounds.position.y - world.ground_height(point)), "solid": not cells.is_empty(), "blocked_cells": cells, "access_cells": access if not access.is_empty() else blocked}, node)
