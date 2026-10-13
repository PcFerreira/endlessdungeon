extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://city-law-preview-%s" % OS.get_process_id()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	game._clear_actors()
	var guard: Dictionary = game.life.residents().filter(func(actor): return actor.role == "guard")[0]
	game.player_point = guard.point + Vector2(0,.5)
	game._snap_camera()
	var node: Node3D = game.Voxels.cube(Vector3(.25,.35,.25),Color("e7be74"))
	node.position = game.to_world(game.player_point)
	game.add_child(node)
	var uid: String = guard.city_id + ":law-preview:lantern"
	game.world_items.register_prop({"uid":uid,"item":"rune_lantern","point":game.player_point,"owner":guard.city_id,"scope":"overworld"},node)
	assert(game.world_items.pickup(uid))
	game.simulate(.1)
	assert(game.state == "guard_demand")
	await frame("law-restitution-demand")
	game.city_law.refuse()
	for index in range(30):
		game.simulate(.1)
	game.life_view.sync(game)
	await frame("law-watch-pursuit")
	assert(game.hp < game.max_hp)
	assert(game.city_law.demand(guard))
	await frame("law-hostile-restitution")
	assert(game.city_law.restitute())
	assert(node.visible)
	await frame("law-property-returned")
	game._generate_surface(Vector2(game.world.start),false)
	var merchant: Dictionary = game.life.residents().filter(func(actor): return actor.role == "merchant")[0]
	game.player_point = merchant.point + Vector2(.5,0)
	game._snap_camera()
	assert(game.inventory.add("gold_coin",12))
	game.interact()
	assert(game.state == "dialogue")
	await frame("law-merchant-currencies")
	game.expansion._trade("health_potion","gold_coin")
	assert(game.inventory.count("gold_coin") == 8)
	await frame("law-merchant-coin-purchase")
	game.expansion.close_lore()
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: native actual theft demand, hostile watch, restitution/source restoration and dual-currency merchant purchase")
	quit()

func frame(label: String) -> void:
	game.notification_time = 0
	game.world_view.update_visibility(game.player_point,game.player_y,game.camera_yaw)
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
