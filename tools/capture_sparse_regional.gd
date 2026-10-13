extends SceneTree

const Game = preload("res://scripts/game.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
var game
var directory := "res://artifacts/sparse-regional"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory.path_join("preview-saves")
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	call_deferred("capture")

func capture() -> void:
	game.start_run(0, 5)
	var marker := {}
	var origin := {}
	for x in range(-2, 3):
		for y in range(-2, 3):
			var region: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE)
			if region.city.is_empty() and marker.is_empty():
				var candidate: Dictionary = Sites.plan(game.world, region, game.exploration.catalog)
				if not candidate.is_empty():
					marker = candidate
			if not region.city.is_empty() and region.dungeons.is_empty() and origin.is_empty():
				origin = region
	assert(not marker.is_empty() and not origin.is_empty())
	game._generate_surface(Vector2(marker.approach[0], marker.approach[1]), false)
	game._clear_actors()
	game.grounded = true
	game.exploration.sync()
	for reverse in [false, true]:
		game.camera_yaw = PI / 4 + (PI if reverse else 0)
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
		await frame("town-free-clue-" + ("reverse" if reverse else "front"))
	game.interact()
	assert(game.state == "discovery_reader")
	await frame("town-free-clue-reader")
	game.exploration.close()
	var book: Dictionary = origin.city.books[0]
	game._generate_surface(book.approach, false)
	game._clear_actors()
	game.grounded = true
	game.interact()
	assert(game.state == "reader")
	var record: Dictionary = game.exploration.history.records[Sites.region_key(game.world, origin)]
	assert(not origin.dungeons.any(func(site): return site.id == record.site_id))
	await frame("neighboring-dungeon-ledger")
	game.expansion.close_lore()
	game.expansion.toggle_journal()
	game.exploration.read_history(record.region_id)
	assert(game.state == "discovery_reader")
	await frame("neighboring-dungeon-history")
	FileAccess.open(directory.path_join("targets.json"), FileAccess.WRITE).store_string(JSON.stringify({"clue": marker, "history": record}, "  "))
	print("PASS: five actual town-free source-family clue/opposing-camera/E and neighboring-dungeon ledger/journal views; target identities in targets.json")
	game.queue_free()
	await process_frame
	quit()

func frame(label: String) -> void:
	for index in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)
