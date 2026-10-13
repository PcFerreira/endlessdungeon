extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Ambience = preload("res://scripts/ambience.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
var scenery := Scenery.new()
var styles := Styles.new(scenery.registry)
var cell_nodes: Dictionary = {}
var dressing_nodes: Dictionary = {}
var explored: Dictionary = {}
var last_cell := Vector2i(-999, -999)
var portal: Node3D
var portal_light: OmniLight3D
var portal_sparks: Array[MeshInstance3D] = []
var braziers: Array[OmniLight3D] = []
var biome := 0
var palette := 0
var visual_family := ""
var time := 0.0
var final_floor := false
var chest_open := false
var chest: MeshInstance3D
var wall_nodes: Array[Dictionary] = []
var wall_meshes: Dictionary = {}
var camera_quadrant := -1

func build(dungeon, depth: int, final: bool = false, claimed: bool = false) -> void:
	final_floor = final
	chest_open = claimed
	for child in get_children():
		remove_child(child)
		child.queue_free()
	cell_nodes.clear()
	dressing_nodes.clear()
	explored.clear()
	portal_sparks.clear()
	braziers.clear()
	wall_nodes.clear()
	wall_meshes.clear()
	camera_quadrant = -1
	last_cell = Vector2i(-999, -999)
	biome = dungeon.biome
	palette = Areas.DUNGEONS[dungeon.family].palette
	visual_family = styles.family_for(biome)
	assert(not visual_family.is_empty(), "Dungeon presentation needs its owning biome family")
	var floor_meshes: Array[ArrayMesh] = []
	for tone in range(4):
		floor_meshes.append(Surfaces.mesh("floor", visual_family, palette, tone))
	for high in [true, false]:
		for along_x in [true, false]:
			wall_meshes["%s:%s" % [high, along_x]] = Surfaces.mesh("wall_high" if high else "wall_low", visual_family, palette, 0, along_x)
	for cell in dungeon.tiles:
		var root := Node3D.new()
		root.position = Vector3(cell.x, 0, cell.y)
		root.visible = false
		add_child(root)
		cell_nodes[cell] = root
		var floor_model := Voxels.instance(floor_meshes[absi(hash(cell)) % 4])
		_tag(floor_model, Surfaces.id(visual_family, "floor"))
		root.add_child(floor_model)
		for direction in dungeon.DIRECTIONS:
			if dungeon.tiles.has(cell + direction):
				continue
			var high: bool = direction.x < 0 or direction.y < 0
			var along_x: bool = direction.y != 0
			var wall := Voxels.instance(wall_meshes["%s:%s" % [high, along_x]])
			_tag(wall, Surfaces.id(visual_family, "wall_high" if high else "wall_low"))
			wall.position = Vector3(direction.x * .51, 0, direction.y * .51)
			root.add_child(wall)
			wall_nodes.append({"node": wall, "direction": Vector2(direction), "along_x": along_x})
	for decoration in dungeon.decorations:
		var model := scenery.fitted_model(decoration.model_id, decoration.footprint, decoration.height, decoration.yaw)
		_tag(model, decoration.model_id)
		model.position = Vector3(decoration.point.x - decoration.cell.x, decoration.elevation, decoration.point.y - decoration.cell.y)
		cell_nodes[decoration.cell].add_child(model)
		dressing_nodes[decoration.uid] = {"node": model, "record": {"uid": decoration.uid, "model_id": decoration.model_id, "visual_family": visual_family, "point": decoration.point, "parent": "", "footprint": decoration.footprint, "height": decoration.height, "elevation": decoration.elevation, "solid": true, "room_role": decoration.room_role, "purpose": decoration.purpose}}
		var orientation := Basis(Vector3.UP, decoration.yaw)
		for index in range(decoration.contents.size()):
			var part: Dictionary = decoration.contents[index]
			var footprint := Vector2(part.footprint[0], part.footprint[1])
			if absf(sin(decoration.yaw)) > .5:
				footprint = Vector2(footprint.y, footprint.x)
			var content := scenery.fitted_model(part.model_id, footprint, part.height, decoration.yaw)
			_tag(content, part.model_id)
			content.position = model.position + orientation * Vector3(part.point[0], 0, part.point[1]) + Vector3.UP * decoration.height
			cell_nodes[decoration.cell].add_child(content)
			var uid: String = decoration.uid + ":part:%s" % index
			var offset: Vector3 = orientation * Vector3(part.point[0], 0, part.point[1])
			dressing_nodes[uid] = {"node": content, "record": {"uid": uid, "model_id": part.model_id, "visual_family": visual_family, "point": decoration.point + Vector2(offset.x, offset.z), "parent": decoration.uid, "footprint": footprint, "height": part.height, "elevation": decoration.height, "solid": false, "room_role": decoration.room_role, "purpose": decoration.purpose}}
	for book in dungeon.readables:
		var root: Node3D = cell_nodes[Vector2i(book.point)]
		root.add_child(_fixture("bookstand", Vector2(.65, .65), .85))
		var model := _fixture("book", Vector2(.32, .24), .10)
		model.position.y = .85
		root.add_child(model)
		var book_label := Label3D.new()
		book_label.text = "Book"
		book_label.position.y = 1.35
		book_label.font_size = 32
		book_label.pixel_size = .007
		book_label.modulate = Color("edce7b")
		book_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(book_label)
	for mount in dungeon.torch_mounts:
		var root: Node3D = cell_nodes[mount.cell]
		var torch := _fixture("standing_fire", mount.footprint, .48, mount.yaw)
		torch.position = Vector3(mount.point.x - mount.cell.x, .25, mount.point.y - mount.cell.y)
		root.add_child(torch)
		var flame := Ambience.emitter("fire", Color("ffc383"), 8)
		flame.position = torch.position + Vector3(0, .5, 0)
		root.add_child(flame)
		var light := OmniLight3D.new()
		light.position = flame.position
		light.light_color = Color("ffc383")
		light.light_energy = 1.2
		light.omni_range = 3.2
		root.add_child(light)
		braziers.append(light)
	portal = Node3D.new()
	portal.position = Vector3(dungeon.exit.x, 0, dungeon.exit.y)
	add_child(portal)
	if final_floor:
		chest = Surfaces.node("chest", visual_family, palette, claimed)
		portal.add_child(chest)
	else:
		portal.add_child(Surfaces.node("portal", visual_family, palette))
	var gate_motes := Ambience.emitter("magic", Color("7be5d8"), 16)
	gate_motes.position.y = .6
	portal.add_child(gate_motes)
	for index in range(14):
		var spark := Surfaces.node("mote", visual_family, palette)
		portal.add_child(spark)
		portal_sparks.append(spark)
	portal_light = OmniLight3D.new()
	portal_light.position.y = .8
	portal_light.light_color = Color("5de0d0")
	portal_light.omni_range = 3.5
	portal.add_child(portal_light)
	var stairs := Surfaces.node("stairs", visual_family, palette)
	stairs.position = Vector3(dungeon.start.x, 0, dungeon.start.y)
	add_child(stairs)
	var label := Label3D.new()
	label.text = "Surface"
	label.position = stairs.position + Vector3(0, 1.3, -.2)
	label.font_size = 40
	label.pixel_size = .007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _tag(model: Node3D, id: String) -> void:
	assert(styles.allows(id, biome), "Rendered dungeon sources must match the owning biome")
	model.set_meta("asset_id", id)
	model.set_meta("visual_family", visual_family)

func _fixture(role: String, footprint: Vector2, height: float, yaw: float = 0) -> Node3D:
	var id := styles.native_id(visual_family, role)
	var model := scenery.fitted_model(id, footprint, height, yaw)
	_tag(model, id)
	return model

func register_dressing(registrar: Callable, item_for_model: Callable, scope: String, owner: String = "") -> void:
	for entry in dressing_nodes.values():
		var item: String = item_for_model.call(entry.record.model_id)
		if item.is_empty():
			continue
		var record: Dictionary = entry.record.duplicate()
		record.item = item
		record.scope = scope
		record.uid = scope + ":" + record.uid
		if not record.parent.is_empty():
			record.parent = scope + ":" + record.parent
		if not owner.is_empty():
			record.owner = owner
		registrar.call(record, entry.node)

func open_chest() -> void:
	chest_open = true
	chest.mesh = Surfaces.mesh("chest", visual_family, palette, 0, true, true)

func update_camera(yaw: float) -> void:
	var quadrant := posmod(floori(yaw / (PI / 2)), 4)
	if quadrant == camera_quadrant:
		return
	camera_quadrant = quadrant
	var forward := Vector2(sin(yaw), cos(yaw))
	for wall in wall_nodes:
		var high: bool = wall.direction.dot(forward) < 0
		wall.node.mesh = wall_meshes["%s:%s" % [high, wall.along_x]]
		_tag(wall.node, Surfaces.id(visual_family, "wall_high" if high else "wall_low"))

func reveal(dungeon, point: Vector2) -> void:
	var center := Vector2i(point.round())
	if center == last_cell:
		return
	last_cell = center
	for x in range(center.x - 8, center.x + 9):
		for y in range(center.y - 8, center.y + 9):
			var cell := Vector2i(x, y)
			if explored.has(cell) or not cell_nodes.has(cell):
				continue
			if point.distance_to(cell) <= 8.0 and dungeon.line_clear(point, Vector2(cell)):
				explored[cell] = true
				cell_nodes[cell].visible = true
	portal.visible = explored.has(dungeon.exit)

func animate(delta: float, unlocked: bool) -> void:
	time += delta
	portal_light.light_color = Color("edce7b") if final_floor else Color("5de0d0")
	portal_light.light_energy = 1.8 if unlocked and not chest_open else .15
	for index in range(portal_sparks.size()):
		var spark := portal_sparks[index]
		var angle := time * .8 + index * TAU / portal_sparks.size()
		spark.position = Vector3(cos(angle) * .43, .85 + sin(angle) * .65, .04)
		spark.visible = unlocked and not chest_open
	for index in range(braziers.size()):
		braziers[index].light_energy = 1.15 + sin(time * 5.0 + index * 1.9) * .15
