extends SceneTree

const Grid = preload("res://scripts/icon_grid.gd")
const Game = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = "user://test-icon-grids-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	var directory: String = game.save_directory
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var parent := VBoxContainer.new()
	root.add_child(parent)
	var called := []
	var tile := Grid.item(game.interface,parent,"health_potion",func(): called.append("health_potion"),3)
	assert(tile.get_meta("item_id") == "health_potion" and tile.text.is_empty())
	assert(tile.find_children("*","TextureRect",true,false).size() > 0)
	tile.pressed.emit()
	assert(called == ["health_potion"])
	assert(Grid.page(range(61),2,24) == range(48,61))
	game.interface.collections(parent,3)
	game.interface._label(parent,"Books")
	var entry := game.interface._button(parent,"A saved book",func(): called.append("book"))
	assert(entry.get_parent() is GridContainer and entry.tooltip_text.contains("A saved book"))
	entry.pressed.emit()
	assert(called[-1] == "book")
	game.inventory.add("gold_coin",100)
	var source: Dictionary = game.stores.sources()[0]
	game.player_point = source.point
	game._snap_camera()
	game.stores.current = source
	game.stores.offers(source)
	game.state = "store"
	game.stores._show()
	var tiles := game.stores.overlay.find_children("*","Button",true,false).filter(func(button): return button.has_meta("item_id"))
	assert(not tiles.is_empty() and tiles.size() <= 24)
	var item: String = tiles[0].get_meta("item_id")
	tiles[0].pressed.emit()
	var buy: Button = game.stores.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("trade_action","") == "buy")[0]
	var before: int = game.inventory.count(item)
	buy.pressed.emit()
	assert(game.inventory.count(item) == before + 1, "The real selected tile's buy callback must deliver the selected item")
	game.stores._change_mode(true)
	game.stores._select(item)
	var sell: Button = game.stores.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("trade_action","") == "sell")[0]
	assert(not sell.disabled)
	sell.pressed.emit()
	assert(game.inventory.count(item) == before, "The selected item's sell callback must remove one clean item")
	game.stores.close()
	game.state = "grimoire"
	game.build.skill_points = 1
	game.interface._rebuild_overlay()
	var learn: Button = game.interface.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("learn_skill","") == game.interface.grimoire_selected_skill)[0]
	assert(not learn.disabled)
	learn.pressed.emit()
	assert(game.build.skill_points == 0 and game.build.ranks[game.interface.grimoire_selected_skill] == 1)
	var abilities: Array = game.interface.overlay.find_children("*","Button",true,false).filter(func(button): return button.has_meta("ability_id"))
	assert(abilities.size() == game.build.unlocked.size())
	var ability: String = abilities[-1].get_meta("ability_id")
	abilities[-1].pressed.emit()
	game.interface._rebuild_overlay()
	var slot: Button = game.interface.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("action_slot",-1) == 9)[0]
	slot.pressed.emit()
	assert(game.ACTION_BAR[9] == ability)
	game.state = "playing"
	var merchant: Dictionary = game.life.residents().filter(func(actor): return actor.role == "merchant")[0]
	game.expansion.open_dialogue(merchant)
	var offer: Dictionary = game.life.activity.role(merchant.role).offers[0]
	var offered_before: int = game.inventory.count(offer.item)
	var payment: Button = game.expansion.overlay.find_children("*","Button",true,false).filter(func(button): return button.text == "%s coins" % int(offer.coin_cost))[0]
	assert(not payment.disabled)
	payment.pressed.emit()
	assert(game.inventory.count(offer.item) == offered_before + 1)
	game.expansion.close_lore()
	var book_id: String = game.expansion.Lore.BOOKS.keys()[0]
	game.expansion.read_books.assign([book_id])
	game.expansion.toggle_journal()
	var book: Button = game.expansion.overlay.find_children("*","Button",true,false).filter(func(button): return button.tooltip_text == game.expansion.Lore.BOOKS[book_id].title)[0]
	assert(book.get_parent() is GridContainer)
	book.pressed.emit()
	assert(game.state == "reader" and game.expansion.current_book == book_id)
	game.expansion.close_lore()
	game.expansion.close_lore()
	game.inventory.add("arcane_staff")
	assert(game.equip_item("arcane_staff"))
	game.state = "inventory"
	game.interface._rebuild_overlay()
	var equipment: Button = game.interface.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("equipment_slot","") == "weapon")[0]
	equipment.pressed.emit()
	game.interface._rebuild_overlay()
	var unequip: Button = game.interface.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("unequip_slot","") == "weapon")[0]
	unequip.pressed.emit()
	assert(game.inventory.equipment.weapon.is_empty())
	game.state = "character"
	game.interface._rebuild_overlay()
	var appearance_tabs: TabContainer = game.interface.overlay.find_children("*","TabContainer",true,false)[0]
	for index in range(appearance_tabs.get_tab_count()):
		if appearance_tabs.get_tab_title(index) == "Colors":
			appearance_tabs.current_tab = index
	game.interface._rebuild_overlay()
	var colors: Array = game.interface.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("profile_choice","") == "skin")
	assert(colors.size() == game.CharacterProfile.SKINS.size() and colors[-1].is_visible_in_tree())
	colors[-1].pressed.emit()
	assert(game.profile.skin == game.CharacterProfile.SKINS.size() - 1)
	game.state = "playing"
	assert(game.inventory.add("oak_chair",2))
	assert(game.world_items.open_placement())
	var portable: Button = game.world_items.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("item_id","") == "oak_chair")[0]
	portable.pressed.emit()
	assert(game.world_items.selected == "oak_chair")
	game.world_items.close()
	assert(game.use_sanctum_sigil())
	assert(game.furnishing_editor.open())
	var chair: Button = game.furnishing_editor.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("item_id","") == "oak_chair")[0]
	chair.pressed.emit()
	assert(game.furnishing_editor.selected == "oak_chair" and not game.furnishing_editor.confirm_button.disabled)
	game.furnishing_editor.confirm_button.pressed.emit()
	assert(game.furnishings.records.size() == 1 and game.inventory.count("oak_chair") == 1)
	var placed: Array = game.furnishing_editor.overlay.find_children("*","Button",true,false).filter(func(button): return button.get_meta("item_id","") == "oak_chair")
	assert(placed.size() == 2)
	placed[-1].pressed.emit()
	assert(game.furnishing_editor.moving == game.furnishings.records[0].uid)
	game.furnishing_editor.pickup_button.pressed.emit()
	assert(game.furnishings.records.is_empty() and game.inventory.count("oak_chair") == 2)
	game.furnishing_editor.close()
	parent.queue_free()
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	if folder != null:
		for file in folder.get_files():
			folder.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: real icon-grid buy/sell and merchant payment, skill learning, action-slot assignment, equipment removal, palette and placement selection, furniture placement/pickup, paging and journal callbacks")
	quit()
