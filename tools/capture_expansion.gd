extends SceneTree

const Game = preload("res://scripts/game.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Lore = preload("res://scripts/lore_catalog.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/expansion-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.begin_journey()
	var cities := {}
	var facets := {}
	for x in range(-12,13):
		for y in range(-12,13):
			var region: Dictionary = game.world.region_at(Vector2i(x,y) * Game.World.REGION_SIZE)
			cities[region.city.archetype_id] = region.city
			if not region.facet.is_empty():
				facets[region.facet] = region
	assert(cities.size() == 6 and facets.size() == 2)
	for id in cities:
		var city: Dictionary = cities[id]
		game._generate_surface(Vector2(city.cell) + Vector2(0,3), false)
		game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
		await frame(id)
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
		await frame(id + "-reverse")
	for id in facets:
		var region: Dictionary = facets[id]
		game._generate_surface(Vector2(region.facet_center), false)
		game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
		await frame(id)
	game._generate_surface(Vector2(game.world.start), false)
	var site: Dictionary = game.world.region_at(game.world.start).dungeons[0].duplicate(true)
	for id in Areas.DUNGEONS:
		site.family = id
		site.floors = 20
		game.active_dungeon = site
		game.layer = "dungeon"
		game.depth = 1
		game._generate_floor(false)
		for cell in game.dungeon_view.cell_nodes:
			game.dungeon_view.cell_nodes[cell].visible = true
		game.player_point = game.dungeon.readables[0].approach
		game._snap_camera()
		await frame(id)
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.dungeon_view.update_camera(game.camera_yaw)
		await frame(id + "-reverse")
	var roles := {}
	for id in cities:
		for resident in cities[id].residents:
			if roles.has(resident.role):
				continue
			roles[resident.role] = true
			game._generate_surface(resident.approach, false)
			assert(game.expansion.open_dialogue(resident))
			game.expansion.talk("topic_companions" if resident.role == "retired_delver" else "topic_dawn")
			await frame("dialogue-" + resident.role)
			game.expansion.close_lore()
	game._generate_surface(Vector2(game.world.start), false)
	for id in Lore.BOOKS:
		assert(game.expansion.read_book(id))
		await frame(id)
		if id == "book_bed_ledger":
			for node in game.expansion.overlay.find_children("*", "ScrollContainer", true, false):
				node.scroll_vertical = 10000
			await frame(id + "-last-page")
		game.expansion.close_lore()
	game.expansion.toggle_journal()
	await frame("field-journal")
	game.expansion.close_lore()
	game.state = "paused"
	await frame("expansion-pause")
	print("PASS: rendered six towns, six dungeon families in both camera directions, two facets, four NPC roles, six readers, field journal and pause menu")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func frame(label: String) -> void:
	for index in range(5):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
