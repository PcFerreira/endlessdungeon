extends RefCounted

const Visual = preload("res://scripts/item_visual.gd")
static var symbols := {}
const SHAPES = {
	"book":"M9 14h19l4 5 4-5h19v38H36l-4 4-4-4H9z M32 19v34 M15 24h10 M15 31h10 M39 24h10 M39 31h10",
	"quest":"M18 10h29v44H18z M24 22h17 M24 29h17 M24 36h10 M29 43l4 4 8-8",
	"save":"M12 10h34l8 8v36H12z M21 10v16h22V10 M22 36h22v18H22z",
	"avatar":"M24 10h16v18H24z M18 35l14-5 14 5 6 19H12z",
	"palette":"M13 15h38v35H13z M21 22h7v7h-7z M36 22h7v7h-7z M21 36h7v7h-7z M36 36h7v7h-7z",
	"travel":"M13 12l13 5 13-5 12 5v35l-12-5-13 5-13-5z M26 17v35 M39 12v35",
	"settings":"M12 18h40 M12 32h40 M12 46h40 M23 13v10 M41 27v10 M28 41v10",
	"pouch":"M25 10h14l-3 10 12 14v16l-16 7-16-7V34l12-14z M25 21h14 M27 36h10 M32 31v16",
	"resume":"M22 12l28 20-28 20z",
	"home":"M10 30l22-20 22 20 M17 25v29h30V25 M27 54V36h10v18",
	"slot":"M14 14h36v36H14z M25 32h14",
	"skill":"M32 9l5 16 17 7-17 7-5 16-5-16-17-7 17-7z",
	"exit":"M14 12h24v42H14z M28 32h27 M45 22l10 10-10 10"
}

static func symbol(kind: String = "pouch") -> Texture2D:
	if not symbols.has(kind):
		var image := Image.new()
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="%s" fill="none" stroke="#d4c299" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>' % SHAPES.get(kind,SHAPES.pouch)
		var load_error := image.load_svg_from_string(svg)
		if load_error != OK:
			push_error("Cannot load menu symbol %s: %s" % [kind, load_error])
			return null
		symbols[kind] = ImageTexture.create_from_image(image)
	return symbols[kind]

static func grid(parent: Node, columns: int = 6) -> GridContainer:
	var result := GridContainer.new()
	result.columns = columns
	result.add_theme_constant_override("h_separation",8)
	result.add_theme_constant_override("v_separation",8)
	parent.add_child(result)
	return result

static func page(values: Array, index: int, capacity: int = 24) -> Array:
	var start := clampi(index,0,maxi(0,ceili(values.size() / float(capacity)) - 1)) * capacity
	return values.slice(start,mini(values.size(),start + capacity))

static func tile(ui, parent: Node, caption: String, texture: Texture2D, callback: Callable, minimum: Vector2 = Vector2(96,100), badge: String = "") -> Button:
	var button: Button = ui._button(parent,"",callback,minimum)
	button.set_meta("icon_tile",true)
	button.tooltip_text = caption
	button.add_theme_stylebox_override("pressed",ui.HudSkin.surface(ui.GOLD,8,Color("172532")))
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	icon.offset_left = 12
	icon.offset_top = 8
	icon.offset_right = -12
	icon.offset_bottom = minf(54,minimum.y - 40)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 2
	label.add_theme_font_size_override("font_size",12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 5
	label.offset_right = -5
	label.offset_top = -38
	label.offset_bottom = -5
	if not badge.is_empty():
		var count := Label.new()
		count.text = badge
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size",12)
		count.add_theme_color_override("font_color",ui.GOLD)
		button.add_child(count)
		count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		count.offset_left = -32
		count.offset_right = -5
		count.offset_top = 4
		count.offset_bottom = 22
	return button

static func item(ui, parent: Node, id: String, callback: Callable, quantity: int = -1, selected: bool = false) -> Button:
	var entry: Dictionary = ui.game.inventory.ITEMS[id]
	var button := tile(ui,parent,entry.name,ui.game.inventory.Catalog.icon(entry),callback,Vector2(80,88),str(quantity) if quantity >= 0 else "")
	button.set_meta("item_id",id)
	button.tooltip_text = entry.name + "\n" + entry.get("description","")
	button.toggle_mode = true
	button.button_pressed = selected
	if selected:
		var restore_focus := func():
			if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree() and button.focus_mode != Control.FOCUS_NONE and not button.disabled:
				button.grab_focus()
		restore_focus.call_deferred()
	if entry.has("asset_id") or entry.has("scenery_key"):
		button.get_child(0).hide()
		var thumbnail := Visual.preview(entry,Vector2(52,44))
		thumbnail.position = Vector2(14,6)
		button.add_child(thumbnail)
	return button

static func inferred_icon(caption: String, callback: Callable) -> Texture2D:
	var text := (caption + " " + callback.get_method()).to_lower()
	if "continue" in text or "resume" in text:
		return symbol("resume")
	if "quit" in text or "leave" in text:
		return symbol("exit")
	if "sanctuary" in text or "main menu" in text:
		return symbol("home")
	if "grimoire" in text or "credits" in text:
		return symbol("book")
	if "load" in text:
		return symbol("save")
	for key in ["book","quest","save","avatar","palette","travel","settings"]:
		if key in text:
			return symbol(key)
	if "journal" in text or "history" in text or "read" in text:
		return symbol("book")
	if "character" in text or "appearance" in text or "class" in text:
		return symbol("avatar")
	if "options" in text:
		return symbol("settings")
	if "world" in text or "journey" in text or "map" in text or "atlas" in text:
		return symbol("travel")
	return symbol()
