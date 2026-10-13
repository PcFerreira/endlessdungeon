extends CanvasLayer

const Lore = preload("res://scripts/lore_catalog.gd")
const World = preload("res://scripts/world.gd")
const Actors = preload("res://scripts/actor_models.gd")
var game
var read_books: Array[String] = []
var met_speakers: Dictionary = {}
var heard: Dictionary = {}
var ruin_returns: Dictionary = {}
var speaker: Dictionary = {}
var dialogue_text := ""
var current_book := ""
var return_state := "playing"
var reader_return_state := "playing"
var farewell := false
var overlay := Control.new()

func _ready() -> void:
	layer = 4
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.hide()

func reset() -> void:
	read_books.clear()
	met_speakers.clear()
	heard.clear()
	ruin_returns.clear()
	speaker = {}
	current_book = ""
	dialogue_text = ""
	_clear_overlay()

func snapshot() -> Dictionary:
	return {"books": read_books.duplicate(), "speakers": met_speakers.keys(), "heard": heard.duplicate(true), "returns": ruin_returns.duplicate()}

static func valid_snapshot(data) -> bool:
	if not data is Dictionary or not data.get("heard") is Dictionary or not data.get("returns") is Dictionary:
		return false
	for key in ["books", "speakers"]:
		if not data.get(key) is Array:
			return false
		for id in data[key]:
			if not id is String:
				return false
	for id in data.books:
		if not Lore.BOOKS.has(id):
			return false
	for id in data.returns:
		if not id is String or not data.returns[id] is String:
			return false
	for id in data.heard:
		if not id is String or not data.heard[id] is Array:
			return false
		for line_id in data.heard[id]:
			if not line_id is String:
				return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data):
		return false
	reset()
	for id in data.books:
		if id not in read_books:
			read_books.append(id)
	for id in data.speakers:
		met_speakers[id] = true
	heard = data.heard.duplicate(true)
	ruin_returns = data.returns.duplicate()
	return true

func record_return(site: Dictionary) -> void:
	var city: Dictionary = game.world.nearest_site(Vector2(site.cell), "city")
	if not city.is_empty():
		ruin_returns[city.id] = site.id

func target() -> Dictionary:
	var candidates: Array = []
	if game.layer == "overworld":
		var city: Dictionary = game.world.region_at(Vector2i(game.player_point.round())).city
		candidates.append_array(game.life.residents())
		if game.dimension.active:
			candidates.append_array(game.population.actors.values())
		candidates.append_array(city.get("books", []))
		for site in game.world.region_at(Vector2i(game.player_point.round())).get("locations", []):
			candidates.append_array(site.books)
	elif game.layer == "dungeon":
		candidates.append_array(game.dungeon.readables)
	var result := {}
	var distance := 2.0
	for candidate in candidates:
		var delta: float = game.player_point.distance_to(candidate.point)
		var sight: Vector2 = candidate.get("approach", candidate.point) if candidate.kind == "book" else candidate.point
		if delta < distance and game.dungeon.line_clear(game.player_point, sight):
			result = candidate
			distance = delta
	return result

func hint() -> String:
	var candidate := target()
	if candidate.is_empty():
		return ""
	if candidate.kind == "npc":
		if candidate.role == "guard" and not game.city_law.wanted(candidate.city_id).is_empty():
			return "E: Return city property to the watch"
		return "E: Talk to the " + _role_name(candidate).to_lower()
	var quest: Dictionary = game.exploration.quests.active_archive()
	return "E: Read " + Lore.BOOKS[candidate.book_id].title + (" / " + quest.target.label if not quest.is_empty() else "")

func interact() -> bool:
	if not game.offline_actions_allowed():
		return false
	var candidate := target()
	if candidate.is_empty():
		return false
	if candidate.kind == "npc":
		open_dialogue(candidate)
	else:
		if candidate.has("site_id"):
			var site: Dictionary = game.world.site_by_id(candidate.site_id, candidate.site_cell)
			if not site.is_empty():
				game.exploration.knowledge.remember(site, "visited", str(game.run_seed))
		read_book(candidate.book_id)
	return true

func _safe() -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.state != "playing":
		return false
	var problem: String = game.sanctum_problem()
	if not problem.is_empty():
		game.notify("Find safe ground before talking or reading.")
		return false
	return true

func open_dialogue(resident: Dictionary) -> bool:
	if not game.offline_actions_allowed():
		return false
	if resident.has("dimension_id"):
		if not game.population.enabled() or not game.population.actors.has(resident.id) or not _safe():
			return false
		speaker = resident
		farewell = false
		return_state = game.state
		_choose_line("greeting")
		met_speakers[speaker.id] = true
		game._auto_save()
		game.state = "dialogue"
		game.rotating_camera = false
		game.population.greet(speaker.id)
		_show_dialogue()
		return true
	if resident.get("role") == "guard" and not game.city_law.wanted(resident.city_id).is_empty():
		return game.city_law.demand(resident)
	if not _safe() or (not Lore.ROLE_NAMES.has(resident.get("role", "")) and game.life.activity.role(resident.get("role", "")).is_empty()):
		return false
	speaker = resident
	farewell = false
	return_state = game.state
	_choose_line("greeting")
	met_speakers[speaker.id] = true
	game._auto_save()
	game.state = "dialogue"
	game.rotating_camera = false
	if game.world_view.npc_models.has(speaker.id):
		var actor = game.world_view.npc_models[speaker.id]
		if is_instance_valid(actor):
			Actors.greet(actor)
	_show_dialogue()
	return true

func _choose_line(event: String) -> void:
	if speaker.has("dimension_id"):
		dialogue_text = game.population.dialogue(speaker, event)
		return
	if speaker.get("roaming",false):
		dialogue_text = game.life.roamers.dialogue(speaker,event,hash("%s:%s:%s" % [speaker.id,event,game.life.tick / 480]))
		return
	if speaker.get("traveling", false):
		dialogue_text = game.life.activity.dialogue(speaker, event, hash("%s:%s:%s" % [speaker.id, event, game.life.tick / 480]))
		return
	var site: Dictionary = game.world.nearest_site(speaker.point, "dungeon")
	var returned := false
	for candidate in game.world.region_at(Vector2i(speaker.point)).dungeons:
		if candidate.id == ruin_returns.get(speaker.city_id, ""):
			site = candidate
			returned = true
	var context := {"met": met_speakers.has(speaker.id), "returned": returned, "biome_label": World.BIOMES[speaker.biome], "city_name": speaker.city_name, "dungeon_name": site.get("name", ""), "player_class": game.build.class_id}
	var episode: Dictionary = game.life.event_at(speaker.city_id)
	context.life_kind = episode.get("kind", "")
	context.life_phase = episode.get("phase", "")
	var history: Array = heard.get(speaker.id, [])
	var entry := Lore.line(speaker.role, event, context, history, hash("%s:%s:%s:%s" % [game.run_seed, speaker.id, event, history.size()]))
	dialogue_text = entry.text
	if entry.id.is_empty() and event == "topic_local_life" and not episode.is_empty():
		dialogue_text = "%s is underway here in %s." % [episode.label, speaker.city_name] if episode.phase == "active" else "%s. The neighbors have returned to their work." % episode.get("aftermath", episode.label + " has finished")
	if not entry.id.is_empty() and entry.id not in history:
		history.append(entry.id)
	heard[speaker.id] = history
	dialogue_text += game.exploration.quests.epilogue(speaker)

func talk(event: String) -> void:
	_choose_line(event)
	farewell = event == "farewell"
	_show_dialogue()
	game._auto_save()

func read_book(id: String) -> bool:
	if not game.offline_actions_allowed():
		return false
	if not Lore.BOOKS.has(id):
		return false
	if game.state == "reader" and current_book == id:
		return true
	if game.state == "journal":
		if id not in read_books:
			return false
		game.exploration.book_region = ""
		game.exploration.quests.archive_text = ""
		reader_return_state = "journal"
	else:
		if not _safe():
			return false
		reader_return_state = "playing"
		return_state = "playing"
		game.exploration.record_book(id)
		game.exploration.quests.capture_book(id)
		if id not in read_books:
			read_books.append(id)
			game._auto_save()
	current_book = id
	game.ambience.play_effect("book_open", game.sound)
	game.state = "reader"
	game.rotating_camera = false
	_show_book()
	return true

func toggle_journal() -> void:
	if not game.offline_actions_allowed():
		return
	if game.state == "journal":
		close_lore()
	elif game.state in ["playing", "paused"]:
		return_state = game.state
		game.state = "journal"
		game.rotating_camera = false
		_show_journal()

func close_lore() -> void:
	if game.state == "reader":
		game.ambience.play_effect("book_close", game.sound)
	if game.state == "reader" and reader_return_state == "journal":
		game.state = "journal"
		_show_journal()
	else:
		game.state = return_state
		_clear_overlay()
		game._auto_save()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE and game.state in ["dialogue", "reader", "journal"]:
		close_lore()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_J and game.state in ["playing", "paused", "journal"]:
		toggle_journal()
		get_viewport().set_input_as_handled()

func _clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.hide()

func _panel(title: String, subtitle: String) -> VBoxContainer:
	_clear_overlay()
	overlay.show()
	var shade := ColorRect.new()
	shade.color = Color(.025, .04, .065, .82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = game.interface._panel(center, Vector2(650, 0), Color("766950"))
	var box = game.interface._vbox(panel, 12)
	game.interface._label(box, title, 27, Color("e5e0d5"), true)
	game.interface._label(box, subtitle, 14, Color("c3a576"))
	return box

func _text(box: VBoxContainer, text: String, height: float) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, height)
	box.add_child(scroll)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("e5e0d5"))
	scroll.add_child(label)

func _show_dialogue() -> void:
	if speaker.has("dimension_id"):
		var realm_box := _panel(speaker.name, speaker.role_label + " / " + speaker.city_name)
		_text(realm_box, dialogue_text, 125)
		if not farewell:
			game.interface._button(realm_box, "Ask about this place", talk.bind("topic_authored"), Vector2(0,36))
			game.interface._button(realm_box, "Farewell", talk.bind("farewell"), Vector2(0,36))
		game.interface._button(realm_box, "Return  [Esc]", close_lore, Vector2(0,36))
		return
	var box := _panel(_role_name(speaker), speaker.city_name + " / Endless World")
	_text(box, dialogue_text, 125)
	if speaker.get("roaming",false):
		if not farewell:
			game.interface._button(box,"Nearby area",talk.bind("topic_route"),Vector2(0,36))
			game.interface._button(box,"Your work",talk.bind("topic_work"),Vector2(0,36))
			if not speaker.get("wonder_trade_profile","").is_empty():
				game.interface._button(box,"Trade",_trade_wonder,Vector2(0,36))
			game.interface._button(box,"Farewell",talk.bind("farewell"),Vector2(0,36))
		game.interface._button(box,"Return  [Esc]",close_lore,Vector2(0,36))
		return
	if speaker.role == "merchant":
		game.interface._label(box, "Coins: %s / Ember shards: %s" % [game.inventory.count("gold_coin") - game.inventory.stolen_count("gold_coin"), game.inventory.count("ember_shard") - game.inventory.stolen_count("ember_shard")], 14, Color("c3a576"))
	if not farewell:
		if speaker.get("traveling", false):
			game.interface._button(box, "Travel route" if speaker.role != "guard" else "The watch", talk.bind("topic_route"), Vector2(0,36))
			var offers: GridContainer = game.interface.IconGrid.grid(box,3)
			for offer in game.life.activity.role(speaker.role).get("offers", []):
				if game.inventory.ITEMS.has(offer.item):
					var column: VBoxContainer = game.interface._vbox(offers,4)
					game.interface.IconGrid.item(game.interface,column,offer.item,Callable())
					var shards: Button = game.interface._button(column, "%s shards" % int(offer.cost), _trade.bind(offer.item,"ember_shard"), Vector2(132,30))
					shards.disabled = game.inventory.count("ember_shard") - game.inventory.stolen_count("ember_shard") < int(offer.cost)
					if offer.has("coin_cost") and game.inventory.ITEMS.has("gold_coin"):
						var coins: Button = game.interface._button(column, "%s coins" % int(offer.coin_cost), _trade.bind(offer.item,"gold_coin"), Vector2(132,30))
						coins.disabled = game.inventory.count("gold_coin") - game.inventory.stolen_count("gold_coin") < int(offer.coin_cost)
		game.interface.collections(box,3,176)
		if game.exploration.has_local_history(speaker):
			game.interface._button(box, "Local history", game.exploration.read_witness.bind(speaker), Vector2(0,36))
		if not game.exploration.quests.for_resident(speaker).is_empty():
			game.interface._button(box, "Local comparison", game.exploration.quests.open_resident.bind(speaker), Vector2(0,36))
		if not speaker.get("traveling",false):
			var city: Dictionary = game.world.region_at(Vector2i(speaker.point.round())).city
			if city.id == speaker.city_id and city.has("magic"):
				game.interface._button(box,"Town charm",town_charm,Vector2(0,36))
		for event in Lore.topics(speaker.role):
			if event == "topic_local_life" and game.life.event_at(speaker.city_id).is_empty():
				continue
			game.interface._button(box, event.trim_prefix("topic_").replace("_", " ").capitalize(), talk.bind(event), Vector2(0,36))
		game.interface._button(box, "Farewell", talk.bind("farewell"), Vector2(0,36))
	if box.has_meta("collection_columns"):
		box.remove_meta("collection_columns")
	game.interface._button(box, "Return  [Esc]", close_lore, Vector2(0,36))

func town_charm() -> void:
	if not game.offline_actions_allowed():
		return
	if game.state != "dialogue" or farewell or speaker.is_empty() or speaker.get("traveling",false):
		return
	var city: Dictionary = game.world.region_at(Vector2i(speaker.point.round())).city
	if city.id != speaker.city_id or not city.has("magic"):
		return
	var profile: Dictionary = city.magic.profile
	var box := _panel(profile.name,city.name + " / A charm kept by the neighbors")
	_text(box,profile.account + "\n\n" + profile.custom,250)
	game.interface._button(box,"Back to the conversation",_show_dialogue,Vector2(0,36))
	game.interface._button(box,"Return  [Esc]",close_lore,Vector2(0,36))

func _role_name(resident: Dictionary) -> String:
	if resident.get("roaming",false):
		return resident.roaming_name
	return Lore.ROLE_NAMES.get(resident.role, game.life.activity.role(resident.role).get("name", "Traveler"))

func _trade_wonder() -> void:
	if game.state != "dialogue" or farewell or not speaker.get("roaming",false) or speaker.get("wonder_trade_profile","").is_empty():
		return
	if game.stores.open_wonder(speaker):
		_clear_overlay()

func _trade(item: String, currency: String = "ember_shard") -> void:
	if not game.offline_actions_allowed():
		return
	if game.state != "dialogue" or farewell:
		return
	dialogue_text = game.life.activity.trade(game.inventory, speaker, item, game.build.class_id, currency)
	_show_dialogue()
	game._auto_save()

func _show_book() -> void:
	var book: Dictionary = Lore.BOOKS[current_book]
	var box := _panel(book.title, book.get("author", "Unknown author"))
	_text(box, book.text + game.exploration.book_appendix() + game.exploration.quests.archive_text, 320)
	game.interface._label(box, "Copied to your field journal.", 13, Color("c3a576"))
	game.interface._button(box, "Close  [Esc]", close_lore, Vector2(0,36))

func _show_journal() -> void:
	var box := _panel("Field journal", "%s books / %s people met" % [read_books.size(), met_speakers.size()])
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	box.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(entries)
	game.interface.collections(entries,4,136)
	if read_books.is_empty():
		game.interface._label(entries, "Read a book in a town or ruin to keep it here.", 16)
	for id in read_books:
		game.interface._button(entries, Lore.BOOKS[id].title, read_book.bind(id), Vector2(0,40))
	game.exploration.journal_rows(entries)
	game.interface._button(box, "Return  [J / Esc]", close_lore, Vector2(0,36))
