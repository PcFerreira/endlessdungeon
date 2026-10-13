extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/quest-preview-saves"
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	call_deferred("capture")

func frame(label: String, end: bool = false) -> void:
	for index in range(5):
		await process_frame
	if end:
		var overlay: Control = game.expansion.overlay if game.state == "reader" else game.exploration.quests.overlay
		for scroll in overlay.find_children("*", "ScrollContainer", true, false):
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK)

func stand(point: Vector2) -> void:
	game.player_point = point
	game.player_y = game.dungeon.ground_height(point)
	game.player.position = game.to_world(point)
	game.grounded = true
	game._snap_camera()
	if game.layer == "dungeon":
		game.dungeon_view.reveal(game.dungeon, point)
		game.dungeon_view.update_camera(game.camera_yaw)

func capture() -> void:
	game.set_physics_process(false)
	game.start_run(91)
	game.begin_journey()
	game._clear_actors()
	var region: Dictionary = game.world.region_at(game.world.start)
	var giver: Dictionary = game.life.residents().filter(func(actor): return actor.id == region.city.residents[0].id)[0]
	stand(giver.point)
	assert(game.expansion.open_dialogue(giver))
	var ui = game.exploration.quests
	var offer: Dictionary = ui.for_resident(giver)
	assert(not offer.is_empty())
	assert(ui.open_resident(giver))
	await frame("quest-offer")
	assert(ui.accept(offer.id))
	await frame("quest-accepted")
	ui.close()
	game.expansion.close_lore()
	stand(region.city.books[0].approach)
	game.interact()
	assert(ui.state.records[offer.id].ledger_read)
	await frame("quest-local-ledger", true)
	game.expansion.close_lore()
	var site: Dictionary = region.dungeons.filter(func(candidate): return candidate.id == offer.site_id)[0]
	game.enter_dungeon(site)
	game._clear_actors()
	stand(game.dungeon.readables[0].approach)
	ui.sync_marker()
	assert(ui.marker.visible)
	await frame("quest-archive-marker")
	game.interact()
	assert(ui.state.records[offer.id].phase == "return")
	await frame("quest-inscription", true)
	game.expansion.close_lore()
	game.expansion.toggle_journal()
	ui.read_saved(offer.id)
	await frame("quest-journal-return")
	ui.close()
	game.expansion.close_lore()
	game.return_to_surface()
	game._generate_surface(Vector2(region.city.cell), false)
	game._clear_actors()
	giver = game.life.residents().filter(func(actor): return actor.id == giver.id)[0]
	stand(giver.point)
	assert(game.expansion.open_dialogue(giver))
	assert(ui.open_resident(giver))
	await frame("quest-report")
	assert(ui.report(offer.id, offer.answer))
	assert(game.inventory.count(offer.reward.item) == 1)
	await frame("quest-completed", true)
	ui.close()
	game.expansion.close_lore()
	assert(game.use_sanctum_sigil())
	var plot: Rect2i = game.dungeon.furnishing_plots[0]
	assert(game.furnishings.place(offer.reward.item, Vector2(plot.get_center()), 0, game.inventory, game.player_point), game.furnishings.error)
	game.refresh_sanctum_furnishings()
	await frame("quest-reward-at-home")
	print("PASS: native local quest offer, real ledger/archive marker/inscription, return comparison, completed record and usable Sanctum furnishing reward")
	game.queue_free()
	await process_frame
	await create_timer(.1).timeout
	quit()
