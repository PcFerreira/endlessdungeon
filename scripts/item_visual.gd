extends RefCounted

const Catalog = preload("res://scripts/item_catalog.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const Models = preload("res://scripts/enemy_models.gd")
const Scenery = preload("res://scripts/scenery.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const Furniture = preload("res://scripts/furnishing_catalog.gd")
static var registry := Registry.new()
static var families := ItemModels.new()

static func model(item: Dictionary, extent: float = .5, family: String = "", item_id: String = "") -> Node3D:
	var root := Node3D.new()
	if not family.is_empty():
		var body: Node3D
		if not item_id.is_empty() and not Furniture.definition(item_id).is_empty():
			body = Furniture.model({"item": item_id, "rotation": 0}, null, family)
		else:
			body = families.create(item, family)
		if body == null:
			root.free()
			return null
		root.add_child(body)
		var box := Models.bounds(body)
		var factor := extent / maxf(.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
		body.scale *= factor
		body.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * factor
		for key in ["source_asset", "render_asset", "visual_family", "representation"]:
			root.set_meta(key, body.get_meta(key))
		root.set_meta("item_id", item_id)
		root.set_meta("asset_id", root.get_meta("render_asset"))
		return root
	if item.has("scenery_key"):
		root.add_child(Scenery.new().model(item.scenery_key, extent, 0 if Scenery.is_native(item.scenery_key) else extent))
	elif item.has("asset_id"):
		var body := registry.instantiate(item.asset_id)
		if body == null:
			root.free()
			return null
		root.add_child(body)
		var box := Models.bounds(body)
		var factor := extent / maxf(.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
		body.scale *= factor
		body.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * factor
	else:
		var sprite := Sprite3D.new()
		sprite.texture = Catalog.icon(item)
		sprite.pixel_size = extent / maxf(1, maxf(sprite.texture.get_width(), sprite.texture.get_height()))
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.position.y = extent * .5
		root.add_child(sprite)
	return root

static func preview(item: Dictionary, size: Vector2 = Vector2(52, 52)) -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var body := model(item, 1.25)
	if body != null:
		viewport.add_child(body)
		body.rotation.y = -.35
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.9
	camera.position = Vector3(2, 1.8, 3)
	viewport.add_child(camera)
	camera.transform = camera.transform.looking_at(Vector3(0, .55, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.3
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a3b1cd")
	settings.ambient_light_energy = .65
	environment.environment = settings
	viewport.add_child(environment)
	return container
