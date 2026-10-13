extends Node3D

const State = preload("res://scripts/world_item_state.gd")
const Catalog = preload("res://scripts/item_catalog.gd")
const Furniture = preload("res://scripts/furnishing_catalog.gd")
const Visual = preload("res://scripts/item_visual.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var game
var state := State.new()
var scenery := Scenery.new()
var registered: Dictionary = {}
var placed_nodes: Dictionary = {}
var applied_obstacles: Array[Rect2] = []
var canvas := CanvasLayer.new()
var overlay := Control.new()
var status: Label
var panel: PanelContainer
var ghost: Node3D
var selected := ""
var target := Vector2.ZERO
var preview_rotation := 0
var mouse_positioning := false
var preview_key := ""
var rest_marker: Node3D
var ghost_materials: Dictionary = {}
var footprint_marker: MeshInstance3D

func _ready() -> void:
	canvas.layer = 21
	add_child(canvas)
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()

func scope() -> String:
	if game.layer == "dungeon":
		return "dungeon:" + game.view_key
	if game.layer == "interior":
		return "interior:" + game.interiors.current.id
	return game.layer

func snapshot() -> Dictionary:
	return state.snapshot()

func restore(data: Dictionary) -> bool:
	stop()
	return state.restore(data)

func reset() -> void:
	stop()
	state.reset()

func stop() -> void:
	overlay.hide()
	selected = ""
	preview_key = ""
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func clear_location() -> void:
	stop()
	registered.clear()
	for node in placed_nodes.values():
		node.queue_free()
	placed_nodes.clear()
	if game != null:
		for obstacle in applied_obstacles:
			game.dungeon.obstacles.erase(obstacle)
	applied_obstacles.clear()
	if is_instance_valid(rest_marker):
		rest_marker.queue_free()
	rest_marker = null

static func position(record: Dictionary) -> Vector2:
	return Vector2(record.point[0], record.point[1])

static func box(record: Dictionary) -> Rect2:
	var size: Array = record.get("footprint", [.35, .35])
	return Rect2(position(record) - Vector2(size[0], size[1]) * .5, Vector2(size[0], size[1]))

func register_prop(source: Dictionary, node: Node3D) -> void:
	if not game.offline_actions_allowed():
		return
	var record := {"uid": source.uid, "scope": source.get("scope", scope()), "item": source.item, "point": source.point, "owner": source.get("owner", ""), "parent": source.get("parent", "")}
	if record.point is Vector2:
		record.point = [record.point.x, record.point.y]
	for key in ["footprint", "height", "elevation", "solid", "model_id", "visual_family", "blocked_cells", "access_cells"]:
		if source.has(key):
			record[key] = source[key]
	if record.get("footprint") is Vector2:
		record.footprint = [record.footprint.x, record.footprint.y]
	for key in ["blocked_cells", "access_cells"]:
		if record.has(key):
			record[key] = record[key].map(func(cell): return [cell.x, cell.y] if cell is Vector2i else cell)
	if not State.valid_record(record):
		return
	registered[record.uid] = {"record": record, "node": node}
	node.visible = not state.removed.has(record.uid)
	if state.removed.has(record.uid) and record.get("solid", false):
		game.dungeon.obstacles.erase(box(record))
		free_source_cells(record)

func free_source_cells(record: Dictionary) -> void:
	if game.layer == "overworld":
		for cell in record.get("blocked_cells", []):
			var point := Vector2i(cell[0], cell[1])
			if game.world.cells.has(point):
				game.world.tiles[point] = true

func register_location() -> void:
	if not game.offline_actions_allowed():
		return
	for uid in registered.keys():
		if not is_instance_valid(registered[uid].node):
			registered.erase(uid)
	if game.layer == "dungeon":
		game.dungeon_view.register_dressing(register_prop, Catalog.for_asset, scope())
	elif game.layer == "interior":
		for index in range(game.dungeon.props.size()):
			var prop: Dictionary = game.dungeon.props[index]
			var item := Catalog.for_asset(prop.kind)
			if item.is_empty():
				continue
			# Required readables keep their own support fixed.
			if game.dungeon.readables.any(func(book): return Rect2(prop.point - prop.footprint * .5, prop.footprint).has_point(book.point)):
				continue
			var key: String = prop.get("source_key", str(index))
			var parent: String = scope() + ":prop:" + prop.parent if not prop.get("parent", "").is_empty() else ""
			register_prop({"uid": scope() + ":prop:" + key, "item": item, "model_id": prop.kind, "visual_family": prop.get("visual_family", ""), "parent": parent, "point": prop.point, "owner": game.interiors.current.city_id, "scope": scope(), "footprint": prop.footprint, "height": prop.height, "elevation": prop.elevation, "solid": prop.get("solid", true)}, game.interiors.view.prop_nodes[index])
	elif game.layer == "overworld" and game.world_view.has_method("register_dressing"):
		game.world_view.register_dressing(register_prop, Catalog.for_asset, scope())
	sync_placed()
	refresh_rest_marker()

func refresh_rest_marker() -> void:
	if is_instance_valid(rest_marker):
		rest_marker.queue_free()
	rest_marker = null
	var rest := rest_record()
	if rest.is_empty():
		return
	rest_marker = Node3D.new()
	rest_marker.position = game.to_world(position(rest), .02)
	var mesh := Voxels.cube(Vector3(.95, .035, .95), Color("6a9d98"))
	rest_marker.add_child(mesh)
	var label := Label3D.new()
	label.text = "Base / Rest"
	label.position.y = .55
	label.font_size = 24
	label.pixel_size = .006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rest_marker.add_child(label)
	add_child(rest_marker)

func sync_placed() -> void:
	for obstacle in applied_obstacles:
		game.dungeon.obstacles.erase(obstacle)
	applied_obstacles.clear()
	var wanted_nodes := {}
	for record in state.placed:
		if record.scope != scope() or not game.dungeon.bounds.has_point(Vector2i(position(record).round())):
			continue
		wanted_nodes[record.uid] = true
		if not placed_nodes.has(record.uid):
			var node := model(record)
			add_child(node)
			placed_nodes[record.uid] = node
		var node: Node3D = placed_nodes[record.uid]
		node.position = game.to_world(position(record), record.get("elevation", 0))
		node.visible = game.layer != "dungeon" or game.enemy_render_visible(position(record))
		if record.get("solid", false) and record.parent.is_empty():
			var obstacle := box(record)
			game.dungeon.obstacles.append(obstacle)
			applied_obstacles.append(obstacle)
	for uid in placed_nodes.keys():
		if not wanted_nodes.has(uid):
			placed_nodes[uid].queue_free()
			placed_nodes.erase(uid)

func model(record: Dictionary) -> Node3D:
	var item: Dictionary = Catalog.definitions[record.item]
	var biome: int = 0
	if game.layer == "overworld":
		var point: Vector2 = position(record) if record.has("point") else target
		biome = game.world.cell_info(Vector2i(point.round())).biome
	elif game.layer in ["dungeon", "interior"]:
		biome = game.dungeon.biome
	var family: String = Visual.families.styles.family_for(biome)
	var recipe := Furniture.definition(record.item)
	if not recipe.is_empty():
		return Furniture.model(record, scenery, family)
	if item.kind == "furnishing" and (item.has("asset_id") or item.has("scenery_key")):
		var spec := placement_spec(record.item)
		var size := Furniture.footprint(spec, int(record.get("rotation", 0)))
		return Visual.families.fitted(Visual.families.create(item, family), size, spec.height, int(record.get("rotation", 0)) * PI / 2)
	var node := Visual.model(item, record.get("height", .45), family, record.item)
	if node == null:
		push_error("Placed item requires a valid family-aware body: " + record.item + " / " + Visual.families.error)
		return null
	var rotation := Transform3D(Basis(Vector3.UP, int(record.get("rotation", 0)) * PI / 2), Vector3.ZERO)
	for child in node.get_children():
		if child is Node3D and not child is SpriteBase3D:
			child.transform = rotation * child.transform
	var bounds := visual_bounds(node)
	var extent: Vector2 = Furniture.footprint(placement_spec(record.item), int(record.get("rotation", 0)))
	var scale_factor := Vector3(extent.x / maxf(.001, bounds.size.x), record.get("height", .45) / maxf(.001, bounds.size.y), extent.y / bounds.size.z if bounds.size.z > .001 else 1.0)
	var fit := Transform3D(Basis.from_scale(scale_factor), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z))
	for child in node.get_children():
		if child is Node3D:
			child.transform = fit * child.transform
		if child is Sprite3D:
			child.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return node

static func visual_bounds(node: Node3D, parent: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent * node.transform
	var bounds := AABB()
	if node is Sprite3D:
		var rect: Rect2 = node.get_item_rect()
		bounds = transform * AABB(Vector3(rect.position.x, -rect.end.y, 0) * node.pixel_size, Vector3(rect.size.x, rect.size.y, 0) * node.pixel_size)
	elif node is MeshInstance3D:
		bounds = transform * node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := visual_bounds(child, transform)
			if child_bounds.size != Vector3.ZERO:
				bounds = child_bounds if bounds.size == Vector3.ZERO else bounds.merge(child_bounds)
	return bounds

func placement_spec(item: String) -> Dictionary:
	var spec := Furniture.definition(item)
	if not spec.is_empty():
		return spec
	var definition: Dictionary = Catalog.definitions.get(item, {})
	if definition.get("kind", "") == "furnishing":
		return {"footprint": [.75, .75], "height": .8, "support": "floor", "solid": true}
	return {"footprint": [.35, .35], "height": .45, "support": "floor", "solid": false}

func nearby() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in registered.values():
		var record: Dictionary = entry.record
		if is_instance_valid(entry.node) and entry.node.is_visible_in_tree() and not state.removed.has(record.uid) and reachable(record):
			result.append(record)
	for record in state.placed:
		if record.scope == scope() and reachable(record):
			result.append(record)
	result.sort_custom(func(a, b):
		var first := position(a).distance_squared_to(game.player_point)
		var second := position(b).distance_squared_to(game.player_point)
		return a.get("elevation", 0) > b.get("elevation", 0) if is_equal_approx(first, second) else first < second)
	return result

func reachable(record: Dictionary) -> bool:
	if game.player_point.distance_to(position(record)) > 2.4 or (game.layer == "dungeon" and not game.enemy_render_visible(position(record))):
		return false
	if game.dungeon.line_clear(game.player_point, position(record)):
		return true
	if game.layer != "overworld" or record.get("access_cells", []).is_empty():
		return false
	var allowed := {}
	for cell in record.access_cells:
		allowed[Vector2i(cell[0], cell[1])] = true
	var steps := maxi(1, ceili(game.player_point.distance_to(position(record)) / .2))
	for index in range(steps + 1):
		var point: Vector2 = game.player_point.lerp(position(record), float(index) / steps)
		var cell := Vector2i(point.round())
		if not game.world.tiles.has(cell) and not allowed.has(cell):
			return false
		if game.world.ground_height(point) > game.player_y + .8:
			return false
	return true

func has_children(uid: String) -> bool:
	return registered.values().any(func(entry): return is_instance_valid(entry.node) and entry.record.parent == uid and not state.removed.has(entry.record.uid)) or state.placed.any(func(record): return record.parent == uid)

func pickup(uid: String) -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.state not in ["playing", "world_items"] or not game.grounded:
		return false
	var found := {}
	for record in nearby():
		if record.uid == uid:
			found = record
	if found.is_empty():
		return false
	if has_children(uid):
		game.notify("Take the objects on this support first.")
		return false
	if not state.pickup(found, game.inventory):
		game.notify(state.error)
		return false
	if registered.has(uid):
		registered[uid].node.hide()
		if found.get("solid", false):
			game.dungeon.obstacles.erase(box(found))
			free_source_cells(found)
	sync_placed()
	game._rebuild_navigation()
	game.notify("Taken: %s%s" % [Catalog.definitions[found.item].name, " / Stolen from the city" if not found.get("owner", "").is_empty() else ""])
	game._auto_save()
	if game.state == "world_items":
		open_placement()
	return true

func take_nearest() -> bool:
	if not game.offline_actions_allowed():
		return false
	var choices := nearby().filter(func(record): return not has_children(record.uid))
	if choices.is_empty():
		game.notify("No movable object within reach. V opens world objects.")
		return false
	return pickup(choices[0].uid)

func wanted(city_id: String) -> Dictionary:
	return state.wanted(city_id)

func refuse_return(city_id: String) -> bool:
	if not game.offline_actions_allowed():
		return false
	var changed := state.refuse_return(city_id)
	if changed:
		game._auto_save()
	return changed

func return_stolen(city_id: String) -> bool:
	if not game.offline_actions_allowed():
		return false
	if not state.return_stolen(city_id, game.inventory):
		game.notify(state.error)
		return false
	for entry in registered.values():
		if is_instance_valid(entry.node) and not state.removed.has(entry.record.uid):
			entry.node.show()
			var blocked: Array = entry.record.get("blocked_cells", [])
			if game.layer == "overworld":
				for cell in blocked:
					game.world.tiles.erase(Vector2i(cell[0], cell[1]))
			if blocked.is_empty() and entry.record.get("solid", false) and not game.dungeon.obstacles.has(box(entry.record)):
				game.dungeon.obstacles.append(box(entry.record))
	sync_placed()
	if not game.dungeon.walkable(game.player_point):
		game.player_point = game.dungeon.safe_position(game.player_point)
		game._snap_camera()
	game._refresh_equipment()
	game._rebuild_navigation()
	game._auto_save()
	return true

func supports() -> Array:
	var result: Array = state.placed.filter(func(record): return record.scope == scope())
	for entry in registered.values():
		if is_instance_valid(entry.node) and not state.removed.has(entry.record.uid):
			result.append(entry.record)
	return result

func stack_depth(record: Dictionary, local: Array) -> int:
	var depth := 1
	var parent: String = record.get("parent", "")
	while not parent.is_empty():
		depth += 1
		if depth > State.MAX_STACK:
			return depth
		var found := false
		for support in local:
			if support.uid == parent:
				parent = support.get("parent", "")
				found = true
				break
		if not found:
			break
	return depth

func placement(item: String, point: Vector2, turn: int) -> Dictionary:
	var spec := placement_spec(item)
	var extent := Furniture.footprint(spec, turn) if not spec.is_empty() else Vector2(.35, .35)
	var record := {"uid": "preview", "item": item, "point": [point.x, point.y], "rotation": turn, "parent": "", "footprint": [extent.x, extent.y], "height": spec.get("height", .45), "elevation": 0.0, "solid": spec.get("solid", false)}
	var problem := ""
	if not Catalog.definitions.has(item) or Catalog.definitions[item].kind == "bound":
		problem = "This item stays bound to you."
	elif game.player_point.distance_to(point) > 4.5:
		problem = "Place objects within reach."
	elif not game.grounded:
		problem = "Stand on solid ground to place an object."
	elif game.enemies.any(func(enemy): return enemy.point.distance_to(game.player_point) < 8 and game.dungeon.line_clear(game.player_point, enemy.point)):
		problem = "Move away from enemies before decorating."
	var support: String = spec.get("support", "floor")
	if support != "wall" and not spec.get("rug", false) and not spec.get("wall_back", false):
		var local := supports()
		for parent in local:
			var parent_spec := placement_spec(parent.item)
			var usable: bool = parent_spec.get("support", "floor") != "wall" and not parent_spec.get("rug", false)
			if support == "surface":
				usable = parent_spec.get("surface", false) or parent_spec.get("support", "floor") == "surface"
			var top: float = parent.get("height", .45) + parent.get("elevation", 0)
			if usable and box(parent).grow(.001).encloses(box(record)) and top > record.elevation:
				record.parent = parent.uid
				record.elevation = top
		if stack_depth(record, local) > State.MAX_STACK:
			problem = "Stacks hold up to four items."
		elif support == "surface" and record.parent.is_empty():
			problem = "Place this object on a table or shelf."
	elif support == "wall":
		var normal := -Vector2(sin(turn * PI / 2), cos(turn * PI / 2)).round()
		var depth: float = (extent.y if normal.y != 0 else extent.x) * .5
		var anchor := Vector2(Vector2i((point + normal * (depth + .35)).round()))
		if game.dungeon.tiles.has(Vector2i(anchor)) or not game.dungeon.tiles.has(Vector2i((anchor - normal).round())):
			problem = "Bring this object to a wall and face it into the room."
		else:
			point = anchor - normal * (.5 + depth + .10)
			record.point = [point.x, point.y]
			record.elevation = spec.get("elevation", .65)
	var footprint := box(record)
	if footprint.grow(.25).has_point(game.player_point) and record.solid and record.parent.is_empty():
		problem = "Leave space for your character."
	for corner in [footprint.position, footprint.end, Vector2(footprint.position.x, footprint.end.y), Vector2(footprint.end.x, footprint.position.y)]:
		if not game.dungeon.tiles.has(Vector2i(corner.round())) or absf(game.dungeon.ground_height(corner) - game.dungeon.ground_height(point)) > .2:
			problem = "Place the object on level, walkable ground."
	if record.parent.is_empty() and game.dungeon.obstacles.any(func(obstacle): return obstacle.grow(.05).intersects(footprint)):
		problem = "Leave walls and other objects clear."
	for other in state.placed:
		if other.scope == scope() and other.uid != record.parent and footprint.grow(.025).intersects(box(other)) and record.elevation < other.get("elevation", 0) + other.get("height", .45) - .005 and record.elevation + record.height > other.get("elevation", 0) + .005:
			problem = "Leave space between objects."
	for anchor in anchors():
		if footprint.grow(.8).has_point(anchor):
			problem = "Keep entrances, rest points and readables accessible."
	if problem.is_empty() and record.solid and record.parent.is_empty() and blocks_path(footprint):
		problem = "Keep a walking path through this area."
	return {"record": record, "problem": problem}

func anchors() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if game.layer == "overworld":
		for region in game.world.regions.values():
			var city: Dictionary = region.get("city", {})
			if not city.is_empty():
				result.append(Vector2(city.cell))
				if city.get("floating_city", false):
					result.append(city.hub_spawn)
					result.append(city.hub_portal)
				for house in city.houses:
					result.append(Vector2(house.approach))
				for book in city.books:
					result.append(book.get("approach", book.point))
			for site in region.dungeons:
				result.append(Vector2(site.get("approach", site.cell + Vector2i.DOWN * 2)))
			if region.has("hub_world_gate"):
				result.append(region.hub_world_gate)
			for site in region.get("locations", []):
				result.append(Vector2(site.approach))
				result.append(site.rest_point)
				for book in site.books:
					result.append(book.approach)
	else:
		result.assign([Vector2(game.dungeon.start), Vector2(game.dungeon.exit)])
		if game.layer == "sanctum":
			result.append(game.dungeon.hearth)
		if game.layer == "interior" and game.dungeon.rest_point != Vector2.ZERO:
			result.append(game.dungeon.rest_point)
		if game.layer in ["dungeon", "interior"]:
			for book in game.dungeon.readables:
				result.append(book.get("approach", book.point))
	var rest := rest_record()
	if not rest.is_empty():
		result.append(Vector2(rest.point[0], rest.point[1]))
	return result

func reachable_cells() -> Dictionary:
	var origin := Vector2i(game.player_point.round())
	var seen := {origin: true}
	var queue: Array[Vector2i] = [origin]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction in game.dungeon.DIRECTIONS:
			var next: Vector2i = cell + direction
			if not seen.has(next) and game.dungeon.can_step(Vector2(cell), Vector2(next)):
				seen[next] = true
				queue.append(next)
	return seen

func blocks_path(footprint: Rect2) -> bool:
	var before := reachable_cells()
	game.dungeon.obstacles.append(footprint)
	var after := reachable_cells()
	game.dungeon.obstacles.erase(footprint)
	for cell in before:
		if not footprint.grow(.2).has_point(Vector2(cell)) and not after.has(cell):
			return true
	return false

func place(item: String, point: Vector2, turn: int = 0) -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.state not in ["playing", "inventory", "world_items"]:
		return false
	var proposal := placement(item, (point * 4).round() / 4, turn)
	if not proposal.problem.is_empty():
		game.notify(proposal.problem)
		return false
	var extra: Dictionary = proposal.record.duplicate()
	for key in ["uid", "item", "point", "rotation"]:
		extra.erase(key)
	if not state.place(item, scope(), position(proposal.record), turn, game.inventory, extra):
		game.notify(state.error)
		return false
	sync_placed()
	game._rebuild_navigation()
	game._auto_save()
	game.notify("Placed: " + Catalog.definitions[item].name)
	return true

func claim_base() -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.layer != "dungeon" or not game.enemies.is_empty() or not state.claim_base(game.active_dungeon.id, game.claimed_chests.has(game.active_dungeon.id)):
		game.notify("Clear the dungeon and claim its final chest before taking a base.")
		return false
	set_rest_point()
	game.notify("This dungeon is your base. Decorate it from your backpack; E rests at your marker.")
	game._auto_save()
	if game.state == "world_items":
		open_placement()
	return true

func set_rest_point() -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.layer != "dungeon" or not state.bases.has(game.active_dungeon.id) or not game.enemies.is_empty() or not game.dungeon.walkable(game.player_point) or game.player_point.distance_to(game.dungeon.start) < 2 or game.player_point.distance_to(game.dungeon.exit) < 2:
		game.notify("Choose clear floor inside your claimed base, away from the stairs and chest.")
		return false
	state.bases[game.active_dungeon.id] = {"scope": scope(), "point": [game.player_point.x, game.player_point.y], "cell": [game.active_dungeon.cell.x, game.active_dungeon.cell.y], "floor": game.depth}
	state.checkpoint = game.active_dungeon.id
	refresh_rest_marker()
	game._auto_save()
	game.notify("Base rest point set. E rests here; you will respawn here.")
	return true

func rest_record() -> Dictionary:
	if game.layer != "dungeon":
		return {}
	var rest = state.bases.get(game.active_dungeon.id, {})
	return rest if rest is Dictionary and rest.get("scope", "") == scope() else {}

func rest_hint() -> String:
	var rest := rest_record()
	return "E: Rest at your base" if not rest.is_empty() and game.player_point.distance_to(position(rest)) < 1.4 else ""

func rest() -> bool:
	if not game.offline_actions_allowed():
		return false
	if rest_hint().is_empty() or not game.enemies.is_empty():
		return false
	game.hp = game.max_hp
	game.mana = game.max_mana
	state.checkpoint = game.active_dungeon.id
	game.notify("Rested at your base. Your checkpoint is here.")
	game._auto_save()
	return true

func respawn_at_base() -> bool:
	if not game.offline_actions_allowed():
		return false
	var rest = state.bases.get(state.checkpoint, {})
	if not rest is Dictionary or rest.is_empty():
		return false
	var cell := Vector2i(rest.cell[0], rest.cell[1])
	for site in game.world.region_at(cell).dungeons:
		if site.id == state.checkpoint and game.claimed_chests.has(site.id) and int(rest.floor) <= site.floors:
			game.active_dungeon = site
			game.surface_return_point = Vector2(site.cell) + Vector2.DOWN * 2
			game.layer = "dungeon"
			game.depth = int(rest.floor)
			game._generate_floor()
			game.player_point = game.dungeon.safe_position(position(rest))
			if not game.dungeon.walkable(game.player_point):
				game.player_point = Vector2(game.dungeon.start)
			game._snap_camera()
			return true
	return false

func open_placement(item: String = "") -> bool:
	if not game.offline_actions_allowed():
		return false
	if not game.has_journey or game.state not in ["playing", "inventory", "world_items"]:
		return false
	stop()
	game.state = "world_items"
	selected = item
	target = game.player_point + game.aim.normalized() * 2
	preview_rotation = 0
	mouse_positioning = false
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	panel = game.interface._panel(overlay, Vector2(310, 0))
	panel.position = Vector2(20, 20)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, minf(560, get_viewport().get_visible_rect().size.y - 80))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list: VBoxContainer = game.interface._vbox(scroll, 8)
	list.custom_minimum_size.x = 280
	game.interface._label(list, "Objects and bases", 22, game.interface.INK, true)
	button(list, "Close [V / Esc]", close)
	status = game.interface._label(list, "Select an item; hover or use arrows. R rotates, Enter places. Esc cancels.", 13, game.interface.MUTED)
	status.custom_minimum_size.x = 275
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not item.is_empty():
		button(list, "Rotate [R]", rotate_preview)
		button(list, "Place [Enter]", confirm)
		make_ghost()
	if game.layer == "dungeon":
		if state.bases.has(game.active_dungeon.id):
			game.interface._label(list, "Your dungeon base", 16, game.interface.GOLD)
			var floors := OptionButton.new()
			for floor_number in range(1, game.active_dungeon.floors + 1):
				floors.add_item("Visit base floor %s" % floor_number)
			floors.selected = game.depth - 1
			floors.item_selected.connect(func(index): visit_base_floor(index + 1))
			list.add_child(floors)
			button(list, "Set rest point here", set_rest_point)
			if not rest_hint().is_empty():
				button(list, "Rest at your base", rest)
		else:
			var claim := button(list, "Claim cleared dungeon as base", claim_base)
			claim.disabled = not game.claimed_chests.has(game.active_dungeon.id)
	game.interface._separator(list)
	game.interface._label(list, "Within reach [T takes nearest]", 16, game.interface.GOLD)
	for record in nearby():
		button(list, "Take " + Catalog.definitions[record.item].name + (" / Stolen" if not record.get("owner", "").is_empty() else ""), pickup.bind(record.uid))
	game.interface._separator(list)
	game.interface._label(list, "Place from backpack", 16, game.interface.GOLD)
	for id in game.inventory.items:
		if Catalog.definitions[id].kind != "bound":
			button(list, "%s x%s" % [Catalog.definitions[id].name, game.inventory.count(id)], open_placement.bind(id))
	overlay.show()
	return true

func visit_base_floor(floor_number: int) -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.layer != "dungeon" or not state.bases.has(game.active_dungeon.id) or floor_number < 1 or floor_number > game.active_dungeon.floors or not game.enemies.is_empty():
		return false
	game.depth = floor_number
	game._generate_floor()
	game.state = "playing"
	game._auto_save()
	return true

func button(parent: Node, caption: String, callback: Callable) -> Button:
	var result: Button = game.interface._button(parent, caption, callback, Vector2(0, 32))
	result.focus_mode = Control.FOCUS_NONE
	return result

func close() -> void:
	stop()
	game.state = "playing"

func rotate_preview() -> void:
	if selected.is_empty():
		return
	preview_rotation = (preview_rotation + 1) % 4
	if is_instance_valid(ghost):
		ghost.queue_free()
	make_ghost()

func make_ghost() -> void:
	ghost = model({"item": selected, "rotation": preview_rotation, "height": placement_spec(selected).height})
	for mesh in ghost.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original = mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				var key: int = original.get_instance_id()
				if not ghost_materials.has(key):
					var material: StandardMaterial3D = original.duplicate()
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.albedo_color.a *= .5
					ghost_materials[key] = material
				mesh.set_surface_override_material(surface, ghost_materials[key])
	while ghost_materials.size() > 512:
		ghost_materials.erase(ghost_materials.keys()[0])
	footprint_marker = Voxels.cube(Vector3.ONE, Color("64c39c"), true)
	footprint_marker.position.y = .015
	ghost.add_child(footprint_marker)
	add_child(ghost)
	preview_key = ""

func confirm() -> bool:
	if not game.offline_actions_allowed():
		return false
	if selected.is_empty() or not place(selected, target, preview_rotation):
		return false
	open_placement()
	return true

func handle_key(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_ESCAPE, KEY_V, KEY_B:
			close()
		KEY_ENTER:
			confirm()
		KEY_R:
			rotate_preview()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var movement := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
			target += game.screen_movement(movement[event.physical_keycode]) * .25
			mouse_positioning = false

func handle_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_positioning = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position):
		target = point_from_screen(event.position)
		confirm()

func point_from_screen(screen: Vector2) -> Vector2:
	var origin: Vector3 = game.camera.project_ray_origin(screen)
	var ray: Vector3 = game.camera.project_ray_normal(screen)
	var hit = Plane(Vector3.UP, 0).intersects_ray(origin, ray)
	if hit == null:
		return target
	var cell := Vector2i((Vector2(origin.x, origin.z) + Vector2.ONE * .5).floor())
	var step := Vector2i(signf(ray.x), signf(ray.z))
	var delta := Vector2(absf(1 / ray.x) if absf(ray.x) > .00001 else INF, absf(1 / ray.z) if absf(ray.z) > .00001 else INF)
	var edge := Vector2(cell) + Vector2(step) * .5
	var next := Vector2((edge.x - origin.x) / ray.x if step.x != 0 else INF, (edge.y - origin.z) / ray.z if step.y != 0 else INF)
	var entered := 0.0
	for index in range(256):
		var leaving := minf(next.x, next.y)
		if game.dungeon.bounds.has_point(cell):
			var ground: float = game.dungeon.ground_height(Vector2(cell))
			var time: float = (ground - origin.y) / ray.y
			if time >= entered - .00001 and time <= leaving + .00001:
				hit = origin + ray * time
				break
		entered = leaving
		if entered > game.camera.far or origin.y + ray.y * entered < -1:
			break
		if next.x < next.y:
			cell.x += step.x
			next.x += delta.x
		else:
			cell.y += step.y
			next.y += delta.y
	var distance: float = origin.distance_squared_to(hit)
	for parent in supports():
		var spec := placement_spec(parent.item)
		if spec.get("rug", false) or spec.get("support", "floor") == "wall":
			continue
		var top: float = game.dungeon.ground_height(position(parent)) + parent.get("elevation", 0) + parent.get("height", .45)
		var surface = Plane(Vector3.UP, top).intersects_ray(origin, ray)
		if surface != null and box(parent).has_point(Vector2(surface.x, surface.z)) and origin.distance_squared_to(surface) < distance:
			hit = surface
			distance = origin.distance_squared_to(surface)
	return (Vector2(hit.x, hit.z) * 4).round() / 4

func _process(_delta: float) -> void:
	if game == null:
		return
	for uid in placed_nodes:
		if game.layer == "dungeon":
			var node: Node3D = placed_nodes[uid]
			node.visible = game.enemy_render_visible(Vector2(node.position.x, node.position.z))
	if is_instance_valid(rest_marker):
		rest_marker.visible = game.enemy_render_visible(Vector2(rest_marker.position.x, rest_marker.position.z))
	if game.state != "world_items":
		if overlay.visible:
			stop()
		return
	if selected.is_empty():
		return
	if mouse_positioning and not panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
		target = point_from_screen(get_viewport().get_mouse_position())
	var key := "%s:%s:%s" % [selected, target, preview_rotation]
	if key == preview_key:
		return
	preview_key = key
	var proposal := placement(selected, target, preview_rotation)
	status.text = Catalog.definitions[selected].name + " / " + ("Ready to place" if proposal.problem.is_empty() else proposal.problem)
	status.modulate = Color("94dac3") if proposal.problem.is_empty() else Color("efaaa8")
	var footprint := box(proposal.record)
	footprint_marker.scale = Vector3(footprint.size.x, .025, footprint.size.y)
	footprint_marker.material_override.albedo_color = Color("64c39c") if proposal.problem.is_empty() else Color("d76f76")
	ghost.position = game.to_world(position(proposal.record), proposal.record.elevation)
