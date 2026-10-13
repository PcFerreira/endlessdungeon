extends "res://tools/capture_micro_biomes.gd"

const LandmarkCatalog = preload("res://scripts/biome_landmark_catalog.gd")
const LANDMARK_EXAMPLES := "res://artifacts/biome-landmarks/plans-seed91.json"
const LANDMARK_SOURCES := ["tools/capture_biome_landmarks.gd", "scripts/biome_landmark_catalog.gd", "scripts/biome_landmark_models.gd", "scripts/biome_landmark_exploration.gd", "config/biome_landmarks.json", LANDMARK_EXAMPLES]
var shot_yaw := PI / 4

func _initialize() -> void:
	super._initialize()
	directory = "res://artifacts/biome-landmarks/native-seed91"
	private_directory = "user://biome-landmark-preview-%s" % Time.get_ticks_usec()

func source_hashes() -> Dictionary:
	var result := super.source_hashes()
	for path in LANDMARK_SOURCES:
		result[path] = FileAccess.get_sha256(path if path.begins_with("res://") else "res://" + path)
	return result

func packed(value):
	if value is Rect2i:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	return super.packed(value)

func load_plans(world) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(LANDMARK_EXAMPLES))
	if not require(data is Dictionary and data.get("seed") == SEED and data.get("edition") == EDITION and data.get("examples") is Dictionary, "Accepted actual landmark examples must match seed91 edition7"):
		return false
	for kind in LandmarkCatalog.KINDS:
		if not require(data.examples.has(kind), "Missing actual landmark: " + kind):
			return false
		var example: Dictionary = data.examples[kind]
		var center := Vector2i(example.center[0], example.center[1])
		var record := LandmarkCatalog.plan(world, Composition.feature(SEED, center))
		if not require(not record.is_empty() and same(packed(record), example), "Fresh authoritative landmark source plan: " + kind):
			return false
		records.append(record)
		print("LOCATED: ", record.id, " center=", record.center, " door=", record.point, " turn=", record.turn)
	return require(records.size() == 8, "All eight genuinely generated landmark kinds")

func marker_proof(record: Dictionary) -> Dictionary:
	var controller = game.exploration.landmarks
	if not controller.markers.has(record.id):
		return {}
	var model: Node3D = controller.markers[record.id]
	var door := model.transform * Vector3(record.door_local.x, 0, record.door_local.y)
	var parts := {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		parts[mesh.name] = {"vertices": arrays[Mesh.ARRAY_VERTEX].size(), "geometry_signature": hash([arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_COLOR]]), "obstructing": mesh.get_meta("obstructing", false)}
	return {"id": record.id, "center": [model.position.x, model.position.y, model.position.z], "world_door": [door.x, door.y, door.z], "turn_radians": model.rotation.y, "source_asset": model.get_meta("source_asset", ""), "visual_family": model.get_meta("visual_family", ""), "representation": model.get_meta("representation", ""), "claimed": model.get_meta("claimed", false), "parts": parts}

func image_frame(label: String, size: float = 22, record: Dictionary = {}) -> bool:
	if not await wait_renderer():
		return false
	game.surface_zoom = size
	game.camera_yaw = shot_yaw
	game.target_yaw = shot_yaw
	game._snap_camera()
	game.camera.size = size
	game.world_view.update_visibility(game.player_point, game.player_y, shot_yaw)
	for index in range(24):
		await process_frame
	if not require(not game.render_warmup.busy and (game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay)), "Actual renderer/overlay readiness before landmark PNG") or not require(source_hashes() == before, "Landmark capture source stability"):
		return false
	RenderingServer.force_draw(false)
	if not require(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Save actual landmark viewport"):
		return false
	frames.append({"image": label + ".png", "point": packed(game.player_point), "camera_size": game.camera.size, "camera_yaw": shot_yaw, "provider": game.world.get_script().resource_path, "layer": game.layer, "state": game.state, "warmup_busy": game.render_warmup.busy, "loading_overlay_absent": game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay), "landmark_model": marker_proof(record) if not record.is_empty() else {}, "visible_landmarks": game.exploration.landmarks.markers.size(), "ambience_profile": game.ambience.profile})
	return true

func visit(record: Dictionary) -> bool:
	game._generate_surface(Vector2(record.approach_far), false)
	game._clear_actors()
	game.grounded = true
	for point in [record.approach, record.point]:
		var next: Vector2 = game.world.move_actor(game.player_point, Vector2(point) - game.player_point)
		if not require(next.is_equal_approx(Vector2(point)), "Supported actual movement through open landmark doorway: " + record.kind):
			return false
		game.player_point = next
		game._snap_camera()
	game.exploration.landmarks.sync(true)
	game.exploration.landmarks.observe()
	if not require(game.exploration.landmarks.target().get("id", "") == record.id and LandmarkCatalog.plan(game.world, Composition.feature(SEED, record.center)) == record, "Actual HubWorld exterior landmark/door equals authoritative plan"):
		return false
	if not await wait_renderer():
		return false
	for index in range(10):
		game.ambience.update(game, 1.0)
	shot_yaw = int(record.turn) * PI / 2 + PI / 4
	return true

func panel_text(panel: Control) -> String:
	var result := ""
	for node in panel.find_children("*", "Control", true, false):
		if node is Label or node is Button or node is RichTextLabel:
			result += node.text + "\n"
	return result

func close_reader() -> bool:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_ESCAPE
	game.exploration._input(event)
	return require(game.state == "playing", "Actual reader Escape returns to play")

func gameplay() -> bool:
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game = Game.new()
	game.records_enabled = false
	game.save_directory = private_directory
	game.settings_path = private_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(SEED, EDITION)
	game.floating_hub.start()
	if not require(game.floating_hub.active(), "Genuine production Lanternwake start") or not await image_frame("00-lanternwake"):
		return false
	game._generate_surface(game.floating_hub.city().hub_portal, false)
	game._clear_actors()
	game.grounded = true
	if not await wait_renderer():
		return false
	game._snap_camera()
	if not require(game.floating_hub.target().get("kind", "") == "depart", "Actual Worldgate E target after native warmup"):
		return false
	press_key(KEY_E)
	if not require(not game.floating_hub.active() and game.world.get_script().resource_path == "res://scripts/hub_world.gd", "Physical Worldgate E retains real HubWorld exterior") or not await image_frame("01-worldgate-departure"):
		return false
	for index in records.size():
		var record: Dictionary = records[index]
		if not await visit(record):
			return false
		var label := "%02d-%s" % [index + 2, record.kind]
		var closed := marker_proof(record)
		for reverse in [false, true]:
			shot_yaw = int(record.turn) * PI / 2 + PI / 4 + (PI if reverse else 0)
			if not await image_frame(label + ("-reverse" if reverse else "-front"), 18, record):
				return false
		shot_yaw = int(record.turn) * PI / 2 + PI / 4
		var inventory: Dictionary = game.inventory.snapshot()
		var material: int = game.inventory.count(record.reward_item) if not record.reward_item.is_empty() else 0
		var coins: int = game.inventory.count("gold_coin")
		var rng_state: int = game.rng.state
		if record.interaction == "well":
			game.hp = 25
			game.mana = 30
		press_key(KEY_E)
		if not require(game.exploration.landmarks.claimed.has(record.id) and game.rng.state == rng_state, "Real landmark E records visit without consuming gameplay RNG"):
			return false
		if record.interaction == "cache":
			if not require(game.inventory.count(record.reward_item) == material + int(record.quantity) and game.inventory.count("gold_coin") == coins + int(record.coins), "Exact owned cache reward") or not await image_frame(label + "-searched", 12, record):
				return false
			press_key(KEY_E)
		elif record.interaction == "well":
			if not require(game.hp == game.max_hp and game.mana == game.max_mana and game.inventory.snapshot() == inventory, "Actual well restores resources without reward farming") or not await image_frame(label + "-rested", 12, record):
				return false
		else:
			if not require(game.inventory.snapshot() == inventory, "Story interaction preserves inventory"):
				return false
		if record.interaction != "well":
			if not require(game.state == "discovery_reader" and panel_text(game.exploration.overlay).contains(record.name) and panel_text(game.exploration.overlay).contains(record.flavor), "Actual E story/cache reader exposes generated name and flavor") or not await image_frame(label + "-reader", 12, record) or not close_reader():
				return false
		payouts.append({"plan": packed(record), "closed_body": closed, "visited_body": marker_proof(record), "coin_delta": game.inventory.count("gold_coin") - coins, "material_delta": game.inventory.count(record.reward_item) - material if not record.reward_item.is_empty() else 0, "gameplay_rng_unchanged": game.rng.state == rng_state})
	press_key(KEY_J)
	if not require(game.state == "journal", "Actual J opens construction journal"):
		return false
	var journal := panel_text(game.expansion.overlay)
	for record in records:
		if not require(journal.contains(record.name) and journal.contains(record.flavor), "Construction journal retains generated name/story: " + record.kind):
			return false
	if not await image_frame("30-journal-top", 12):
		return false
	for scroll in game.expansion.overlay.find_children("*", "ScrollContainer", true, false):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	return await image_frame("31-journal-bottom", 12)

func run() -> void:
	before = source_hashes()
	var world := World.new()
	world.generate(SEED, EDITION)
	if not load_plans(world) or not require(source_hashes() == before, "Headless landmark locator source stability"):
		await finish(1)
		return
	var manifest := {"seed": SEED, "edition": EDITION, "examples": packed(records), "sources_before": before}
	if "--locate-only" in OS.get_cmdline_user_args():
		manifest.sources_after = source_hashes()
		manifest.source_stable = manifest.sources_after == before
		FileAccess.open("/tmp/endless-compass-landmark-capture-locations.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
		print("PASS: eight current source-stable real landmark plans; data-only locator")
		await finish(0)
		return
	if DisplayServer.get_name() == "headless":
		print("FAIL: native landmark review awaits explicit source/window handoff")
		await finish(1)
		return
	var complete := await gameplay()
	manifest.frames = frames
	manifest.interactions = payouts
	manifest.fresh_hub_recipe = "Game.start_run(91,7), production FloatingHub.start(), actual KEY_E Worldgate departure; separate new-character UI flow has headless acceptance"
	manifest.landmark_ledger = game.exploration.landmarks.snapshot() if game != null else {}
	manifest.sources_after = source_hashes()
	manifest.source_stable = manifest.sources_after == before
	manifest.viewport = [root.size.x, root.size.y]
	FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
	print("%s: %s actual private Game7 construction views; eight real generated structures/E/story/well/cache/journal" % ["PASS" if complete and manifest.source_stable else "REJECT", frames.size()])
	await finish(0 if complete and manifest.source_stable else 1)
