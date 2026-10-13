extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/icon-grid-preview-saves"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	game.inventory.add("gold_coin",100)
	for id in ["oak_chair","rune_lantern","wool_rug"]:
		game.inventory.add(id,2)
	for state in ["inventory","grimoire","character","paused","save","load","dead","menu","title"]:
		game.state = state
		game.interface._rebuild_overlay()
		await frame("grid-" + state)
		if state == "grimoire":
			game.interface.grimoire_tabs.current_tab = 1
			await frame("grid-abilities")
		if state == "character":
			var initial: TabContainer = game.interface.overlay.find_children("*","TabContainer",true,false)[0]
			var names: Array[String] = []
			for index in range(initial.get_tab_count()):
				names.append(initial.get_tab_title(index))
			for index in range(1,names.size()):
				var tabs: TabContainer = game.interface.overlay.find_children("*","TabContainer",true,false)[0]
				tabs.current_tab = index
				await frame("grid-character-" + names[index].to_lower())
	game.state = "playing"
	game.expansion.read_books.assign(game.expansion.Lore.BOOKS.keys())
	game.expansion.toggle_journal()
	await frame("grid-journal")
	game.expansion.close_lore()
	var merchant: Dictionary = game.life.residents().filter(func(actor): return actor.role == "merchant")[0]
	game.expansion.open_dialogue(merchant)
	await frame("grid-merchant")
	game.expansion.close_lore()
	game.world_items.open_placement()
	await frame("grid-world-objects")
	game.world_items.close()
	game.use_sanctum_sigil()
	game.furnishing_editor.open()
	await frame("grid-furnishings")
	game.furnishing_editor.select_item("oak_chair")
	assert(game.furnishing_editor.confirm())
	game.furnishing_editor.select_placed(game.furnishings.records[0].uid)
	await frame("grid-furnishings-placed")
	game.furnishing_editor.close()
	game.state = "menu"
	game.interface._rebuild_overlay()
	game.online.lobby.show_form()
	await frame("grid-online-class")
	game.online.lobby.hide_form()
	game.queue_free()
	await process_frame
	print("PASS: native icon-grid inventory, skills/abilities, character/palette choices, menu/saves, journal, merchant, object and furnishing collections")
	quit()

func frame(name: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % name) == OK)
