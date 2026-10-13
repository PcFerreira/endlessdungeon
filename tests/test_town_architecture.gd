extends SceneTree

const Areas = preload("res://scripts/area_catalog.gd")
const World = preload("res://scripts/world.gd")
const Game = preload("res://scripts/game.gd")
const Scenery = preload("res://scripts/scenery.gd")
const REQUIRED_THEMES := ["japanese", "chinese", "korean", "halloween", "christmas", "cyberpunk", "mage", "fairy", "woodland", "winter", "caravan", "merchant", "fungal"]
var architecture
var catalog
var directory := "res://artifacts/town-architecture/check-%s" % Time.get_ticks_usec()
var imported_meshes := 0
var textured_surfaces := 0
var voxel_colors := {}

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(ResourceLoader.exists("res://scripts/town_architecture_catalog.gd"), "Town architecture catalog must exist")
	assert(ResourceLoader.exists("res://scripts/town_architecture.gd"), "Town architecture builder must exist")
	var catalog_script = load("res://scripts/town_architecture_catalog.gd")
	catalog = catalog_script.new()
	architecture = load("res://scripts/town_architecture.gd").new()
	assert(catalog.error.is_empty() and catalog_script.valid(catalog.data))
	_check_catalog(catalog_script)
	_check_geometry()
	await _check_game()
	print("PASS: every town recipe in source and voxel forms, real imported resources/materials, fitted facings, source immutability, all uses/themes, deterministic RNG-independent choices, walkable approaches and disk-restored shop return")
	quit()

func _check_catalog(script) -> void:
	var invalid: Dictionary = catalog.data.duplicate(true)
	invalid.version = 2
	assert(not script.valid(invalid), "Unsupported catalog versions must be rejected")
	invalid = catalog.data.duplicate(true)
	var first: String = invalid.templates.keys()[0]
	invalid.templates[first].parts[0].size = [0, 1, 1]
	assert(not script.valid(invalid), "Zero-width recipe parts must be rejected")
	invalid = catalog.data.duplicate(true)
	invalid.themes[invalid.themes.keys()[0]].houses.append("missing_recipe")
	assert(not script.valid(invalid), "Dangling theme recipes must be rejected")
	invalid = catalog.data.duplicate(true)
	for id in invalid.themes.japanese.houses:
		invalid.templates[id].uses.erase("scribe")
	assert(not script.valid(invalid), "Every theme must cover every actual business purpose")
	var referenced := {}
	for theme in REQUIRED_THEMES:
		assert(catalog.data.themes.has(theme), "Missing town theme: " + theme)
	for theme in catalog.data.themes:
		var entry: Dictionary = catalog.data.themes[theme]
		assert(entry.houses.size() >= 2 and not entry.civics.is_empty(), "Each theme needs distinct homes and a civic recipe")
		for id in entry.houses + entry.civics:
			referenced[id] = true
		var city := {"id": "check:" + theme, "theme_id": theme, "archetype_id": "city_crossroads", "biome": 2}
		assert(catalog.theme_for(city) == theme)
		for use_id in Areas.DATA.building_uses:
			var house := _house("check:" + theme + ":" + use_id, use_id)
			var before: Dictionary = house.duplicate(true)
			var chosen: Dictionary = catalog.choose(house, city)
			assert(not chosen.is_empty() and chosen.kind == "house" and chosen.uses.has(use_id), "Purpose-ineligible recipe for " + theme + ":" + use_id)
			assert(entry.houses.has(chosen.id), "Purpose choice must use the town's own architectural series")
			assert(chosen.theme == theme, "Purpose choice must retain the town's theme palette")
			for part in chosen.parts:
				if part.has("asset"):
					assert(catalog.registry.resource(part.asset) is PackedScene, "Theme palette points to an unavailable imported scene: " + part.asset)
			assert(chosen == catalog.choose(house, city) and house == before)
			seed(9743)
			var expected := randi()
			seed(9743)
			catalog.choose(house, city)
			assert(randi() == expected, "Recipe selection must not consume gameplay RNG")
	assert(referenced.size() == catalog.data.templates.size(), "Every declared recipe must be reachable through a theme pool")
	for id in catalog.data.templates:
		var recipe: Dictionary = catalog.data.templates[id]
		var reached := false
		for theme in catalog.data.themes:
			var pool: Array = catalog.data.themes[theme].houses if recipe.kind == "house" else catalog.data.themes[theme].civics
			if not pool.has(id):
				continue
			for index in range(128):
				var house := {"id": "reach:%s:%s" % [id, index], "kind": recipe.kind, "use_id": recipe.uses[0] if recipe.kind == "house" else ""}
				var selected: Dictionary = catalog.choose(house, {"id": "reach:" + theme, "theme_id": theme})
				if selected.id == id:
					reached = true
					break
			if reached:
				break
		assert(reached, "Recipe can never be selected for an eligible theme and building purpose: " + id)

func _check_geometry() -> void:
	var started := Time.get_ticks_msec()
	var distinct_geometry := {}
	for id in catalog.data.templates:
		var recipe: Dictionary = catalog.data.templates[id].duplicate(true)
		recipe.id = id
		var source: Node3D = architecture.build_template(recipe, Vector2(2.83, 1.83), 3.6, "flat_lowpoly")
		_check_model(source, id, Vector2(2.83, 1.83), 3.6, "source")
		if id == "town_timber_cottage":
			_check_cottage_walls(source)
		for yaw in [0.0, PI * .5, PI, PI * 1.5]:
			var rotated := _rotated_bounds(source, yaw)
			var extent := Vector2(2.83, 1.83) if is_zero_approx(sin(yaw)) else Vector2(1.83, 2.83)
			assert(rotated.size.x <= extent.x + .001 and rotated.size.z <= extent.y + .001, "Every recipe must fit its rotated lot bounds")
		var source_signature := _snapshot(source)
		var cache_signature := _cache_snapshot()
		var blocks: Node3D = architecture.build_template(recipe, Vector2(2.83, 1.83), 3.6, "block_voxel")
		_check_model(blocks, id, Vector2(2.83, 1.83), 3.6, "voxelized")
		assert(_snapshot(source) == source_signature and _cache_snapshot() == cache_signature, "Voxel conversion must not mutate imported source geometry, transforms or materials")
		distinct_geometry[_geometry_key(source)] = true
		var imported_resources := {}
		for template in architecture.scenery.templates.values():
			for child in template.get_children():
				imported_resources[child.mesh.get_instance_id()] = true
		var recipe_imports := 0
		for child in source.get_children():
			if imported_resources.has(child.mesh.get_instance_id()):
				recipe_imports += 1
			for surface in range(child.mesh.get_surface_count()):
				var material: StandardMaterial3D = child.get_active_material(surface)
				if material.albedo_texture != null:
					textured_surfaces += 1
				if imported_resources.has(child.mesh.get_instance_id()):
					imported_meshes += 1
		var declared_assets := []
		for part in recipe.parts:
			if part.has("asset") and not declared_assets.has(part.asset):
				declared_assets.append(part.asset)
		assert(source.get_meta("source_assets").size() == declared_assets.size())
		assert(declared_assets.all(func(asset): return source.get_meta("source_assets").has(asset)))
		assert(declared_assets.is_empty() or recipe_imports > 0, "Source recipes must retain the actual imported mesh resources")
		for child in blocks.get_children():
			for surface in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(surface)
				for normal in arrays[Mesh.ARRAY_NORMAL]:
					var axis: Vector3 = normal.abs()
					assert(axis.max_axis_index() >= 0 and absf(axis[axis.max_axis_index()] - 1) < .0001 and absf(axis.x + axis.y + axis.z - 1) < .0001, "Voxel surfaces must remain axis aligned")
				for color in arrays[Mesh.ARRAY_COLOR]:
					voxel_colors[color] = true
		source.free()
		blocks.free()
	assert(imported_meshes > 0 and textured_surfaces > 0, "Recipe geometry must use real imported meshes and their textures")
	assert(voxel_colors.size() > 8 and distinct_geometry.size() > 6, "Town diversity must survive geometry and material conversion")
	var city := {"id": "facings", "theme_id": "japanese", "archetype_id": "city_crossroads", "biome": 0}
	for biome in range(4):
		city.biome = biome
		for facing in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
			var house := _house("facings:%s:%s" % [biome, facing], "home")
			house.facing = facing
			var model: Node3D = architecture.build(house, city)
			assert(model.get_meta("house_id") == house.id)
			assert(model.get_meta("visual_family") == ("block_voxel" if biome < 2 else "flat_lowpoly"))
			var box := _rotated_bounds(model, atan2(facing.x, facing.y))
			assert(box.size.x <= house.footprint.size.x + .001 and box.size.z <= house.footprint.size.y + .001, "Rotated mesh must stay inside its collision footprint")
			assert(absf(box.position.y) < .001, "House must meet the ground")
			model.free()
		var civic: Node3D = architecture.civic(city)
		assert(civic.get_meta("house_id") == city.id + ":civic")
		var civic_bounds := Scenery.new().bounds(civic)
		assert(civic_bounds.size.x <= 3 and civic_bounds.size.z <= 3 and absf(civic_bounds.position.y) < .001, "Civic must fit the reserved square")
		civic.free()
	print("Architecture geometry: %s recipes, %s distinct meshes, %s imported surfaces, %s textured surfaces, %s voxel colors, %s ms" % [catalog.data.templates.size(), distinct_geometry.size(), imported_meshes, textured_surfaces, voxel_colors.size(), Time.get_ticks_msec() - started])

func _check_cottage_walls(model: Node3D) -> void:
	var wall: Mesh = architecture.scenery.templates["kenney_fantasy_town_kit/Models/GLB format/wall-wood.glb"].get_child(0).mesh
	var sides := 0
	var backs := 0
	for child in model.get_children():
		if child.mesh != wall:
			continue
		var box: AABB = child.transform * wall.get_aabb()
		if box.size.x < box.size.z * .2:
			sides += 1
		if box.size.z < box.size.x * .2:
			backs += 1
	print("Cottage imported wall orientation: %s thin-X side walls, %s wide-X back walls" % [sides, backs])
	assert(sides == 2 and backs == 1, "Local wall dimensions must rotate with part yaw before the complete building is fitted")

func _check_model(model: Node3D, id: String, footprint: Vector2, height: float, representation: String) -> void:
	assert(model != null and model.get_child_count() > 0, "Missing recipe geometry: " + id)
	assert(model.get_meta("template_id") == id and model.get_meta("representation") == representation)
	assert(model.get_meta("source_assets") is Array)
	var family: String = model.get_meta("visual_family")
	var render_asset: String = model.get_meta("render_asset")
	assert(architecture.styles.family_of(render_asset) == family, "Rendered construction identity must match its geometry family")
	for biome in range(4):
		assert(architecture.styles.allows(render_asset, biome) == (biome < 2 if representation == "voxelized" else biome >= 2), "Rendered identity must respect the biome family")
	for asset in model.get_meta("source_assets"):
		assert(architecture.styles.family_of(asset) == "flat_lowpoly", "Imported source identity must retain its original geometry family")
	assert(is_equal_approx(model.get_meta("render_height"), height))
	assert(model.get_children().all(func(child): return child is MeshInstance3D and child.mesh != null), "Recipes must flatten imported scene hierarchies")
	assert(Scenery.new().valid_materials(model), "Recipe has missing imported materials/textures: " + id)
	var box := Scenery.new().bounds(model)
	assert(absf(box.position.y) < .001 and box.size.x <= footprint.x + .001 and box.size.z <= footprint.y + .001 and absf(box.size.y - height) < .001, "Recipe fitted bounds differ: " + id)
	for child in model.get_children():
		for surface in range(child.mesh.get_surface_count()):
			assert(not child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].is_empty())

func _snapshot(model: Node3D) -> Array:
	var result := []
	for child in model.get_children():
		var surfaces := []
		for surface in range(child.mesh.get_surface_count()):
			var material: StandardMaterial3D = child.get_active_material(surface)
			surfaces.append([child.mesh.surface_get_arrays(surface), material.get_instance_id(), material.albedo_color, material.albedo_texture, material.texture_filter, material.roughness])
		result.append([child.transform, child.mesh.get_instance_id(), surfaces])
	return result

func _cache_snapshot() -> Dictionary:
	var result := {}
	for key in architecture.scenery.templates:
		result[key] = _snapshot(architecture.scenery.templates[key])
	return result

func _geometry_key(model: Node3D) -> String:
	var vertices := PackedVector3Array()
	for child in model.get_children():
		for surface in range(child.mesh.get_surface_count()):
			for vertex in child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				vertices.append(child.transform * vertex)
	return var_to_bytes(vertices).hex_encode().sha256_text()

func _rotated_bounds(model: Node3D, yaw: float) -> AABB:
	var result := AABB()
	var first := true
	var rotation := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	for child in model.get_children():
		var box: AABB = rotation * child.transform * child.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _house(id: String, use_id: String) -> Dictionary:
	return {"id": id, "footprint": Rect2i(0, 0, 3, 2), "height": 2.5, "style": 0, "facing": Vector2i.DOWN, "use_id": use_id, "architecture": Areas.CITIES.city_crossroads.architecture}

func _check_game() -> void:
	var started := Time.get_ticks_msec()
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var city: Dictionary = game.world.region_at(game.world.start).city
	var before: Dictionary = city.duplicate(true)
	var shop := {}
	for house in city.houses:
		assert(game.world.walkable(house.approach), "House approach must remain walkable")
		var place: Dictionary = game.interiors.describe(city, house)
		if place.type == "shop":
			shop = place
	assert(not shop.is_empty())
	game._generate_surface(shop.approach, false)
	assert(game.world.region_at(city.cell).city == before, "Visual construction must not change generated lots or entrances")
	var exterior: Array = game.world_view.find_children("*", "Node3D", true, false).filter(func(node): return node.get_meta("house_id", "") == shop.id and node.has_meta("template_id"))
	assert(not exterior.is_empty(), "Streamed town must use the new architecture builder")
	game._clear_actors()
	game.interact()
	assert(game.layer == "interior" and game.interiors.current.id == shop.id)
	var counter: Dictionary = game.stores.sources()[0]
	assert(counter.id == shop.id and game.dungeon.walkable(counter.point))
	game.player_point = counter.point
	game.interact()
	assert(game.state == "store")
	game.stores.close()
	assert(game.save_game(1))
	var fresh := Game.new()
	fresh.records_enabled = false
	fresh.save_directory = directory
	fresh.settings_path = directory.path_join("settings.cfg")
	root.add_child(fresh)
	fresh.set_physics_process(false)
	assert(fresh.load_game(1) and fresh.layer == "interior" and fresh.interiors.current.id == shop.id)
	assert(fresh.interiors.leave() and fresh.layer == "overworld" and fresh.player_point.is_equal_approx(shop.approach))
	assert(fresh.world.region_at(city.cell).city.houses == before.houses)
	game.queue_free()
	fresh.queue_free()
	await process_frame
	print("Architecture game compatibility: %s ms" % (Time.get_ticks_msec() - started))
