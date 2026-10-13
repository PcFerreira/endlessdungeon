extends SceneTree

const Game = preload("res://scripts/game.gd")
const Profile = preload("res://scripts/character_profile.gd")
const Visual = preload("res://scripts/character_visual.gd")
const Menu = preload("res://scripts/character_menu.gd")
var game
var output := "res://artifacts/player-wardrobe"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("capture")

func capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202a38")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.7
	camera.position = Vector3(0, 1.7, 12)
	camera.current = true
	stage.add_child(camera)
	var bodies: Array[Node3D] = []
	var entries := Profile.premades()
	for index in range(entries.size()):
		var profile := Profile.new()
		assert(profile.restore(Profile.preset_snapshot(entries[index].id, "mage", "Wanderer"), "mage"))
		var visual := Visual.new()
		visual.position = Vector3((index % 4 - 1.5) * 2.1, (2 - index / 4) * 1.9 - 1.25, 0)
		stage.add_child(visual)
		visual.configure("mage", profile)
		visual.animations[0].stop()
		bodies.append(visual)
		var label := Label3D.new()
		label.text = entries[index].display_name
		label.font_size = 30
		label.pixel_size = .005
		label.position = visual.position + Vector3(0, -.18, 0)
		stage.add_child(label)
	await frame("presets-front")
	for body in bodies:
		body.rotation.y = PI
	await frame("presets-back")
	for child in stage.get_children():
		if child is Visual or child is Label3D:
			child.free()
	bodies.clear()
	var outfits := Profile.options("costume", "mage")
	for index in range(outfits.size()):
		var profile := Profile.new()
		profile.costume = outfits[index].id
		profile.outfit = index % 12
		var visual := Visual.new()
		visual.position = Vector3((index % 5 - 2) * 2.0, (2 - index / 5) * 1.9 - 1.25, 0)
		stage.add_child(visual)
		visual.configure("mage", profile)
		visual.animations[0].stop()
		bodies.append(visual)
		var label := Label3D.new()
		label.text = outfits[index].label
		label.font_size = 28
		label.pixel_size = .0045
		label.position = visual.position + Vector3(0, -.18, 0)
		stage.add_child(label)
	await frame("outfits-front")
	for body in bodies:
		body.rotation.y = PI
	await frame("outfits-back")
	stage.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "user://player-wardrobe-preview"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.open_character_menu()
	for index in range(5):
		Menu.active_tab = index
		game.interface.previous_state = ""
		await frame("creator-" + ["presets", "body", "face", "clothes", "colors"][index])
	Menu.active_tab = 0
	game.interface.previous_state = ""
	await process_frame
	await process_frame
	press_choice("model", "voxel:woodland_scout")
	await frame("selected-preset")
	Menu.active_tab = 3
	Menu.selected_fields.Clothes = "outerwear"
	game.interface.previous_state = ""
	await process_frame
	await process_frame
	press_choice("outerwear", "long_cloak")
	await frame("selected-cloak")
	Menu.active_tab = 4
	Menu.selected_fields.Colors = "outer_color"
	game.interface.previous_state = ""
	await process_frame
	await process_frame
	press_choice("outer_color", 10)
	assert(game.profile.model == "voxel:woodland_scout" and game.profile.outerwear == "long_cloak" and game.profile.outer_color == 10)
	await frame("selected-color")
	game.close_character_menu()
	game.begin_journey()
	await frame("world")
	game._clear_actors()
	assert(game.use_sanctum_sigil())
	await frame("sanctum")
	game.queue_free()
	await process_frame
	print("PASS: native voxel preset/outfit fronts/backs, five creator tabs, actual preset/cloak/color callbacks, world and sanctum")
	quit()

func press_choice(key: String, value) -> void:
	for button in game.interface.overlay.find_children("*", "Button", true, false):
		if button.get_meta("profile_choice", "") == key and button.get_meta("choice_value", null) == value:
			button.pressed.emit()
			return
	assert(false, "Missing appearance choice: " + key)

func frame(label: String) -> void:
	for index in range(12):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
