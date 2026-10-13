extends CanvasLayer

const HudSkin = preload("res://scripts/hud_skin.gd")
var client
var root := Control.new()
var status_label: Label
var address: LineEdit
var username: LineEdit
var password: LineEdit
var classes: OptionButton

func _ready() -> void:
	layer = 12
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = HudSkin.theme()
	add_child(root)
	root.hide()

func show_form() -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(.025, .04, .065, .94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "The public world"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(550, 60)
	box.add_child(status_label)
	address = field(box, "World address", client.endpoint)
	username = field(box, "Account name", "")
	username.max_length = 24
	password = field(box, "Password (12–128 characters)", "")
	password.secret = true
	password.max_length = 128
	classes = OptionButton.new()
	for id in client.game.CharacterBuild.CLASSES:
		classes.add_item(client.game.CharacterBuild.CLASSES[id].name)
		classes.set_item_metadata(classes.item_count - 1, id)
	classes.tooltip_text = "Starting class for a new account"
	box.add_child(classes)
	classes.hide()
	var choices: GridContainer = client.game.interface.IconGrid.grid(box,3)
	var group := ButtonGroup.new()
	var index := 0
	for id in client.game.CharacterBuild.CLASSES:
		var data: Dictionary = client.game.CharacterBuild.CLASSES[id]
		var choice: Button = client.game.interface.IconGrid.tile(client.game.interface,choices,data.name,load("res://assets/spells/%s.svg" % data.starter[0]),classes.select.bind(index),Vector2(170,100))
		choice.toggle_mode = true
		choice.button_group = group
		choice.button_pressed = index == classes.selected
		index += 1
	var actions := HBoxContainer.new()
	box.add_child(actions)
	button(actions, "Sign in", submit.bind("login"))
	button(actions, "Create account", submit.bind("register"))
	button(box, "Resume remembered account", submit.bind("resume"))
	button(box, "Back to main menu", client.disconnect_world.bind(""))
	root.show()
	update_status()
	username.grab_focus()

func field(box: Node, caption: String, value: String) -> LineEdit:
	var label := Label.new()
	label.text = caption
	box.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.custom_minimum_size.y = 40
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(edit)
	return edit

func button(parent: Node, caption: String, callback: Callable) -> void:
	var control := Button.new()
	control.text = caption
	control.custom_minimum_size.y = 40
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.pressed.connect(callback)
	parent.add_child(control)

func submit(action: String) -> void:
	client.endpoint = address.text.strip_edges()
	client.connect_account(action, username.text.strip_edges(), password.text, classes.get_item_metadata(classes.selected))
	password.clear()

func update_status() -> void:
	if is_instance_valid(status_label):
		status_label.text = client.status

func hide_form() -> void:
	if is_instance_valid(password):
		password.clear()
	root.hide()
