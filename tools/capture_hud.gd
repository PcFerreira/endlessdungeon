extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var ui

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/hud-preview-saves"
	root.add_child(game)
	ui = game.interface
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	await frame("hud-main-menu")
	game.start_run(12345)
	game.begin_journey()
	game.customize_character({"name": "Mira"})
	game._generate_surface(Vector2(game.world.start) + Vector2(0, 7), false)
	game.notification_time = 0
	await frame("hud-exploration")
	assert(ui.hud.visible and not ui.target_panel.visible)
	assert(not ui.hint.text.contains("WASD"))
	assert(ui.hotbar.get_child_count() == 10)
	for spell in ui.spell_status:
		assert(ui.spell_status[spell].text.is_empty())
		assert(ui.spell_buttons[spell].tooltip_text.contains(game.ABILITIES[spell].description))
	for button in ui.utility_buttons:
		assert(not button.text.contains("["))
		assert(not button.tooltip_text.is_empty())
	await click(ui.utility_buttons[1])
	assert(game.state == "inventory" and not ui.hud.visible)
	await frame("hud-backpack")
	game.toggle_inventory()
	await frames()
	await click(ui.utility_buttons[2])
	assert(game.state == "grimoire")
	await frame("hud-grimoire")
	game.toggle_grimoire()
	await frames()
	await click(ui.utility_buttons[3])
	assert(game.state == "journal")
	await frame("hud-journal")
	game.expansion.close_lore()
	await frames()
	await click(ui.map_button)
	assert(game.state == "map")
	await frame("hud-atlas")
	game.toggle_map()
	await frames()
	await key(KEY_TAB)
	assert(game.state == "map")
	await key(KEY_TAB)
	assert(game.state == "playing")
	await click(ui.utility_buttons[5])
	assert(game.state == "paused")
	await frame("hud-pause")
	game.open_options()
	await frame("hud-options")
	game.close_options()
	game.toggle_pause()
	var city: Dictionary = game.world.nearest_site(game.player_point, "city")
	game._generate_surface(Vector2(city.cell) + Vector2.DOWN, false)
	game.notification_time = 0
	await frame("hud-interaction")
	assert(ui.interaction_panel.visible and ui.interaction_key.text == "E")
	game.notify("A new road waits beyond the city.")
	await frame("hud-prompt-and-notification")
	assert(ui.message_panel.visible and ui.interaction_panel.visible)
	assert(not ui.message_panel.get_global_rect().intersects(ui.interaction_panel.get_global_rect()))
	await click(ui.sanctum_button)
	assert(game.layer == "sanctum")
	await frame("hud-sanctum")
	assert(game.use_sanctum_sigil())
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game.enter_dungeon(site)
	game.notification_time = 0
	for enemy in game.enemies:
		enemy.node.queue_free()
	game.enemies.clear()
	game._spawn_enemy(game.player_point + Vector2(2.3, 0), 0)
	game.select_target(game.enemies[0])
	await frames()
	await click(ui.spell_buttons["fire"])
	assert(game.cooldowns.fire > 0)
	assert(ui.target_panel.visible and not ui.spell_status.fire.text.is_empty())
	await frame("hud-combat")
	game.mana = 0
	await frame("hud-low-resource")
	assert(ui.spell_warnings.nova.visible)
	game.clear_target()
	await frames()
	assert(not ui.target_panel.visible)
	game.state = "title"
	game.choose_class("sword")
	game.state = "playing"
	game.has_journey = true
	await frame("hud-sword")
	assert(ui.previous_class == "sword" and ui.spell_buttons.has("strike"))
	game.state = "title"
	game.choose_class("spellsword")
	game.state = "playing"
	game.has_journey = true
	await frame("hud-spellsword")
	assert(game.customize_character({"name": "A Very Patient Wanderer"}))
	game._generate_surface(Vector2(game.world.start), false)
	await frame("hud-long-name")
	for window_size in [Vector2i(1024, 768), Vector2i(1600, 900)]:
		root.size = window_size
		await frame("hud-%sx%s" % [window_size.x, window_size.y])
		print("HUD window %s / canvas %s / capture %s" % [root.size, ui.hud.size, root.get_texture().get_image().get_size()])
	root.size = Vector2i(1280, 800)
	await frames()
	await hover(ui.spell_buttons["blink"])
	await frame("hud-ability-tooltip")
	print("PASS: native HUD captures, pointer-driven abilities/utilities/map/sigil, cooldowns, target/resource states, contextual prompts, modal visibility and layout at three window sizes")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func click(button: Button) -> void:
	assert(button.is_visible_in_tree() and not button.disabled)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		root.push_input(event, true)
		await process_frame
	await frames()

func frames() -> void:
	for index in range(6):
		await process_frame

func hover(button: Button) -> void:
	var event := InputEventMouseMotion.new()
	event.position = button.get_global_rect().get_center()
	root.push_input(event, true)
	await create_timer(.8).timeout

func key(code: Key) -> void:
	game.set_process_unhandled_key_input(true)
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await frames()
	game.set_process_unhandled_key_input(false)

func frame(label: String) -> void:
	await frames()
	if ui.hud.visible:
		var bounds := Rect2(Vector2.ZERO, ui.hud.size)
		for panel in [ui.action_dock, ui.location_panel, ui.map_panel, ui.target_panel, ui.message_panel, ui.interaction_panel]:
			if panel.visible:
				assert(bounds.encloses(panel.get_global_rect()), "%s is outside the viewport in %s" % [panel.name, label])
		for button in ui.hotbar.get_children():
			assert(ui.action_dock.get_global_rect().encloses(button.get_global_rect()))
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
