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
	for material in biome_materials.values():
		material.set_shader_parameter("mage_position", Vector3(point.x, height, point.y))
		material.set_shader_parameter("camera_forward", Vector2(sin(yaw), cos(yaw)))

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	chunk_nodes.clear()
	npc_models.clear()

func sync(world) -> void:
	portable_world = world
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
		var root := Node3D.new()
		root.position = Vector3(coordinate.x * World.CHUNK_SIZE, 0, coordinate.y * World.CHUNK_SIZE)
		add_child(root)
		chunk_nodes[coordinate] = root
		var terrain_groups := {}
		var prop_groups := {}
		var region: Dictionary = world.region_at(coordinate * World.CHUNK_SIZE)
		for cell in world.chunks[coordinate].cells:
			var info: Dictionary = world.chunks[coordinate].cells[cell]
			if info.has("hub_id"):
				continue
			var point: Vector2i = cell - coordinate * World.CHUNK_SIZE
			var transform := Transform3D(Basis.IDENTITY, Vector3(point.x, info.height, point.y))
			var axis: Vector2i = info.bridge_axis if info.terrain == "bridge" else Vector2i.ZERO
			var edge: int = info.bridge_edge if info.terrain == "bridge" else 0
			var ecology: Dictionary = info if info.has("biome_id") else {}
			var palette: String = World.Biomes.palette_key(info)
			var key := "%s:%s:%s:%s:%s:%s:%s:%s" % [info.terrain, info.biome, info.tone, info.height, info.facet,axis,edge,palette]
			if not terrain_meshes.has(key):
				terrain_meshes[key] = Models.terrain(info.terrain, info.biome, info.tone, info.height, info.facet,info.bridge_axis,info.bridge_edge,ecology)
			if not terrain_groups.has(key):
				terrain_groups[key] = []
			terrain_groups[key].append(transform)
			if info.terrain == "bridge":
				var base_key := "%s:%s:%s:%s:%s" % [info.base_terrain,info.biome,info.tone,info.base_height,palette]
				if not terrain_meshes.has(base_key):
					terrain_meshes[base_key] = Models.terrain(info.base_terrain,info.biome,info.tone,info.base_height,"",Vector2i.RIGHT,0,ecology)
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
					if prop.begins_with("biome:"):
						var role: String = prop.trim_prefix("biome:")
						var biome_key := "biome:%s:%s:%s" % [role, info.biome, hash("%s:%s" % [world.run_seed, cell]) & 3]
						if not prop_groups.has(biome_key):
							prop_groups[biome_key] = []
						prop_groups[biome_key].append(transform)
						continue
					var context := {"biome": info.biome, "city_type": region.city.get("archetype_id", ""), "region_id": region.city.get("id", "region:%s:%s:%s" % [world.generator_version, region.coordinate.x, region.coordinate.y])}
					var dressing_key := _construction_key(prop, context, hash("%s:%s" % [world.run_seed,cell]))
					if dressing_key.is_empty():
						dressing_key = _environment_fallback_key(prop, context)
					if not prop_groups.has(dressing_key):
						prop_groups[dressing_key] = []
					prop_groups[dressing_key].append(transform)
		for key in terrain_groups:
			_batch(root, terrain_meshes[key], terrain_groups[key], true)
		for key in prop_groups:
			if key.begins_with("biome:"):
				_batch_biome(root, key, prop_groups[key])
			elif key in ["oak", "pine", "cactus", "rock"]:
				if not prop_meshes.has(key):
					prop_meshes[key] = Models.prop(key)
				_batch(root, prop_meshes[key], prop_groups[key], true)
			else:
				_batch_profile(root, key, prop_groups[key])
		if not region.city.is_empty() and World.chunk_at(Vector2(region.city.cell)) == coordinate:
			if region.city.get("floating_city", false):
				var hub := FloatingCityView.new()
				hub.build(region.city)
				hub.position -= root.position
				root.add_child(hub)
			else:
				_build_city(root, region.city, region.facet)
				_build_town_magic(root,region.city)
				_build_town_style(root,region.city)
		if region.has("hub_world_gate") and World.chunk_at(region.hub_world_gate) == coordinate:
			var point: Vector2 = region.hub_world_gate
			var anchor := Vector3(point.x, world.ground_height(point), point.y) - root.position
			for index in range(24):
				var angle := index * TAU / 24
				var stone := Voxels.cube(Vector3(.13, .035, .13), Color("aa8bcf"), true)
				stone.position = anchor + Vector3(cos(angle) * 1.25, .02, sin(angle) * 1.25)
				root.add_child(stone)
			_label(root, "Lanternwake  [E]", anchor + Vector3(0, .8, 0), Color("d5c2ef"))
		for site in region.dungeons:
			if World.chunk_at(Vector2(site.cell)) == coordinate:
				_build_dungeon(root, site)
		for site in region.get("locations", []):
			if World.chunk_at(Vector2(site.cell)) == coordinate:
				_build_location(root, site)
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
			var mesh: Mesh = node.mesh.duplicate()
			for surface in range(mesh.get_surface_count()):
				var material: StandardMaterial3D = node.get_active_material(surface)
				mesh.surface_set_material(surface, material if material.emission_enabled else _biome_material(material))
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

func _build_city(parent: Node3D, city: Dictionary, facet: String = "") -> void:
	var house_models := {}
	for lot in city.outdoor_lots:
		_build_outdoor_lot(parent,city,lot)
	for house in city.houses:
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
		house_models[house.id] = model
		var length: float = house.footprint.size.x if house.facing.x != 0 else house.footprint.size.y
		_build_use_marker(parent,model,house,length,city.biome)
		if not model.has_meta("template_id"):
			var front: Vector3 = model.position + model.basis * Vector3(-.65,.75,length * .5 + .03)
			var banner := _place(parent, "banner_blue" if house.style % 2 == 0 else "banner_red", .48, front, .90, city.biome)
			banner.rotation.y = model.rotation.y
	parent.set_meta("house_models",house_models)
	for decoration in city.decorations:
		var point := Vector3(decoration.cell.x, city.height, decoration.cell.y) - parent.position
		var context := {"biome": city.biome, "city_type": city.archetype_id, "region_id": city.id}
		if _constructed(parent, decoration.kind, context, hash(str(decoration.cell)), point) != null:
			continue
		var profile: Array = Profiles.MODELS.get(decoration.kind,["",.85,.8])
		_place(parent, decoration.kind, profile[1], point, profile[2], city.biome)
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
	if not living_residents:
		for resident in city.residents:
			var citizen := Actors.create(resident.appearance, resident)
			citizen.position = Vector3(resident.point.x, city.height, resident.point.y) - parent.position
			parent.add_child(citizen)
			npc_models[resident.id] = citizen
		parent.set_meta("residents", city.residents.map(func(resident): return resident.id))
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
	var top := maxf(1.4,scenery.bounds(model).end.y + .22) if model.has_meta("parts") else 1.4
	_label(parent,lot.name,model.position + Vector3(0,top,0),Color("d6c99d"))

func _build_location(parent: Node3D, site: Dictionary) -> void:
	var model := location_view.build(site)
	model.position = Vector3(site.cell.x, site.height, site.cell.y) - parent.position
	model.rotation.y = atan2(site.facing.x, site.facing.y)
	for part in model.get_children():
		_architecture_materials(part)
	parent.add_child(model)
	var local_book: Vector2 = Vector2(site.books[0].point) - Vector2(site.cell)
	var rotation := Transform3D(Basis(Vector3.UP, -model.rotation.y), Vector3.ZERO)
	var book_point: Vector3 = rotation * Vector3(local_book.x, 1.4, local_book.y)
	_label(model, "Book", book_point, Color("edce7b"))
	var rest: Vector2 = site.rest_point - Vector2(site.cell)
	_label(model, "Shelter / Rest", rotation * Vector3(rest.x, .6, rest.y), Color("bfd0c0"))

func _build_dungeon(parent: Node3D, site: Dictionary) -> void:
	var point := Vector3(site.cell.x, site.height, site.cell.y) - parent.position
	var anchor := Node3D.new()
	anchor.name = "DungeonEntrance"
	anchor.position = point
	var facing: Vector2i = site.get("facing", Vector2i.DOWN)
	anchor.rotation.y = atan2(facing.x, facing.y)
	anchor.set_meta("site_id", site.id)
	anchor.set_meta("facing", facing)
	parent.add_child(anchor)
	parent = anchor
	point = Vector3.ZERO
	var context := {"family": site.family, "region_id": site.id, "biome": portable_world._biome_at(site.cell)}
	if _constructed(parent,"entrance_arch",context,hash(site.id),point + Vector3(0,0,-.18)) == null:
		_place(parent, "arch", 2.6, point + Vector3(0, 0, -.18), 1.85, context.biome)
	var darkness := Voxels.cube(Vector3(1.10, 1.55, .05), Color("14222d"))
	darkness.position = point + Vector3(0, .78, -.25)
	parent.add_child(darkness)
	for side in [-1, 1]:
		var light := _constructed(parent,"entrance_light",context,hash(site.id + str(side)),point + Vector3(side * .85,0,.38))
		if light == null:
			_place(parent, "torch", .26, point + Vector3(side * .85, .50, .38), .45, context.biome)
		var flame := _context_emitter("fire", Color("ffc787"), 10, site.id)
		flame.position = point + Vector3(side * .85, .83 if light != null else .96, .38 if light != null else .45)
		parent.add_child(flame)
	var motes := _context_emitter("magic", Color("bd9ee5"), 12, site.id)
	motes.position = point + Vector3(0, .35, .1)
	parent.add_child(motes)
	_portal_flare(parent,point + Vector3(0,.8,.15),hash(site.id))
	var title: String = site.name if site.name == Areas.DUNGEONS[site.family].name else site.name + "\n" + Areas.DUNGEONS[site.family].name
	_label(parent, title, point + Vector3(0, 2.65, -.1), Color("d1bae9"))
	_label(parent, "Survey Road", point + Vector3(0,.45,2.4), Color("c5d6ba"))

func _context_emitter(kind: String, color: Color, amount: int, identity: String) -> CPUParticles3D:
	var result := Ambience.emitter(kind,color,amount)
	var role: String = {"magic": "magic_particles", "fire": "fire_particles", "smoke": "smoke_particles"}[kind]
	var pool: Array = construction.catalog.pools.get(role, [])
	if not pool.is_empty():
		var texture = construction.catalog.registry.resource(pool[(hash(identity) & 0x7fffffff) % pool.size()])
		if texture is Texture2D:
			result.mesh.material.albedo_texture = texture
	return result

func _portal_flare(parent: Node3D, point: Vector3, seed_value: int) -> void:
	var paths: Array = construction.catalog.pools.get("arcane_frames", [])
	var groups: Array[String] = []
	for path in paths:
		if path.get_base_dir() not in groups:
			groups.append(path.get_base_dir())
	if groups.is_empty():
		return
	var group := groups[posmod(seed_value,groups.size())]
	if not portal_frames.has(group):
		var sequence := SpriteFrames.new()
		sequence.set_animation_speed("default",6)
		for path in paths:
			if path.get_base_dir() == group:
				var texture = construction.catalog.registry.resource(path)
				if texture is Texture2D:
					sequence.add_frame("default",texture)
		portal_frames[group] = sequence
	var frames: SpriteFrames = portal_frames[group]
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
		var mesh: Mesh = part.mesh.duplicate()
		for surface in range(mesh.get_surface_count()):
			mesh.surface_set_material(surface, _cutaway_material(part.get_active_material(surface)))
		var placed := []
		for transform in transforms:
			placed.append(transform * part.transform)
		_batch(parent, mesh, placed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
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

