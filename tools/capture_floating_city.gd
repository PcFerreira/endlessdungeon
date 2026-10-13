extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://floating-city-preview-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("capture")

func frame(name: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/floating-city-%s.png" % name) == OK)

func capture() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.has_journey = false
	game.state = "title"
	game.begin_journey()
	assert(game.location_name() == "Lanternwake" and game.enemies.is_empty())
	await frame("arrival")
	var hub: Dictionary = game.world.hub.city_record()
	game.notification_time = 0
	game.camera.size = 52
	game.camera_focus = Vector3(hub.cell.x, hub.height, hub.cell.y + 4)
	game._update_camera(0)
	await frame("halloween-overview")
	game.player_point = hub.houses[0].approach
	game._snap_camera()
	game.camera.size = 18
	game.interact()
	assert(game.state == "hub_board")
	await frame("guild-charter")
	game.floating_hub.close()
	game.player_point = hub.outdoor_lots[0].approach
	game._snap_camera()
	game.camera.size = 18
	assert(game.inventory.add("gold_coin", 10))
	game.interact()
	assert(game.state == "store")
	assert(game.stores.buy("health_potion"))
	await frame("market-purchase")
	game.stores.close()
	game.player_point = game.world.hub.portal - Vector2.DOWN
	game._snap_camera()
	game.camera.size = 20
	await frame("worldgate")
	game.player_point = game.floating_hub.portal_point("sanctum")
	game._snap_camera()
	game.camera.size = 25
	game.notification_time = 0
	await frame("portal-court")
	game.interact()
	assert(game.layer == "sanctum")
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	game.notification_time = 0
	await frame("sanctum-lanternwake-gate")
	game.interact()
	assert(game.floating_hub.active())
	assert(game.floating_hub.set_theme("arcane"))
	game.camera.size = 52
	game.camera_focus = Vector3(hub.cell.x, hub.height, hub.cell.y + 4)
	game._update_camera(0)
	await frame("arcane-overview")
	assert(game.world.hub.houses == hub.houses and game.world.hub.markets == hub.outdoor_lots)
	assert(game.floating_hub.set_theme("halloween"))
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: native Lanternwake arrival, seasonal layouts, guild/market, connected Portal Court and actual Sanctum Lanternwake gate travel")
	quit()
