extends Node3D

const City = preload("res://scripts/floating_city.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Actors = preload("res://scripts/actor_models.gd")
var scenery := Scenery.new()
var city: Dictionary = {}
var palette: Dictionary = {}
var motes: Array[Node3D] = []
var age := 0.0

func build(record: Dictionary, season: String = "") -> void:
	city = record
	palette = City.data.themes[record.theme if season.is_empty() else season]
	position = Vector3(record.cell.x, record.height, record.cell.y)
	set_meta("floating_city_id", record.id)
	set_meta("theme", record.theme if season.is_empty() else season)
	var floors := []
	for cell in record.hub_tiles:
		var point := Vector2(cell - record.cell)
		var bridge: bool = record.hub_tiles[cell] == "bridge"
		var color := Color(palette.stone).lightened(posmod(cell.x * 7 + cell.y * 3, 4) * .025)
		var thickness := 1.0 + float(posmod(cell.x * 3 + cell.y * 5, 5)) * .22
		floors.append([Vector3(point.x, -.12, point.y), Vector3(.97, .24, .97), Color(palette.accent).darkened(.35) if bridge else color])
		floors.append([Vector3(point.x, -.24 - thickness * .5, point.y), Vector3(.95, thickness, .95), Color(palette.edge)])
	add_child(Voxels.instance(Voxels.mesh(floors)))
	for island in City.data.islands:
		var point := Vector2(island.center[0], island.center[1])
		var stone := diamond(Vector3(island.radius[0] * .65, 4.8, island.radius[1] * .65), Color(palette.edge).lightened(.1))
		stone.position = Vector3(point.x, -3, point.y)
		add_child(stone)
		var rune := diamond(Vector3(1.3, 2.4, 1.3), Color(palette.magic), true)
		rune.position = Vector3(point.x, -5.8, point.y)
		add_child(rune)
	_ring(Vector2(record.hub_spawn - Vector2(record.cell)), 2.1, Color(palette.magic))
	_ring(Vector2.ZERO, 4.3, Color(palette.accent).darkened(.15))
	var fountain := Node3D.new()
	fountain.position = Vector3(0, 0, -2)
	add_child(fountain)
	_box(fountain, Vector3(0, .12, 0), Vector3(1.2, .24, 1.2), Color("91869e"))
	var crystal := diamond(Vector3(.85, 2.3, .85), Color(palette.magic), true)
	crystal.position.y = 1.65
	fountain.add_child(crystal)
	var light := OmniLight3D.new()
	light.position.y = 2
	light.light_color = Color(palette.magic)
	light.light_energy = 1.1
	light.omni_range = 9
	fountain.add_child(light)
	for hall in record.houses:
		_hall(hall)
	for market in record.outdoor_lots:
		_market(market)
	for point in City.data.benches:
		var bench := scenery.fitted_model(City.data.models.bench, Vector2(1.8, .7), .9)
		bench.position = Vector3(point[0], 0, point[1])
		add_child(bench)
	for point in City.data.lamps:
		_lamp(Vector2(point[0], point[1]))
	for point in City.data.ornaments:
		var model: Node3D
		if palette.pumpkins:
			model = scenery.fitted_model(City.data.models.pumpkin, Vector2.ONE * .7, .7)
		else:
			model = diamond(Vector3(.6, .7, .6), Color(palette.magic), true)
			model.position.y = .35
		model.position += Vector3(point[0], 0, point[1])
		add_child(model)
		var candle := scenery.fitted_model(City.data.models.candles, Vector2(.35, .25), .55)
		candle.position = Vector3(point[0] + .65, 0, point[1])
		add_child(candle)
	_portal(Vector2(record.hub_portal - Vector2(record.cell)))
	_label("Lanternwake Commons", Vector3(0, .65, 8.8), Color("e9d9c1"), 26)
	_label("Ember Market", Vector3(21, 3.7, -5), Color(palette.accent), 28)
	_label("Moonlit Guild Walk", Vector3(-21, 3.7, 6), Color(palette.magic), 26)
	for resident in record.residents:
		var actor := Actors.create(resident.appearance, resident)
		actor.position = Vector3(resident.point.x - record.cell.x, 0, resident.point.y - record.cell.y)
		actor.rotation.y = PI / 4
		add_child(actor)
	for index in range(36):
		var angle := index * TAU / 36
		var mote := Voxels.cube(Vector3.ONE * .05, Color(palette.magic), true)
		mote.position = Vector3(cos(angle) * (5 + index % 8), .5 + index % 6 * .23, sin(angle) * (4 + index % 7))
		mote.set_meta("origin", mote.position)
		add_child(mote)
		motes.append(mote)

func _box(parent: Node3D, point: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var model := Voxels.cube(size, color, glow)
	model.position = point
	parent.add_child(model)
	return model

func _hall(hall: Dictionary) -> void:
	var root := Node3D.new()
	var plot: Rect2i = hall.footprint
	var size := Vector2(plot.size)
	var center := Vector2(plot.position - city.cell) + (size - Vector2.ONE) * .5
	root.position = Vector3(center.x, 0, center.y)
	root.set_meta("hub_hall_id", hall.id)
	add_child(root)
	var wall := Color(hall.color).lightened(.25)
	_box(root, Vector3(0, hall.height * .5, 0), Vector3(size.x - .2, hall.height, size.y - .2), wall)
	_box(root, Vector3(0, .12, 0), Vector3(size.x, .24, size.y), Color("8c7c8e"))
	for x in [-size.x * .5 + .18, size.x * .5 - .18]:
		for z in [-size.y * .5 + .18, size.y * .5 - .18]:
			_box(root, Vector3(x, hall.height * .5, z), Vector3(.22, hall.height + .15, .22), Color(palette.edge))
	_box(root, Vector3(0, hall.height, 0), Vector3(size.x + .28, .25, size.y + .28), Color(palette.roof))
	var roof := pyramid(Vector3(size.x + .5, 1.9, size.y + .5), Color(palette.roof))
	roof.position.y = hall.height + .12
	root.add_child(roof)
	var finial := diamond(Vector3(.4, .8, .4), Color(palette.magic), true)
	finial.position.y = hall.height + 2.35
	root.add_child(finial)
	_box(root, Vector3(0, 1.0, size.y * .5 - .075), Vector3(1.05, 2, .09), Color("282236"))
	_box(root, Vector3(0, 2.1, size.y * .5), Vector3(1.35, .18, .24), Color(palette.accent))
	for side in [-1, 1]:
		_box(root, Vector3(side * size.x * .28, 1.8, size.y * .5), Vector3(.7, 1.0, .04), Color(palette.magic).darkened(.3), true)
		_box(root, Vector3(side * size.x * .28, 1.8, size.y * .5 + .025), Vector3(.075, 1.1, .05), Color(palette.edge))
	_label(hall.use_name, root.position + Vector3(0, hall.height + 2.9, 0), Color("e1cda9"), 28)

func _market(market: Dictionary) -> void:
	var plot: Rect2i = market.footprint
	var point := Vector2(plot.position - city.cell) + (Vector2(plot.size) - Vector2.ONE) * .5
	var root := Node3D.new()
	root.position = Vector3(point.x, 0, point.y)
	root.set_meta("hub_market_id", market.id)
	add_child(root)
	_box(root, Vector3(0, .45, 0), Vector3(plot.size.x - .15, .9, .85), Color("8e6859"))
	_box(root, Vector3(0, .94, 0), Vector3(plot.size.x, .1, 1.0), Color(palette.accent))
	for side in [-1, 1]:
		_box(root, Vector3(side * (plot.size.x * .5 - .18), 1.2, -.5), Vector3(.15, 2.4, .15), Color(palette.edge))
	for stripe in range(4):
		_box(root, Vector3(-plot.size.x * .5 + (stripe + .5) * plot.size.x / 4, 2.5, 0), Vector3(plot.size.x / 4, .14, 2.1), Color(palette.roof if stripe % 2 == 0 else palette.accent))
	for side in [-1, 1]:
		var candle := scenery.fitted_model(City.data.models.candles, Vector2(.4, .3), .45)
		candle.position = Vector3(side * .85, .99, 0)
		root.add_child(candle)
	var wares := diamond(Vector3(.35, .45, .35), Color(palette.magic), true)
	wares.position.y = 1.215
	root.add_child(wares)
	_label(market.name + "  [E]", root.position + Vector3(0, 3.1, 0), Color("e1cda9"), 24)

func _lamp(point: Vector2) -> void:
	_box(self, Vector3(point.x, 1, point.y), Vector3(.18, 2, .18), Color(palette.edge))
	_box(self, Vector3(point.x, 2.05, point.y), Vector3(.45, .12, .45), Color(palette.accent))
	_box(self, Vector3(point.x, 2.34, point.y), Vector3(.27, .46, .27), Color(palette.accent), true)
	_box(self, Vector3(point.x, 2.62, point.y), Vector3(.45, .1, .45), Color(palette.edge))

func _portal(point: Vector2) -> void:
	for side in [-1, 1]:
		_box(self, Vector3(point.x + side * 1.5, 1.5, point.y), Vector3(.4, 3, .4), Color("898395"))
	_box(self, Vector3(point.x, 3.1, point.y), Vector3(3.6, .4, .6), Color(palette.accent))
	_box(self, Vector3(point.x, 1.5, point.y), Vector3(2.5, 2.8, .08), Color(palette.magic).darkened(.3), true)
	for index in range(8):
		_box(self, Vector3(point.x - 1.1 + index * .3, .12, point.y - .4), Vector3(.13, .035, .14), Color(palette.accent), true)
	_label("Worldgate  [E]", Vector3(point.x, 3.9, point.y), Color("d5c2ef"), 28)

func _ring(point: Vector2, radius: float, color: Color) -> void:
	for index in range(40):
		var angle := index * TAU / 40
		var stone := _box(self, Vector3(point.x + cos(angle) * radius, .025, point.y + sin(angle) * radius), Vector3(.20, .025, .065), color, true)
		stone.rotation.y = -angle

func _label(text: String, point: Vector3, color: Color, font: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = font
	label.pixel_size = .013
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)

static func diamond(size: Vector3, color: Color, luminous: bool = false) -> MeshInstance3D:
	var vertices := [Vector3(0, size.y * .5, 0), Vector3(size.x * .5, 0, 0), Vector3(0, 0, size.z * .5), Vector3(-size.x * .5, 0, 0), Vector3(0, 0, -size.z * .5), Vector3(0, -size.y * .5, 0)]
	var triangles := [[0, 2, 1], [0, 3, 2], [0, 4, 3], [0, 1, 4], [5, 1, 2], [5, 2, 3], [5, 3, 4], [5, 4, 1]]
	return polyhedron(vertices, triangles, color, luminous)

static func pyramid(size: Vector3, color: Color) -> MeshInstance3D:
	var vertices := [Vector3(-size.x * .5, 0, -size.z * .5), Vector3(size.x * .5, 0, -size.z * .5), Vector3(size.x * .5, 0, size.z * .5), Vector3(-size.x * .5, 0, size.z * .5), Vector3(0, size.y, 0)]
	return polyhedron(vertices, [[0, 4, 1], [1, 4, 2], [2, 4, 3], [3, 4, 0], [0, 1, 2], [0, 2, 3]], color)

static func polyhedron(vertices: Array, triangles: Array, color: Color, luminous: bool = false) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in triangles:
		for step in range(2, -1, -1):
			surface.set_color(color)
			surface.add_vertex(vertices[triangle[step]])
	surface.generate_normals()
	var mesh := Voxels.instance(surface.commit())
	if luminous:
		mesh.material_override = Voxels.glow(color)
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1
		mesh.material_override = material
	return mesh

func _process(delta: float) -> void:
	age += delta
	for index in range(motes.size()):
		var origin: Vector3 = motes[index].get_meta("origin")
		motes[index].position = origin + Vector3(sin(age * .4 + index) * .15, sin(age * .7 + index) * .18, cos(age * .3 + index) * .15)
