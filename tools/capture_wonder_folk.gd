extends SceneTree

const Voxels = preload("res://scripts/voxel_kit.gd")
const SOURCES := ["res://config/wonder_folk.json", "res://scripts/wonder_catalog.gd", "res://scripts/wonder_npc_catalog.gd", "res://scripts/wonder_models.gd", "res://scripts/actor_models.gd", "res://scripts/wilderness_roamers.gd", "res://scripts/world_life.gd", "res://scripts/world_life_view.gd", "res://scripts/enemy_catalog.gd", "res://scripts/enemy_models.gd", "res://scripts/monster_areas.gd", "res://scripts/dungeon.gd", "res://scripts/stores.gd", "res://scripts/expansion.gd", "res://scripts/game.gd", "res://scripts/world_view.gd", "res://scripts/interface.gd", "res://scripts/render_warmup.gd"]
var catalog
var models
var stage: Node3D
var camera: Camera3D
var game
var frames := []
var examples := {}
var directory := "res://artifacts/wonder-folk/capture-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	assert(DisplayServer.get_name() != "headless", "Wonder folk capture needs the native renderer")
	root.size = Vector2i(1280, 800)
	AudioServer.set_bus_mute(0, true)
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var source_before := _source_hashes()
	catalog = load("res://scripts/wonder_catalog.gd")
	models = load("res://scripts/wonder_models.gd")
	assert(catalog != null and models != null)
	_setup_gallery()
	assert(await _gallery())
	stage.queue_free()
	await process_frame
	assert(await _world())
	assert(frames.size() == 27, "Every planned native gallery and gameplay view must be captured")
	var source_after := _source_hashes()
	assert(source_before == source_after, "Wonder art and gameplay sources must stay unchanged through the complete native fixture")
	var manifest := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"resolution": [1280, 800], "seed": 91, "edition": 6, "catalog_sha256": JSON.stringify(catalog.DATA).sha256_text(), "source_before": source_before, "source_after": source_after, "frames": frames}, "\t"))
	manifest.close()
	game.queue_free()
	await process_frame
	print("CAPTURE_DIRECTORY: " + ProjectSettings.globalize_path(directory))
	print("PASS: %s original wonder-folk native gallery and actual encounter views" % frames.size())
	quit()

func _source_hashes() -> Dictionary:
	var result := {}
	for path in SOURCES:
		var fingerprint := FileAccess.get_sha256(path)
		assert(fingerprint.length() == 64, "Missing capture dependency: " + path)
		result[path] = fingerprint
	return result

func _setup_gallery() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202e39")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e8ecf2")
	environment.environment.ambient_light_energy = .7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.1
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	stage.add_child(camera)

func _gallery() -> bool:
	var definitions: Dictionary = catalog.DATA.npcs.duplicate()
	definitions.merge(catalog.DATA.creatures)
	for family in ["block_voxel", "flat_lowpoly"]:
		var gallery := Node3D.new()
		stage.add_child(gallery)
		var actors: Array[Node3D] = []
		var ids: Array = definitions.keys()
		for index in range(ids.size()):
			var id: String = ids[index]
			var actor: Node3D = models.create(id, family, 71)
			actor.position = Vector3((index % 4 - 1.5) * 1.9, 0, (index / 4 - .5) * 2.4)
			gallery.add_child(actor)
			actors.append(actor)
			var floor := Voxels.cube(Vector3(1.5, .08, 1.55), Color("415662"))
			floor.position = actor.position + Vector3(0, -.04, 0)
			gallery.add_child(floor)
			var label := Label3D.new()
			label.text = definitions[id].name
			label.position = actor.position + Vector3(0, -.12, .87)
			label.font_size = 26
			label.pixel_size = .004
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.modulate = Color("e0d5b5")
			gallery.add_child(label)
		for direction in [1, -1]:
			camera.position = Vector3(direction * 5, 6, direction * 10)
			camera.look_at(Vector3(0, .6, 0))
			await _frame("gallery-%s-%s" % [family, "front" if direction == 1 else "back"], {"family": family, "entries": ids, "mode": "Idle"})
		for index in range(actors.size()):
			var players: Array[Node] = actors[index].find_children("*", "AnimationPlayer", true, false)
			assert(not players.is_empty())
			var player: AnimationPlayer = players[0]
			var mode := "Walk" if index % 2 == 0 else ("Wave" if index < 4 else "Attack")
			assert(player.has_animation(mode))
			player.play(mode)
			player.advance(.3)
			player.pause()
		camera.position = Vector3(5, 6, 10)
		camera.look_at(Vector3(0, .6, 0))
		await _frame("gallery-%s-motion" % family, {"family": family, "entries": ids, "mode": "Walk / Wave / Attack"})
		gallery.queue_free()
		await process_frame
	return true

func _world() -> bool:
	var fixture_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixtures="):
			fixture_path = argument.trim_prefix("--fixtures=")
	assert(not fixture_path.is_empty() and FileAccess.file_exists(fixture_path), "Supply the accepted actual encounter fixture using --fixtures=<examples.json>")
	examples = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	assert(examples.npcs.size() == 4 and examples.ambient.size() == 2 and examples.enemies.size() == 2)
	game = load("res://scripts/game.gd").new()
	game.records_enabled = false
	game.save_directory = directory.path_join("preview-saves")
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(91, 6)
	game.begin_journey()
	for id in examples.npcs:
		var record: Dictionary = examples.npcs[id]
		_load_example(record)
		assert(game.life.actors.has(record.id) and game.life.actors[record.id].wonder_id == id)
		var actor: Dictionary = game.life.actors[record.id]
		assert(_approach(actor.point, .7).is_finite())
		assert(game.expansion.target().get("id", "") == actor.id)
		await _frame(id + "-world", _context(id, record))
		game.interact()
		assert(game.state == "dialogue" and game.expansion.speaker.id == actor.id)
		game.expansion.talk("topic_work")
		await _frame(id + "-dialogue-work", _context(id, record))
		if not actor.wonder_trade_profile.is_empty():
			game.expansion._trade_wonder()
			assert(game.state == "store" and game.stores.current.wonder_actor == actor.id)
			assert(game.inventory.add("forage_bramble_berries"))
			game.stores._change_mode(true)
			game.stores.selected_item = "forage_bramble_berries"
			game.stores._show()
			await _frame(id + "-trade-before", _context(id, record))
			var coins: int = game.inventory.count("gold_coin")
			assert(game.stores.sell("forage_bramble_berries") and game.inventory.count("gold_coin") > coins)
			game.stores._show()
			await _frame(id + "-trade-sold", _context(id, record))
			game.stores.close()
		else:
			game.expansion.close_lore()
	for id in examples.ambient:
		var record: Dictionary = examples.ambient[id]
		_load_example(record)
		assert(game.life.actors.has(record.id) and game.life.actors[record.id].species == id)
		var actor: Dictionary = game.life.actors[record.id]
		assert(game.life_view.models.has(actor.id) and not game.valid_enemy(actor))
		assert(_approach(actor.point, .9).is_finite())
		await _frame(id + "-peaceful-world", _context(id, record))
		game.camera_yaw += PI
		game.target_yaw = game.camera_yaw
		game._snap_camera()
		game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
		await _frame(id + "-peaceful-reverse", _context(id, record))
	for id in examples.enemies:
		var record: Dictionary = examples.enemies[id]
		_load_example(record)
		var found: Array = game.enemies.filter(func(enemy): return enemy.id == record.id)
		assert(found.size() == 1 and found[0].species == id)
		var enemy: Dictionary = found[0]
		for other in game.enemies.duplicate():
			if other != enemy:
				other.node.queue_free()
				game.enemies.erase(other)
		assert(_approach(enemy.point, .7 if id == "bog_mossback" else 2).is_finite())
		game.select_target(enemy)
		game._update_enemies(.1)
		if id == "bog_mossback":
			assert(not enemy.active)
			await _frame(id + "-neutral-before", _context(id, record).merged({"hp": enemy.hp, "active": enemy.active}))
			game._hit_enemy(enemy, 1)
			enemy.attack = 0
			game._update_enemies(.1)
			assert(enemy.active and enemy.windup > 0)
			await _frame(id + "-retaliation", _context(id, record).merged({"hp": enemy.hp, "active": enemy.active}))
		else:
			enemy.attack = 0
			game._update_enemies(.1)
			assert(enemy.active and enemy.windup > 0)
			await _frame(id + "-hostile-telegraph", _context(id, record).merged({"hp": enemy.hp, "active": enemy.active}))
			for index in range(10):
				game._update_enemies(.1)
			assert(game.projectiles.any(func(shot): return shot.hostile))
			await _frame(id + "-ranged-cast", _context(id, record).merged({"hp": enemy.hp, "active": enemy.active}))
	assert(not examples.dungeon.is_empty())
	var crypt: Dictionary = examples.dungeon
	var cell := Vector2i(crypt.site_cell[0], crypt.site_cell[1])
	var site: Dictionary = game.world.site_by_id(crypt.site_id, cell)
	assert(not site.is_empty() and site.family == crypt.family and crypt.floor <= site.floors)
	game._generate_surface(Vector2(site.cell), false)
	game.enter_dungeon(site)
	if game.depth != crypt.floor:
		game.depth = crypt.floor
		game._generate_floor()
	var husks: Array = game.enemies.filter(func(enemy): return enemy.id == crypt.id)
	assert(husks.size() == 1 and husks[0].species == "choir_husk")
	var husk: Dictionary = husks[0]
	for offset in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
		var point: Vector2 = husk.point + offset
		if game.dungeon.walkable(point) and game.dungeon.line_clear(point, husk.point):
			game.player_point = point
			break
	game.dungeon_zoom = 10
	game.camera_yaw = PI / 4
	game.target_yaw = game.camera_yaw
	game._snap_camera()
	game.dungeon_view.reveal(game.dungeon, game.player_point)
	game.select_target(husk)
	game._update_enemies(.1)
	assert(husk.node.visible)
	await _frame("choir-husk-real-crypt", _context("choir_husk", crypt).merged({"depth": game.depth, "family": game.dungeon.family, "variant": husk.variant}))
	return true

func _load_example(record: Dictionary) -> void:
	game.life.reset(91)
	game._generate_surface(Vector2(record.source[0], record.source[1]), false)
	game.surface_zoom = 10
	game.camera_yaw = PI / 4
	game.target_yaw = game.camera_yaw
	game._snap_camera()
	game.state = "playing"

func _approach(point: Vector2, reach: float) -> Vector2:
	for offset in [Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach), Vector2.ZERO]:
		var candidate: Vector2 = point + offset
		if game.world.walkable(candidate) and game.world.line_clear(candidate, point) and absf(game.world.ground_height(candidate) - game.world.ground_height(point)) < .5:
			game.player_point = candidate
			game._snap_camera()
			game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
			return candidate
	return Vector2.INF

func _context(id: String, record: Dictionary) -> Dictionary:
	return record.merged({"wonder_id": id, "state": game.state, "layer": game.layer, "gold": game.inventory.count("gold_coin"), "hint": game.interaction_hint()})

func _frame(name: String, record: Dictionary) -> void:
	if game != null:
		assert(await _wait_renderer())
		game._snap_camera()
		if game.layer == "overworld":
			game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
	for index in range(8):
		await process_frame
	if game != null:
		assert(not game.render_warmup.busy and game.warmup_overlay == null, "Capture cannot hide behind the live renderer's loading overlay")
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK)
	frames.append(record.merged({"image": name + ".png", "renderer_ready": game == null or not game.render_warmup.busy, "warmup_overlay_clear": game == null or game.warmup_overlay == null, "camera_size": camera.size if game == null else game.camera.size}))
	print("CAPTURE: " + name)

func _wait_renderer() -> bool:
	var count := 0
	while game.render_warmup.busy:
		await process_frame
		count += 1
		assert(count < 600, "The actual renderer must finish its warmup before native acceptance")
	for index in range(2):
		await process_frame
	assert(not game.render_warmup.busy and game.warmup_overlay == null)
	return true
