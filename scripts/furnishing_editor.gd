extends Node

const Furnishings = preload("res://scripts/furnishings.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const Scenery = preload("res://scripts/scenery.gd")
var scenery := Scenery.new()
var game
var canvas := CanvasLayer.new()
var overlay := Control.new()
var panel: PanelContainer
var status: Label
var confirm_button: Button
var pickup_button: Button
var ghost: Node3D
var selected := ""
var moving := ""
var rotation := 0
var target := Vector2(8, 11)
var proposal: Dictionary = {}
var preview_key := ""
var keyboard_position := true
var original_zoom := 15.0

func _ready() -> void:
	canvas.layer = 20
	add_child(canvas)
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false

func open(id: String = "") -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.layer != "sanctum" or not game.has_journey or game.state not in ["playing", "inventory", "furnishing"]:
		game.notify("Visit your Sanctum to place furnishings.")
		return false
	if game.state != "furnishing":
		original_zoom = game.camera.size
	game.state = "furnishing"
	game.rotating_camera = false
	overlay.visible = true
	game.camera.size = 22
	frame_camera()
	if not id.is_empty():
		select_item(id)
	else:
		cancel_selection()
	return true

func stop() -> void:
	if game == null:
		return
	overlay.visible = false
	clear_ghost()
	for node in game.sanctum_view.furniture_nodes.values():
		node.visible = true
	selected = ""
	moving = ""
	preview_key = ""

func close() -> void:
	stop()
	game.state = "playing"
	game.camera.size = original_zoom
	game._snap_camera()
	game.sanctum_view.update_camera(game.camera_yaw)

func frame_camera() -> void:
	var center := Vector3(10, 0, 10)
	game.camera.position = center + Vector3(sin(game.camera_yaw) * 20, 14, cos(game.camera_yaw) * 20)
	game.camera.look_at(center)
	game.sanctum_view.update_camera(game.camera_yaw, true)

func orbit(step: float) -> void:
	game.camera_yaw = wrapf(game.camera_yaw + step, -PI, PI)
	game.target_yaw = game.camera_yaw
	keyboard_position = true
	frame_camera()

func select_item(id: String) -> void:
	cancel_selection(false)
	selected = id
	rotation = 0
	target = Vector2(8, 11)
	keyboard_position = true
	refresh_panel()
	update_preview()

func select_placed(uid: String) -> void:
	cancel_selection(false)
	var record: Dictionary = game.furnishings.get_record(uid)
	if record.is_empty():
		return
	selected = record.item
	moving = uid
	rotation = record.rotation
	target = Furnishings.point(record)
	keyboard_position = true
	refresh_panel()
	update_preview()

func cancel_selection(rebuild: bool = true) -> void:
	clear_ghost()
	for node in game.sanctum_view.furniture_nodes.values():
		node.visible = true
	selected = ""
	moving = ""
	proposal = {}
	preview_key = ""
	if rebuild:
		refresh_panel()

func clear_ghost() -> void:
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func refresh_panel() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	var ui = game.interface
	panel = ui._panel(overlay, Vector2(320, 0))
	panel.position = Vector2(20, 20)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(284, maxf(420, get_viewport().get_visible_rect().size.y - 80))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box: VBoxContainer = ui._vbox(scroll, 10)
	box.custom_minimum_size.x = 280
	ui._label(box, "Furnish your Sanctum", 22, ui.INK, true)
	ui._label(box, "Walls, keepsakes and a place to rest.", 13, ui.GOLD)
	var view_row := HBoxContainer.new()
	box.add_child(view_row)
	button(view_row, "< View", orbit.bind(-PI / 4))
	button(view_row, "View >", orbit.bind(PI / 4))
	button(view_row, "Close [B]", close)
	ui._separator(box)
	ui._label(box, "In your backpack", 17, ui.GOLD, true)
	var available := 0
	var bag_scroll := ScrollContainer.new()
	bag_scroll.custom_minimum_size = Vector2(280, 125)
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(bag_scroll)
	var bag_list: VBoxContainer = ui._vbox(bag_scroll, 4)
	bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bag_grid: GridContainer = ui.IconGrid.grid(bag_list,3)
	for id in game.inventory.items:
		var item: Dictionary = game.inventory.ITEMS[id]
		if item.kind != "furnishing":
			continue
		available += 1
		var choice: Button = ui.IconGrid.item(ui,bag_grid,id,select_item.bind(id),game.inventory.count(id),id == selected)
		choice.focus_mode = Control.FOCUS_NONE
		choice.disabled = Furnishings.Catalog.definition(id).is_empty()
		choice.tooltip_text = "This find needs a supported furniture recipe." if choice.disabled else item.description
	if available == 0:
		ui._label(bag_list, "Collect furnishings during your journeys.", 13, ui.MUTED)
	ui._separator(box)
	ui._label(box, "Placed  %s / %s" % [game.furnishings.records.size(), Furnishings.MAX_PLACED], 17, ui.GOLD, true)
	var placed_scroll := ScrollContainer.new()
	placed_scroll.custom_minimum_size = Vector2(280, 115)
	placed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(placed_scroll)
	var placed_list: VBoxContainer = ui._vbox(placed_scroll, 4)
	placed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var placed_grid: GridContainer = ui.IconGrid.grid(placed_list,3)
	for record in game.furnishings.records:
		var choice: Button = ui.IconGrid.item(ui,placed_grid,record.item,select_placed.bind(record.uid),-1,record.uid == moving)
		choice.focus_mode = Control.FOCUS_NONE
		choice.tooltip_text += "\nMove or pick up"
	if game.furnishings.records.is_empty():
		ui._label(placed_list, "Furnish any clear island floor.", 13, ui.MUTED)
	ui._separator(box)
	var name: String = game.inventory.ITEMS.get(selected, {}).get("name", "Choose a furnishing")
	ui._label(box, name, 17, ui.INK, true)
	status = ui._label(box, "", 13, ui.MUTED)
	status.custom_minimum_size.x = 275
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	box.add_child(row)
	button(row, "Rotate [R]", rotate_selection)
	confirm_button = button(row, "Move [Enter]" if not moving.is_empty() else "Place [Enter]", confirm)
	pickup_button = button(box, "Pick up to backpack [Delete]", pickup)
	pickup_button.visible = not moving.is_empty()
	button(box, "Cancel selection [Esc]", cancel_selection)
	var instructions: Label = ui._label(box, "Hover to position; click to place.\nArrow keys move the preview. R rotates.\nEsc cancels; B closes.\nSmall objects need a table or shelf.", 12, ui.MUTED)
	instructions.custom_minimum_size.x = 275
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_key = ""

func button(parent: Node, caption: String, callback: Callable) -> Button:
	var result: Button = game.interface._button(parent, caption, callback, Vector2(0, 32))
	result.focus_mode = Control.FOCUS_NONE
	return result

func rotate_selection() -> void:
	rotation = (rotation + 1) % 4
	preview_key = ""
	update_preview()

func confirm() -> bool:
	if not game.offline_actions_allowed():
		return false
	if selected.is_empty():
		return false
	update_preview()
	if not proposal.get("problem", "").is_empty():
		return false
	var success: bool = game.furnishings.place(selected, target, rotation, game.inventory, game.player_point, portable_obstacles()) if moving.is_empty() else game.furnishings.move(moving, target, rotation, game.player_point, portable_obstacles())
	if not success:
		status.text = game.furnishings.error
		status.modulate = Color("efaaa8")
		return false
	game.refresh_sanctum_furnishings()
	game._auto_save()
	cancel_selection()
	return true

func portable_obstacles() -> Array[Rect2]:
	var portable = game.get("world_items")
	return portable.applied_obstacles if portable != null else []

func pickup() -> bool:
	if not game.offline_actions_allowed():
		return false
	if moving.is_empty() or not game.furnishings.remove(moving, game.inventory):
		status.text = game.furnishings.error
		status.modulate = Color("efaaa8")
		return false
	game.refresh_sanctum_furnishings()
	game._auto_save()
	cancel_selection()
	return true

func _process(_delta: float) -> void:
	if game == null or game.state != "furnishing":
		if overlay.visible:
			stop()
		return
	if not keyboard_position and not selected.is_empty():
		var mouse := get_viewport().get_mouse_position()
		if not panel.get_global_rect().has_point(mouse):
			position_from_screen(mouse)
	update_preview()

func position_from_screen(screen: Vector2) -> void:
	var projected = project(screen, 0)
	var spec := Furnishings.Catalog.definition(selected)
	if spec.get("support", "") == "surface":
		for record in game.furnishings.records:
			if Furnishings.Catalog.definition(record.item).get("surface", false):
				var top: float = Furnishings.elevation(record, game.furnishings.records) + Furnishings.Catalog.definition(record.item).height
				var on_surface = project(screen, top)
				if on_surface != null and Furnishings.box(record).has_point(on_surface):
					projected = on_surface
					break
	if projected != null:
		target = projected

func project(screen: Vector2, height: float):
	var hit = Plane(Vector3.UP, height).intersects_ray(game.camera.project_ray_origin(screen), game.camera.project_ray_normal(screen))
	return Vector2(hit.x, hit.z) if hit != null else null

func update_preview() -> void:
	if status == null:
		return
	if selected.is_empty():
		confirm_button.disabled = true
		status.text = "Choose an item from your backpack or a placed furnishing."
		return
	var key := str([selected, moving, target, rotation, game.furnishings.next_id])
	if key == preview_key:
		return
	preview_key = key
	proposal = game.furnishings.candidate(selected, target, rotation, moving, game.player_point, portable_obstacles())
	var spec := Furnishings.Catalog.definition(selected)
	clear_ghost()
	var problem: String = proposal.problem
	if moving.is_empty() and game.inventory.has_method("stolen_count") and game.inventory.stolen_count(selected) > 0 and game.inventory.count(selected) <= game.inventory.stolen_count(selected):
		problem = "Use Place in world to place stolen furnishings."
	proposal.problem = problem
	if not moving.is_empty() and game.sanctum_view.furniture_nodes.has(moving):
		game.sanctum_view.furniture_nodes[moving].visible = game.furnishings.has_dependants(moving)
	if not spec.is_empty() and (moving.is_empty() or not game.furnishings.has_dependants(moving)):
		ghost = Furnishings.Catalog.model(proposal.record, scenery, "block_voxel")
		for mesh in ghost.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color.a *= .5
				mesh.set_surface_override_material(surface, material)
		var footprint := Furnishings.box(proposal.record)
		var marker := Voxels.cube(Vector3(footprint.size.x, .028, footprint.size.y), Color("64c39c") if problem.is_empty() else Color("d76f76"), true)
		marker.position.y = .014
		ghost.add_child(marker)
		var point := Furnishings.point(proposal.record)
		ghost.position = Vector3(point.x, Furnishings.elevation(proposal.record, game.furnishings.records) + .015, point.y)
		game.add_child(ghost)
	status.text = problem if not problem.is_empty() else "Ready. Click or press Enter to " + ("move." if not moving.is_empty() else "place.")
	status.modulate = Color("efaaa8") if not problem.is_empty() else Color("94dac3")
	confirm_button.disabled = not problem.is_empty()
	pickup_button.disabled = moving.is_empty() or game.furnishings.has_dependants(moving)

func handle_mouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		keyboard_position = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_selection()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position):
		if not selected.is_empty():
			position_from_screen(event.position)
			confirm()
		else:
			var point = project(event.position, 0)
			if point != null:
				for record in game.furnishings.records:
					if Furnishings.box(record).has_point(point):
						select_placed(record.uid)
						break

func handle_key(event: InputEventKey) -> void:
	match event.physical_keycode:
		KEY_B: close()
		KEY_ESCAPE:
			if selected.is_empty(): close()
			else: cancel_selection()
		KEY_R: rotate_selection()
		KEY_ENTER, KEY_KP_ENTER: confirm()
		KEY_DELETE, KEY_BACKSPACE: pickup()
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			var direction := Vector2.ZERO
			if event.physical_keycode == KEY_UP: direction = Vector2.UP
			if event.physical_keycode == KEY_DOWN: direction = Vector2.DOWN
			if event.physical_keycode == KEY_LEFT: direction = Vector2.LEFT
			if event.physical_keycode == KEY_RIGHT: direction = Vector2.RIGHT
			target += game.screen_movement(direction) * .5
			keyboard_position = true
			update_preview()
