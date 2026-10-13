extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Rooms = preload("res://scripts/interior_area.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
var scenery := Scenery.new()
var styles := Styles.new(scenery.registry)
var biome := 0
var visual_family := ""
var walls: Array[Dictionary] = []
var prop_nodes: Array[Node3D] = []

func build(area) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	walls.clear()
	prop_nodes.clear()
	biome = area.biome
	visual_family = styles.family_for(biome)
	var floor_color := Color(Rooms.content.get_entry("interiors", area.place.type).floor)
	var blocks := []
	for cell in area.tiles:
		blocks.append([Vector3(cell.x, -.09, cell.y), Vector3(.98, .18, .98), floor_color.lightened(.06) if (cell.x + cell.y) % 2 == 0 else floor_color])
	var floor := Voxels.instance(Surfaces.mesh_boxes(blocks, visual_family))
	_tag(floor, Surfaces.id(visual_family, "floor"))
	add_child(floor)
	for cell in area.tiles:
		for direction in area.DIRECTIONS:
			if area.tiles.has(cell + direction):
				continue
			if cell == area.exit and direction == Vector2i.DOWN:
				continue
			var position := Vector3(cell.x + direction.x * .5, 0, cell.y + direction.y * .5)
			var wall := Node3D.new()
			wall.position = position
			var along_x: bool = direction.y != 0
			var wall_blocks := [
				[Vector3(0, .8, 0), Vector3(1.02, 1.6, .14) if along_x else Vector3(.14, 1.6, 1.02), Color("675c58")],
				[Vector3(0, 1.65, 0), Vector3(1.04, .12, .18) if along_x else Vector3(.18, .12, 1.04), Color("b5976a")]
			]
			var mesh := Voxels.instance(Surfaces.mesh_boxes(wall_blocks, visual_family))
			_tag(mesh, Surfaces.id(visual_family, "wall_high"))
			wall.add_child(mesh)
			add_child(wall)
			walls.append({"node": wall, "direction": Vector2(direction)})
	for prop in area.props:
		var model := scenery.fitted_model(prop.kind, prop.footprint, prop.height, prop.yaw)
		_tag(model, prop.kind)
		model.position = Vector3(prop.point.x, prop.elevation, prop.point.y)
		add_child(model)
		prop_nodes.append(model)
	for book in area.readables:
		var model := _fixture("book", .42, .10)
		var support_height := 0.0
		for prop in area.props:
			if Rect2(prop.point - prop.footprint * .5, prop.footprint).has_point(book.point):
				support_height = maxf(support_height, prop.height + prop.elevation)
		model.position = Vector3(book.point.x, support_height + .01, book.point.y)
		add_child(model)
	var mat := Voxels.instance(Surfaces.mesh_boxes([[Vector3(area.exit.x, .025, area.exit.y), Vector3(1.3, .045, .8), Color("c8ac76")]], visual_family))
	_tag(mat, styles.native_id(visual_family, "rug_floor"))
	add_child(mat)
	for point in [Vector2(2, area.bounds.size.y - 3), Vector2(area.bounds.size.x - 3, 2)]:
		var lamp := _fixture("lantern", .25, .45)
		lamp.position = Vector3(point.x, 0, point.y)
		add_child(lamp)
		var light := OmniLight3D.new()
		light.position = lamp.position + Vector3(0, .2, 0)
		light.light_color = Color("ffd5a1")
		light.light_energy = 1.5
		light.omni_range = 8
		add_child(light)
	update_camera(PI / 4)

func _tag(model: Node3D, id: String) -> void:
	assert(styles.allows(id, biome), "Rendered town interiors must use their owning biome family")
	model.set_meta("asset_id", id)
	model.set_meta("visual_family", visual_family)

func _fixture(role: String, width: float, height: float) -> Node3D:
	var id := styles.native_id(visual_family, role)
	var model := scenery.model(id, width, height)
	_tag(model, id)
	return model

func update_camera(yaw: float) -> void:
	var forward := Vector2(sin(yaw), cos(yaw))
	for wall in walls:
		wall.node.scale.y = .18 if wall.direction.dot(forward) > .05 else 1.0
