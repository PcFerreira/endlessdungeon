extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Ambience = preload("res://scripts/ambience.gd")
const Furnishings = preload("res://scripts/furnishings.gd")
var scenery := Scenery.new()
var motes: Array[MeshInstance3D] = []
var portal_light: OmniLight3D
var time := 0.0
var furniture_nodes: Dictionary = {}
var furniture_root: Node3D
var alcove_walls: Array[Dictionary] = []
var faded_wall: StandardMaterial3D

func build(home) -> void:
	if faded_wall == null:
		faded_wall = Voxels.material().duplicate()
		faded_wall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		faded_wall.albedo_color.a = .25
	for child in get_children():
		remove_child(child)
		child.queue_free()
	motes.clear()
	alcove_walls.clear()
	furniture_nodes.clear()
	var blocks := []
	for cell in home.tiles:
		var garden: bool = cell.x < 3 or cell.x > 17 or cell.y < 2 or cell.y > 18
		var color := Color("698982") if garden else (Color("626775") if (cell.x + cell.y) % 2 == 0 else Color("6c7180"))
		if cell.x >= 9 and cell.x <= 11 and cell.y > 7:
			color = Color("6b5c83")
		blocks.append([Vector3(cell.x, -.13, cell.y), Vector3(.98, .26, .98), color])
		var thickness := .8 + float(absi(hash(cell)) % 4) * .35
		blocks.append([Vector3(cell.x, -.3 - thickness * .5, cell.y), Vector3(.94, thickness, .94), Color("393b55")])
	add_child(Voxels.instance(Voxels.mesh(blocks)))
	for wall in home.furnishing_walls:
		var along_x: bool = wall.normal.y != 0
		var node := Node3D.new()
		node.position = Vector3(wall.point.x, 0, wall.point.y)
		var mesh := Voxels.instance(Voxels.mesh([
			[Vector3(0, .9, 0), Vector3(wall.length, 1.8, .12) if along_x else Vector3(.12, 1.8, wall.length), Color("656078")],
			[Vector3(0, 1.84, 0), Vector3(wall.length, .10, .18) if along_x else Vector3(.18, .10, wall.length), Color("b7a185")]
		]))
		node.add_child(mesh)
		add_child(node)
		alcove_walls.append({"node": node, "mesh": mesh, "normal": wall.normal})
	furniture_root = Node3D.new()
	add_child(furniture_root)
	refresh_furnishings(home)
	var pavilion := []
	for cell in [Vector2(7, 3), Vector2(13, 3), Vector2(7, 7), Vector2(13, 7)]:
		pavilion.append([Vector3(cell.x, .9, cell.y), Vector3(.5, 1.8, .5), Color("838596")])
		pavilion.append([Vector3(cell.x, 1.85, cell.y), Vector3(.65, .12, .65), Color("c4ad82")])
	pavilion.append([Vector3(10, 2, 3), Vector3(6.8, .3, .55), Color("6c6486")])
	add_child(Voxels.instance(Voxels.mesh(pavilion)))
	var hearth := Voxels.instance(Voxels.mesh([
		[Vector3(0, .15, 0), Vector3(1.2, .3, 1.2), Color("a6a4b6")],
		[Vector3(0, .38, 0), Vector3(.7, .18, .7), Color("bba37c")]
	]))
	hearth.position = Vector3(home.hearth.x, 0, home.hearth.y)
	add_child(hearth)
	var flame := Ambience.emitter("magic", Color("b29aff"), 24)
	flame.position.y = .7
	hearth.add_child(flame)
	var hearth_light := OmniLight3D.new()
	hearth_light.position.y = 1
	hearth_light.light_color = Color("b9a0ff")
	hearth_light.light_energy = 2
	hearth_light.omni_range = 6
	hearth.add_child(hearth_light)
	_label("Hearth [E]", hearth.position + Vector3(0, 1.5, 0))
	var desk := Voxels.instance(Voxels.mesh([
		[Vector3(5, .55, 5.8), Vector3(1.6, .15, .8), Color("997959")],
		[Vector3(4.4, .25, 5.8), Vector3(.16, .5, .6), Color("66516b")],
		[Vector3(5.6, .25, 5.8), Vector3(.16, .5, .6), Color("66516b")],
		[Vector3(5, .68, 5.8), Vector3(.5, .1, .38), Color("d5c6a8")]
	]))
	add_child(desk)
	var portal := Voxels.instance(Voxels.portal())
	portal.position = Vector3(home.exit.x, 0, home.exit.y)
	add_child(portal)
	portal_light = OmniLight3D.new()
	portal_light.position = portal.position + Vector3(0, 1, 0)
	portal_light.light_color = Color("84daca")
	portal_light.light_energy = 1.8
	portal_light.omni_range = 5
	add_child(portal_light)
	var gate_motes := Ambience.emitter("magic", Color("84daca"), 18)
	gate_motes.position = portal.position + Vector3(0, .7, 0)
	add_child(gate_motes)
	_label("Journey [E]", portal.position + Vector3(0, 1.7, 0))
	for cell in [Vector2(3, 5), Vector2(17, 5), Vector2(3, 16), Vector2(17, 16)]:
		var pot := scenery.model("pot", .65, .65)
		pot.position = Vector3(cell.x, 0, cell.y)
		add_child(pot)
		var crystal := Voxels.cube(Vector3(.25, .45, .25), Color("9bcabf"), true)
		crystal.position = pot.position + Vector3(0, .7, 0)
		crystal.rotation.y = PI / 4
		add_child(crystal)
	var random := RandomNumberGenerator.new()
	random.seed = 4271
	for index in range(60):
		var star := Voxels.cube(Vector3.ONE * random.randf_range(.035, .08), Color("b8acd7"), true)
		var angle := random.randf() * TAU
		var radius := random.randf_range(12, 25)
		star.position = Vector3(10 + cos(angle) * radius, random.randf_range(-3, 5), 10 + sin(angle) * radius)
		add_child(star)
		motes.append(star)

func refresh_furnishings(home) -> void:
	for child in furniture_root.get_children():
		furniture_root.remove_child(child)
		child.queue_free()
	furniture_nodes.clear()
	for record in home.placements:
		var model := Furnishings.Catalog.model(record, scenery, "block_voxel")
		var point := Furnishings.point(record)
		model.position = Vector3(point.x, Furnishings.elevation(record, home.placements), point.y)
		model.set_meta("furnishing_uid", record.uid)
		furniture_root.add_child(model)
		furniture_nodes[record.uid] = model

func update_camera(yaw: float, furnishing: bool = false) -> void:
	var forward := Vector2(sin(yaw), cos(yaw))
	for wall in alcove_walls:
		wall.mesh.material_override = faded_wall if wall.normal.dot(forward) > .05 and not furnishing else Voxels.material()

func _label(text: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = 32
	label.pixel_size = .006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("eadfc9")
	add_child(label)

func animate(delta: float) -> void:
	time += delta
	portal_light.light_energy = 1.7 + sin(time * 2) * .2
	for index in range(motes.size()):
		motes[index].scale = Vector3.ONE * (.6 + .4 * sin(time + index))
