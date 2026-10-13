extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const Models = preload("res://scripts/world_voxels.gd")
const World = preload("res://scripts/world.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Ambience = preload("res://scripts/ambience.gd")
const Profiles = preload("res://scripts/asset_profiles.gd")
const Actors = preload("res://scripts/actor_models.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Lore = preload("res://scripts/lore_catalog.gd")
const TownMagic = preload("res://scripts/town_magic.gd")
const TownStyle = preload("res://scripts/town_style.gd")
const Decor = preload("res://scripts/decor_geometry.gd")
const Construction = preload("res://scripts/world_construction.gd")
const Portables = preload("res://scripts/surface_portables.gd")
const Architecture = preload("res://scripts/town_architecture.gd")
const Fallback = preload("res://scripts/town_fallback.gd")
const LocationView = preload("res://scripts/surface_location_view.gd")
const FloatingCityView = preload("res://scripts/floating_city_view.gd")
const BiomeModels = preload("res://scripts/biome_models.gd")
const TerrainData = preload("res://scripts/terrain_mesh_data.gd")
var fuse_terrain := true
var terrain_tasks := {}
var terrain_arrays := {}
var terrain_upload_frame := -1
var portable_world
var npc_models: Dictionary = {}
var living_residents := false
var prop_templates: Dictionary = {}
var scenery := Scenery.new()
var construction := Construction.new()
var architecture := Architecture.new()
var location_view := LocationView.new()
var biome_models := BiomeModels.new()
var biome_templates := {}
var biome_materials := {}
var imported_materials: Dictionary = {}
var portal_frames: Dictionary = {}
var chunk_nodes: Dictionary = {}
var preparing: Dictionary = {}
var prepared_nodes: Dictionary = {}
var preparation_context := []
var measure_preparation := false
var preparation_spikes := []
var terrain_meshes: Dictionary = {}
var batch_meshes: Dictionary = {}
const BATCH_MESH_LIMIT := 512
var prop_meshes: Dictionary = {}
var cutaway := ShaderMaterial.new()

func _init() -> void:
	cutaway.shader = preload("res://assets/world_cutaway.gdshader")

func _process(_delta: float) -> void:
	_poll_terrain()

func _poll_terrain() -> void:
	for task in terrain_tasks.keys():
		if WorkerThreadPool.is_task_completed(task):
			terrain_tasks[task].finish()
			terrain_tasks.erase(task)

func update_visibility(point: Vector2, height: float = 0, yaw: float = PI / 4) -> void:
	cutaway.set_shader_parameter("mage_position", Vector3(point.x, height, point.y))
	cutaway.set_shader_parameter("camera_forward", Vector2(sin(yaw), cos(yaw)))
	for material in imported_materials.values():
		material.set_shader_parameter("mage_position", Vector3(point.x, height, point.y))
		material.set_shader_parameter("camera_forward", Vector2(sin(yaw), cos(yaw)))
	for material in biome_materials.values():
		material.set_shader_parameter("mage_position", Vector3(point.x, height, point.y))
		material.set_shader_parameter("camera_forward", Vector2(sin(yaw), cos(yaw)))

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	chunk_nodes.clear()
	preparing.clear()
	prepared_nodes.clear()
	preparation_context.clear()
	npc_models.clear()

func _preparation_context(world) -> Array:
	return [world.get_instance_id(), world.run_seed, world.generator_version, living_residents]

func clear_prepared() -> void:
	for job in preparing.values():
		remove_child(job.root)
		job.root.queue_free()
	for node in prepared_nodes.values():
		remove_child(node)
		node.queue_free()
	preparing.clear()
	prepared_nodes.clear()

func prepare(world, chunks: Dictionary, coordinates: Array, budget_usec: int = 2000) -> void:
	_poll_terrain()
	coordinates = coordinates.slice(0, 25)
	var context := _preparation_context(world)
	if preparation_context != context:
		clear_prepared()
		preparation_context = context
	portable_world = world
	for coordinate in preparing.keys():
		if coordinate not in coordinates:
			remove_child(preparing[coordinate].root)
			preparing[coordinate].root.queue_free()
			preparing.erase(coordinate)
	for coordinate in prepared_nodes.keys():
		if coordinate not in coordinates:
			remove_child(prepared_nodes[coordinate])
			prepared_nodes[coordinate].queue_free()
			prepared_nodes.erase(coordinate)
	for coordinate in coordinates:
		if preparing.size() >= 9:
			break
		if not chunk_nodes.has(coordinate) and not preparing.has(coordinate) and not prepared_nodes.has(coordinate):
			preparing[coordinate] = _chunk_job(world, coordinate, chunks[coordinate])
	var deadline := Time.get_ticks_usec() + budget_usec
	while not preparing.is_empty() and Time.get_ticks_usec() < deadline:
		var coordinate: Vector2i = preparing.keys()[0]
		var job: Dictionary = preparing[coordinate]
		if job.cursor >= job.cells.size() and not job.terrain_built and (not job.terrain_data.ready or terrain_upload_frame == Engine.get_process_frames()):
			break
		var started := Time.get_ticks_usec() if measure_preparation else 0
		var phase: String = "cell" if job.cursor < job.cells.size() else ("terrain_upload" if not job.terrain_built else (str(job.tasks[job.task_cursor].get_method()) if job.task_cursor < job.tasks.size() else "finish"))
		var ready := _chunk_step(job)
		if measure_preparation and Time.get_ticks_usec() - started > 4000:
			preparation_spikes.append({"coordinate":[coordinate.x, coordinate.y], "phase":phase, "ms":(Time.get_ticks_usec() - started) / 1000.0})
		if ready:
			prepared_nodes[coordinate] = job.root
			preparing.erase(coordinate)
	while preparation_spikes.size() > 64:
		preparation_spikes.pop_front()

func _chunk_job(world, coordinate: Vector2i, chunk: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(coordinate.x * World.CHUNK_SIZE, 0, coordinate.y * World.CHUNK_SIZE)
	root.visible = false
	root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(root)
	return {"root":root, "coordinate":coordinate, "chunk":chunk, "cells":chunk.cells.keys(), "cursor":0, "tasks":[], "task_cursor":0, "terrain_groups":{}, "meshes":{}, "prop_groups":{}, "terrain_data":null, "terrain_built":not fuse_terrain, "region":world.region_at(coordinate * World.CHUNK_SIZE), "visual_seed":world.decoration_seed if world.has_method("dimension_record") else world.run_seed}

func _chunk_step(job: Dictionary, blocking: bool = false) -> bool:
	if job.cursor < job.cells.size():
		_build_chunk_cell(job, job.cells[job.cursor])
		job.cursor += 1
		if job.cursor == job.cells.size():
			_chunk_tasks(job)
		return false
	if not job.terrain_built:
		var data = job.terrain_data
		if not data.ready:
			if not blocking:
				return false
			var task: int = data.task
			data.finish()
			terrain_tasks.erase(task)
		if not data.arrays[Mesh.ARRAY_VERTEX].is_empty():
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.arrays)
			var terrain := MeshInstance3D.new()
			terrain.name = "Terrain"
			terrain.mesh = mesh
			terrain.material_override = cutaway
			job.root.add_child(terrain)
		job.terrain_built = true
		job.terrain_data = null
		terrain_upload_frame = Engine.get_process_frames()
		return false
	if job.task_cursor < job.tasks.size():
		job.tasks[job.task_cursor].call()
		job.task_cursor += 1
		return false
	return true

func _build_chunk_cell(job: Dictionary, cell: Vector2i) -> void:
	var root: Node3D = job.root
	var coordinate: Vector2i = job.coordinate
	var region: Dictionary = job.region
	var visual_seed: int = job.visual_seed
	var terrain_groups: Dictionary = job.terrain_groups
	var prop_groups: Dictionary = job.prop_groups
	var info: Dictionary = job.chunk.cells[cell]
	if info.has("hub_id"):
		return
	var point: Vector2i = cell - coordinate * World.CHUNK_SIZE
	var transform := Transform3D(Basis.IDENTITY, Vector3(point.x, info.height, point.y))
	var axis: Vector2i = info.bridge_axis if info.terrain == "bridge" else Vector2i.ZERO
	var edge: int = info.bridge_edge if info.terrain == "bridge" else 0
	var ecology: Dictionary = info if info.has("biome_id") else {}
	var palette: String = World.Biomes.palette_key(info)
	var key := "%s:%s:%s:%s:%s:%s:%s:%s" % [info.terrain, info.biome, info.tone, info.height, info.facet,axis,edge,palette]
	if not terrain_meshes.has(key):
		terrain_meshes[key] = Models.terrain(info.terrain, info.biome, info.tone, info.height, info.facet,info.bridge_axis,info.bridge_edge,ecology)
	job.meshes[key] = terrain_meshes[key]
	if not terrain_groups.has(key):
		terrain_groups[key] = []
	terrain_groups[key].append(transform)
	if info.terrain == "bridge":
		var base_key := "%s:%s:%s:%s:%s" % [info.base_terrain,info.biome,info.tone,info.base_height,palette]
		if not terrain_meshes.has(base_key):
			terrain_meshes[base_key] = Models.terrain(info.base_terrain,info.biome,info.tone,info.base_height,"",Vector2i.RIGHT,0,ecology)
		job.meshes[base_key] = terrain_meshes[base_key]
		if not terrain_groups.has(base_key):
			terrain_groups[base_key] = []
		terrain_groups[base_key].append(Transform3D(Basis.IDENTITY,Vector3(point.x,info.base_height,point.y)))
		if info.bridge_pier and info.bridge_edge != 0:
			var height: float = info.height - info.base_height
			var pillar := Voxels.cube(Vector3(.18,height,.18),Color("685744"))
			pillar.position = Vector3(point.x,info.base_height + height * .5,point.y)
			root.add_child(pillar)
	for prop in [info.prop, info.detail]:
		if not prop.is_empty():
			var placement := transform
			var variant: int = hash("%s:%s" % [visual_seed, cell]) & 3
			if portable_world.generator_version >= 7 and World.MicroBiomes.nature_world(portable_world, cell):
				var variation := World.Composition.visual(visual_seed, cell, prop == info.detail, prop)
				placement.basis = Basis(Vector3.UP, variation.turn * PI / 2).scaled(variation.scale)
				variant = variation.variant
			if prop.begins_with("biome:"):
				var role: String = prop.trim_prefix("biome:")
				var biome_key := "biome:%s:%s:%s" % [role, info.biome, variant]
				if not prop_groups.has(biome_key):
					prop_groups[biome_key] = []
				prop_groups[biome_key].append(placement)
				continue
			var context := {"biome": info.biome, "city_type": region.city.get("archetype_id", ""), "region_id": region.city.get("id", region.get("id", "region:%s:%s:%s" % [portable_world.generator_version, region.coordinate.x, region.coordinate.y]))}
			var dressing_key := _construction_key(prop, context, hash("%s:%s" % [visual_seed,cell]))
			if dressing_key.is_empty():
				dressing_key = _environment_fallback_key(prop, context)
			if not prop_groups.has(dressing_key):
				prop_groups[dressing_key] = []
			prop_groups[dressing_key].append(placement)

func _chunk_tasks(job: Dictionary) -> void:
	var root: Node3D = job.root
	var coordinate: Vector2i = job.coordinate
	var region: Dictionary = job.region
	if fuse_terrain:
		var pieces := []
		for key in job.terrain_groups:
			var mesh: Mesh = job.meshes[key]
			var id := mesh.get_instance_id()
			if not terrain_arrays.has(id):
				terrain_arrays[id] = {"mesh":mesh, "arrays":mesh.surface_get_arrays(0)}
			pieces.append({"arrays":terrain_arrays[id].arrays, "placements":job.terrain_groups[key]})
		var data := TerrainData.new()
		data.start(pieces)
		job.terrain_data = data
		terrain_tasks[data.task] = data
		while terrain_arrays.size() > 768:
			terrain_arrays.erase(terrain_arrays.keys()[0])
	else:
		for key in job.terrain_groups:
			job.tasks.append(_batch.bind(root, job.meshes[key], job.terrain_groups[key], true))
	for key in job.prop_groups:
		if key.begins_with("biome:"):
			job.tasks.append(_batch_biome.bind(root, key, job.prop_groups[key]))
		elif key in ["oak", "pine", "cactus", "rock"]:
			if not prop_meshes.has(key):
				prop_meshes[key] = Models.prop(key)
			job.tasks.append(_batch.bind(root, prop_meshes[key], job.prop_groups[key], true))
		else:
			job.tasks.append(_batch_profile.bind(root, key, job.prop_groups[key]))
	if not region.city.is_empty() and World.chunk_at(Vector2(region.city.cell)) == coordinate:
		if region.city.get("floating_city", false):
			job.tasks.append(_build_hub.bind(root, region.city))
		else:
			job.tasks.append_array(_city_steps(root, region.city, region.facet))
			job.tasks.append(_build_town_magic.bind(root, region.city))
			job.tasks.append(_build_town_style.bind(root, region.city))
	if region.has("hub_world_gate") and World.chunk_at(region.hub_world_gate) == coordinate:
		job.tasks.append(_build_hub_gate.bind(root, region.hub_world_gate))
	for site in region.dungeons:
		if World.chunk_at(Vector2(site.cell)) == coordinate:
			job.tasks.append_array(_dungeon_steps(root, site))
	for site in region.get("locations", []):
		if World.chunk_at(Vector2(site.cell)) == coordinate:
			job.tasks.append_array(_location_steps(root, site))

func _build_hub(root: Node3D, city: Dictionary) -> void:
	var hub := FloatingCityView.new()
	hub.build(city)
	hub.position -= root.position
	root.add_child(hub)

func _build_hub_gate(root: Node3D, point: Vector2) -> void:
	var anchor := Vector3(point.x, portable_world.ground_height(point), point.y) - root.position
	for index in range(24):
		var angle := index * TAU / 24
		var stone := Voxels.cube(Vector3(.13, .035, .13), Color("aa8bcf"), true)
		stone.position = anchor + Vector3(cos(angle) * 1.25, .02, sin(angle) * 1.25)
		root.add_child(stone)
	_label(root, "Lanternwake  [E]", anchor + Vector3(0, .8, 0), Color("d5c2ef"))

func sync(world) -> void:
	portable_world = world
	var context := _preparation_context(world)
	if preparation_context != context:
		clear_prepared()
		preparation_context = context
	for coordinate in chunk_nodes.keys():
		if not world.chunks.has(coordinate):
			var node: Node3D = chunk_nodes[coordinate]
			for id in node.get_meta("residents", []):
				npc_models.erase(id)
			remove_child(node)
			node.queue_free()
			chunk_nodes.erase(coordinate)
	for coordinate in world.chunks:
		if chunk_nodes.has(coordinate):
			continue
		var root: Node3D
		if prepared_nodes.has(coordinate):
			root = prepared_nodes[coordinate]
			prepared_nodes.erase(coordinate)
		else:
			var job: Dictionary = preparing.get(coordinate, {})
			if job.is_empty():
				job = _chunk_job(world, coordinate, world.chunks[coordinate])
			while not _chunk_step(job, true):
				pass
			root = job.root
			preparing.erase(coordinate)
		chunk_nodes[coordinate] = root
		root.visible = true
		root.process_mode = Node.PROCESS_MODE_INHERIT
		npc_models.merge(root.get_meta("resident_models", {}))
	_trim_construction_cache()
	while terrain_meshes.size() > 768:
		terrain_meshes.erase(terrain_meshes.keys()[0])
	while biome_templates.size() > 128:
		var first: String = biome_templates.keys()[0]
		biome_templates[first].free()
		biome_templates.erase(first)

func _batch_biome(parent: Node3D, key: String, transforms: Array) -> void:
	if not biome_templates.has(key):
		var fields := key.split(":")
		var body := biome_models.create(fields[1], int(fields[2]), int(fields[3]))
		assert(body != null, biome_models.error)
		biome_templates[key] = body
	var body: Node3D = biome_templates[key]
	var pending := [[body, Transform3D.IDENTITY]]
	while not pending.is_empty():
		var current: Array = pending.pop_back()
		var node: Node3D = current[0]
		var local: Transform3D = current[1] * node.transform
		if node is MeshInstance3D:
			var mesh := _shared_batch_mesh(node, true)
			var placed := []
			for transform in transforms:
				placed.append(transform * local)
			_batch(parent, mesh, placed)
			var batch: Node = parent.get_child(parent.get_child_count() - 1)
			for field in ["asset_id", "source_asset", "render_asset", "visual_family", "representation", "biome_role"]:
				batch.set_meta(field, body.get_meta(field))
			batch.set_meta("biome", int(key.split(":")[2]))
		for child in node.get_children():
			if child is Node3D:
				pending.append([child, local])

func _biome_material(original: StandardMaterial3D) -> ShaderMaterial:
	var key := str([original.albedo_color, original.vertex_color_use_as_albedo, original.albedo_texture.get_instance_id() if original.albedo_texture != null else 0, original.metallic, original.metallic_specular, original.roughness, original.uv1_scale, original.uv1_offset])
	if not biome_materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/biome_cutaway.gdshader")
		material.set_shader_parameter("base_color", original.albedo_color)
		material.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
		material.set_shader_parameter("textured", original.albedo_texture != null)
		material.set_shader_parameter("metallic_amount", original.metallic)
		material.set_shader_parameter("specular_amount", original.metallic_specular)
		material.set_shader_parameter("roughness_amount", original.roughness)
		material.set_shader_parameter("uv_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
		material.set_shader_parameter("uv_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
		if original.albedo_texture != null:
			material.set_shader_parameter("albedo_tex", original.albedo_texture)
		biome_materials[key] = material
	return biome_materials[key]

func _construction_key(anchor: String, context: Dictionary, seed_value: int) -> String:
	var recipe := construction.catalog.recipe_for(anchor, context)
	if recipe.is_empty():
		return ""
	var plan := construction.catalog.plan(recipe, context, seed_value)
	if plan.is_empty():
		return ""
	var key := "construction:" + JSON.stringify(plan)
	if not prop_templates.has(key):
		var model := construction.build(plan)
		if model == null:
			return ""
		prop_templates[key] = model
	return key

func _environment_fallback_key(anchor: String, context: Dictionary) -> String:
	var styles = construction.catalog.styles
	var role: String = styles.data.anchors.get(anchor, "")
	if role.is_empty():
		return anchor
	var family: String = styles.family_for(int(context.get("biome", 0)))
	var key: String = styles.native_id(family, role)
	if not prop_templates.has(key):
		var size: Array = styles.data.sizes[role]
		prop_templates[key] = styles.native_model(role, family, Vector2.ONE * float(size[0]), float(size[1]))
	return key

func register_dressing(registrar: Callable, item_for_model: Callable, scope: String) -> void:
	if portable_world != null:
		Portables.register(self, portable_world, registrar, item_for_model, scope)

func _trim_construction_cache() -> void:
	var cap: int = construction.catalog.data.get("template_cap",96)
	for key in prop_templates.keys():
		if prop_templates.size() <= cap:
			break
		prop_templates[key].free()
		prop_templates.erase(key)
	for key in construction.scenery.templates.keys():
		if construction.scenery.templates.size() <= cap:
			break
		construction.scenery.templates[key].free()
		construction.scenery.templates.erase(key)

func _constructed(parent: Node3D, anchor: String, context: Dictionary, seed_value: int, point: Vector3) -> Node3D:
	var key := _construction_key(anchor, context, seed_value)
	if key.is_empty():
		return null
	var model: Node3D = prop_templates[key].duplicate()
	model.position = point
	for part in model.get_children():
		for surface in range(part.mesh.get_surface_count()):
			part.set_surface_override_material(surface, _cutaway_material(part.get_active_material(surface)))
	parent.add_child(model)
	return model

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

func _city_steps(parent: Node3D, city: Dictionary, facet: String) -> Array:
	var steps := []
	parent.set_meta("house_models", {})
	for lot in city.outdoor_lots:
		steps.append(_build_outdoor_lot.bind(parent, city, lot))
	for house in city.houses:
		steps.append(_build_house.bind(parent, city, house))
	for decoration in city.decorations:
		steps.append(_build_decoration.bind(parent, city, decoration))
	steps.append(_build_city_center.bind(parent, city, facet))
	steps.append(_build_town_gateway.bind(parent, city))
	return steps

func _build_city(parent: Node3D, city: Dictionary, facet: String = "") -> void:
	for step in _city_steps(parent, city, facet):
		step.call()

func _build_house(parent: Node3D, city: Dictionary, house: Dictionary) -> void:
	var model: Node3D = architecture.build(house,city)
	if model == null:
		model = Fallback.model("house", construction.catalog.styles.family_for(city.biome), house, city.biome)
		model.material_override = cutaway
	else:
		_architecture_materials(model)
	var center: Vector2 = Vector2(house.footprint.position) + (Vector2(house.footprint.size) - Vector2.ONE) * .5
	model.position = Vector3(center.x, city.height, center.y) - parent.position
	model.rotation.y = atan2(house.facing.x,house.facing.y)
	parent.add_child(model)
	parent.get_meta("house_models")[house.id] = model
	var length: float = house.footprint.size.x if house.facing.x != 0 else house.footprint.size.y
	_build_use_marker(parent,model,house,length,city.biome)
	if not model.has_meta("template_id"):
		var front: Vector3 = model.position + model.basis * Vector3(-.65,.75,length * .5 + .03)
		var banner := _place(parent, "banner_blue" if house.style % 2 == 0 else "banner_red", .48, front, .90, city.biome)
		banner.rotation.y = model.rotation.y

func _build_decoration(parent: Node3D, city: Dictionary, decoration: Dictionary) -> void:
	var point := Vector3(decoration.cell.x, city.height, decoration.cell.y) - parent.position
	var context := {"biome": city.biome, "city_type": city.archetype_id, "region_id": city.id}
	if _constructed(parent, decoration.kind, context, hash(str(decoration.cell)), point) != null:
		return
	var profile: Array = Profiles.MODELS.get(decoration.kind,["",.85,.8])
	_place(parent, decoration.kind, profile[1], point, profile[2], city.biome)

func _build_city_center(parent: Node3D, city: Dictionary, facet: String) -> void:
	var point := Vector3(city.cell.x, city.height, city.cell.y) - parent.position
	var fountain := _place(parent, "fountain", 1.4, point, .6, city.biome)
	parent.set_meta("magic_support", fountain)
	var mist := Ambience.emitter("smoke", Color("b5e5e9"), 10)
	mist.position = point + Vector3(0, .4, 0)
	parent.add_child(mist)
	var tower: Node3D = architecture.civic(city)
	if tower == null:
		tower = Fallback.model("civic_tower", construction.catalog.styles.family_for(city.biome), city, city.biome)
		tower.material_override = cutaway
	else:
		_architecture_materials(tower)
	tower.position = point + Vector3(9, 0, 9)
	parent.add_child(tower)
	if not tower.has_meta("template_id"):
		_place(parent, "stag", .70, point + Vector3(8, 0, 8), 1.1, city.biome)
	else:
		_label(parent,tower.get_meta("construction_name"),tower.position + Vector3(0,tower.get_meta("render_height") + .25,0),Color("d4c596"))
	var resident_models := {}
	if not living_residents and city.get("population_residents", []).is_empty():
		for resident in city.residents:
			var citizen := Actors.create(resident.appearance, resident)
			citizen.position = Vector3(resident.point.x, city.height, resident.point.y) - parent.position
			parent.add_child(citizen)
			resident_models[resident.id] = citizen
		parent.set_meta("residents", city.residents.map(func(resident): return resident.id))
	parent.set_meta("resident_models", resident_models)
	for book in city.books:
		var location := Vector3(book.point.x, city.height + .85, book.point.y) - parent.position
		_place(parent, "book", .32, location, .10, city.biome)
		_label(parent, "Book", location + Vector3(0,.5,0), Color("edce7b"))
	var marker := point + Vector3(-12,0,2)
	_place(parent, "signpost", .7, marker, .95, city.biome)
	var transition: String = Areas.DATA.facets[facet].transition if not facet.is_empty() else "transition_boundary_common"
	var region_label: String = Areas.DATA.transitions[transition].name
	_label(parent, region_label, marker + Vector3(0,1.35,0), Color("c5d6ba"))
	_label(parent, city.name + "\n" + city.get("settlement_type_name",Areas.CITIES[city.archetype_id].name), point + Vector3(0, 2.5, -2), Color("f0d59a"))

func _architecture_materials(model: Node3D) -> void:
	for mesh in model.get_children():
		if mesh is MeshInstance3D:
			for surface in range(mesh.mesh.get_surface_count()):
				mesh.set_surface_override_material(surface,_cutaway_material(mesh.get_active_material(surface)))

func _build_town_gateway(parent: Node3D, city: Dictionary) -> void:
	var model: Node3D = architecture.native_town.gate(city,construction.catalog.styles.family_for(city.biome))
	if model == null:
		return
	var gateway: Dictionary = city.gateway
	_architecture_materials(model)
	model.position = Vector3(gateway.cell.x,city.height,gateway.cell.y) - parent.position
	model.rotation.y = atan2(gateway.facing.x,gateway.facing.y)
	model.set_meta("gateway_id",gateway.id)
	parent.add_child(model)

func _build_town_magic(parent: Node3D, city: Dictionary) -> void:
	if not city.has("magic"):
		return
	var magic := TownMagic.new()
	magic.position = Vector3(city.cell.x,city.height,city.cell.y) - parent.position
	magic.build(city, parent.get_meta("house_models", {}), parent.get_meta("magic_support", null))
	parent.add_child(magic)

func _build_town_style(parent: Node3D, city: Dictionary) -> void:
	if not city.has("exterior_profile"):
		return
	var style := TownStyle.new()
	style.position = Vector3(city.cell.x,city.height,city.cell.y) - parent.position
	style.build(city,cutaway,parent.get_meta("house_models", {}))
	parent.add_child(style)

func _build_use_marker(parent: Node3D, model: Node3D, house: Dictionary, length: float, biome: int = 0) -> void:
	if house.interior_type == "home":
		return
	var family: String = construction.catalog.styles.family_for(biome)
	var board := Decor.node([[Vector3.ZERO, Vector3(.85,.26,.05), Color("68513f")]], family, "trade_sign")
	board.position = model.position + model.basis * Vector3(0,1.58,length * .5 + .08)
	if model.has_meta("template_id"):
		var entrance := Vector3(house.door.x,model.position.y + parent.position.y,house.door.y) - parent.position
		board.position = entrance + model.basis * Vector3(.40,1.35,0)
		var post := Decor.node([[Vector3.ZERO, Vector3(.07,1.35,.07), Color("68513f")]], family, "trade_sign")
		post.position = board.position - Vector3(0,.675,0)
		parent.add_child(post)
	board.rotation.y = model.rotation.y
	parent.add_child(board)
	var label := Label3D.new()
	label.text = house.use_name
	label.position = board.position + model.basis * Vector3(0,0,.03)
	label.rotation.y = model.rotation.y
	label.font_size = 32
	label.pixel_size = .0018
	label.modulate = Color("f1ddb0")
	label.outline_size = 3
	parent.add_child(label)

func _build_outdoor_lot(parent: Node3D, city: Dictionary, lot: Dictionary) -> void:
	var center: Vector2i = lot.footprint.get_center()
	var point := Vector3(center.x,city.height,center.y) - parent.position
	var context := {"biome": city.biome, "city_type": city.archetype_id, "region_id": city.id}
	var model := _constructed(parent,"lot_" + lot.kind,context,hash(lot.id),point)
	if model == null:
		model = Fallback.model("farm_lot" if lot.kind == "farm" else "market_lot", construction.catalog.styles.family_for(city.biome), lot, city.biome)
		model.position = point
		model.material_override = cutaway
		parent.add_child(model)
	model.rotation.y = atan2(lot.facing.x,lot.facing.y)
	if lot.kind == "market":
		var shelter: Node3D = architecture.native_town.market(model,city,construction.catalog.styles.family_for(city.biome))
		if shelter != null:
			_architecture_materials(shelter)
	var top := maxf(1.4,Decor.bounds(model).end.y + .22) if model.has_meta("parts") else 1.4
	_label(parent,lot.name,model.position + Vector3(0,top,0),Color("d6c99d"))

func _location_steps(parent: Node3D, site: Dictionary) -> Array:
	var model := location_view.begin(site)
	model.position = Vector3(site.cell.x, site.height, site.cell.y) - parent.position
	model.rotation.y = atan2(site.facing.x, site.facing.y)
	parent.add_child(model)
	var steps := []
	for group in ["structures", "fixtures"]:
		for part in site[group]:
			steps.append(_location_part.bind(model, site, group, part))
	steps.append(_location_labels.bind(model, site))
	return steps

func _location_part(model: Node3D, site: Dictionary, group: String, part: Dictionary) -> void:
	location_view.add_part(model, site, group, part)
	_architecture_materials(model.get_meta("site_models")[part.id])

func _location_labels(model: Node3D, site: Dictionary) -> void:
	var local_book: Vector2 = Vector2(site.books[0].point) - Vector2(site.cell)
	var rotation := Transform3D(Basis(Vector3.UP, -model.rotation.y), Vector3.ZERO)
	var book_point: Vector3 = rotation * Vector3(local_book.x, 1.4, local_book.y)
	_label(model, "Book", book_point, Color("edce7b"))
	var rest: Vector2 = site.rest_point - Vector2(site.cell)
	_label(model, "Shelter / Rest", rotation * Vector3(rest.x, .6, rest.y), Color("bfd0c0"))

func _build_location(parent: Node3D, site: Dictionary) -> void:
	for step in _location_steps(parent, site):
		step.call()

func _dungeon_steps(parent: Node3D, site: Dictionary) -> Array:
	var anchor := Node3D.new()
	anchor.name = "DungeonEntrance"
	anchor.position = Vector3(site.cell.x, site.height, site.cell.y) - parent.position
	var facing: Vector2i = site.get("facing", Vector2i.DOWN)
	anchor.rotation.y = atan2(facing.x, facing.y)
	anchor.set_meta("site_id", site.id)
	anchor.set_meta("facing", facing)
	parent.add_child(anchor)
	var context := {"family":site.family, "region_id":site.id, "biome":portable_world._biome_at(site.cell)}
	var steps := [_dungeon_arch.bind(anchor, site, context), _dungeon_darkness.bind(anchor)]
	for side in [-1, 1]:
		steps.append(_dungeon_light.bind(anchor, site, context, side))
	steps.append(_dungeon_motes.bind(anchor, site))
	steps.append_array(_portal_steps(anchor, Vector3(0,.8,.15), hash(site.id)))
	var title: String = site.name if site.name == Areas.DUNGEONS[site.family].name else site.name + "\n" + Areas.DUNGEONS[site.family].name
	steps.append(_label.bind(anchor, title, Vector3(0,2.65,-.1), Color("d1bae9")))
	steps.append(_label.bind(anchor, "Survey Road", Vector3(0,.45,2.4), Color("c5d6ba")))
	return steps

func _dungeon_arch(parent: Node3D, site: Dictionary, context: Dictionary) -> void:
	if _constructed(parent,"entrance_arch",context,hash(site.id),Vector3(0,0,-.18)) == null:
		_place(parent, "arch", 2.6, Vector3(0,0,-.18), 1.85, context.biome)

func _dungeon_darkness(parent: Node3D) -> void:
	var darkness := Voxels.cube(Vector3(1.10, 1.55, .05), Color("14222d"))
	darkness.position = Vector3(0,.78,-.25)
	parent.add_child(darkness)

func _dungeon_light(parent: Node3D, site: Dictionary, context: Dictionary, side: int) -> void:
	var light := _constructed(parent,"entrance_light",context,hash(site.id + str(side)),Vector3(side * .85,0,.38))
	if light == null:
		_place(parent, "torch", .26, Vector3(side * .85,.50,.38), .45, context.biome)
	var flame := _context_emitter("fire", Color("ffc787"), 10, site.id)
	flame.position = Vector3(side * .85, .83 if light != null else .96, .38 if light != null else .45)
	parent.add_child(flame)

func _dungeon_motes(parent: Node3D, site: Dictionary) -> void:
	var motes := _context_emitter("magic", Color("bd9ee5"), 12, site.id)
	motes.position = Vector3(0,.35,.1)
	parent.add_child(motes)

func _build_dungeon(parent: Node3D, site: Dictionary) -> void:
	for step in _dungeon_steps(parent, site):
		step.call()

func _context_emitter(kind: String, color: Color, amount: int, identity: String) -> CPUParticles3D:
	var result := Ambience.emitter(kind,color,amount)
	var role: String = {"magic": "magic_particles", "fire": "fire_particles", "smoke": "smoke_particles"}[kind]
	var pool: Array = construction.catalog.pools.get(role, [])
	if not pool.is_empty():
		var texture = construction.catalog.registry.resource(pool[(hash(identity) & 0x7fffffff) % pool.size()])
		if texture is Texture2D:
			result.mesh.material.albedo_texture = texture
	return result

func _portal_steps(parent: Node3D, point: Vector3, seed_value: int) -> Array:
	var paths: Array = construction.catalog.pools.get("arcane_frames", [])
	var groups: Array[String] = []
	for path in paths:
		if path.get_base_dir() not in groups:
			groups.append(path.get_base_dir())
	if groups.is_empty():
		return []
	var group := groups[posmod(seed_value,groups.size())]
	var steps := []
	var frames: SpriteFrames = portal_frames.get(group)
	if frames == null:
		frames = SpriteFrames.new()
		frames.set_animation_speed("default", 6)
		for path in paths:
			if path.get_base_dir() == group:
				steps.append(_portal_frame.bind(frames, path))
		steps.append(_remember_portal_frames.bind(group, frames))
	steps.append(_add_portal_flare.bind(parent, point, seed_value, frames))
	return steps

func _portal_frame(frames: SpriteFrames, path: String) -> void:
	var texture = construction.catalog.registry.resource(path)
	if texture is Texture2D:
		frames.add_frame("default", texture)

func _remember_portal_frames(group: String, frames: SpriteFrames) -> void:
	portal_frames[group] = frames

func _add_portal_flare(parent: Node3D, point: Vector3, seed_value: int, frames: SpriteFrames) -> void:
	if frames.get_frame_count("default") == 0:
		return
	var flare := AnimatedSprite3D.new()
	flare.sprite_frames = frames
	flare.pixel_size = .007
	flare.modulate = Color(1,.75,1,.35)
	flare.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flare.position = point
	flare.play("default")
	flare.frame = posmod(seed_value,frames.get_frame_count("default"))
	parent.add_child(flare)

func _portal_flare(parent: Node3D, point: Vector3, seed_value: int) -> void:
	for step in _portal_steps(parent, point, seed_value):
		step.call()

func _place(parent: Node3D, key: String, width: float, point: Vector3, height: float = 0, biome: int = 0) -> Node3D:
	var styles = construction.catalog.styles
	var family: String = styles.family_for(biome)
	var role: String = {"banner_blue": "banner_wall", "banner_red": "banner_wall", "stag": "statue", "arch": "portal", "torch": "standing_fire"}.get(key, styles.data.anchors.get(key, key))
	assert(not family.is_empty() and styles.supports(role), "Direct local scenery needs a known biome and purposeful native role")
	var source: String = Profiles.MODELS[key][0].trim_prefix("res://assets/expansion/") if Profiles.MODELS.has(key) else key
	var resolved: String = source if styles.allows(source, biome) and construction.catalog.registry.resource(source) != null else styles.native_id(family, role)
	var model := scenery.model(resolved, width, height)
	model.set_meta("asset_id", resolved)
	model.set_meta("visual_family", family)
	model.position = point
	for part in model.get_children():
		for surface in range(part.mesh.get_surface_count()):
			var original: StandardMaterial3D = part.get_active_material(surface)
			part.set_surface_override_material(surface, _cutaway_material(original))
	parent.add_child(model)
	return model

func _cutaway_material(original: StandardMaterial3D) -> ShaderMaterial:
	var id := "%s:%s:%s" % [original.albedo_color, original.vertex_color_use_as_albedo, original.albedo_texture.get_instance_id() if original.albedo_texture != null else 0]
	if not imported_materials.has(id):
		var material := ShaderMaterial.new()
		material.shader = cutaway.shader
		material.set_shader_parameter("base_color", original.albedo_color)
		material.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
		material.set_shader_parameter("textured", original.albedo_texture != null)
		if original.albedo_texture != null:
			material.set_shader_parameter("albedo_tex", original.albedo_texture)
		imported_materials[id] = material
	return imported_materials[id]

func _batch_profile(parent: Node3D, key: String, transforms: Array) -> void:
	if not prop_templates.has(key):
		prop_templates[key] = scenery.profiled(key) if Profiles.MODELS.has(key) else scenery.model(key,.9,1.2)
	for part in prop_templates[key].get_children():
		var mesh := _shared_batch_mesh(part, false)
		var placed := []
		for transform in transforms:
			placed.append(transform * part.transform)
		_batch(parent, mesh, placed)

func _shared_batch_mesh(part: MeshInstance3D, biome: bool) -> Mesh:
	var materials: Array[Material] = []
	var ids := [part.mesh.get_instance_id()]
	for surface in range(part.mesh.get_surface_count()):
		var original: StandardMaterial3D = part.get_active_material(surface)
		var material: Material = (original if original.emission_enabled else _biome_material(original)) if biome else _cutaway_material(original)
		materials.append(material)
		ids.append(material.get_instance_id())
	var key := str(ids)
	if not batch_meshes.has(key):
		var mesh: Mesh = part.mesh.duplicate()
		for surface in range(materials.size()):
			mesh.surface_set_material(surface, materials[surface])
		if batch_meshes.size() >= BATCH_MESH_LIMIT:
			batch_meshes.erase(batch_meshes.keys()[0])
		batch_meshes[key] = mesh
	return batch_meshes[key]

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for data in terrain_tasks.values():
			data.finish()
		for template in prop_templates.values():
			template.free()
		for template in biome_templates.values():
			template.free()

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

