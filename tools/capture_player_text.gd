extends SceneTree

const Game = preload("res://scripts/game.gd")
const Items = preload("res://scripts/item_catalog.gd")
var game
var directory := "res://artifacts/player-text/capture-%s" % Time.get_ticks_usec()
var texts := {}

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	assert(DisplayServer.get_name() != "headless", "Copy review needs native rendering")
	root.size = Vector2i(1280, 800)
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://player-text-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	var item := ""
	for id in Items.definitions:
		if Items.definitions[id].classification_name == "Blue Set 0000 Weapon":
			item = id
			break
	assert(not item.is_empty() and game.inventory.add(item))
	game.toggle_inventory()
	game.interface.inventory_selected = item
	game.interface.previous_state = ""
	await frame("backpack", game.interface.overlay)
	assert(texts.backpack.has("Weapon"))
	game.toggle_inventory()
	game.inventory.add("gold_coin", 120)
	var city: Dictionary = game.world.region_at(game.world.start).city
	var traded := false
	for house in city.houses:
		var place: Dictionary = game.interiors.describe(city, house)
		if place.type != "workshop":
			continue
		game._generate_surface(place.approach, false)
		game.interact()
		assert(game.layer == "interior")
		var source: Dictionary = game.stores.sources()[0]
		game.player_point = source.point
		game.player.position = game.to_world(source.point)
		game._snap_camera()
		game.interact()
		assert(game.state == "store" and game.stores.catalog.accepts(source.profile, item))
		game.stores.records[source.id].stock = {item: 2}
		game.stores._show()
		await frame("trade", game.stores.overlay)
		assert(texts.trade.has("Weapon  /  Stock 2"))
		assert(game.stores.buy(item))
		game.stores._show()
		await frame("receipt", game.stores.overlay)
		assert(game.stores.feedback.begins_with("Bought Weapon for "))
		game.stores.close()
		traded = true
		break
	assert(traded)
	var save_directory: String = game.save_directory
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(save_directory):
		DirAccess.remove_absolute(save_directory.path_join(file))
	DirAccess.remove_absolute(save_directory)
	await construction()
	var manifest := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"resolution": [1280, 800], "visible_text": texts}, "\t"))
	manifest.close()
	print("CAPTURE_DIRECTORY: " + ProjectSettings.globalize_path(directory))
	print("PASS: native backpack, real workshop trade/receipt and actual WorldView construction signs; isolated saves")
	quit()

func construction() -> void:
	var world = load("res://scripts/world.gd").new()
	world.generate(12345)
	var city: Dictionary = world.region_at(world.start).city
	city.theme_id = "medieval"
	city.biome = 2
	world.load_around(Vector2(city.cell))
	var view = load("res://scripts/world_view.gd").new()
	root.add_child(view)
	view.sync(world)
	var civic: Node3D = null
	for node in view.find_children("*", "Node3D", true, false):
		if node.get_meta("house_id", "") == city.id + ":civic":
			civic = node
			break
	assert(civic != null and civic.has_meta("construction_name"))
	var sign: Label3D = null
	for node in view.find_children("*", "Label3D", true, false):
		assert(not node.text.to_lower().contains("medieval"))
		if node.get_parent() == civic.get_parent() and node.text == civic.get_meta("construction_name"):
			sign = node
			if node.position.distance_to(civic.position) < 10:
				break
	assert(sign != null, "The actual civic construction must have its corrected sign")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	camera.position = sign.global_position + Vector3(8, 5, 8)
	camera.look_at(sign.global_position - Vector3(0, 1.5, 0))
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	root.add_child(light)
	await frame("construction-sign", view)
	assert(texts["construction-sign"].has(sign.text))
	view.queue_free()
	camera.queue_free()
	light.queue_free()
	await process_frame

func frame(label: String, node: Node) -> void:
	for index in range(8):
		await process_frame
	texts[label] = visible_text(node)
	for text in texts[label]:
		assert(not text.to_lower().contains("medieval") and not text.contains("0000") and not text.contains("compatibility with earlier bundles"))
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)

func visible_text(node: Node) -> Array:
	var result := []
	if node is Label or node is Button or node is Label3D:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(visible_text(child))
	return result
