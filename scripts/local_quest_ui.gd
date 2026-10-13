extends CanvasLayer

const State = preload("res://scripts/local_quests.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var game
var state := State.new()
var overlay := Control.new()
var marker := Node3D.new()
var previous := "playing"
var current := ""
var preview: Dictionary = {}
var archive_text := ""
var feedback := ""
var marker_key := ""

func _ready() -> void:
	layer = 6
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.hide()
	add_child(marker)

func reset() -> void:
	state.reset()
	archive_text = ""
	current = ""
	preview.clear()
	marker_key = ""
	marker.hide()
	_clear()

func _process(_delta: float) -> void:
	if game != null:
		sync_marker()

func for_resident(resident: Dictionary) -> Dictionary:
	if not game.exploration.has_local_history(resident):
		return {}
	var region: Dictionary = game.world.region_at(Vector2i(resident.point.round()))
	return state.offer(game.world, region, game.exploration.regional_record(region), resident)

func open_resident(resident: Dictionary) -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	if game.state != "dialogue" or game.expansion.speaker.get("id", "") != resident.get("id", ""):
		return false
	preview = for_resident(resident)
	if preview.is_empty():
		return false
	current = preview.id
	previous = "dialogue"
	feedback = ""
	game.expansion.overlay.hide()
	_show()
	return true

func accept(id: String) -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	if game.state != "quest_reader" or previous != "dialogue" or id != current or preview.get("id") != id or game.expansion.speaker.get("id") != preview.giver_id:
		return false
	if not state.accept(preview):
		feedback = "Finish an active comparison before accepting another."
		_show()
		return false
	var record: Dictionary = state.records[id]
	game.exploration.note_site(record.site_id, record.site_cell)
	var region: Dictionary = game.world.region_at(Vector2i(record.city_cell[0], record.city_cell[1]))
	if not game.exploration.history.records.has(record.region_id):
		game.exploration.history.records[record.region_id] = game.exploration.regional_record(region).duplicate(true)
	var history: Dictionary = game.exploration.history.records.get(record.region_id, {})
	if history.get("sources", {}).has("book"):
		state.record_ledger(id, record.city_id, record.town_book)
	game._auto_save()
	_show()
	return true

func capture_book(id: String) -> void:
	if game != null and not game.offline_actions_allowed():
		return
	archive_text = ""
	if game.state != "playing":
		return
	if game.layer == "overworld":
		var region: Dictionary = game.world.region_at(Vector2i(game.player_point.round()))
		for book in region.get("city", {}).get("books", []):
			if book.book_id != id or game.player_point.distance_to(book.point) >= 2 or not game.world.line_clear(game.player_point, book.approach):
				continue
			for quest_id in state.active:
				var record: Dictionary = state.records[quest_id]
				if state.record_ledger(record.id, region.city.id, id):
					game._auto_save()
	elif game.layer == "dungeon":
		var record := active_archive()
		if record.is_empty():
			return
		var book: Dictionary = game.dungeon.readables[0]
		if id != record.ruin_book or book.book_id != id or game.player_point.distance_to(book.point) >= 2 or not game.dungeon.line_clear(game.player_point, book.approach):
			return
		if record.phase == "ledger":
			archive_text = "\n\n%s\nCopy the local ledger at %s before comparing this inscription." % [record.target.label, record.city_name]
			return
		if state.inspect(record.id, {"site_id": game.active_dungeon.id, "depth": game.depth, "book_id": id, "point": [int(book.point.x), int(book.point.y)]}):
			game._auto_save()
		archive_text = "\n\nLocal ledger\n%s\n\n%s / %s\n%s\n\nReturn to the resident at %s with your comparison." % [record.ledger_text, record.target.label, record.title, record.inscription, record.city_name]

func active_archive() -> Dictionary:
	if game.layer != "dungeon" or game.active_dungeon.is_empty() or game.dungeon.readables.is_empty():
		return {}
	for quest_id in state.active:
		var record: Dictionary = state.records[quest_id]
		if record.phase != "completed" and record.site_id == game.active_dungeon.id and record.ruin_book == game.dungeon.readables[0].book_id:
			return record
	return {}

func sync_marker() -> void:
	var record := active_archive()
	if record.is_empty() or not game.has_journey:
		marker.hide()
		return
	var book: Dictionary = game.dungeon.readables[0]
	var key := "%s:%s:%s" % [record.id, game.dungeon.get_instance_id(), book.point]
	if key != marker_key:
		for child in marker.get_children():
			marker.remove_child(child)
			child.queue_free()
		marker_key = key
		var tablet := Voxels.instance(Voxels.mesh([
			[Vector3(0,.45,.34), Vector3(.34,.20,.04), Color("827660")],
			[Vector3(0,.49,.365), Vector3(.24,.018,.008), Color("ddd1ac")],
			[Vector3(0,.44,.365), Vector3(.20,.018,.008), Color("ddd1ac")],
			[Vector3(0,.39,.365), Vector3(.25,.018,.008), Color("ddd1ac")]
		]))
		marker.add_child(tablet)
		var label := Label3D.new()
		label.text = record.target.label
		label.position.y = 1.75
		label.font_size = 28
		label.pixel_size = .009
		label.modulate = Color("cce4d5")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.add_child(label)
	marker.position = Vector3(book.point.x, 0, book.point.y)
	marker.visible = game.dungeon_view.explored.has(Vector2i(book.point)) and game.player_point.distance_to(book.point) < 9

func epilogue(resident: Dictionary) -> String:
	var id: String = state.by_giver.get(resident.get("id", ""), "")
	if state.records.has(id) and state.records[id].phase == "completed":
		return "\n\n" + state.records[id].completion
	return ""

func report(id: String, choice: String) -> bool:
	if game != null and not game.offline_actions_allowed():
		return false
	if game.state != "quest_reader" or previous != "dialogue" or id != current or not state.records.has(id):
		return false
	if not state.report(id, game.expansion.speaker.get("id", ""), choice):
		feedback = "Read both copied accounts again. This comparison does not match their words."
		_show()
		return false
	var received := state.claim(id, game.inventory)
	game.notify("Comparison recorded. " + ("Your decoration is in the backpack." if received else "Your decoration is reserved until there is room."))
	game.expansion._choose_line("greeting")
	game._auto_save()
	feedback = ""
	_show()
	return true

func claim(id: String) -> void:
	if game != null and not game.offline_actions_allowed():
		return
	if game.state != "quest_reader" or id != current or not state.claim(id, game.inventory):
		return
	game._auto_save()
	_show()

func mark(id: String) -> void:
	if not state.records.has(id):
		return
	var record: Dictionary = state.records[id]
	var cell: Array = record.city_cell if record.phase in ["ledger", "return", "completed"] else record.site_cell
	var region: Dictionary = game.world.region_at(Vector2i(cell[0], cell[1]))
	var sites: Array = [region.city] if record.phase in ["ledger", "return", "completed"] else region.dungeons
	var wanted: String = record.city_id if record.phase in ["ledger", "return", "completed"] else record.site_id
	for site in sites:
		if site.id == wanted:
			game.exploration.knowledge.remember(site, "rumor", str(game.run_seed))
			game.waypoint = site
			game.notify("Route marked: " + site.name)
			game._auto_save()
			return

func journal_rows(parent: VBoxContainer) -> void:
	game.interface._label(parent, "Local quests / %s" % state.records.size(), 17, Color("c3a576"))
	var ids: Array = state.records.keys()
	ids.sort()
	for id in ids:
		var record: Dictionary = state.records[id]
		game.interface._button(parent, "%s / %s / %s" % [record.title, record.city_name, status(record)], read_saved.bind(id), Vector2(0,40))

static func status(record: Dictionary) -> String:
	match record.phase:
		"ledger": return "Read town ledger"
		"inscription": return "Inspect ruin archive"
		"return": return "Report to resident"
	return "Completed" if record.reward_claimed else "Reward ready"

func read_saved(id: String) -> void:
	if game.state != "journal" or not state.records.has(id):
		return
	previous = "journal"
	current = id
	preview.clear()
	feedback = ""
	game.expansion.overlay.hide()
	_show()

func _show() -> void:
	_clear()
	var record: Dictionary = state.records.get(current, preview)
	if record.is_empty():
		return
	game.state = "quest_reader"
	game.rotating_camera = false
	var shade := ColorRect.new()
	shade.color = Color(.025,.035,.04,.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = game.interface._panel(center, Vector2(650,0), Color("766950"))
	var box = game.interface._vbox(panel, 10)
	game.interface._label(box, record.title, 27, Color("e5e0d5"), true)
	game.interface._label(box, record.author, 14, Color("c3a576"))
	var text: String = record.text
	if record.phase == "ledger":
		text += "\n\n" + record.ledger_prompt
	if record.ledger_read:
		text += "\n\nTown ledger\n" + record.ledger_text
	if not record.evidence.is_empty():
		text += "\n\nArchive inscription / %s\n%s" % [record.site_name, record.inscription]
	if record.phase == "completed":
		text += "\n\n" + record.finding + "\n\n" + record.completion
	game.expansion._text(box, text, 240)
	var accepted := state.records.has(current)
	game.interface._label(box, status(record) if accepted else "Optional local comparison", 14, Color("c3a576"))
	if not feedback.is_empty():
		var message = game.interface._label(box, feedback, 14)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not accepted:
		game.interface._button(box, "Accept comparison", accept.bind(current), Vector2(0,36))
	elif record.phase == "return" and previous == "dialogue":
		for choice in record.choices:
			game.interface._button(box, choice.label, report.bind(current, choice.id), Vector2(0,36))
	elif record.phase == "completed" and not record.reward_claimed:
		game.interface._label(box, "Reward reserved. Make room in your backpack to collect it.", 13, Color("c3a576"))
		game.interface._button(box, "Collect " + game.inventory.ITEMS.get(record.reward.item, {}).get("name", record.reward.item), claim.bind(current), Vector2(0,36))
	elif record.phase == "completed":
		game.interface._label(box, "Reward received: " + game.inventory.ITEMS.get(record.reward.item, {}).get("name", record.reward.item), 13, Color("c3a576"))
	if accepted:
		game.interface._button(box, "Mark next destination", mark.bind(current), Vector2(0,36))
	game.interface._button(box, "Back to " + ("conversation" if previous == "dialogue" else "journal"), close, Vector2(0,36))
	overlay.show()

func _clear() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.hide()

func close() -> void:
	_clear()
	game.state = previous
	if previous == "dialogue":
		game.expansion._show_dialogue()
	elif previous == "journal":
		game.expansion._show_journal()

func _input(event: InputEvent) -> void:
	if game != null and game.state == "quest_reader" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_J]:
		close()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not overlay.is_inside_tree():
		overlay.free()
		marker.free()
