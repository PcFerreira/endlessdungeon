extends RefCounted

const INK := Color("eee9dc")
const MUTED := Color("b0b9c4")
const GOLD := Color("cbb78b")
const EDGE := Color("655d4c")

static func surface(accent: Color = EDGE, margin: int = 12, background: Color = Color("141d28f2")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0, 0, 0, .28)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style

static func button(control: Button, accent: Color = EDGE) -> void:
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_color_override("font_pressed_color", GOLD)
	control.add_theme_color_override("font_disabled_color", MUTED.darkened(.35))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var background := Color("202c39")
		var border := accent
		if state == "hover":
			background = Color("34414d")
			border = GOLD
		elif state == "pressed":
			background = Color("111922")
		elif state == "disabled":
			background = Color("151d27")
			border = Color("36404b")
		elif state == "focus":
			background = Color.TRANSPARENT
			border = GOLD
		var style := surface(border, 8, background)
		style.shadow_size = 0
		control.add_theme_stylebox_override(state, style)

static func meter(control: ProgressBar, color: Color) -> void:
	control.show_percentage = false
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := surface(Color("36404b"), 0, Color("0c131b"))
	background.shadow_size = 0
	background.set_corner_radius_all(3)
	var fill := surface(color.lightened(.12), 0, color)
	fill.shadow_size = 0
	fill.set_corner_radius_all(3)
	control.add_theme_stylebox_override("background", background)
	control.add_theme_stylebox_override("fill", fill)

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	for type in ["Label", "TooltipLabel", "OptionButton", "LineEdit", "CheckBox", "PopupMenu", "TabContainer"]:
		result.set_color("font_color", type, INK)
		result.set_color("font_hover_color", type, Color.WHITE)
		result.set_color("font_disabled_color", type, MUTED.darkened(.35))
	result.set_stylebox("panel", "TooltipPanel", surface(GOLD.darkened(.35), 12, Color("101822")))
	result.set_font_size("font_size", "TooltipLabel", 14)
	result.set_stylebox("normal", "LineEdit", surface(EDGE, 10))
	result.set_stylebox("focus", "LineEdit", surface(GOLD, 10, Color.TRANSPARENT))
	result.set_color("caret_color", "LineEdit", GOLD)
	result.set_color("selection_color", "LineEdit", Color("496475"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		result.set_stylebox(state, "OptionButton", surface(GOLD if state in ["hover", "focus"] else EDGE, 10, Color("25313e") if state == "hover" else Color("18222e")))
	result.set_stylebox("panel", "PopupMenu", surface(EDGE, 8, Color("18222e")))
	result.set_stylebox("hover", "PopupMenu", surface(GOLD.darkened(.35), 8, Color("34414d")))
	result.set_stylebox("panel", "TabContainer", surface(EDGE, 12))
	result.set_stylebox("tab_selected", "TabContainer", surface(GOLD.darkened(.3), 10, Color("293644")))
	result.set_stylebox("tab_unselected", "TabContainer", surface(EDGE, 10, Color("18222e")))
	result.set_stylebox("tab_hovered", "TabContainer", surface(GOLD, 10, Color("34414d")))
	result.set_color("font_selected_color", "TabContainer", INK)
	result.set_color("font_unselected_color", "TabContainer", MUTED)
	return result
