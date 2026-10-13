extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const Models = preload("res://scripts/world_voxels.gd")
const World = preload("res://scripts/world.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Ambience = preload("res://scripts/ambience.gd")
var scenery := Scenery.new()
var imported_materials: Dictionary = {}
var chunk_nodes: Dictionary = {}
var terrain_meshes: Dictionary = {}
var prop_meshes: Dictionary = {}
var cutaway := ShaderMaterial.new()

func _init() -> void:
	cutaway.shader = preload("res://assets/world_cutaway.gdshader")

func update_visibility(point: Vector2, height: float = 0, yaw: float = PI / 4) -> void:
	cutaway.set_shader_parameter("mage_position", Vector3(point.x, height, point.y))
	cutaway.set_shader_parameter("camera_forward", Vector2(sin(yaw), cos(yaw)))
	for material in imported_materials.values():
		material.set_shader_parameter("mage_position", Vector3(point.x, height, point.y))
		material.set_shader_parameter("camera_forward", Vector2(sin(yaw), cos(yaw)))

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	chunk_nodes.clear()

func sync(world) -> void:
	for coordinate in chunk_nodes.keys():
		if not world.chunks.has(coordinate):
			var node: Node3D = chunk_nodes[coordinate]
			remove_child(node)
			node.queue_free()
			chunk_nodes.erase(coordinate)
	for coordinate in world.chunks:
		if chunk_nodes.has(coordinate):
			continue
		var root := Node3D.new()
		root.position = Vector3(coordinate.x * World.CHUNK_SIZE, 0, coordinate.y * World.CHUNK_SIZE)
		add_child(root)
		chunk_nodes[coordinate] = root
		var terrain_groups := {}
		var prop_groups := {}
		for cell in world.chunks[coordinate].cells:
			var info: Dictionary = world.chunks[coordinate].cells[cell]
			var point: Vector2i = cell - coordinate * World.CHUNK_SIZE
			var transform := Transform3D(Basis.IDENTITY, Vector3(point.x, info.height, point.y))
			var key := "%s:%s:%s:%s" % [info.terrain, info.biome, info.tone, info.height]
			if not terrain_meshes.has(key):
				terrain_meshes[key] = Models.terrain(info.terrain, info.biome, info.tone, info.height)
			if not terrain_groups.has(key):
				terrain_groups[key] = []
			terrain_groups[key].append(transform)
			if not info.prop.is_empty():
				if not prop_meshes.has(info.prop):
					prop_meshes[info.prop] = Models.prop(info.prop)
				if not prop_groups.has(info.prop):
					prop_groups[info.prop] = []
				prop_groups[info.prop].append(transform)
		for key in terrain_groups:
			_batch(root, terrain_meshes[key], terrain_groups[key], true)
		for key in prop_groups:
			_batch(root, prop_meshes[key], prop_groups[key], true)
		var region: Dictionary = world.region_at(coordinate * World.CHUNK_SIZE)
		if World.chunk_at(Vector2(region.city.cell)) == coordinate:
			_build_city(root, region.city)
		for site in region.dungeons:
			if World.chunk_at(Vector2(site.cell)) == coordinate:
				_build_dungeon(root, site)

func _batch(parent: Node, asset: Mesh, transforms: Array, obstructing: bool = false) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = asset
	batch.instance_count = transforms.size()
	for index in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	if obstructing:
		node.material_override = cutaway
	parent.add_child(node)

func _build_city(parent: Node3D, city: Dictionary) -> void:
	for house in city.houses:
		var model := Voxels.instance(Models.house(house, city.biome))
		model.material_override = cutaway
		var center: Vector2 = Vector2(house.footprint.position) + (Vector2(house.footprint.size) - Vector2.ONE) * .5
		model.position = Vector3(center.x, city.height, center.y) - parent.position
		parent.add_child(model)
		var front: Vector3 = model.position + Vector3(0, 0, house.footprint.size.y * .5 - .5)
		_place(parent, "banner_blue" if house.style % 2 == 0 else "banner_red", .48, front + Vector3(-.65, .75, .53), .90)
	for decoration in city.decorations:
		var point := Vector3(decoration.cell.x, city.height, decoration.cell.y) - parent.position
		_place(parent, decoration.kind, .42 if decoration.kind == "pot" else .62, point)
	var point := Vector3(city.cell.x, city.height, city.cell.y) - parent.position
	var fountain := Voxels.instance(Models.fountain())
	fountain.position = point
	parent.add_child(fountain)
	var mist := Ambience.emitter("smoke", Color("b5e5e9"), 10)
	mist.position = point + Vector3(0, .4, 0)
	parent.add_child(mist)
	var tower := Voxels.instance(Models.tower(city.style))
	tower.material_override = cutaway
	tower.position = point + Vector3(9, 0, 9)
	parent.add_child(tower)
	_place(parent, "stag", .70, point + Vector3(8, 0, 8), 1.1)
	for index in range(3):
		var color: Color = [Color("8c7f57"), Color("6f8296"), Color("a6736b")][index]
		var citizen := Voxels.instance(Models.citizen(color))
		citizen.position = point + Vector3(-2.5 + index * 2.5, 0, -2.5)
		citizen.rotation.y = index * .9
		parent.add_child(citizen)
	_label(parent, city.name, point + Vector3(0, 2.0, -2), Color("f0d59a"))

func _build_dungeon(parent: Node3D, site: Dictionary) -> void:
	var point := Vector3(site.cell.x, site.height, site.cell.y) - parent.position
	_place(parent, "arch", 2.6, point + Vector3(0, 0, -.18), 1.85)
	var darkness := Voxels.cube(Vector3(1.10, 1.55, .05), Color("14222d"))
	darkness.position = point + Vector3(0, .78, -.25)
	parent.add_child(darkness)
	for side in [-1, 1]:
		_place(parent, "torch", .26, point + Vector3(side * .85, .50, .38), .45)
		var flame := Ambience.emitter("fire", Color("ffc787"), 10)
		flame.position = point + Vector3(side * .85, .96, .45)
		parent.add_child(flame)
	var motes := Ambience.emitter("magic", Color("bd9ee5"), 12)
	motes.position = point + Vector3(0, .35, .1)
	parent.add_child(motes)
	_label(parent, site.name, point + Vector3(0, 2.30, -.1), Color("d1bae9"))

func _place(parent: Node3D, key: String, width: float, point: Vector3, height: float = 0) -> Node3D:
	var model := scenery.model(key, width, height)
	model.position = point
	for part in model.get_children():
		for surface in range(part.mesh.get_surface_count()):
			var original: StandardMaterial3D = part.get_active_material(surface)
			var id := original.get_instance_id()
			if not imported_materials.has(id):
				var material := ShaderMaterial.new()
				material.shader = cutaway.shader
				material.set_shader_parameter("base_color", original.albedo_color)
				material.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
				material.set_shader_parameter("textured", original.albedo_texture != null)
				if original.albedo_texture != null:
					material.set_shader_parameter("albedo_tex", original.albedo_texture)
				imported_materials[id] = material
			part.set_surface_override_material(surface, imported_materials[id])
	parent.add_child(model)
	return model

func _label(parent: Node, text: String, point: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = 42
	label.pixel_size = .007
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.outline_size = 7
	parent.add_child(label)

