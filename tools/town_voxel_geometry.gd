extends RefCounted

const DIRECTIONS := [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]
var cells := {}
var palette: Dictionary
var theme := ""
var pitch := .125
var door := Vector3.ZERO
var has_door := false
var faces := 0

func generate(theme_id: String, kind: String, variant: int, colors: Dictionary) -> Node3D:
	cells.clear()
	palette = colors
	theme = theme_id
	has_door = kind in ["house","workshop","gate"]
	if kind in ["house","workshop"]:
		building(variant)
	elif kind == "gate":
		gate()
	elif kind == "market":
		market()
	else:
		landmark()
	var result := Node3D.new()
	result.name = "VoxelAsset"
	var model := MeshInstance3D.new()
	model.name = "Shell"
	model.mesh = mesh()
	result.add_child(model)
	model.owner = result
	result.set_meta("voxel_pitch",pitch)
	result.set_meta("voxel_count",cells.size())
	result.set_meta("exposed_faces",faces)
	result.set_meta("visual_family","block_voxel")
	if has_door:
		result.set_meta("door_socket",door)
		result.set_meta("door_clearance",Vector2(.75,1.5))
		result.set_meta("front_axis",Vector3.BACK)
	return result

func box(x: int,y: int,z: int,w: int,h: int,d: int,color: String) -> void:
	for a in range(x,x + w):
		for b in range(y,y + h):
			for c in range(z,z + d):
				cells[Vector3i(a,b,c)] = palette.get(color,color)

func shell(w: int,d: int,h: int) -> void:
	box(-w / 2,0,-d / 2,w,2,d,"wood")
	box(-w / 2,2,-d / 2,w,h - 2,2,"wall")
	box(-w / 2,2,-d / 2,2,h - 2,d,"wall")
	box(w / 2 - 2,2,-d / 2,2,h - 2,d,"wall")
	box(-w / 2,2,d / 2 - 2,w / 2 - 3,h - 2,2,"wall")
	box(3,2,d / 2 - 2,w / 2 - 3,h - 2,2,"wall")
	box(-3,14,d / 2 - 2,6,h - 14,2,"wood")
	for side in [-1,1]:
		box(side * (w / 2 - 2) - 1,2,-d / 2,2,h - 2,d,"wood")
		var x: int = side * (w / 2 - 4) - 3
		box(x,6,d / 2 - 1,6,6,1,"light")
		box(x,5,d / 2 - 1,6,1,1,"wood")
		box(x,12,d / 2 - 1,6,1,1,"wood")
		box(x + 3,6,d / 2 - 1,1,6,1,"wood")
		if theme in ["japanese","korean"]:
			for slot in [1,5]:
				box(x + slot,6,d / 2 - 1,1,6,1,"wood")
			if theme == "korean":
				box(x,8,d / 2 - 1,6,1,1,"wood")
				box(x,10,d / 2 - 1,6,1,1,"wood")
	door = Vector3(0,2 * pitch,(d / 2.0) * pitch)

func gable(w: int,d: int,y: int,curve: bool = false) -> void:
	for step in range(w / 4):
		box(-w / 2 + step * 2,y + step,-d / 2,w - step * 4,1,d,"roof")
	if curve:
		for side in [-1,1]:
			box(side * (w / 2 - 1) - 1,y + 1,-d / 2,2,1,d,"roof")
	box(-1,y + w / 4,-d / 2,2,1,d,"trim")

func hip(w: int,d: int,y: int,steps: int,curve: bool = false) -> void:
	for step in range(steps):
		box(-w / 2 + step,y + step,-d / 2 + step,w - step * 2,1,d - step * 2,"roof")
	box(-2,y + steps,-d / 2 + steps,4,1,d - steps * 2,"trim")
	if curve:
		for x in [-1,1]:
			for z in [-1,1]:
				box(x * (w / 2 - 2) - 1,y + 1,z * (d / 2 - 2) - 1,3,1,3,"roof")
				box(x * (w / 2 - 1) - 1,y + 2,z * (d / 2 - 1) - 1,2,1,2,"trim")

func cylinder(radius: int,y: int,h: int,color: String,hollow: bool = false,entrance: bool = false) -> void:
	for x in range(-radius,radius):
		for z in range(-radius,radius):
			var square := (x + .5) * (x + .5) + (z + .5) * (z + .5)
			if square > radius * radius or (hollow and square < (radius - 2) * (radius - 2)):
				continue
			for b in range(y,y + h):
				if entrance and x >= -3 and x < 3 and z > 0 and b >= 2 and b < 14:
					continue
				cells[Vector3i(x,b,z)] = palette.get(color,color)

func building(variant: int) -> void:
	var w := 32 if variant == 0 else 40
	var d := 24
	var h := 16
	if theme == "mage" and variant == 0:
		cylinder(12,0,2,"wood")
		cylinder(12,2,28,"wall",true,true)
		for step in range(18):
			cylinder(20 - step,30 + step,1,"roof")
		box(-1,48,-1,2,3,2,"light")
		door = Vector3(0,2 * pitch,12 * pitch)
		return
	if theme == "fairy" and variant == 0:
		cylinder(10,0,2,"wood")
		cylinder(10,2,16,"wall",true,true)
		for step in range(10):
			cylinder(16 - step / 2,18 + step,1,"roof")
		for p in [Vector3i(-8,24,-3),Vector3i(6,24,5),Vector3i(0,27,-2)]:
			box(p.x,p.y,p.z,3,1,3,"light")
		door = Vector3(0,2 * pitch,10 * pitch)
		return
	if theme == "cyberpunk":
		h = 28 if variant == 0 else 16
		w = 24 if variant == 0 else 40
	if theme == "halloween" and variant == 1:
		w = 24
		h = 24
	shell(w,d,h)
	match theme:
		"japanese":
			gable(w + 4,d + 4,h,true)
			box(-w / 2,h - 2,d / 2 - 1,w,1,1,"wood")
		"chinese":
			hip(w + 6,d + 6,h,8,true)
			for x in [-w / 2,w / 2 - 3]:
				for z in [-d / 2,d / 2 - 3]:
					for step in range(3):
						box(x - step,h - 3 + step,z - step,3 + step * 2,1,3 + step * 2,"trim")
		"korean":
			hip(w + 4,d + 4,h,5,true)
			box(-w / 2,0,d / 2,w,2,4,"wood")
		"halloween":
			gable(w + 4,d + 4,h)
			for step in range(8):
				box(step / 2 - 2,h + w / 4 + step,-3,4,1,6,"roof")
			pumpkin(-w / 2 + 4,h + 2,0,3)
		"christmas":
			gable(w + 4,d + 4,h)
			for side in [-1,1]:
				box(side * 3 - 1,15,d / 2,2,5,1,"plant")
				box(-3,17 + side * 2,d / 2,6,1,1,"plant")
			for side in [-1,1]:
				box(side * (w / 2 - 1) - 1,2,d / 2 - 2,2,h - 2,1,"trim")
			for x in range(-w / 2 + 2,w / 2,4):
				box(x,h,d / 2 + 1,1,2,1,"light")
		"cyberpunk":
			box(-w / 2 - 1,h,-d / 2 - 1,w + 2,2,d + 2,"roof")
			box(-w / 2,h,d / 2,w,1,1,"light")
			for side in [-1,1]:
				box(side * (w / 2 - 3),3,d / 2 - 1,1,h - 4,1,"trim")
			box(-w / 2 + 3,h + 2,-d / 2 + 3,6,4,6,"wood")
			box(-w / 2 + 5,h + 6,-d / 2 + 5,1,8,1,"light")
			if variant == 0:
				box(-5,h + 2,0,10,8,2,"wood")
				box(-4,h + 3,1,8,6,1,"light")
		"mage":
			gable(w + 4,d + 4,h)
			for side in [-1,1]:
				box(side * 8 - 1,6,d / 2,2,8,1,"trim")
				box(side * 8 - 3,9,d / 2,6,2,1,"light")
		"fairy":
			hip(w + 4,d + 4,h,7)
			for x in [-1,1]:
				for z in [-1,1]:
					box(x * (w / 2 - 4) - 2,h + 3,z * 7 - 2,5,1,5,"trim")
			for side in [-1,1]:
				for step in range(6):
					box(side * (w / 2 - 4),3 + step * 2,d / 2 - 1,2,2,1,"plant")

func gate() -> void:
	for side in [-1,1]:
		box(side * 8 - 2,0,-2,4,22,4,"wood")
	if theme != "mage":
		box(-12,20,-3,24,3,6,"trim")
	if theme in ["japanese","chinese","korean"]:
		if theme == "japanese":
			gable(28,12,23,true)
		else:
			hip(28,12,23,4,theme == "chinese")
	elif theme == "halloween":
		pumpkin(0,23,0,5)
	elif theme == "christmas":
		box(-2,18,3,4,7,2,"plant")
		box(-4,21,3,8,2,2,"trim")
	elif theme == "cyberpunk":
		box(-9,3,2,2,16,1,"light")
		box(7,3,2,2,16,1,"light")
		box(-8,20,3,16,1,1,"light")
	elif theme == "mage":
		for step in range(10):
			var radius := maxi(2,10 - step)
			box(-radius,20 + step,-2,2,1,4,"trim")
			box(radius - 2,20 + step,-2,2,1,4,"trim")
		box(-1,30,-1,2,2,2,"light")
	else:
		for side in [-1,1]:
			for step in range(6):
				box(side * 8 - 1,step * 3,2,3,2,2,"plant")
		flower(0,24,0,5)
	door = Vector3(0,0,.5)

func market() -> void:
	for x in [-1,1]:
		for z in [-1,1]:
			box(x * 12 - 1,0,z * 8 - 1,2,16,2,"wood")
	box(-14,6,5,28,3,5,"wood")
	box(-13,9,5,26,1,5,"trim")
	if theme in ["chinese","korean","fairy"]:
		hip(30,22,16,5,theme == "chinese")
	elif theme == "cyberpunk":
		box(-15,16,-11,30,2,22,"roof")
		box(-14,18,10,28,1,1,"light")
		box(-14,18,-11,28,1,1,"trim")
	else:
		gable(30,22,16,theme == "japanese")
	if theme == "fairy":
		for side in [-1,1]:
			flower(side * 12,21,8,2)
			for step in range(5):
				box(side * 12,2 + step * 3,9,2,2,2,"plant")
	elif theme == "mage":
		box(-3,24,-1,6,1,2,"light")
		box(-1,24,-3,2,1,6,"trim")
	for x in [-8,0,8]:
		if theme == "halloween":
			pumpkin(x,10,7,2)
		elif theme == "christmas":
			box(x - 2,10,5,4,4,4,"trim")
			box(x,10,5,1,4,4,"light")
		elif theme == "cyberpunk":
			box(x - 2,10,5,4,3,3,"light")
		else:
			box(x - 2,10,5,4,3,3,"wall")
			box(x - 1,13,6,2,1,2,"trim")

func pumpkin(x: int,y: int,z: int,radius: int) -> void:
	for step in range(radius * 2):
		var r := maxi(1,radius - absi(step - radius) / 2)
		for a in range(-r,r):
			for c in range(-r,r):
				if (a + .5) * (a + .5) + (c + .5) * (c + .5) <= r * r:
					cells[Vector3i(x + a,y + step,z + c)] = palette.trim
	box(x,y + radius * 2,z,1,2,1,"plant")
	for side in [-1,1]:
		box(x + side * 2,y + radius,z + radius - 1,1,1,1,"light")
	box(x - 2,y + maxi(1,radius - 2),z + radius - 1,4,1,1,"wood")

func flower(x: int,y: int,z: int,radius: int) -> void:
	box(x - 2,y - 2,z - 2,4,4,4,"light")
	for side in [-1,1]:
		box(x + side * radius - 2,y - 2,z - 1,4,4,2,"trim")
		box(x - 2,y + side * radius - 2,z - 1,4,4,2,"roof")

func landmark() -> void:
	box(-8,0,-8,16,2,16,"wood")
	match theme:
		"japanese":
			box(-2,2,-2,4,16,4,"wood")
			box(-6,18,-6,12,2,12,"trim")
			box(-4,20,-4,8,8,8,"light")
			gable(14,14,28,true)
		"chinese":
			for x in [-1,1]:
				for z in [-1,1]:
					box(x * 7 - 1,2,z * 7 - 1,2,18,2,"wood")
			hip(22,22,20,6,true)
			cylinder(4,12,7,"trim")
			box(-1,10,-1,2,2,2,"light")
		"korean":
			for step in range(18):
				var radius := maxi(2,8 - absi(step - 9) / 2)
				cylinder(radius,2 + step,1,"light")
			cylinder(4,20,2,"trim",true)
		"halloween":
			pumpkin(0,2,0,8)
		"christmas":
			box(-2,2,-2,4,25,4,"wood")
			for step in range(24):
				cylinder(maxi(1,12 - step / 2),3 + step,1,"plant")
			for p in [Vector3i(-7,7,6),Vector3i(6,8,-6),Vector3i(-4,16,4),Vector3i(4,17,-3)]:
				box(p.x,p.y,p.z,2,2,2,"trim")
			box(-1,27,-1,2,3,2,"light")
		"cyberpunk":
			box(-3,2,-3,6,26,6,"wall")
			for step in range(3):
				box(-7,10 + step * 6,-7,14,2,14,"trim")
				box(-6,12 + step * 6,-6,12,1,12,"light")
			box(-1,28,-1,2,12,2,"light")
		"mage":
			box(-2,2,-2,4,12,4,"wood")
			for step in range(20):
				var y := 14 + step
				var r := maxi(2,10 - absi(step - 10) / 2)
				box(-r,y,-1,2,1,2,"trim")
				box(r - 2,y,-1,2,1,2,"trim")
				box(-1,y,-r,2,1,2,"roof")
				box(-1,y,r - 2,2,1,2,"roof")
			box(-2,22,-2,4,4,4,"light")
		"fairy":
			box(-1,2,-1,2,15,2,"plant")
			flower(0,20,0,6)

func mesh() -> ArrayMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * pitch
	var arrays := cube.get_mesh_arrays()
	var face_vertices := {}
	for direction in DIRECTIONS:
		face_vertices[direction] = []
	for index in arrays[Mesh.ARRAY_INDEX]:
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
		face_vertices[Vector3i(normal)].append(arrays[Mesh.ARRAY_VERTEX][index])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	faces = 0
	for cell in cells:
		var color := Color(cells[cell]).srgb_to_linear()
		var center := (Vector3(cell) + Vector3.ONE * .5) * pitch
		for direction in DIRECTIONS:
			if cells.has(cell + direction):
				continue
			faces += 1
			for vertex in face_vertices[direction]:
				surface.set_normal(Vector3(direction))
				surface.set_color(color)
				surface.add_vertex(center + vertex)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .9
	surface.set_material(material)
	surface.index()
	return surface.commit()
