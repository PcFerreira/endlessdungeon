extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/character-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.state = "title"
	game.open_character_menu()
	await frame("character-customization")
	for class_id in game.CharacterBuild.CLASSES:
		game.close_character_menu()
		game.choose_class(class_id)
		game.open_character_menu()
		for style in game.CharacterProfile.CLOTHING[class_id]:
			game.customize_character({"costume": style})
			game.interface.previous_state = ""
			await frame("clothing-%s-%s" % [class_id, style])
	game.close_character_menu()
	game.choose_class("mage")
	game.open_character_menu()
	var premades: Array = game.CharacterProfile.premades()
	for index in range(premades.size()):
		game.customize_character({"model": premades[index].id})
		game.interface.previous_state = ""
		await frame("premade-%s" % index)
	game.close_character_menu()
	game.begin_journey()
	await frame("premade-world")
	game.player_mesh.animate(true, true)
	await frame("premade-walk")
	game.player_mesh.animate(false, true)
	game.state = "title"
	game.customize_character({"model": "custom", "costume": "class_default"})
	game.open_character_menu()
	game.customize_character({"name": "Mira", "ancestry": "elf", "skin": 3, "hair": 2, "outfit": 4, "head": "long"})
	game.interface.previous_state = ""
	await frame("character-elf")
	game.close_character_menu()
	game.choose_class("sword")
	game.customize_character({"name": "Dorin", "ancestry": "dwarf", "head": "beard", "outfit": 2})
	game.open_character_menu()
	await frame("character-dwarf")
	game.close_character_menu()
	game.begin_journey()
	for id in ["oak_chair", "rune_lantern", "wool_rug", "ember_shard", "iron_sword", "traveler_coat", "silver_charm"]:
		game.inventory.add(id, 1)
	game.equip_item("traveler_coat")
	game.equip_item("iron_sword")
	game.hp = 65
	game.toggle_inventory()
	game.interface.inventory_selected = "health_potion"
	await frame("inventory-consumable")
	game.interface.inventory_selected = "rune_lantern"
	game.interface.inventory_filter = 3
	game.interface.previous_state = ""
	await frame("inventory-furnishings")
	game.toggle_inventory()
	assert(game.use_sanctum_sigil())
	game.toggle_inventory()
	await frame("inventory-at-home")
	game.toggle_inventory()
	game.state = "paused"
	await frame("character-pause")
	print("PASS: captured nine class clothing styles, registry premades, world/walk, creator, ancestry previews, backpack/equipment, furnishings, home inventory, and pause controls")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func frame(label: String) -> void:
	for index in range(4):
		await process_frame
	RenderingServer.force_draw()
	if game.state == "character":
		check_preview(game.interface.overlay)
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)

func check_preview(node: Node) -> void:
	if node is SubViewport:
		var pixels: Image = node.get_texture().get_image()
		var visible := 0
		for x in range(0, pixels.get_width(), 4):
			for y in range(0, pixels.get_height(), 4):
				if pixels.get_pixel(x, y).a > .5:
					visible += 1
		assert(visible > 30, "The live character preview must render visible geometry")
	for child in node.get_children():
		check_preview(child)
