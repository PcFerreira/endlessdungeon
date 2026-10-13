extends CanvasLayer

const Minimap = preload("res://scripts/minimap.gd")
const AimCursor = preload("res://scripts/aim_cursor.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const INK := Color("e5e0d5")
const MUTED := Color("909caa")
const GOLD := Color("c3a576")
const TEAL := Color("7bded0")
var game
var root := Control.new()
var overlay := Control.new()
var depth_label: Label
var theme_label: Label
var objective_label: Label
var map_title: Label
var map_legend: Label
var map_help: Label
var vitality_label: Label
var aether_label: Label
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var message: Label
var hint: Label
var spell_status: Dictionary = {}
var spell_buttons: Dictionary = {}
var spell_recharge: Dictionary = {}
var target_name: Label
var target_status: Label
var target_bar: ProgressBar
var previous_state := ""
var previous_bar: Array[String] = []
var hotbar: HBoxContainer
var grimoire_tabs: TabContainer
var grimoire_tab := 0
var title_font: Font
var hud := Control.new()
var target_panel: PanelContainer
var sanctum_button: Button
var class_icon: TextureRect
var previous_class := ""

func _ready() -> void:
	if ResourceLoader.exists("res://assets/fonts/Cinzel.ttf"):
		title_font = load("res://assets/fonts/Cinzel.ttf")
	else:
		title_font = ThemeDB.fallback_font
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	var cursor := AimCursor.new()
	cursor.game = game
	root.add_child(cursor)
	cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _panel(parent: Node, minimum: Vector2, accent: Color = Color("36444f")) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UISkin.frame("panel_blue", Color("333d50"), 18)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	UISkin.ornament(panel, GOLD if accent == Color("766950") else Color("778a9d"))
	return panel

func _label(parent: Node, text: String, font_size: int = 16, color: Color = INK, serif: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if serif:
		label.add_theme_font_override("font", title_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _vbox(parent: Node, separation: int = 9) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box

func _button(parent: Node, text: String, callback: Callable, minimum: Vector2 = Vector2(0, 49)) -> Button:
	var button := Button.new()
	button.text = text
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.custom_minimum_size = minimum
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var tint := Color("727e91") if state in ["hover", "focus"] else Color("4d596d")
		if state == "disabled":
			tint = Color("333c4d")
		var style := UISkin.frame("buttonLong_blue_pressed" if state == "pressed" else "buttonLong_blue", tint, 10)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _bar(parent: Node, color: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(245, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UISkin.bar("Back"))
	bar.add_theme_stylebox_override("fill", UISkin.bar(color))
	parent.add_child(bar)
	return bar

func _build_hud() -> void:
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var top := _panel(hud, Vector2(292, 0))
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.position = Vector2(22, 22)
	var column := _vbox(top, 5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	class_icon = TextureRect.new()
	class_icon.custom_minimum_size = Vector2(40, 40)
	class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(class_icon)
	var identity := _vbox(row, 2)
	depth_label = _label(identity, "Mage", 22, INK, true)
	_label(identity, "THE WANDERING LANDS", 10, GOLD)
	vitality_label = _label(column, "VITALITY", 12, INK)
	hp_bar = _bar(column, "Red")
	aether_label = _label(column, "AETHER", 12, INK)
	mana_bar = _bar(column, "Blue")
	var top_right := _panel(hud, Vector2(206, 0))
	top_right.mouse_filter = Control.MOUSE_FILTER_STOP
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -228
	top_right.offset_right = -22
	top_right.offset_top = 22
	var map_column := _vbox(top_right, 6)
	map_title = _label(map_column, "ATLAS OF THE LANDS", 12, GOLD, true)
	var map := Minimap.new()
	map.game = game
	map.custom_minimum_size = Vector2(170, 150)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_column.add_child(map)
	map_legend = _label(map_column, "", 10, MUTED)
	map_help = _label(map_column, "", 10, MUTED)
	var utilities := HBoxContainer.new()
	utilities.add_theme_constant_override("separation", 6)
	map_column.add_child(utilities)
	_button(utilities, "Book [G]", game.toggle_grimoire, Vector2(82, 30)).add_theme_font_size_override("font_size", 12)
	_button(utilities, "Menu", game.toggle_pause, Vector2(82, 30)).add_theme_font_size_override("font_size", 12)
	var chapter := VBoxContainer.new()
	hud.add_child(chapter)
	chapter.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	chapter.offset_left = -255
	chapter.offset_right = 255
	chapter.offset_top = 33
	theme_label = _label(chapter, "", 21, INK, true)
	theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	theme_label.add_theme_color_override("font_shadow_color", Color("14212c"))
	theme_label.add_theme_constant_override("shadow_outline_size", 3)
	objective_label = _label(chapter, "", 13, GOLD)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_color_override("font_shadow_color", Color("14212c"))
	objective_label.add_theme_constant_override("shadow_outline_size", 3)
	target_panel = _panel(hud, Vector2(290, 0), Color("766950"))
	target_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	target_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	target_panel.offset_left = -145
	target_panel.offset_right = 145
	target_panel.offset_top = 100
	var target_column := _vbox(target_panel, 5)
	_label(target_column, "TARGET", 10, GOLD)
	target_name = _label(target_column, "No target", 16, INK, true)
	target_bar = _bar(target_column, "Red")
	target_status = _label(target_column, "Left-click a warden to select", 11, MUTED)
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	hud.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_left = -416
	footer.offset_right = 416
	footer.offset_top = -126
	footer.offset_bottom = -18
	var tray := _panel(footer, Vector2.ZERO, Color("766950"))
	tray.add_theme_stylebox_override("panel", UISkin.frame("panel_blue", Color("30384a"), 10))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 18)
	tray.add_child(actions)
	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 4)
	actions.add_child(hotbar)
	_build_action_bar()
	sanctum_button = _button(actions, "", game.use_sanctum_sigil, Vector2(76, 76))
	sanctum_button.focus_mode = Control.FOCUS_NONE
	sanctum_button.icon = load("res://assets/sanctum_sigil.svg")
	sanctum_button.expand_icon = true
	sanctum_button.add_theme_constant_override("icon_max_width", 40)
	var sigil_key := _label(sanctum_button, "H", 12, GOLD)
	sigil_key.position = Vector2(9, 5)
	var sigil_name := _label(sanctum_button, "Sanctum", 10, INK)
	sigil_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sigil_name.offset_left = -31
	sigil_name.offset_right = 31
	sigil_name.offset_top = -18
	sigil_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint = _label(footer, "", 12, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_shadow_color", Color("14212c"))
	hint.add_theme_constant_override("shadow_outline_size", 3)
	message = _label(hud, "", 16, INK)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message.offset_left = -450
	message.offset_right = 450
	message.offset_top = -173
	message.offset_bottom = -140
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_shadow_color", Color("101722"))
	message.add_theme_constant_override("shadow_outline_size", 5)

func _build_action_bar() -> void:
	for child in hotbar.get_children():
		hotbar.remove_child(child)
		child.queue_free()
	spell_status.clear()
	spell_buttons.clear()
	spell_recharge.clear()
	previous_bar = game.ACTION_BAR.duplicate()
	for index in range(game.ACTION_BAR.size()):
		var spell: String = game.ACTION_BAR[index]
		var empty := spell.is_empty()
		var color: Color = MUTED.darkened(.5) if empty else game.ABILITIES[spell].color
		var button := _button(hotbar, "", game.cast_slot.bind(index), Vector2(68, 76))
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = empty
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var tint := Color("71899c") if state in ["hover", "focus"] else Color("aaa59b")
			if empty or state == "disabled":
				tint = Color("555d70")
			var style := UISkin.frame("buttonSquare_brown_pressed" if state == "pressed" else "buttonSquare_brown", tint, 6)
			button.add_theme_stylebox_override(state, style)
		var box := _vbox(button, 3)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 6
		box.offset_right = -6
		box.offset_top = 5
		box.offset_bottom = -5
		var key_label := _label(button, str((index + 1) % 10), 11, GOLD if not empty else MUTED)
		key_label.position = Vector2(7, 4)
		if empty:
			var placeholder := _label(box, ".", 28, color)
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.tooltip_text = "Empty slot %s. G opens your grimoire to assign an ability." % ((index + 1) % 10)
			continue
		var icon := TextureRect.new()
		icon.texture = load("res://assets/spells/%s.svg" % spell)
		icon.custom_minimum_size = Vector2(0, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		_label(box, game.ABILITIES[spell].short, 10, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_status[spell] = _label(box, "", 10, MUTED)
		spell_status[spell].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_buttons[spell] = button
		button.tooltip_text = "%s [%s]\n%s %s / %.2fs recharge\n%s" % [game.ABILITIES[spell].name, (index + 1) % 10, int(game.ABILITIES[spell].cost), game.CharacterBuild.CLASSES[game.build.class_id].resource.to_lower(), game.ABILITIES[spell].recharge, game.ABILITIES[spell].description]
		var recharge := ProgressBar.new()
		recharge.custom_minimum_size.y = 3
		recharge.show_percentage = false
		recharge.max_value = 1.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		recharge.add_theme_stylebox_override("fill", fill)
		box.add_child(recharge)
		spell_recharge[spell] = recharge

func _process(_delta: float) -> void:
	if game == null:
		return
	if previous_bar != game.ACTION_BAR:
		_build_action_bar()
	hud.visible = game.has_journey and not game.state in ["menu", "title", "credits"]
	if previous_class != game.build.class_id:
		previous_class = game.build.class_id
		class_icon.texture = load("res://assets/spells/%s.svg" % {"mage": "bolt", "sword": "strike", "spellsword": "runeblade"}[previous_class])
		mana_bar.add_theme_stylebox_override("fill", UISkin.bar("Green" if previous_class == "sword" else "Blue"))
	depth_label.text = game.CharacterBuild.CLASSES[game.build.class_id].name
	theme_label.text = game.location_name()
	if game.layer == "overworld":
		map_title.text = "ATLAS OF THE LANDS"
		map_legend.text = "Gold: city   /   Violet: dungeon"
		map_help.text = "Tab: atlas   /   White: you"
		objective_label.text = "Explore the lands. Tab opens the atlas."
		if not game.waypoint.is_empty():
			objective_label.text = "%s / %.0f away" % [game.waypoint.name, game.player_point.distance_to(game.waypoint.cell)]
		hint.text = "WASD: move   Q/R: rotate   Space: jump   G: grimoire   1-0: abilities   E: interact   Tab: atlas   Esc: pause"
	elif game.layer == "sanctum":
		map_title.text = "THE INNER SANCTUM"
		map_legend.text = "Violet: hearth / Teal: portal"
		map_help.text = "Your home beyond the world"
		objective_label.text = "A quiet place between journeys"
		hint.text = "E: rest / portal   H: return   G: grimoire   Esc: menu"
	else:
		map_title.text = "CHART OF THE DEPTHS"
		map_legend.text = "Rose: wardens   /   Gold: you"
		map_help.text = "Squares: stairs and descent gate"
		var goal: String = "%s wardens remain" % game.enemies.size() if not game.enemies.is_empty() else ("Final chest claimed" if game.claimed_chests.has(game.active_dungeon.id) else ("Claim the final chest: +1 skill point" if game.depth == game.active_dungeon.floors else "Find the descent gate"))
		objective_label.text = "Floor %s / %s / %s" % [game.depth, game.active_dungeon.floors, goal]
		hint.text = "WASD: move   Q/R: rotate   Space: jump   G: grimoire   1-0: abilities   E: interact   F: surface   Esc: pause"
	vitality_label.text = "VITALITY    %s / %s" % [ceili(game.hp), int(game.max_hp)]
	aether_label.text = "%s      %s / %s" % [game.CharacterBuild.CLASSES[game.build.class_id].resource.to_upper(), int(game.mana), int(game.max_mana)]
	hp_bar.max_value = game.max_hp
	hp_bar.value = game.hp
	mana_bar.max_value = game.max_mana
	mana_bar.value = game.mana
	sanctum_button.disabled = game.state != "playing"
	sanctum_button.tooltip_text = "Sanctum Sigil [H]\nA bound home between worlds. Rest at its hearth and return to the place you left.\n" + ("Return to your journey." if game.layer == "sanctum" else (game.sanctum_problem() if not game.sanctum_problem().is_empty() else "Ready. Requires stable footing and distance from enemies."))
	target_panel.visible = game.valid_enemy(game.selected_target)
	if game.valid_enemy(game.selected_target):
		var target: Dictionary = game.selected_target
		target_name.text = game.ENEMY_NAMES[target.kind]
		target_bar.max_value = target.max_hp
		target_bar.value = target.hp
		var problem: String = game.target_problem()
		target_status.text = "%s / %s   Range %.1f" % [ceili(target.hp), int(target.max_hp), game.player_point.distance_to(target.point)] if problem.is_empty() else problem
		target_status.modulate = Color.WHITE if problem.is_empty() else Color("e5a097")
	else:
		target_name.text = "No target"
		target_bar.value = 0
		target_status.text = "Left-click a warden to select"
		target_status.modulate = Color.WHITE
	message.text = game.notification if game.notification_time > 0 and game.state == "playing" else ""
	var action_hint: String = game.interaction_hint()
	if game.state == "playing" and not action_hint.is_empty():
		message.text = action_hint
	for spell in spell_status:
		var label: Label = spell_status[spell]
		var cooldown: float = game.cooldowns[spell]
		var blocked: bool = game.ABILITIES[spell].range > 0 and not game.target_problem(game.ABILITIES[spell].range).is_empty()
		label.text = "%.1fs" % cooldown if cooldown > 0 else ("Free" if game.ABILITIES[spell].cost == 0 else str(int(game.ABILITIES[spell].cost)))
		if cooldown <= 0 and blocked:
			label.text = "Target" if game.selected_target.is_empty() else "Blocked"
		label.modulate = Color("d6978e") if blocked or game.mana < game.ABILITIES[spell].cost else Color.WHITE
		spell_recharge[spell].value = cooldown / game.ABILITIES[spell].recharge
		spell_buttons[spell].disabled = game.state != "playing"
	if previous_state != game.state:
		previous_state = game.state
		_rebuild_overlay()

func _rebuild_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	if game.state == "playing":
		return
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, .065, .79)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := _panel(center, Vector2(1100 if game.state == "grimoire" else (760 if game.state in ["map", "credits"] else 650), 0), Color("766950"))
	var box := _vbox(panel, 16)
	var kicker := _label(box, "PROCEDURAL WORLD  /  VOXEL PROTOTYPE", 12, GOLD)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match game.state:
		"menu":
			_center_label(box, "The Wandering\nLands", 44, INK, true)
			_center_label(box, "Steel and spells. A world beyond the gate.", 17, MUTED)
			_separator(box)
			var resume := _button(box, "Continue", game.continue_journey)
			resume.disabled = not game.has_journey and game.saves.latest_slot() < 0
			_button(box, "New Game", game.new_character)
			_button(box, "Load Game", game.open_save_menu.bind(true))
			_button(box, "Options", game.open_options)
			_button(box, "Credits", game.show_credits, Vector2(0, 36))
			_button(box, "Quit", game.quit_game, Vector2(0, 36))
			_center_label(box, "Voxel world  /  Godot  /  MVP 0.7", 11, GOLD)
		"title":
			_center_label(box, "The Wandering\nLands", 44, INK, true)
			_center_label(box, "Steel and spells. A world beyond the gate.", 17, MUTED)
			_separator(box)
			_center_label(box, "Explore biomes. Rest in cities. Discover old dungeons.\nThe lands unfold as you travel.", 16, INK)
			_center_label(box, "WASD: Move   Space: Jump   Click: Target\nQ/R or middle-drag: Rotate   Wheel: Zoom\n1-0: Abilities   G: Grimoire   E: Interact", 14, MUTED)
			var classes := HBoxContainer.new()
			classes.add_theme_constant_override("separation", 8)
			box.add_child(classes)
			for id in game.CharacterBuild.CLASSES:
				var data: Dictionary = game.CharacterBuild.CLASSES[id]
				var button := _button(classes, data.name, game.choose_class.bind(id), Vector2(190, 40))
				button.tooltip_text = data.description
			_center_label(box, "Selected: " + game.CharacterBuild.CLASSES[game.build.class_id].name, 15, GOLD)
			_center_label(box, game.CharacterBuild.CLASSES[game.build.class_id].description, 13, MUTED)
			_button(box, "Begin your journey  [Enter]", game.begin_journey)
			_button(box, "Back to main menu  [Esc]", func(): game.state = "menu", Vector2(0, 36))
		"map":
			_center_label(box, "Atlas of the wandering lands", 25, INK, true)
			_center_label(box, "Gold squares: cities   /   Violet diamonds: dungeons", 13, GOLD)
			var atlas := Minimap.new()
			atlas.game = game
			atlas.world_map_mode = true
			atlas.custom_minimum_size = Vector2(700, 440)
			atlas.mouse_filter = Control.MOUSE_FILTER_STOP
			box.add_child(atlas)
			_center_label(box, "Click a city or dungeon to set your route. The chart covers this region and its neighbors.", 12, MUTED)
			_button(box, "Return to the journey  [Tab / Esc]", game.toggle_map)
		"paused":
			_center_label(box, "A moment of stillness", 30, INK, true)
			_center_label(box, game.location_name(), 16, MUTED)
			_button(box, "Continue  [Esc]", game.toggle_pause)
			var saves := HBoxContainer.new()
			saves.add_theme_constant_override("separation", 12)
			box.add_child(saves)
			_button(saves, "Save Game  [F5]", game.open_save_menu.bind(false), Vector2(296, 40))
			_button(saves, "Load Game  [F9]", game.open_save_menu.bind(true), Vector2(296, 40))
			_button(box, "Grimoire  [G]", game.toggle_grimoire, Vector2(0, 36))
			_button(box, "Options", game.open_options, Vector2(0, 36))
			if game.layer == "dungeon":
				_button(box, "Return to the surface", game.return_to_surface, Vector2(0, 36))
			if game.layer == "sanctum":
				_button(box, "Return to your journey  [H]", func(): game.state = "playing"; game.leave_sanctum(), Vector2(0, 36))
			_button(box, "Return to sanctuary / Unstuck", game.return_to_sanctuary, Vector2(0, 36))
			_button(box, "Main Menu", game.return_to_menu, Vector2(0, 36))
			_button(box, "Save and Quit", game.quit_game, Vector2(0, 36))
		"save", "load":
			var loading: bool = game.state == "load"
			_center_label(box, "Load Game" if loading else "Save Game", 30, INK, true)
			_center_label(box, "Choose a journey to continue." if loading else "Choose one of three manual slots.", 15, MUTED)
			for slot in range(0 if loading else 1, 4):
				var info: Dictionary = game.saves.summary(slot)
				var callback: Callable = game.load_game.bind(slot) if loading else game.save_game.bind(slot)
				var button := _button(box, "%s\n%s" % [info.label, info.text], callback, Vector2(0, 82))
				button.disabled = loading and not info.valid
			_button(box, "Back  [Esc]", game.close_save_menu, Vector2(0, 36))
		"options":
			_center_label(box, "Options", 30, INK, true)
			_audio_slider(box, "Music", game.sound.music_level, game.sound.set_music_level)
			_audio_slider(box, "Effects", game.sound.sfx_level, game.sound.set_sfx_level)
			_button(box, "Unmute sound" if game.sound.muted else "Mute sound", func(): game.sound.toggle_mute(); game.interface.previous_state = "", Vector2(0, 36))
			var fullscreen := CheckBox.new()
			fullscreen.text = "Fullscreen  [F11]"
			fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.get_name() != "headless" else false
			fullscreen.toggled.connect(game.set_fullscreen)
			box.add_child(fullscreen)
			_separator(box)
			_center_label(box, "WASD / arrows: Move   Space: Jump\nClick: Target   1-0: Abilities   G: Grimoire\nQ/R: Rotate   Middle-drag: Orbit   Wheel: Zoom\nE: Interact   Tab: Atlas   F: Surface   H: Sanctum\nF5: Save slot 1   F9: Load latest   M: Sound\nEsc: Clear target / Pause / Back", 14, MUTED)
			_button(box, "Back  [Esc]", game.close_options, Vector2(0, 36))
		"save_failed":
			_center_label(box, "The journey could not be saved", 27, INK, true)
			_center_label(box, game.menu_notice, 15, MUTED)
			_button(box, "Return to the game", func(): game.state = "paused")
			_button(box, "Continue without saving", game.finish_exit, Vector2(0, 36))
		"credits":
			_center_label(box, "The makers behind the lands", 28, INK, true)
			_center_label(box, "Music by Eric Matyas\nwww.soundimage.org", 20, GOLD)
			_center_label(box, "Fantascape  /  Netherplace  /  Lost Jungle\nFantasy Game Background  /  Our Mountain\nCity Beneath the Waves v001  /  Misty Bog\nSpells a-Brewin  /  Strange Phenomenon", 15, INK)
			_center_label(box, "Music: Soundimage International Public License\nsoundimage.org/sample-page/\nSource recordings used unchanged; playback loops and crossfades.", 12, MUTED)
			_separator(box)
			_center_label(box, "KayKit Dungeon Pack 1.1: Kay Lousberg\nwww.kaylousberg.com\nUltimate Modular Ruins: Quaternius / quaternius.com\nParticle Pack: Kenney / kenney.nl", 15, INK)
			_center_label(box, "RPG UI Pack and Fantasy UI Borders: Kenney / kenney.nl\nEnvironment, particles, and UI packs: CC0 1.0\nCinzel typeface: SIL Open Font License\nVoxel terrain, characters, spells, and synthesized effects: original project work", 12, MUTED)
			_button(box, "Back  [Esc]", game.close_credits)
		"grimoire":
			_build_grimoire(box)
		"dead":
			_center_label(box, "The light fades", 40, Color("d6aaaa"), true)
			_center_label(box, "Return to your sanctuary and continue the journey.", 17, INK)
			_center_label(box, "Deepest dungeon: %s  /  World seed: %s" % [game.best_depth, game.run_seed], 13, MUTED)
			_separator(box)
			_button(box, "Return to sanctuary  [R / Enter]", game.respawn)
			_button(box, "Load Game", game.open_save_menu.bind(true), Vector2(0, 36))
			_button(box, "Main Menu", game.return_to_menu, Vector2(0, 36))
			_button(box, "Save and Quit", game.quit_game, Vector2(0, 36))
	if game.state in ["menu", "load", "save"] and not game.menu_notice.is_empty():
		_center_label(box, game.menu_notice, 13, GOLD)

func _center_label(parent: Node, text: String, font_size: int, color: Color, serif: bool = false) -> Label:
	var label := _label(parent, text, font_size, color, serif)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _separator(parent: Node) -> void:
	var line := TextureRect.new()
	line.texture = load("res://assets/ui/fantasy/divider.png")
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.custom_minimum_size.y = 12
	line.modulate = GOLD
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _audio_slider(parent: Node, caption: String, value: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := _label(row, caption, 14, MUTED)
	label.custom_minimum_size.x = 80
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0
	slider.max_value = 1
	slider.step = .05
	slider.value = value
	slider.custom_minimum_size.y = 24
	slider.value_changed.connect(callback)
	row.add_child(slider)

func _build_grimoire(box: VBoxContainer) -> void:
	_center_label(box, "Grimoire of the " + game.CharacterBuild.CLASSES[game.build.class_id].name, 29, INK, true)
	_center_label(box, "%s skill %s / Earn one from each dungeon's final chest" % [game.build.skill_points, "point" if game.build.skill_points == 1 else "points"], 15, GOLD)
	var tabs := TabContainer.new()
	grimoire_tabs = tabs
	tabs.custom_minimum_size = Vector2(1040, 430)
	box.add_child(tabs)
	var skill_scroll := ScrollContainer.new()
	skill_scroll.name = "Skill tree"
	tabs.add_child(skill_scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	skill_scroll.add_child(grid)
	for skill in game.build.tree():
		var panel := _panel(grid, Vector2(334, 185), GOLD if game.build.ranks.get(skill.id, 0) > 0 else Color("36444f"))
		var column := _vbox(panel, 8)
		_label(column, skill.name, 18, INK, true)
		_label(column, "Rank %s / %s" % [game.build.ranks.get(skill.id, 0), skill.max], 12, GOLD)
		var description := _label(column, skill.description, 13, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = 275
		var parent_name := ""
		for other in game.build.tree():
			if other.id == skill.parent:
				parent_name = other.name
		_label(column, "Root skill" if parent_name.is_empty() else "Requires: " + parent_name, 12, GOLD)
		var button := _button(column, "Learn / 1 point", game.learn_skill.bind(skill.id), Vector2(0, 34))
		button.disabled = not game.build.can_learn(skill.id)
		if game.build.ranks.get(skill.id, 0) >= skill.max:
			button.text = "Mastered"
	var ability_scroll := ScrollContainer.new()
	ability_scroll.name = "Abilities and action bar"
	tabs.add_child(ability_scroll)
	var list := _vbox(ability_scroll, 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for spell in game.build.unlocked:
		var ability: Dictionary = game.ABILITIES[spell]
		var panel := _panel(list, Vector2(1010, 0), ability.color.darkened(.4))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		panel.add_child(row)
		var info := _vbox(row, 6)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(info, ability.name, 19, ability.color, true)
		_label(info, ability.description, 14, INK)
		_label(info, "%s %s / %.2fs recharge%s" % [int(ability.cost), game.CharacterBuild.CLASSES[game.build.class_id].resource.to_lower(), ability.recharge, " / Target range %.1f" % ability.range if ability.range > 0 else ""], 12, MUTED)
		var slots := OptionButton.new()
		slots.custom_minimum_size = Vector2(180, 40)
		slots.add_item("Unassigned")
		for index in range(10):
			slots.add_item("Slot %s" % ((index + 1) % 10))
		slots.select(game.ACTION_BAR.find(spell) + 1)
		slots.item_selected.connect(_assign_slot.bind(spell))
		row.add_child(slots)
	tabs.current_tab = grimoire_tab
	tabs.tab_changed.connect(func(index: int): grimoire_tab = index)
	_button(box, "Return  [G / Esc]", game.toggle_grimoire)

func _assign_slot(index: int, spell: String) -> void:
	if index > 0:
		game.equip_ability(spell, index - 1)
	else:
		var slot: int = game.ACTION_BAR.find(spell)
		if slot >= 0:
			game.equip_ability("", slot)
