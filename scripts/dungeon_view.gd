extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Ambience = preload("res://scripts/ambience.gd")
var scenery := Scenery.new()
var cell_nodes: Dictionary = {}
var explored: Dictionary = {}
var last_cell := Vector2i(-999, -999)
var portal: Node3D
var portal_light: OmniLight3D
var portal_sparks: Array[MeshInstance3D] = []
var braziers: Array[OmniLight3D] = []
var biome := 0
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
	explored.clear()
	portal_sparks.clear()
	braziers.clear()
	wall_nodes.clear()
	wall_meshes.clear()
	camera_quadrant = -1
	last_cell = Vector2i(-999, -999)
	biome = (depth - 1) % 3
	var floor_meshes: Array[ArrayMesh] = []
	for tone in range(4):
		floor_meshes.append(Voxels.tile(tone, biome))
	for high in [true, false]:
		for along_x in [true, false]:
			wall_meshes["%s:%s" % [high, along_x]] = Voxels.wall(high, along_x, biome)
	for cell in dungeon.tiles:
		var root := Node3D.new()
		root.position = Vector3(cell.x, 0, cell.y)
		root.visible = false
		add_child(root)
		cell_nodes[cell] = root
		root.add_child(Voxels.instance(floor_meshes[absi(hash(cell)) % 4]))
		var tint: Color = [Color("7f7467"), Color("746f90"), Color("6b8979")][biome]
		var floor_model := scenery.model("floor_broken" if absi(hash(cell)) % 7 == 0 else "floor", .98, 0, tint)
		floor_model.position.y = .012
		root.add_child(floor_model)
		for direction in dungeon.DIRECTIONS:
			if dungeon.tiles.has(cell + direction):
				continue
			var high: bool = direction.x < 0 or direction.y < 0
			var along_x: bool = direction.y != 0
			var wall := Voxels.instance(wall_meshes["%s:%s" % [high, along_x]])
			wall.position = Vector3(direction.x * .51, 0, direction.y * .51)
			root.add_child(wall)
			wall_nodes.append({"node": wall, "direction": Vector2(direction), "along_x": along_x})
	for room in dungeon.rooms:
		for cell in [room.position, room.end - Vector2i.ONE]:
			var root: Node3D = cell_nodes[cell]
			var back: bool = cell == room.position
			var direction := -1.0 if back else 1.0
			var torch := scenery.model("torch", .22, .48)
			torch.position = Vector3(direction * .37, .25, direction * .39)
			torch.rotation.y = 0 if back else PI
			root.add_child(torch)
			var flame := Ambience.emitter("fire", Color("ffc383"), 8)
			flame.position = torch.position + Vector3(0, .5, -direction * .07)
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
		chest = Voxels.instance(Voxels.reward_chest(claimed))
		portal.add_child(chest)
	else:
		portal.add_child(Voxels.instance(Voxels.portal()))
	var gate_motes := Ambience.emitter("magic", Color("7be5d8"), 16)
	gate_motes.position.y = .6
	portal.add_child(gate_motes)
	for index in range(14):
		var spark := Voxels.cube(Vector3(.10, .10, .10), Color("6ddeca"), true)
		portal.add_child(spark)
		portal_sparks.append(spark)
	portal_light = OmniLight3D.new()
	portal_light.position.y = .8
	portal_light.light_color = Color("5de0d0")
	portal_light.omni_range = 3.5
	portal.add_child(portal_light)
	var stairs := Voxels.instance(Voxels.mesh([
		[Vector3(0, .05, 0), Vector3(1.1, .1, 1.1), Color("9c9077")],
		[Vector3(0, .12, -.2), Vector3(1.1, .1, .7), Color("b3a487")],
		[Vector3(0, .22, -.4), Vector3(1.1, .1, .3), Color("c5b79b")]
	]))
	stairs.position = Vector3(dungeon.start.x, 0, dungeon.start.y)
	add_child(stairs)
	var label := Label3D.new()
	label.text = "Surface [E]"
	label.position = stairs.position + Vector3(0, 1.3, -.2)
	label.font_size = 40
	label.pixel_size = .007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func open_chest() -> void:
	chest_open = true
	chest.mesh = Voxels.reward_chest(true)

func update_camera(yaw: float) -> void:
	var quadrant := posmod(floori(yaw / (PI / 2)), 4)
	if quadrant == camera_quadrant:
		return
	camera_quadrant = quadrant
	var forward := Vector2(sin(yaw), cos(yaw))
	for wall in wall_nodes:
		var high: bool = wall.direction.dot(forward) < 0
		wall.node.mesh = wall_meshes["%s:%s" % [high, wall.along_x]]

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
