extends SceneTree

const Game = preload("res://scripts/game.gd")
const Catalog = preload("res://scripts/dimension_catalog.gd")
const Minimap = preload("res://scripts/minimap.gd")
var game
var directory := "user://dimension-preview-%s" % Time.get_ticks_usec()
var output := ""
var frames: Array[Dictionary] = []
var site_views := false
var population_views := false
var atlas_only := false

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("capture")

func source_hashes() -> Dictionary:
	var paths: Array[String] = ["scripts/game.gd", "scripts/finite_world.gd", "scripts/dimension_catalog.gd", "scripts/dimension_terrain.gd", "scripts/dimension_constructions.gd", "scripts/dimension_population.gd", "scripts/dimension_travel.gd", "scripts/minimap.gd", "scripts/interface.gd", "scripts/surface_location_view.gd", "scripts/town_voxel_models.gd", "scripts/world_view.gd", "scripts/actor_models.gd", "scripts/enemy_models.gd", "scripts/creature_models.gd", "scripts/expansion.gd", "scripts/biome_catalog.gd", "config/dimension_constructions.json", "config/town_voxel_runtime.json", "config/town_architecture.json", "config/biomes.json", "tools/capture_dimension.gd"]
	paths.append_array(["scripts/render_warmup.gd", "scripts/streaming_data.gd"])
	paths.append_array(["scripts/enemy_catalog.gd", "config/world_content.json", "assets/bundles/catalog.json", "config/content_edits.json"])
	paths.append_array(["scripts/biome_models.gd", "config/biome_art.json", "scripts/render_cache.gd", "assets/render_cache/catalog.json"])
	for name in DirAccess.get_files_at("res://config/dimensions"):
		if name.ends_with(".json"):
			paths.append("config/dimensions/" + name)
	var hashes := {}
	for path in paths:
		assert(FileAccess.file_exists("res://" + path))
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes

func atlas_control():
	var maps: Array = game.interface.find_children("*", "Control", true, false).filter(func(node): return node.get_script() == Minimap and node.world_map_mode)
	assert(maps.size() == 1)
	return maps[0]

func wait_renderer() -> void:
	var count := 0
	while game.render_warmup.busy:
		await process_frame
		count += 1
		assert(count < 600, "Native renderer warmup must finish before a gallery frame")

func frame(name: String, site: Dictionary = {}) -> void:
	var camera_size: float = game.render_warmup.camera_size_before if game.render_warmup.busy and game.camera.size >= 160 else game.camera.size
	var camera_transform: Transform3D = game.camera.transform
	await wait_renderer()
	game.camera.size = camera_size
	game.camera.transform = camera_transform
	for index in range(24):
		await process_frame
	assert(not game.render_warmup.busy and game.warmup_overlay == null, "Actual loading overlay must be gone before an accepted gallery frame")
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)
	var area: Dictionary = game.world.area_at(Vector2i(game.player_point.round())) if game.world.has_method("area_at") else {}
	var speech := {}
	if game.state == "dialogue":
		speech = {"speaker_id": game.expansion.speaker.id, "speaker_name": game.expansion.speaker.name, "text": game.expansion.dialogue_text}
	var creatures: Array[Dictionary] = []
	for enemy in game.enemies:
		if str(enemy.get("grounds", {}).get("area_id", "")).begins_with("dimension:"):
			creatures.append({"id": enemy.id, "species": enemy.species, "hp": enemy.hp, "point": [enemy.point.x, enemy.point.y], "grounds": enemy.grounds.area_id})
	var hovered: String = atlas_control().hovered_site_id if game.state == "map" else ""
	frames.append({"name": name, "point": [game.player_point.x, game.player_point.y], "layer": game.layer, "state": game.state, "loaded_chunks": game.world.chunks.size(), "area": area.get("name", ""), "site_id": site.get("id", ""), "site_type": site.get("type", ""), "site_name": site.get("name", ""), "dialogue": speech, "enemies": creatures, "hovered_site_id": hovered, "waypoint_id": game.waypoint.get("id", ""), "camera_size": camera_size, "renderer_ready": not game.render_warmup.busy, "loading_overlay_visible": game.warmup_overlay != null, "known_realm_sites": game.exploration.knowledge.sites.keys().filter(func(id): return str(id).begins_with("dimension:" + Catalog.default_id() + ":site:")).size()})

func capture() -> void:
	var sources := source_hashes()
	var definition := Catalog.definition()
	output = "res://artifacts/" + definition.id
	for argument in OS.get_cmdline_user_args():
		if argument == "--site-views":
			site_views = true
		elif argument == "--population-views":
			population_views = true
		elif argument == "--atlas-only":
			atlas_only = true
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) == OK)
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(12345)
	game.has_journey = true
	game.state = "playing"
	await wait_renderer()
	assert(game.use_sanctum_sigil())
	game.player_point = Vector2(definition.sanctum_portal[0], definition.sanctum_portal[1])
	game.camera.size = 18
	game._snap_camera()
	if not atlas_only:
		await frame("sanctum-hub-gate")
	assert(game.floating_hub.from_sanctum())
	assert(game.floating_hub.active())
	if not atlas_only:
		await frame("hub-arrival")
	game.player_point = game.floating_hub.portal_point("dimension")
	game._snap_camera()
	if not atlas_only:
		await frame("hub-dimension-gate")
	assert(game.dimension.enter())
	assert(game.world.dimension_id == definition.id and game.layer == "overworld")
	game.camera.size = 30
	if atlas_only:
		await capture_atlases()
		var areas: Array[Dictionary] = game.world.authored_areas()
		assert(game.dimension.return_to_hub())
		await finish(definition, areas, sources)
		return
	await frame("arrival")
	game.toggle_map()
	assert(game.state == "map")
	await frame("atlas")
	game.toggle_map()
	var areas: Array[Dictionary] = game.world.authored_areas()
	assert(not areas.is_empty())
	for area in areas:
		game.notification_time = 0
		var point: Vector2 = game.world.safe_position(Vector2(area.label_cell))
		assert(game.world.area_at(Vector2i(point.round())).id == area.id)
		game._generate_surface(point, false)
		game.camera.size = 30
		game.camera_yaw = PI / 4
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		await frame(area.id + "-east")
		game.camera_yaw = PI * 5 / 4
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		await frame(area.id + "-west")
		assert(game.world.chunks.size() <= 25, "Finite gallery must retain bounded live geometry")
	if site_views:
		for site in game.world.authored_sites():
			var distance := 10 if site.type in ["village", "castle"] else 8
			var point: Vector2 = game.world.safe_position(Vector2(site.cell) + Vector2(0, distance))
			game._generate_surface(point, false)
			game.notification_time = 0
			game.camera.size = 30
			game.camera_yaw = PI / 4
			game.target_yaw = game.camera_yaw
			game._snap_camera()
			game.camera_focus = game.to_world(Vector2(site.cell)) + Vector3.UP
			game._update_camera(0.0)
			await frame("site-" + str(site.id).get_slice(":site:", 1), site)
			assert(game.world.chunks.size() <= 25)
	if population_views:
		game.population.sync()
		for area in areas:
			var residents: Array = game.population.recipes.filter(func(actor): return game.world.area_at(Vector2i(actor.home.round())).get("id", "") == area.id)
			assert(not residents.is_empty(), "Each authored area needs an actual resident for dialogue capture")
			var recipe: Dictionary = residents[0]
			game._generate_surface(game.world.safe_position(recipe.home + Vector2.RIGHT), false)
			game.population.sync()
			assert(game.population.actors.has(recipe.id))
			var actor: Dictionary = game.population.actors[recipe.id]
			game.player_point = game.world.safe_position(actor.point + Vector2.RIGHT, 2)
			game.camera.size = 24
			game.notification_time = 0
			game._snap_camera()
			assert(game.population.interact() and game.state == "dialogue")
			assert(game.expansion.speaker.id == actor.id and not game.expansion.dialogue_text.is_empty())
			await frame("dialogue-" + area.id, game.world.nearest_site(actor.point))
			game.expansion.close_lore()
			assert(game.state == "playing" and game.world.chunks.size() <= 25)
		for area in areas:
			var grounds: Array = definition.get("encounters", []).filter(func(ground): return game.world.area_at(Vector2i(ground.cell[0], ground.cell[1])).get("id", "") == area.id)
			assert(not grounds.is_empty(), "Each authored area needs an actual encounter for creature capture")
			var ground: Dictionary = grounds[0]
			var point := Vector2(ground.cell[0], ground.cell[1])
			game._generate_surface(game.world.safe_position(point + Vector2(0, 12), 16), false)
			var id: String = "dimension:%s:grounds:%s" % [definition.id, ground.id]
			var enemies: Array = game.enemies.filter(func(enemy): return enemy.get("grounds", {}).get("area_id", "") == id and enemy.hp > 0)
			assert(not enemies.is_empty(), "The gallery must show a real live authored enemy rather than a preview model")
			assert(enemies.all(func(enemy): return is_instance_valid(enemy.node) and enemy.node.is_inside_tree()))
			game.camera.size = 24
			game.notification_time = 0
			game._snap_camera()
			await frame("encounter-" + area.id)
			assert(game.world.chunks.size() <= 25)
	game.toggle_map()
	assert(game.state == "map")
	await frame("atlas-observed")
	if site_views:
		var atlas = atlas_control()
		var known: Array[Dictionary] = atlas.map_sites()
		assert(known.size() >= 2)
		var motion := InputEventMouseMotion.new()
		motion.position = atlas._map_point(Vector2(known[0].cell))
		atlas._gui_input(motion)
		assert(atlas.hovered_site_id == known[0].id)
		await frame("atlas-hover")
		atlas.mouse_exited.emit()
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = atlas._map_point(Vector2(known[-1].cell))
		atlas._gui_input(click)
		assert(game.state == "playing" and game.waypoint.id == known[-1].id)
		await process_frame
		game.toggle_map()
		await frame("atlas-waypoint")
	game.toggle_map()
	var terrain: Dictionary = definition.get("terrain", {})
	var features: Array[Dictionary] = []
	if terrain.has("coast"):
		var cell: Array = terrain.coast.polygon[0]
		features.append({"name": "coast-wide", "point": Vector2(cell[0], cell[1]), "search": 64})
	if not terrain.get("rivers", []).is_empty():
		var path: Array = terrain.rivers[0].path
		var cell: Array = path[mini(2, path.size() - 1)]
		features.append({"name": "river-bank-wide", "point": Vector2(cell[0], cell[1]), "search": 24})
	if not terrain.get("lakes", []).is_empty():
		var lake: Dictionary = terrain.lakes[0]
		features.append({"name": "lake-bank-wide", "point": Vector2(lake.center[0] + lake.radii[0], lake.center[1]), "search": 24})
	if not terrain.get("hills", []).is_empty():
		var cell: Array = terrain.hills[0].center
		features.append({"name": "hill-wide", "point": Vector2(cell[0], cell[1]), "search": 24})
	for feature in features:
		var point: Vector2 = game.world.safe_position(feature.point, feature.search)
		game._generate_surface(point, false)
		game.notification_time = 0
		game.camera.size = 36
		game.camera_yaw = PI / 4
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		await frame(feature.name)
		assert(game.world.chunks.size() <= 25)
	assert(game.dimension.return_to_hub())
	assert(game.floating_hub.active())
	await frame("hub-return")
	await finish(definition, areas, sources)

func capture_atlases() -> void:
	for site in game.world.authored_sites():
		assert(game.exploration.knowledge.remember(site, "seen", str(game.run_seed)))
	game.toggle_map()
	assert(game.state == "map")
	await frame("atlas-observed")
	var atlas = atlas_control()
	var known: Array[Dictionary] = atlas.map_sites()
	var motion := InputEventMouseMotion.new()
	motion.position = atlas._map_point(Vector2(known[0].cell))
	atlas._gui_input(motion)
	assert(atlas.hovered_site_id == known[0].id)
	await frame("atlas-hover")
	atlas.mouse_exited.emit()
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = atlas._map_point(Vector2(known[-1].cell))
	atlas._gui_input(click)
	assert(game.state == "playing" and game.waypoint.id == known[-1].id)
	await process_frame
	game.toggle_map()
	await frame("atlas-waypoint")
	game.toggle_map()

func finish(definition: Dictionary, areas: Array[Dictionary], sources: Dictionary) -> void:
	var after := source_hashes()
	var stable := sources == after
	var file := FileAccess.open(output.path_join("native-gallery.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"dimension_id": definition.id, "map_version": definition.map_version, "content_version": definition.get("content_version", 1), "definition": definition, "source_sha256": sources, "source_sha256_after": after, "source_stable": stable, "map_bounds": definition.bounds, "area_count": areas.size(), "site_count": definition.sites.size(), "site_views": site_views, "population_views": population_views, "atlas_only": atlas_only, "frames": frames}, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	if not stable:
		push_error("Native gallery source changed during capture; reject this run")
		quit(1)
		return
	print("PASS: native actual portal travel, finite %s and bounded chunks" % ("three-atlas label refresh" if atlas_only else "arrival/atlas, %s authored areas in opposing cameras" % areas.size()))
	quit()
