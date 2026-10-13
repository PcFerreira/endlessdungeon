extends RefCounted

static var bars: Dictionary = {}

static func frame(name: String, tint: Color = Color.WHITE, margin: int = 12) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/rpg/%s.png" % name)
	style.modulate_color = tint
	style.texture_margin_left = 8
	style.texture_margin_right = 8
	style.texture_margin_top = 8
	style.texture_margin_bottom = 8
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

static func bar(color: String) -> StyleBoxTexture:
	if not bars.has(color):
		var strip := Image.create(36, 18, false, Image.FORMAT_RGBA8)
		var left_texture: Texture2D = load("res://assets/ui/rpg/bar%s_horizontalLeft.png" % color)
		var middle_texture: Texture2D = load("res://assets/ui/rpg/bar%s_horizontalMid.png" % color)
		var right_texture: Texture2D = load("res://assets/ui/rpg/bar%s_horizontalRight.png" % color)
		var left := left_texture.get_image()
		var middle := middle_texture.get_image()
		var right := right_texture.get_image()
		for part in [left, middle, right]:
			part.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(left, Rect2i(0, 0, 9, 18), Vector2i.ZERO)
		strip.blit_rect(middle, Rect2i(0, 0, 18, 18), Vector2i(9, 0))
		strip.blit_rect(right, Rect2i(0, 0, 9, 18), Vector2i(27, 0))
		bars[color] = ImageTexture.create_from_image(strip)
	var style := StyleBoxTexture.new()
	style.texture = bars[color]
	style.texture_margin_left = 9
	style.texture_margin_right = 9
	return style

static func ornament(parent: Control, color: Color) -> void:
	var border := StyleBoxTexture.new()
	border.texture = load("res://assets/ui/fantasy/frame.png")
	border.texture_margin_left = 24
	border.texture_margin_right = 24
	border.texture_margin_top = 24
	border.texture_margin_bottom = 24
	border.draw_center = false
	border.modulate_color = color
	parent.draw.connect(func(): parent.draw_style_box(border, Rect2(Vector2.ZERO, parent.size)))
