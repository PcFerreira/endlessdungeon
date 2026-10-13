extends "res://tools/capture_micro_biomes.gd"

var focus_yaw := PI / 4

func _initialize() -> void:
	super._initialize()
	directory = "res://artifacts/micro-biomes/fungal-focus-seed91"
	private_directory = "user://fungal-micro-preview-%s" % Time.get_ticks_usec()

func source_hashes() -> Dictionary:
	var result := super.source_hashes()
	result["tools/capture_fungal_micro_biomes.gd"] = FileAccess.get_sha256("res://tools/capture_fungal_micro_biomes.gd")
	for path in ["scripts/biome_landmark_catalog.gd", "scripts/biome_landmark_models.gd", "scripts/biome_landmark_exploration.gd", "config/biome_landmarks.json"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result

func load_plans(world) -> bool:
	if not super.load_plans(world):
		return false
	records = records.filter(func(record): return record.profile_id in ["fairy_ring", "mycelial_nursery"])
	return require(records.size() == 2, "Both genuine fungal focus pockets")

func image_frame(label: String, size: float = 22, record: Dictionary = {}) -> bool:
	if not await wait_renderer():
		return false
	game.surface_zoom = size
	game.camera_yaw = focus_yaw
	game.target_yaw = focus_yaw
	game._snap_camera()
	game.camera.size = size
	game.world_view.update_visibility(game.player_point, game.player_y, focus_yaw)
	for index in range(24):
		await process_frame
	if not require(not game.render_warmup.busy and (game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay)), "Actual focal renderer and loading overlay readiness") or not require(source_hashes() == before, "Fungal focal source stability"):
		return false
	RenderingServer.force_draw(false)
	if not require(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Save actual fungal focal image"):
		return false
	frames.append({"image": label + ".png", "point": packed(game.player_point), "camera_size": game.camera.size, "camera_yaw": focus_yaw, "provider": game.world.get_script().resource_path, "state": game.state, "warmup_busy": game.render_warmup.busy, "loading_overlay_absent": game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay), "micro_marker": marker_proof(record) if not record.is_empty() else {}})
	return true

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
	if not require(game.floating_hub.active(), "Genuine production fresh hub start") or not await wait_renderer():
		return false
	game._generate_surface(game.floating_hub.city().hub_portal, false)
	game._clear_actors()
	game.grounded = true
	if not await wait_renderer():
		return false
	game._snap_camera()
	if not require(game.floating_hub.target().get("kind", "") == "depart", "Actual ready Worldgate departure target"):
		return false
	press_key(KEY_E)
	if not require(not game.floating_hub.active() and game.world.get_script().resource_path == "res://scripts/hub_world.gd", "Actual physical E departure to HubWorld exterior"):
		return false
	for record in records:
		if not await visit(record):
			return false
		var closed := marker_proof(record)
		if not require(not closed.is_empty() and not closed.claimed, "Actual closed focus cache"):
			return false
		for reverse in [false, true]:
			focus_yaw = PI / 4 + (PI if reverse else 0)
			if not await image_frame(record.profile_id + ("-reverse-closed" if reverse else "-front-closed"), 12, record):
				return false
		var material: int = game.inventory.count(record.reward_item)
		var coins: int = game.inventory.count("gold_coin")
		var rng_state: int = game.rng.state
		press_key(KEY_E)
		var opened := marker_proof(record)
		if not require(opened.get("claimed", false) and opened.geometry_signature != closed.geometry_signature and game.inventory.count(record.reward_item) == material + int(record.quantity) and game.inventory.count("gold_coin") == coins + int(record.coins) and game.rng.state == rng_state, "Actual focus E body/reward and RNG preservation"):
			return false
		for reverse in [false, true]:
			focus_yaw = PI / 4 + (PI if reverse else 0)
			if not await image_frame(record.profile_id + ("-reverse-opened" if reverse else "-front-opened"), 12, record):
				return false
		payouts.append({"plan": packed(record), "closed_body": closed, "opened_body": opened, "actual_neighborhood": actual_records(game.world, record.center), "material_delta": game.inventory.count(record.reward_item) - material, "coin_delta": game.inventory.count("gold_coin") - coins, "gameplay_rng_unchanged": true})
	return require(game.exploration.micro.distinct_claims().size() == 2, "Both genuine fungal pockets studied")

func run() -> void:
	before = source_hashes()
	var world := World.new()
	world.generate(SEED, EDITION)
	if not load_plans(world) or not require(source_hashes() == before, "Data-only fungal focus location source stability"):
		await finish(1)
		return
	var manifest := {"seed": SEED, "edition": EDITION, "examples": packed(records), "sources_before": before}
	if "--locate-only" in OS.get_cmdline_user_args():
		manifest.sources_after = source_hashes()
		manifest.source_stable = manifest.sources_after == before
		FileAccess.open("/tmp/endless-compass-fungal-focus-locations.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
		print("PASS: both actual focal plans remain source-stable; data-only locator")
		await finish(0)
		return
	if DisplayServer.get_name() == "headless":
		print("FAIL: targeted native review waits for explicit source/window handoff")
		await finish(1)
		return
	var complete := await gameplay()
	manifest.frames = frames
	manifest.payouts = payouts
	manifest.fresh_hub_recipe = "Game.start_run(91,7), production FloatingHub.start(), actual KEY_E Worldgate departure; no invented cells/props"
	manifest.sources_after = source_hashes()
	manifest.source_stable = manifest.sources_after == before
	manifest.viewport = [root.size.x, root.size.y]
	FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
	print("%s: %s actual focused fungal closed/open/opposing views" % ["PASS" if complete and manifest.source_stable else "REJECT", frames.size()])
	await finish(0 if complete and manifest.source_stable else 1)
