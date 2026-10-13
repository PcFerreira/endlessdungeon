extends CanvasLayer

const Minimap = preload("res://scripts/minimap.gd")
const AimCursor = preload("res://scripts/aim_cursor.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const HudSkin = preload("res://scripts/hud_skin.gd")
const CharacterMenu = preload("res://scripts/character_menu.gd")
const InventoryMenu = preload("res://scripts/inventory_menu.gd")
const INK := HudSkin.INK
const MUTED := HudSkin.MUTED
const GOLD := HudSkin.GOLD
const TEAL := Color("7bded0")
var game
var root := Control.new()
var overlay := Control.new()
var depth_label: Label
var theme_label: Label
var objective_label: Label
var map_title: Label
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
var inventory_selected := "sanctum_sigil"
var inventory_filter := 0
var profile_name: Label
var action_dock: PanelContainer
var location_panel: PanelContainer
var map_panel: PanelContainer
var map_button: Button
var message_panel: PanelContainer
var interaction_panel: PanelContainer
var interaction_key: Label
var spell_icons: Dictionary = {}
var spell_shades: Dictionary = {}
var spell_warnings: Dictionary = {}
var utility_buttons: Array[Button] = []

func _ready() -> void:
	if ResourceLoader.exists("res://assets/fonts/Cinzel.ttf"):
		title_font = load("res://assets/fonts/Cinzel.ttf")
	else:
		title_font = ThemeDB.fallback_font
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = HudSkin.theme()
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
	var style := HudSkin.surface(GOLD.darkened(.45) if accent == Color("766950") else Color("48596a"), 18)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
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
	if text.ends_with("]") and text.contains(" ["):
		var caption := text.split(" [", false, 1)
		button.text = caption[0].strip_edges()
		button.tooltip_text = "Shortcut: " + caption[1].trim_suffix("]")
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.custom_minimum_size = minimum
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	HudSkin.button(button)
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _hud_panel(parent: Node, minimum: Vector2 = Vector2.ZERO, margin: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", HudSkin.surface(HudSkin.EDGE, margin))
	parent.add_child(panel)
	return panel

func _hud_button(parent: Node, text: String, tooltip: String, callback: Callable, minimum: Vector2 = Vector2(0, 30)) -> Button:
	var button := _button(parent, text, callback, minimum)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.tooltip_text = tooltip
	return button

func _meter(parent: Node, color: Color, minimum: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = minimum
	HudSkin.meter(bar, color)
	parent.add_child(bar)
	return bar

func _build_hud() -> void:
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_panel = _hud_panel(hud, Vector2(400, 0))
	location_panel.position = Vector2(24, 24)
	var chapter := _vbox(location_panel, 5)
	theme_label = _label(chapter, "", 20, INK, true)
	theme_label.custom_minimum_size.x = 374
	theme_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label = _label(chapter, "", 13, GOLD)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_panel = _hud_panel(hud, Vector2(192, 0), 10)
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_panel.offset_left = -216
	map_panel.offset_right = -24
	map_panel.offset_top = 24
	var map_column := _vbox(map_panel, 7)
	map_title = _label(map_column, "LOCAL MAP", 11, GOLD, true)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_button = _hud_button(map_column, "", "Local map\nClick to open the atlas.\nTab: atlas", game.toggle_map, Vector2(172, 156))
	map_button.clip_contents = true
	var map := Minimap.new()
	map.game = game
	map_button.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.offset_left = 5
	map.offset_top = 5
	map.offset_right = -5
	map.offset_bottom = -5
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_panel = _hud_panel(hud, Vector2(280, 0), 10)
	target_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	target_panel.offset_left = -140
	target_panel.offset_right = 140
	target_panel.offset_top = 24
	var target_column := _vbox(target_panel, 5)
	target_name = _label(target_column, "", 16, INK, true)
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_bar = _meter(target_column, Color("a84d53"), Vector2(260, 12))
	target_status = _label(target_column, "", 12, MUTED)
	target_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_dock = _hud_panel(hud, Vector2(866, 0), 12)
	action_dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_dock.offset_left = -433
	action_dock.offset_right = 433
	action_dock.offset_top = -125
	action_dock.offset_bottom = -16
	var dock_column := _vbox(action_dock, 8)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	dock_column.add_child(actions)
	var vitals := _vbox(actions, 4)
	vitals.custom_minimum_size.x = 188
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 7)
	vitals.add_child(identity)
	class_icon = TextureRect.new()
	class_icon.custom_minimum_size = Vector2(21, 21)
	class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(class_icon)
	profile_name = _label(identity, "Wanderer", 14, INK, true)
	profile_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	profile_name.custom_minimum_size.x = 145
	depth_label = _label(vitals, "", 11, GOLD)
	depth_label.visible = false
	hp_bar = _meter(vitals, Color("af5159"), Vector2(188, 16))
	vitality_label = _label(hp_bar, "", 12, INK)
	vitality_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vitality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vitality_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_bar = _meter(vitals, Color("497fa5"), Vector2(188, 13))
	aether_label = _label(mana_bar, "", 11, INK)
	aether_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aether_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aether_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hotbar = HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 4)
	actions.add_child(hotbar)
	_build_action_bar()
	sanctum_button = _hud_button(actions, "", "Sanctum Sigil\nH: visit your sanctum", game.use_sanctum_sigil, Vector2(52, 60))
	sanctum_button.icon = load("res://assets/sanctum_sigil.svg")
	sanctum_button.expand_icon = true
	sanctum_button.add_theme_constant_override("icon_max_width", 32)
	var sigil_key := _label(sanctum_button, "H", 10, GOLD)
	sigil_key.position = Vector2(6, 4)
	var utility_row := HBoxContainer.new()
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_row.add_theme_constant_override("separation", 6)
	dock_column.add_child(utility_row)
	utility_buttons.append(_hud_button(utility_row, "Character", "Character appearance\nC: customize", game.open_character_menu))
	utility_buttons.append(_hud_button(utility_row, "Backpack", "Items and equipment\nI: backpack", game.toggle_inventory))
	utility_buttons.append(_hud_button(utility_row, "Grimoire", "Skills and action-bar loadout\nG: grimoire", game.toggle_grimoire))
	utility_buttons.append(_hud_button(utility_row, "Journal", "Read your field notes\nJ: journal", game.expansion.toggle_journal))
	utility_buttons.append(_hud_button(utility_row, "Atlas", "Chart a route through the lands\nTab: atlas", game.toggle_map))
	utility_buttons.append(_hud_button(utility_row, "Menu", "Pause, save and options\nEsc: pause", game.toggle_pause))
	utility_buttons.append(_hud_button(utility_row, "Objects", "Take nearby objects with T\nV: place items and manage your base", game.world_items.open_placement))
	interaction_panel = _hud_panel(hud, Vector2(0, 38), 8)
	var interaction_row := HBoxContainer.new()
	interaction_row.add_theme_constant_override("separation", 10)
	interaction_panel.add_child(interaction_row)
	interaction_key = _label(interaction_row, "E", 14, GOLD)
	hint = _label(interaction_row, "", 14, INK)
	hint.custom_minimum_size.x = 300
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_panel = _hud_panel(hud, Vector2(0, 34), 8)
	message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message = _label(message_panel, "", 14, INK)
	message.custom_minimum_size.x = 380
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_action_bar() -> void:
	for child in hotbar.get_children():
		hotbar.remove_child(child)
		child.queue_free()
	spell_status.clear()
	spell_buttons.clear()
	spell_recharge.clear()
	spell_icons.clear()
	spell_shades.clear()
	spell_warnings.clear()
	previous_bar = game.ACTION_BAR.duplicate()
	for index in range(game.ACTION_BAR.size()):
		var spell: String = game.ACTION_BAR[index]
		var button := _hud_button(hotbar, "", "Empty slot\nAssign an ability in the grimoire (G).", game.cast_slot.bind(index), Vector2(52, 60))
		button.disabled = spell.is_empty()
		if spell.is_empty():
			continue
		var color: Color = game.ABILITIES[spell].color
		HudSkin.button(button, color.darkened(.55))
		var icon := TextureRect.new()
		icon.texture = load("res://assets/spells/%s.svg" % spell)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 9
		icon.offset_top = 12
		icon.offset_right = -9
		icon.offset_bottom = -9
		spell_icons[spell] = icon
		var shade := ColorRect.new()
		shade.color = Color(0.025, .04, .06, .78)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.offset_left = 2
		shade.offset_top = 2
		shade.offset_right = -2
		shade.offset_bottom = -2
		spell_shades[spell] = shade
		var key_label := _label(button, str((index + 1) % 10), 10, GOLD)
		key_label.position = Vector2(6, 3)
		var counter := _label(button, "", 22, INK)
		counter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		counter.add_theme_color_override("font_shadow_color", Color("0b1017"))
		counter.add_theme_constant_override("shadow_outline_size", 2)
		spell_status[spell] = counter
		spell_buttons[spell] = button
		button.set_meta("ability_tooltip", "%s [%s]\n%s\n%s %s / %.2fs recharge" % [game.ABILITIES[spell].name, (index + 1) % 10, game.ABILITIES[spell].description, int(game.ABILITIES[spell].cost), game.CharacterBuild.CLASSES[game.build.class_id].resource, game.ABILITIES[spell].recharge])
		var warning := _label(button, "!", 12, Color("efbe83"))
		warning.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		warning.offset_left = -12
		warning.offset_right = -4
		warning.offset_top = -21
		spell_warnings[spell] = warning
		var recharge := _meter(button, color, Vector2(0, 3))
		recharge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		recharge.offset_left = 4
		recharge.offset_right = -4
		recharge.offset_top = -5
		recharge.offset_bottom = -2
		recharge.max_value = 1.0
		spell_recharge[spell] = recharge

func _process(_delta: float) -> void:
	if game == null:
		return
	if previous_bar != game.ACTION_BAR or previous_class != game.build.class_id:
		previous_class = game.build.class_id
		_build_action_bar()
		class_icon.texture = load("res://assets/spells/%s.svg" % {"mage": "bolt", "sword": "strike", "spellsword": "runeblade"}[previous_class])
		HudSkin.meter(mana_bar, Color("6b9366") if previous_class == "sword" else Color("497fa5"))
	hud.visible = game.has_journey and game.state == "playing"
	depth_label.text = game.CharacterBuild.CLASSES[game.build.class_id].name
	profile_name.text = game.profile.display_name
	profile_name.tooltip_text = "%s\n%s\nC: character appearance" % [game.profile.display_name, depth_label.text]
	theme_label.text = game.location_name().replace(" / ", "\n")
	if game.layer == "overworld":
		map_title.text = "THE WANDERING LANDS"
		map_panel.tooltip_text = "Gold squares: cities\nViolet diamonds: destinations\nOutlined: reported\nFilled: seen; marked center: visited\nWhite dot: you"
		if game.online.session:
			map_panel.tooltip_text = "Nearby downloaded terrain and places\nGold squares: cities\nViolet diamonds: destinations\nWhite dot: you"
		objective_label.text = "Explore the lands"
		if game.online.session:
			objective_label.text = "Public world / %s nearby players" % game.online.players.size()
		if game.floating_hub.active():
			map_title.text = "LANTERNWAKE"
			objective_label.text = "Guilds, markets and companions"
			map_panel.tooltip_text = "Floating districts and sky bridges\nGold: arrival commons\nWhite: you"
		if not game.waypoint.is_empty():
			objective_label.text = "%s  /  %.0f away" % [game.waypoint.name, game.player_point.distance_to(game.waypoint.cell)]
	elif game.layer == "sanctum":
		map_title.text = "INNER SANCTUM"
		map_panel.tooltip_text = "Violet: hearth\nTeal: return portal\nFurnish any clear island floor"
		objective_label.text = "A quiet place between journeys"
	elif game.layer == "interior":
		map_title.text = "ROOM CHART"
		map_panel.tooltip_text = "Gold: exit\nWhite: you"
		objective_label.text = "A place to pause along the road"
	else:
		map_title.text = "FLOOR %s OF %s" % [game.depth, game.active_dungeon.floors]
		map_panel.tooltip_text = "Rose dots: wardens\nGold outline: stairs\nTeal outline: open descent gate"
		var goal: String = "%s wardens remain" % game.enemies.size() if not game.enemies.is_empty() else ("Final chest claimed" if game.claimed_chests.has(game.active_dungeon.id) else ("Claim the final chest" if game.depth == game.active_dungeon.floors else "Find the descent gate"))
		objective_label.text = "Floor %s of %s  /  %s" % [game.depth, game.active_dungeon.floors, goal]
	map_button.disabled = game.layer != "overworld"
	map_button.tooltip_text = map_panel.tooltip_text + ("\nClick to open the atlas (Tab)." if game.layer == "overworld" else "\nThe atlas charts the surface.")
	utility_buttons[4].disabled = game.layer != "overworld"
	for index in [0, 1, 2, 3, 6]:
		utility_buttons[index].disabled = game.online.session
	utility_buttons[4].tooltip_text = "Chart a route through the lands\nTab: atlas" if game.layer == "overworld" else "The atlas charts the surface."
	if game.online.session:
		utility_buttons[4].tooltip_text = "Nearby downloaded places\nTab: atlas"
	vitality_label.text = "%s / %s" % [ceili(game.hp), int(game.max_hp)]
	aether_label.text = "%s / %s" % [int(game.mana), int(game.max_mana)]
	hp_bar.max_value = game.max_hp
	hp_bar.value = game.hp
	mana_bar.max_value = game.max_mana
	mana_bar.value = game.mana
	action_dock.tooltip_text = "%s\nHealth: %s\n%s: %s" % [depth_label.text, vitality_label.text, game.CharacterBuild.CLASSES[game.build.class_id].resource, aether_label.text]
	var sigil_problem: String = game.sanctum_problem()
	sanctum_button.disabled = game.state != "playing" or game.online.session
	sanctum_button.tooltip_text = "Sanctum Sigil [H]\nRest at your hearth, then return to the place you left.\n" + (sigil_problem if not sigil_problem.is_empty() else ("Return to your journey." if game.layer == "sanctum" else "Ready to open your sanctum."))
	sanctum_button.modulate = Color("a3b7cb") if not sigil_problem.is_empty() else Color.WHITE
	target_panel.visible = game.valid_enemy(game.selected_target)
	if target_panel.visible:
		var target: Dictionary = game.selected_target
		target_name.text = game.ENEMY_NAMES[target.kind]
		target_bar.max_value = target.max_hp
		target_bar.value = target.hp
		var problem: String = game.target_problem()
		target_status.text = "%s / %s" % [ceili(target.hp), int(target.max_hp)] if problem.is_empty() else problem
		target_status.modulate = Color.WHITE if problem.is_empty() else Color("eca49d")
		target_panel.tooltip_text = "%s\nDistance: %.1f\n%s" % [target_name.text, game.player_point.distance_to(target.point), "In sight" if problem.is_empty() else problem]
	message.text = game.notification if game.notification_time > 0 and game.state == "playing" else ""
	message_panel.visible = not message.text.is_empty()
	var action_hint: String = game.interaction_hint() if game.state == "playing" else ""
	interaction_key.text = "E" if action_hint.begins_with("E: ") else ("B" if action_hint.begins_with("B: ") else ("F" if action_hint == "Chest claimed. F: Return to the world" else ""))
	hint.text = action_hint.trim_prefix("E: ").trim_prefix("B: ").replace("Chest claimed. F: ", "")
	interaction_key.visible = not interaction_key.text.is_empty()
	interaction_panel.visible = not action_hint.is_empty()
	_layout_hud()
	for spell in spell_status:
		var cooldown: float = game.cooldowns[spell]
		var problem: String = game.target_problem(game.ABILITIES[spell].range) if game.ABILITIES[spell].range > 0 else ""
		var lacks_resource: bool = game.mana < game.ABILITIES[spell].cost
		var blocked := not problem.is_empty()
		spell_status[spell].text = str(ceili(cooldown)) if cooldown >= 1 else ("%.1f" % cooldown if cooldown > 0 else "")
		spell_shades[spell].visible = cooldown > 0
		spell_shades[spell].anchor_bottom = clampf(cooldown / game.ABILITIES[spell].recharge, 0, 1)
		spell_icons[spell].modulate = Color("929da9") if blocked or lacks_resource else Color.WHITE
		spell_warnings[spell].visible = cooldown <= 0 and (lacks_resource or (blocked and game.valid_enemy(game.selected_target)))
		spell_recharge[spell].visible = cooldown > 0
		spell_recharge[spell].value = 1 - cooldown / game.ABILITIES[spell].recharge
		spell_buttons[spell].disabled = game.state != "playing" or game.online.session
		var status := "Ready"
		if cooldown > 0:
			status = "Recharging: %.1fs" % cooldown
		elif lacks_resource:
			status = "Not enough " + game.CharacterBuild.CLASSES[game.build.class_id].resource.to_lower()
		elif blocked:
			status = problem
		spell_buttons[spell].tooltip_text = spell_buttons[spell].get_meta("ability_tooltip") + "\n" + status
	if previous_state != game.state:
		previous_state = game.state
		_rebuild_overlay()

func _layout_hud() -> void:
	var width := hud.size.x
	action_dock.position.x = (width - action_dock.size.x) * .5
	action_dock.position.y = hud.size.y - action_dock.size.y - 16
	map_panel.position.x = width - map_panel.size.x - 24
	interaction_panel.position = Vector2((width - interaction_panel.size.x) * .5, action_dock.position.y - interaction_panel.size.y - 14)
	var toast_y := interaction_panel.position.y - message_panel.size.y - 10 if interaction_panel.visible else action_dock.position.y - message_panel.size.y - 14
	message_panel.position = Vector2((width - message_panel.size.x) * .5, toast_y)

func _rebuild_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	if game.state in ["playing", "online_lobby", "dialogue", "reader", "journal", "discovery_reader", "quest_reader", "furnishing", "guard_demand", "world_items", "store", "hub_board", "hub_travel_loading"]:
		return
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, .065, .79)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var width := 1100 if game.state == "grimoire" else (960 if game.state == "inventory" else (820 if game.state == "character" else (760 if game.state in ["map", "credits"] else 650)))
	var panel := _panel(center, Vector2(width, 0), Color("766950"))
	var box := _vbox(panel, 16)
	match game.state:
		"menu":
			_center_label(box, "The Wandering\nLands", 44, INK, true)
			_center_label(box, "Steel and spells. A world beyond the gate.", 17, MUTED)
			if not game.menu_notice.is_empty():
				_center_label(box, game.menu_notice, 15, GOLD)
			_separator(box)
			_button(box, "Online world", game.online.open_lobby)
			if not OS.has_feature("web"):
				var resume := _button(box, "Continue", game.continue_journey)
				resume.disabled = not game.has_journey and game.saves.latest_slot() < 0
				_button(box, "New Game", game.new_character)
				_button(box, "Load Game", game.open_save_menu.bind(true))
			_button(box, "Options", game.open_options)
			_button(box, "Credits", game.show_credits, Vector2(0, 36))
			_button(box, "Quit", game.quit_game, Vector2(0, 36))
		"title":
			_center_label(box, "The Wandering\nLands", 44, INK, true)
			_center_label(box, "Steel and spells. A world beyond the gate.", 17, MUTED)
			_separator(box)
			_center_label(box, "Explore biomes. Rest in cities. Discover old dungeons.\nThe lands unfold as you travel.", 16, INK)
			var classes := HBoxContainer.new()
			classes.add_theme_constant_override("separation", 8)
			box.add_child(classes)
			for id in game.CharacterBuild.CLASSES:
				var data: Dictionary = game.CharacterBuild.CLASSES[id]
				var button := _button(classes, data.name, game.choose_class.bind(id), Vector2(190, 40))
				button.tooltip_text = data.description
			_center_label(box, "Selected: " + game.CharacterBuild.CLASSES[game.build.class_id].name, 15, GOLD)
			_center_label(box, game.CharacterBuild.CLASSES[game.build.class_id].description, 13, MUTED)
			_button(box, "Customize your character  [C]", game.open_character_menu, Vector2(0, 36))
			_button(box, "Begin your journey  [Enter]", game.begin_journey)
			_button(box, "Online world", game.online.open_lobby)
			_button(box, "Back to main menu  [Esc]", func(): game.state = "menu", Vector2(0, 36))
		"map":
			_center_label(box, "Nearby lands" if game.online.session else "Atlas of the wandering lands", 25, INK, true)
			_center_label(box, "Downloaded places around you" if game.online.session else "Outlined: reported   /   Filled: seen   /   Marked center: visited", 13, GOLD)
			var atlas := Minimap.new()
			atlas.game = game
			atlas.world_map_mode = true
			atlas.custom_minimum_size = Vector2(700, 440)
			atlas.mouse_filter = Control.MOUSE_FILTER_STOP
			box.add_child(atlas)
			_center_label(box, "Nearby downloaded places are marked. Click a place to set your route." if game.online.session else "Only reported or discovered places are marked. Click a known place to set your route.", 12, MUTED)
			_button(box, "Return to the journey  [Tab / Esc]", game.toggle_map)
		"paused":
			if game.online.session:
				_center_label(box, "The public world", 30, INK, true)
				_center_label(box, "The world continues while you rest here.\nCombat, trade and building are forthcoming.", 16, MUTED)
				_button(box, "Continue  [Esc]", game.toggle_pause)
				_button(box, "Options", game.open_options, Vector2(0, 36))
				_button(box, "Leave the public world", game.online.disconnect_world)
				return
			_center_label(box, "A moment of stillness", 30, INK, true)
			_center_label(box, game.location_name(), 16, MUTED)
			_button(box, "Continue  [Esc]", game.toggle_pause)
			var saves := HBoxContainer.new()
			saves.add_theme_constant_override("separation", 12)
			box.add_child(saves)
			_button(saves, "Save Game  [F5]", game.open_save_menu.bind(false), Vector2(296, 40))
			_button(saves, "Load Game  [F9]", game.open_save_menu.bind(true), Vector2(296, 40))
			_button(box, "Grimoire  [G]", game.toggle_grimoire, Vector2(0, 36))
			_button(box, "Field journal  [J]", game.expansion.toggle_journal, Vector2(0,36))
			var character_actions := HBoxContainer.new()
			character_actions.add_theme_constant_override("separation", 12)
			box.add_child(character_actions)
			_button(character_actions, "Backpack [I]", game.toggle_inventory, Vector2(296, 36))
			_button(character_actions, "Appearance [C]", game.open_character_menu, Vector2(296, 36))
			_button(box, "Options", game.open_options, Vector2(0, 36))
			if game.layer in ["dungeon", "interior"]:
				_button(box, "Return to the surface", game.return_to_surface, Vector2(0, 36))
			if game.layer == "sanctum":
				_button(box, "Return to your journey  [H]", func(): game.state = "playing"; game.leave_sanctum(), Vector2(0, 36))
			_button(box, "Return to sanctuary / Unstuck", game.return_to_sanctuary, Vector2(0, 36))
			if game.world.has_method("spawn_point") and game.layer == "overworld":
				_button(box, "Return to Lanternwake", game.floating_hub.recall, Vector2(0, 36))
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
			_audio_slider(box, "Ambience", game.sound.ambience_level, game.sound.set_ambience_level)
			_button(box, "Unmute sound" if game.sound.muted else "Mute sound", func(): game.sound.toggle_mute(); game.interface.previous_state = "", Vector2(0, 36))
			var resolution_row := HBoxContainer.new()
			resolution_row.add_theme_constant_override("separation", 16)
			box.add_child(resolution_row)
			_label(resolution_row, "Window resolution", 14, MUTED)
			var resolution := OptionButton.new()
			resolution.name = "Resolution"
			resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			resolution.custom_minimum_size.y = 32
			var choices: Array[Vector2i] = game.resolution_choices()
			for size in choices:
				var index := resolution.item_count
				resolution.add_item("%s x %s" % [size.x,size.y])
				resolution.set_item_disabled(index, not game.resolution_fits(size))
				if size == game.windowed_resolution:
					resolution.select(index)
			resolution.disabled = game.is_fullscreen()
			resolution.tooltip_text = "Choose a window size. Unavailable sizes exceed the current display."
			resolution.item_selected.connect(func(index): game.set_resolution(choices[index]))
			resolution_row.add_child(resolution)
			var fullscreen := CheckBox.new()
			fullscreen.name = "Fullscreen"
			fullscreen.text = "Fullscreen"
			fullscreen.tooltip_text = "F11: toggle fullscreen"
			fullscreen.button_pressed = game.is_fullscreen()
			fullscreen.toggled.connect(game.set_fullscreen)
			box.add_child(fullscreen)
			_center_label(box, "Fullscreen uses your display's resolution.", 12, MUTED)
			_separator(box)
			_center_label(box, "WASD / arrows: Move   Space: Jump\nClick: Target   1-0: Abilities   G: Grimoire\nRight mouse drag: Orbit   Wheel: Zoom\nE: Interact   Tab: Atlas   F: Surface   H: Sanctum\nI: Backpack   C: Appearance   J: Journal\nF5: Save slot 1   F9: Load latest   M: Sound\nEsc: Clear target / Pause / Back", 14, MUTED)
			_button(box, "Back  [Esc]", game.close_options, Vector2(0, 36))
		"save_failed":
			_center_label(box, "The journey could not be saved", 27, INK, true)
			_center_label(box, game.menu_notice, 15, MUTED)
			_button(box, "Return to the game", func(): game.state = "paused")
			_button(box, "Continue without saving", game.finish_exit, Vector2(0, 36))
		"credits":
			_center_label(box, "The makers behind the lands", 28, INK, true)
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(0,530)
			box.add_child(scroll)
			var credits := VBoxContainer.new()
			credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			credits.add_theme_constant_override("separation",16)
			scroll.add_child(credits)
			_center_label(credits, "Music by Eric Matyas\nwww.soundimage.org", 20, GOLD)
			_center_label(credits, "Fantascape  /  Netherplace  /  Lost Jungle\nFantasy Game Background  /  Our Mountain\nCity Beneath the Waves v001  /  Misty Bog\nSpells a-Brewin  /  Strange Phenomenon", 15, INK)
			_center_label(credits, "Music: Soundimage International Public License\nsoundimage.org/sample-page/\nSource recordings used unchanged; playback loops and crossfades.", 12, MUTED)
			_center_label(credits, "Fantasy Song Pack Volume 1 by troubadour (CC0)\nopengameart.org/content/fantasy-song-pack-volume-1", 13, GOLD)
			_center_label(credits, "Forest, mountain, river and wildlife ambience: Blender Foundation; submitted by Lamoot\nCC-BY-3.0 / creativecommons.org/licenses/by/3.0/\nopengameart.org/content/ambient-bird-cricket-and-frog\nopengameart.org/content/ambient-mountain-river-wind-and-forest-and-waterfall\nWind: Luke.RUSTLTD / Rain: Ylmir / Dungeon ambience: JaggedStone\nRPG, impact and interface sounds: Kenney (CC0)", 12, MUTED)
			_separator(credits)
			_center_label(credits, "KayKit Dungeon, Furniture, Medieval Hexagon and Halloween: Kay Lousberg\nwww.kaylousberg.com\nRuins, Monsters, Cube World, Village and Fantasy Props: Quaternius\nquaternius.com\nNature, Town, Survival, Food, Castle, Holiday and Graveyard: Kenney\nkenney.nl", 13, INK)
			_center_label(credits, "Modular Temple: Keith at Fertile Soil Productions (CC0)\nfertile-soil-productions.itch.io/temple-modular-collection\nArcane Magic Effect: Cethiel (CC0)\nParticle Pack: Kenney and credited filter contributors (CC0)\nVoxel Micro Farm: Dopamine King\nDopamine King Free Commercial Asset License 1.0", 12, MUTED)
			_center_label(credits, "RPG UI Pack and Fantasy UI Borders: Kenney (CC0)\nCinzel typeface: SIL Open Font License\nOriginal terrain, spells, scene recipes, custom appearances and lore: project work", 12, MUTED)
			_button(box, "Back  [Esc]", game.close_credits)
		"grimoire":
			_build_grimoire(box)
		"character":
			CharacterMenu.build(self, box)
		"inventory":
			InventoryMenu.build(self, box)
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
