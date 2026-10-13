extends SceneTree

const Bundles = preload("res://scripts/bundle_catalog.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Models = preload("res://scripts/enemy_models.gd")
const Visual = preload("res://scripts/item_visual.gd")
const Life = preload("res://scripts/world_life_catalog.gd")
var gallery: Node3D
var camera: Camera3D
var game

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	gallery = Node3D.new()
	root.add_child(gallery)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14
	camera.position = Vector3(0, 10, 10)
	gallery.add_child(camera)
	camera.look_at(Vector3(0,0,0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	gallery.add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("171d2a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4c6dd")
	settings.ambient_light_energy = .7
	environment.environment = settings
	gallery.add_child(environment)
	var actors := Node3D.new()
	gallery.add_child(actors)
	for page in range(ceili(float(Bundles.data.enemies.size()) / 24)):
		_clear(actors)
		for index in range(page * 24, mini((page+1)*24,Bundles.data.enemies.size())):
			var definition: Dictionary = Bundles.data.enemies[index]
			var model := Models.create(Enemies.index_of(definition.id),42)
			_place(actors,model,index%24,definition.name)
		await frame("bundle-enemies-%s" % page)
	var life := Life.new()
	for page in range(ceili(float(life.data.species.size()) / 24)):
		_clear(actors)
		for index in range(page*24,mini((page+1)*24,life.data.species.size())):
			var definition: Dictionary = life.data.species[index]
			var model := life.registry.instantiate(life.model_choices[definition.id][0].id)
			var bounds := Models.bounds(model)
			var factor := 1.1 / maxf(.01,maxf(bounds.size.y,maxf(bounds.size.x,bounds.size.z)))
			model.scale *= factor
			model.position = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
			var wrapper := Node3D.new()
			wrapper.add_child(model)
			_place(actors,wrapper,index%24,definition.get("name", definition.id.capitalize()))
		await frame("bundle-animals-%s" % page)
	_clear(actors)
	var item_packs := {}
	for item in Bundles.data.items:
		if not item_packs.has(item.source_pack):
			item_packs[item.source_pack] = item
	var index := 0
	for item in item_packs.values():
		_place(actors,Visual.model(item,1.1),index,item.source_pack.replace("_"," "))
		index += 1
	await frame("bundle-item-sources")
	gallery.queue_free()
	await process_frame
	if "--gallery-only" in OS.get_cmdline_user_args():
		print("PASS: native gallery of every creature and all item source bundles")
		quit()
		return
	var Game = load("res://scripts/game.gd")
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/bundle-preview-saves"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	for item in item_packs.values():
		if game.inventory.slots_used() < game.inventory.CAPACITY:
			game.inventory.add(item.id)
	game.notification_time = 0
	game.toggle_inventory()
	game.interface.inventory_selected = item_packs.values()[0].id
	await frame("bundle-backpack")
	verify_previews(game.interface.overlay)
	print("PASS: native pages for every creature visual, one actual item from every source bundle and live model thumbnails in the backpack")
	game.queue_free()
	await process_frame
	quit()

func _clear(node: Node3D) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _place(parent: Node3D, model: Node3D, index: int, caption: String) -> void:
	var wrapper := Node3D.new()
	parent.add_child(wrapper)
	wrapper.position = Vector3((index%6-2.5)*2.2,0,(int(index/6)-1.5)*2.7)
	wrapper.add_child(model)
	var label := Label3D.new()
	label.text = caption
	label.font_size = 20
	label.pixel_size = .009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0,-.3,.25)
	wrapper.add_child(label)

func frame(label: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/"+label+".png") == OK)

func verify_previews(node: Node) -> void:
	if node is SubViewport:
		var pixels: Image = node.get_texture().get_image()
		var visible := 0
		for x in range(pixels.get_width()):
			for y in range(pixels.get_height()):
				if pixels.get_pixel(x,y).a > .5:
					visible += 1
		assert(visible > 0,"Inventory thumbnail must render real geometry, including thin arrows/tools")
	for child in node.get_children():
		verify_previews(child)
