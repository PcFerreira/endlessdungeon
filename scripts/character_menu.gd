extends RefCounted

const Visual = preload("res://scripts/character_visual.gd")

static func build(ui, box: VBoxContainer) -> void:
	var game = ui.game
	ui._center_label(box, "Shape your wanderer", 30, ui.INK, true)
	ui._center_label(box, game.CharacterBuild.CLASSES[game.build.class_id].name + " / Appearance choices are cosmetic", 14, ui.GOLD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var preview_panel: PanelContainer = ui._panel(row, Vector2(330, 370))
	var preview_column: VBoxContainer = ui._vbox(preview_panel)
	var preview := SubViewportContainer.new()
	preview.custom_minimum_size = Vector2(294, 280)
	preview.stretch = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_column.add_child(preview)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(294, 280)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(viewport)
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
	var model := Visual.new()
	model.rotation_degrees.y = -25
	viewport.add_child(model)
	model.configure(game.build.class_id, game.profile)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.8
	camera.position = Vector3(0, .9, 3)
	camera.current = true
	viewport.add_child(camera)
	camera.look_at(Vector3(0, .55, 0))
	ui._center_label(preview_column, "Premade character" if game.profile.model != "custom" else "Your custom character", 14, ui.GOLD)
	var turn := HBoxContainer.new()
	turn.add_theme_constant_override("separation", 8)
	preview_column.add_child(turn)
	ui._button(turn, "Turn left", func(): model.rotation.y -= PI / 4, Vector2(140, 32)).add_theme_font_size_override("font_size", 13)
	ui._button(turn, "Turn right", func(): model.rotation.y += PI / 4, Vector2(140, 32)).add_theme_font_size_override("font_size", 13)
	var form: VBoxContainer = ui._vbox(row, 10)
	form.custom_minimum_size.x = 390
	ui._label(form, "Name", 14, ui.GOLD)
	var name := LineEdit.new()
	name.text = game.profile.display_name
	name.max_length = 24
	name.custom_minimum_size.y = 38
	form.add_child(name)
	var error: Label = ui._label(form, "", 12, Color("e5a097"))
	var models := ["custom"]
	var labels := ["Create a custom character"]
	for entry in game.CharacterProfile.premades():
		models.append(entry.id)
		labels.append(entry.get("display_name", entry.id.get_file().get_basename().replace("_", " ")))
	_choices(ui, form, "Character", models, labels, game.profile.model, "model", model)
	var editable: bool = game.profile.model == "custom"
	if not editable:
		var note: Label = ui._label(form, "Premade appearance. Your name and class still apply.", 12, ui.GOLD)
		note.custom_minimum_size.x = 380
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choices(ui, form, "Ancestry", game.CharacterProfile.ANCESTRIES.keys(), game.CharacterProfile.ANCESTRIES.values(), game.profile.ancestry, "ancestry", model, editable)
	_choices(ui, form, "Head", game.CharacterProfile.HEADS.keys(), game.CharacterProfile.HEADS.values(), game.profile.head, "head", model, editable)
	_choices(ui, form, "Skin", [0, 1, 2, 3, 4, 5], ["Warm sand", "Ivory", "Copper", "Umber", "Deep brown", "Ash"], game.profile.skin, "skin", model, editable)
	_choices(ui, form, "Hair", [0, 1, 2, 3, 4, 5], ["Chestnut", "Gold", "Silver", "Auburn", "Black", "Slate"], game.profile.hair, "hair", model, editable)
	var clothing: Dictionary = game.CharacterProfile.CLOTHING[game.build.class_id]
	_choices(ui, form, "Style", clothing.keys(), clothing.values(), game.profile.costume, "costume", model, editable)
	_choices(ui, form, "Color", [0, 1, 2, 3, 4, 5], ["Azure", "Crimson", "Emerald", "Violet", "Amber", "Slate"], game.profile.outfit, "outfit", model, editable)
	var done: Button = ui._button(box, "Keep this appearance / Return  [Esc]", game.close_character_menu)
	name.text_changed.connect(func(text: String):
		var valid: bool = game.customize_character({"name": text})
		error.text = "Enter a name of 1-24 characters." if not valid else ""
		done.disabled = not valid
	)

static func _choices(ui, form: VBoxContainer, caption: String, values: Array, labels: Array, current, key: String, model: Node3D, editable: bool = true) -> void:
	var row := HBoxContainer.new()
	form.add_child(row)
	var label: Label = ui._label(row, caption, 14, ui.INK)
	label.custom_minimum_size.x = 90
	var choices := OptionButton.new()
	choices.custom_minimum_size = Vector2(290, 34)
	for text in labels:
		choices.add_item(str(text))
	choices.select(values.find(current))
	choices.disabled = not editable
	row.add_child(choices)
	choices.item_selected.connect(func(index: int):
		ui.game.customize_character({key: values[index]})
		if key == "model":
			ui.previous_state = ""
		else:
			model.configure(ui.game.build.class_id, ui.game.profile)
	)
