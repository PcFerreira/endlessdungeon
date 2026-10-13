extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")

static func model(item: Dictionary, family: String) -> Node3D:
	var color := Color(item.forage_color)
	var stem := Color("536d48")
	var pieces := []
	match item.forage_shape:
		"herb":
			for side in [-1,0,1]:
				pieces.append([Vector3(side * .10,.17,0),Vector3(.035,.34,.035),stem,"stem"])
				pieces.append([Vector3(side * .12,.23,.03),Vector3(.16,.13,.10),color,"leaf"])
		"berry":
			pieces.append([Vector3(0,.19,0),Vector3(.07,.38,.07),stem,"stem"])
			for side in [-1,1]:
				pieces.append([Vector3(side * .10,.30,0),Vector3(.19,.08,.08),stem,"stem"])
				pieces.append([Vector3(side * .12,.34,.02),Vector3(.15,.15,.15),color,"round"])
			pieces.append([Vector3(0,.42,0),Vector3(.14,.14,.14),color.lightened(.2),"round"])
		"fungus":
			for side in [-1,1]:
				pieces.append([Vector3(side * .13,.14,0),Vector3(.07,.28,.07),Color("cdbb99"),"stem"])
				pieces.append([Vector3(side * .13,.30,0),Vector3(.28,.13,.25),color,"leaf"])
		"mineral":
			pieces.append([Vector3(0,.07,0),Vector3(.42,.14,.34),Color("6c777f"),"round"])
			for side in [-1,0,1]:
				pieces.append([Vector3(side * .12,.18 + abs(side) * .02,0),Vector3(.13,.28,.13),color.lightened(side * .10),"leaf"])
		"shell":
			pieces.append([Vector3(0,.035,0),Vector3(.4,.07,.28),Color("b9ac8b"),"round"])
			for index in range(3):
				pieces.append([Vector3((index - 1) * .08,.10,index * .025),Vector3(.13,.12,.18),color.lightened(index * .1),"round"])
	var root := Node3D.new()
	var mesh: ArrayMesh
	if family == "block_voxel":
		mesh = Voxels.mesh(pieces.map(func(piece): return piece.slice(0,3)))
	else:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in pieces:
			var primitive: PrimitiveMesh
			match piece[3]:
				"round":
					var sphere := SphereMesh.new()
					sphere.radial_segments = 6
					sphere.rings = 3
					primitive = sphere
				_:
					var cylinder := CylinderMesh.new()
					cylinder.radial_segments = 6
					cylinder.top_radius = .04 if piece[3] == "leaf" else .5
					primitive = cylinder
			var arrays := primitive.get_mesh_arrays()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var size: Vector3 = piece[1]
			for index in indices:
				surface.set_normal((normals[index] / Vector3(size.x,size.y * .5,size.z)).normalized())
				surface.set_color(piece[2].srgb_to_linear())
				surface.add_vertex(vertices[index] * Vector3(size.x,size.y * .5,size.z) + piece[0])
		surface.set_material(Voxels.material())
		mesh = surface.commit()
	root.add_child(Voxels.instance(mesh))
	root.set_meta("visual_family",family)
	root.set_meta("forage_shape",item.forage_shape)
	return root
