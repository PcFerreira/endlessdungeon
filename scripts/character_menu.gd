extends RefCounted

const Visual = preload("res://scripts/character_visual.gd")
const Profile = preload("res://scripts/character_profile.gd")
static var active_tab := 0
static var selected_fields := {"Face": "head", "Clothes": "costume", "Colors": "skin"}
static var page_indices := {}
const GROUPS := {
	"Face": {"head": "Haircut", "beard": "Beard", "headwear": "Headwear", "eye_shape": "Gaze"},
	"Clothes": {"costume": "Clothes", "outerwear": "Outer layer", "gloves": "Gloves", "boots": "Boots", "belt": "Belt", "accessory": "Accessory"},
	"Colors": {"skin": "Skin", "hair": "Hair", "outfit": "Clothes", "trim": "Trim", "trousers": "Trousers", "boots_color": "Boots", "outer_color": "Outer layer", "headwear_color": "Headwear", "eye_color": "Eyes"}
}

static func build(ui, box: VBoxContainer) -> void:
	var game = ui.game
	ui._center_label(box, "Shape your wanderer", 30, ui.INK, true)
	ui._center_label(box, game.CharacterBuild.CLASSES[game.build.class_id].name + " / Your look is yours to change", 14, ui.GOLD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var preview_panel: PanelContainer = ui._panel(row, Vector2(300, 380))
	var preview_column: VBoxContainer = ui._vbox(preview_panel, 10)
	var preview := SubViewportContainer.new()
	preview.custom_minimum_size = Vector2(264, 300)
	preview.stretch = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_column.add_child(preview)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(264, 300)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(viewport)
	scene(viewport)
	var model := Visual.new()
	model.rotation_degrees.y = -25
	viewport.add_child(model)
	model.configure(game.build.class_id, game.profile)
	ui._center_label(preview_column, "Every voxel preset stays editable", 13, ui.GOLD)
	var turn := HBoxContainer.new()
	turn.add_theme_constant_override("separation", 8)
	preview_column.add_child(turn)
	ui._button(turn, "Turn left", func(): model.rotation.y -= PI / 4, Vector2(126, 30))
	ui._button(turn, "Turn right", func(): model.rotation.y += PI / 4, Vector2(126, 30))
	var poses := HBoxContainer.new()
	poses.add_theme_constant_override("separation", 4)
	preview_column.add_child(poses)
	ui._button(poses, "Stand", func(): model.animate(false, true), Vector2(84, 28))
	ui._button(poses, "Walk", func(): model.animate(true, true), Vector2(84, 28))
	ui._button(poses, "Jump", func(): model.animate(false, false), Vector2(84, 28))
	var form: VBoxContainer = ui._vbox(row, 8)
	form.custom_minimum_size.x = 420
	ui._label(form, "Name", 14, ui.GOLD)
	var name := LineEdit.new()
	name.text = game.profile.display_name
	name.max_length = 24
	name.custom_minimum_size.y = 36
	form.add_child(name)
	var error: Label = ui._label(form, "", 12, Color("e5a097"))
	var tabs := TabContainer.new()
	tabs.set_meta("player_wardrobe_tabs", true)
	tabs.custom_minimum_size = Vector2(420, 420)
	form.add_child(tabs)
	var captions := ["Presets", "Body", "Face", "Clothes", "Colors"]
	for index in range(captions.size()):
		var caption: String = captions[index]
		var scroll := ScrollContainer.new()
		scroll.name = caption
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var contents: VBoxContainer = ui._vbox(scroll, 8)
		contents.custom_minimum_size.x = 392
		if caption == "Presets":
			ui._label(contents, "A starting look, then make it your own.", 13, ui.MUTED)
			choices(ui, contents, "model", model, index == active_tab)
		elif caption == "Body":
			ui._label(contents, "Ancestry", 15, ui.GOLD)
			choices(ui, contents, "ancestry", model, index == active_tab)
			ui._label(contents, "Build", 15, ui.GOLD)
			choices(ui, contents, "body_type", model, index == active_tab)
		else:
			var categories: GridContainer = ui.IconGrid.grid(contents, 4)
			for key in GROUPS[caption]:
				var category: Button = ui.IconGrid.tile(ui, categories, GROUPS[caption][key], ui.IconGrid.symbol("palette" if caption == "Colors" else "avatar"), func():
					selected_fields[caption] = key
					ui.previous_state = "", Vector2(90, 72))
				category.toggle_mode = true
				category.button_pressed = selected_fields[caption] == key
				category.set_meta("appearance_category", key)
			ui._separator(contents)
			if caption == "Face":
				ui._label(contents, "Headwear can cover your hair.", 12, ui.MUTED)
			choices(ui, contents, selected_fields[caption], model, index == active_tab)
	tabs.current_tab = clampi(active_tab, 0, captions.size() - 1)
	tabs.tab_changed.connect(func(index): active_tab = index; ui.previous_state = "")
	var done: Button = ui._button(box, "Keep this appearance / Return  [Esc]", game.close_character_menu)
	name.text_changed.connect(func(value: String):
		var valid: bool = game.customize_character({"name": value})
		error.text = "Enter a name of 1-24 characters." if not valid else ""
		done.disabled = not valid)

static func scene(viewport: SubViewport) -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("e0e5fa")
	sky.ambient_light_energy = .8
	environment.environment = sky
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.position = Vector3(0, .9, 3)
	camera.current = true
	viewport.add_child(camera)
	camera.transform = camera.transform.looking_at(Vector3(0, .66, 0))

static func choices(ui, parent: Node, key: String, model: Node3D, thumbnails: bool) -> void:
	var options := Profile.options(key, ui.game.build.class_id)
	var colored := Profile.Wardrobe.COLOR_FIELDS.has(key)
	var grid: GridContainer = ui.IconGrid.grid(parent, 6 if colored else 4)
	var current_page: int = page_indices.get(key, 0)
	var capacity := 18 if colored else 12
	var visible: Array = ui.IconGrid.page(options, current_page, capacity)
	var group := ButtonGroup.new()
	for option in visible:
		var button: Button = ui.IconGrid.tile(ui, grid, option.label, ui.IconGrid.symbol("palette" if colored else "avatar"), func():
			if ui.game.customize_character({key: option.id}):
				model.configure(ui.game.build.class_id, ui.game.profile)
				ui.previous_state = "", Vector2(60, 80) if colored else Vector2(90, 106))
		button.set_meta("profile_choice", key)
		button.set_meta("choice_value", option.id)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = ui.game.profile.get(key) == option.id
		if colored:
			button.get_child(0).hide()
			var swatch := ColorRect.new()
			swatch.color = option.color
			swatch.position = Vector2(10, 9)
			swatch.size = Vector2(40, 36)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(swatch)
		elif thumbnails:
			button.get_child(0).hide()
			var sample := thumbnail(ui.game, key, option.id)
			sample.position = Vector2(10, 5)
			button.add_child(sample)
	if options.size() > capacity:
		var navigation := HBoxContainer.new()
		navigation.add_theme_constant_override("separation", 8)
		parent.add_child(navigation)
		var previous: Button = ui._button(navigation, "Previous", func(): page_indices[key] = maxi(0, current_page - 1); ui.previous_state = "", Vector2(112, 30))
		previous.disabled = current_page <= 0
		ui._label(navigation, "%s / %s" % [current_page + 1, ceili(options.size() / float(capacity))], 13, ui.GOLD)
		var next: Button = ui._button(navigation, "Next", func(): page_indices[key] = current_page + 1; ui.previous_state = "", Vector2(112, 30))
		next.disabled = (current_page + 1) * capacity >= options.size()

static func thumbnail(game, key: String, value) -> Control:
	var data: Dictionary = Profile.preset_snapshot(value, game.build.class_id, game.profile.display_name) if key == "model" and value != "custom" else game.profile.snapshot()
	data[key] = value
	if key == "head":
		data.headwear = "none"
	var candidate := Profile.new()
	var restored := candidate.restore(data, game.build.class_id)
	assert(restored)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(70, 65)
	container.size = Vector2(70, 65)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(70, 65)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	scene(viewport)
	var visual := Visual.new()
	visual.rotation_degrees.y = -20
	viewport.add_child(visual)
	visual.configure(game.build.class_id, candidate)
	visual.animations[0].stop()
	return container
