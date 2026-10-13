extends SceneTree

const Game = preload("res://scripts/game.gd")
const Content = preload("res://scripts/world_content.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/places-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	var city: Dictionary = game.world.nearest_site(game.player_point, "city")
	var visited := {}
	for house in city.houses:
		var place: Dictionary = game.interiors.describe(city, house)
		if visited.has(place.type):
			continue
		visited[place.type] = true
		game._generate_surface(place.approach)
		game.notification_time = 0
		await frame("entrance-" + place.type)
		assert(game.interiors.enter(game.interiors.target()))
		game.notification_time = 0
		await frame("interior-" + place.type)
		game.target_yaw = PI * 1.25
		game.camera_yaw = game.target_yaw
		game._snap_camera()
		game.interiors.view.update_camera(game.camera_yaw)
		await frame("interior-" + place.type + "-reverse")
		var definition: Dictionary = game.InteriorArea.content.get_entry("interiors", place.type)
		assert(game.interiors.current.layout_id in definition.layouts.map(func(layout): return layout.id))
		if game.dungeon.rest_point != Vector2.ZERO:
			game.player_point = game.dungeon.rest_point
			game.hp = 20
			game.interact()
			assert(game.hp == game.max_hp)
		game.player_point = game.dungeon.readables[0].approach
		game.interact()
		assert(game.state == "reader")
		await frame("interior-reader-" + place.type)
		game.expansion.close_lore()
		assert(game.interiors.leave())
	assert(visited.size() == Content.new().entries("interiors").size())
	var inn: Dictionary = game.interiors.describe(city, city.houses[1])
	game._generate_surface(inn.approach)
	assert(game.interiors.enter(game.interiors.target()))
	game.notification_time = 0
	game._clear_actors()
	for index in range(game.EnemyCatalog.TYPES.size()):
		game._spawn_enemy(Vector2(3 + index % 5 * 2.6, 5 + int(index / 5) * 4), index, "preview:%s" % index)
		game.enemies[-1].node.visible = true
	game.player_point = Vector2(8, 7)
	game.target_yaw = PI / 4
	game.camera_yaw = game.target_yaw
	game._snap_camera()
	game.camera.size = 19
	game.interiors.view.update_camera(game.camera_yaw)
	await frame("enemies-catalogue")
	for index in range(game.EnemyCatalog.TYPES.size()):
		game.select_target(game.enemies[index])
		await frame("enemy-" + game.EnemyCatalog.TYPES[index].id)
	game._clear_actors()
	game.interiors.leave()
	game._generate_surface(Vector2(game.world.start))
	await frame("wildlife-town")
	print("PASS: native house entrances, every interior from both camera sides, readable/rest interactions, imported enemy variants and shared peaceful wildlife")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func frame(label: String) -> void:
	for index in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
