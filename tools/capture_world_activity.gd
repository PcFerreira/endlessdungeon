extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://world-activity-preview-%s" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var city: Dictionary = game.world.region_at(game.world.start).city
	game.player_point = Vector2(city.cell) + Vector2(6,5)
	game._snap_camera()
	game.camera.size = 22
	for index in range(360):
		game.life.advance(1.0 / 60)
		game.life.step(game.world,game.player_point,1.0 / 60)
		game.life_view.sync(game)
	await frame("activity-guard-watch")
	var merchant: Dictionary = game.life.residents().filter(func(actor): return actor.role == "merchant")[0]
	game.player_point = merchant.point + Vector2(.7,0)
	game._snap_camera()
	game.interact()
	assert(game.state == "dialogue")
	assert(game.inventory.add("ember_shard", 12))
	await frame("activity-merchant-barter")
	game.expansion._trade("health_potion")
	await frame("activity-merchant-purchase")
	game.expansion.close_lore()
	game.player_point = Vector2(city.cell) + Vector2(0,8)
	game._snap_camera()
	game.life.tick = 220
	game.life_view.sync(game)
	await frame("activity-town-market")
	var found := false
	for x in range(-3,4):
		if found:
			break
		for y in range(-3,4):
			var region: Dictionary = game.world.region_at(Vector2i(x,y) * game.world.REGION_SIZE)
			for area in game.world.MonsterAreas.plans(game.world,region):
				game._generate_surface(Vector2(area.cell),false)
				if not game.enemies.is_empty():
					game.player_point = game.world.safe_position(Vector2(area.cell) + Vector2(0,5), 4)
					game._snap_camera()
					game.camera.size = 22
					assert(game.enemies.any(func(enemy): return enemy.has("grounds")))
					await frame("activity-monster-grounds")
					found = true
					break
			if found:
				break
	assert(found)
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: native guard-watch, live merchant barter/purchase, varied town episode and natural monster-grounds captures")
	quit()

func frame(label: String) -> void:
	game.notification_time = 0
	game.world_view.update_visibility(game.player_point,game.player_y,game.camera_yaw)
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
