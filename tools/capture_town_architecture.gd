extends SceneTree

const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_view.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const Types = preload("res://scripts/town_types.gd")
const PAGE_SIZE := 12
var stage: Node3D
var camera: Camera3D
var heading: Label
var footer: Label
var architecture
var directory := "res://artifacts/town-architecture/capture-%s" % Time.get_ticks_usec()
var captured := []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	assert(DisplayServer.get_name() != "headless", "Town capture needs the native renderer")
	root.size = Vector2i(1280, 800)
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	architecture = load("res://scripts/town_architecture.gd").new()
	assert(architecture.catalog.error.is_empty())
	_make_stage()
	if not await _towns():
		quit(1)
		return
	if not await _galleries():
		quit(1)
		return
	var manifest := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"resolution": [1280, 800], "images": captured, "templates": architecture.catalog.data.templates.keys(), "themes": architecture.catalog.data.themes.keys(), "catalog_sha256": JSON.stringify(architecture.catalog.data).sha256_text()}, "\t"))
	manifest.close()
	print("CAPTURE_DIRECTORY: " + ProjectSettings.globalize_path(directory))
	print("PASS: %s native town and recipe images, opposing views, imported source and converted voxel forms" % captured.size())
	stage.queue_free()
	await process_frame
	quit()

func _make_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("23303a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e4e9ed")
	environment.environment.ambient_light_energy = .85
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	stage.add_child(camera)
	var captions := CanvasLayer.new()
	root.add_child(captions)
	heading = _caption(captions, Vector2(20, 12), 24)
	footer = _caption(captions, Vector2(20, 770), 16)

func _caption(parent: Node, point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4ead2"))
	label.add_theme_color_override("font_outline_color", Color("18252b"))
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	return label

func _towns() -> bool:
	var index := 0
	for theme in architecture.catalog.data.themes:
		var world := World.new()
		world.generate(12345)
		var city: Dictionary = world.region_at(world.start).city
		city.theme_id = theme
		city.biome = 0 if index % 2 == 0 else 2
		city.name = theme.capitalize() + " architecture"
		city.settlement_type_name = "Generated streets, lots and entrances"
		city.erase("exterior_profile")
		for entry in Types.DATA.types.values():
			if entry.get("theme_id", "") == theme:
				city.exterior_profile = {"style": entry.exterior_style, "color": entry.magic.color, "accent": entry.magic.accent}
				break
		world.load_around(Vector2(city.cell))
		var view := View.new()
		if not view.construction.catalog.error.is_empty() or not view.construction.catalog.styles.error.is_empty():
			push_error("Town capture needs valid environment catalogues: %s; %s" % [view.construction.catalog.error, view.construction.catalog.styles.error])
			view.free()
			return false
		stage.add_child(view)
		view.sync(world)
		var family := "voxelized" if city.biome < 2 else "source"
		heading.text = "%s town | %s" % [theme.capitalize(), family]
		footer.text = "Actual streamed town geometry with generated plots, businesses and civic slot"
		var target := Vector3(city.cell.x, city.height + 1.2, city.cell.y)
		camera.size = 30
		for reverse in [false, true]:
			var yaw := PI * 1.25 if reverse else PI * .25
			camera.position = target + Vector3(sin(yaw) * 24, 29, cos(yaw) * 24)
			camera.look_at(target)
			view.update_visibility(Vector2(city.cell) + Vector2(0, 3), city.height, yaw)
			await _frame("town-%s-%s-%s" % [theme, family, "reverse" if reverse else "front"])
		view.queue_free()
		await process_frame
		index += 1
	return true

func _galleries() -> bool:
	var ids: Array = architecture.catalog.data.templates.keys()
	for family in ["flat_lowpoly", "block_voxel"]:
		var representation := "source" if family == "flat_lowpoly" else "voxelized"
		for offset in range(0, ids.size(), PAGE_SIZE):
			var gallery := Node3D.new()
			stage.add_child(gallery)
			var floor := Voxels.cube(Vector3(23, .12, 20), Color("65726f"))
			floor.position.y = -.06
			gallery.add_child(floor)
			var end := mini(offset + PAGE_SIZE, ids.size())
			for index in range(offset, end):
				var id: String = ids[index]
				var recipe: Dictionary = architecture.catalog.data.templates[id].duplicate(true)
				recipe.id = id
				var slot := index - offset
				var model: Node3D = architecture.build_template(recipe, Vector2(3.4, 3.1), 3.6, family)
				if model == null:
					push_error("Gallery cannot construct %s: %s" % [id, architecture.error])
					gallery.queue_free()
					return false
				model.position = Vector3((slot % 4 - 1.5) * 5.3, 0, (slot / 4 - 1) * 5.8)
				gallery.add_child(model)
				var label := Label3D.new()
				label.text = "%s\n%s" % [id.replace("_", " "), recipe.series]
				label.position = model.position + Vector3(0, 5.0, 0)
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.no_depth_test = true
				label.font_size = 32
				label.pixel_size = .014
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.width = 250
				label.outline_size = 7
				gallery.add_child(label)
			heading.text = "Town recipe gallery | %s | page %s" % [representation, offset / PAGE_SIZE + 1]
			footer.text = "Templates %s to %s of %s | actual imported geometry and recipe parts" % [offset + 1, end, ids.size()]
			camera.size = 23
			for reverse in [false, true]:
				camera.position = Vector3(-19, 29, -25) if reverse else Vector3(19, 29, 25)
				camera.look_at(Vector3(0, 1.5, 0))
				await _frame("gallery-%s-%02d-%s" % [representation, offset / PAGE_SIZE + 1, "reverse" if reverse else "front"])
			gallery.queue_free()
			await process_frame
	return true

func _frame(name: String) -> void:
	for frame in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	var path := directory.path_join(name + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	captured.append(name + ".png")
	print("CAPTURE: " + name)
