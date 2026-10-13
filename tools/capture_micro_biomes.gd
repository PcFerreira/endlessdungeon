extends "res://tools/capture_biome_composition.gd"

const PocketCatalog = preload("res://scripts/micro_biome_catalog.gd")
const EXAMPLES := "res://artifacts/micro-biomes/plans-seed91.json"
var records: Array[Dictionary] = []
var payouts: Array = []

func _initialize() -> void:
	directory = "res://artifacts/micro-biomes/native-seed91"
	private_directory = "user://micro-biome-preview-%s" % Time.get_ticks_usec()
	super._initialize()

func source_hashes() -> Dictionary:
	var result := super.source_hashes()
	result["tools/capture_micro_biomes.gd"] = FileAccess.get_sha256("res://tools/capture_micro_biomes.gd")
	result[EXAMPLES] = FileAccess.get_sha256(EXAMPLES)
	return result

func packed(value):
	if value is Vector2i or value is Vector2:
		return [value.x, value.y]
	if value is Array:
		return value.map(packed)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = packed(value[key])
		return result
	return value

func same(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	if left is Array and right is Array:
		return left.size() == right.size() and range(left.size()).all(func(index): return same(left[index], right[index]))
	if left is Dictionary and right is Dictionary:
		return left.size() == right.size() and left.keys().all(func(key): return right.has(key) and same(left[key], right[key]))
	return left == right

func require(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		print("FAIL: ", message)
	return condition

func load_plans(world) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(EXAMPLES))
	if not require(data is Dictionary and data.get("seed") == SEED and data.get("edition") == EDITION and data.get("examples") is Dictionary, "Use the accepted actual seed91 edition7 example artifact"):
		return false
	for biome in ["greenwood", "dense_forest", "haunted_hollows", "marsh", "meadows", "desert", "frostlands", "jungle", "autumn_woodland", "fungal_grove", "volcanic_wastes", "highlands", "coast", "crystal_tundra"]:
		if not require(data.examples.has(biome), "Missing actual pocket ecology: " + biome):
			return false
		var example: Dictionary = data.examples[biome]
		var center := Vector2i(example.center[0], example.center[1])
		var plan := PocketCatalog.plan(world, Composition.feature(SEED, center))
		if not require(not plan.is_empty() and same(packed(plan), example), "Fresh authoritative terrain/catalogue plan: " + biome):
			return false
		records.append(plan)
		print("LOCATED: ", plan.id, " center=", plan.center, " approach=", plan.approach, " wet=", plan.get("water_cell", "none"))
	return require(records.size() == 14, "All fourteen genuine ecology pockets")

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	if key == KEY_J:
		game.expansion._input(event)
	else:
		game._unhandled_key_input(event)

func marker_proof(record: Dictionary) -> Dictionary:
	if not game.exploration.micro.markers.has(record.id):
		return {}
	var marker: MeshInstance3D = game.exploration.micro.markers[record.id]
	var arrays: Array = marker.mesh.surface_get_arrays(0)
	return {"id": record.id, "position": packed(Vector2(marker.position.x, marker.position.z)), "source_asset": marker.get_meta("source_asset", ""), "visual_family": marker.get_meta("visual_family", ""), "representation": marker.get_meta("representation", ""), "claimed": marker.get_meta("claimed", false), "vertices": arrays[Mesh.ARRAY_VERTEX].size(), "geometry_signature": hash([arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_COLOR]])}

func image_frame(label: String, size: float = 22, record: Dictionary = {}) -> bool:
	if not await wait_renderer():
		return false
	game.surface_zoom = size
	game.camera_yaw = PI / 4
	game.target_yaw = game.camera_yaw
	game._snap_camera()
	game.camera.size = size
	game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
	for index in range(24):
		await process_frame
	if not require(not game.render_warmup.busy and (game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay)), "Actual warmup and loading overlay must be gone before PNG") or not require(source_hashes() == before, "Capture source hashes remain stable"):
		return false
	RenderingServer.force_draw(false)
	if not require(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Save actual viewport image"):
		return false
	frames.append({"image": label + ".png", "point": packed(game.player_point), "camera_size": game.camera.size, "provider": game.world.get_script().resource_path, "layer": game.layer, "state": game.state, "warmup_busy": game.render_warmup.busy, "loading_overlay_absent": game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay), "micro_marker": marker_proof(record) if not record.is_empty() else {}, "visible_markers": game.exploration.micro.markers.size(), "ambience_profile": game.ambience.profile})
	return true

func visit(record: Dictionary) -> bool:
	game._generate_surface(Vector2(record.approach), false)
	game._clear_actors()
	game.grounded = true
	game.player_point = game.world.move_actor(game.player_point, (Vector2(record.point) - game.player_point).normalized())
	game._snap_camera()
	game.exploration.micro.sync(true)
	game.exploration.micro.observe()
	if not require(game.world.walkable(game.player_point) and game.exploration.micro.target().get("id", "") == record.id, "Actual supported movement from real approach targets " + record.name):
		return false
	if not require(PocketCatalog.plan(game.world, Composition.feature(SEED, record.center)) == record, "Genuine HubWorld exterior pocket equals source plan"):
		return false
	if not await wait_renderer():
		return false
	for index in range(10):
		game.ambience.update(game, 1.0)
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
	if not require(game.floating_hub.active(), "Production fresh-start hub method enters genuine Lanternwake") or not await image_frame("00-lanternwake"):
		return false
	game._generate_surface(game.floating_hub.city().hub_portal, false)
	game._clear_actors()
	game.grounded = true
	if not await wait_renderer():
		return false
	game._snap_camera()
	if not require(game.floating_hub.target().get("kind", "") == "depart", "Actual Worldgate is the E target"):
		return false
	press_key(KEY_E)
	if not require(not game.floating_hub.active() and game.world.get_script().resource_path == "res://scripts/hub_world.gd" and game.world.generator_version == EDITION, "Physical E departure retains real HubWorld exterior") or not await image_frame("01-worldgate-departure"):
		return false
	var initial_skills: int = game.build.skill_points
	for index in records.size():
		var record: Dictionary = records[index]
		if not await visit(record):
			return false
		var label := "%02d-%s" % [index + 2, record.profile_id]
		var closed := marker_proof(record)
		if not require(not closed.is_empty() and not closed.claimed and game.interaction_hint() == game.exploration.micro.hint(), "Actual closed cache and E hint") or not await image_frame(label + "-closed", 12, record):
			return false
		var material_count: int = game.inventory.count(record.reward_item)
		var coins: int = game.inventory.count("gold_coin")
		var rng_state: int = game.rng.state
		press_key(KEY_E)
		var opened := marker_proof(record)
		if not require(game.exploration.micro.claimed.has(record.id) and not opened.is_empty() and opened.claimed and opened.geometry_signature != closed.geometry_signature, "Actual E opens a different rendered body"):
			return false
		if not require(game.inventory.count(record.reward_item) == material_count + int(record.quantity) and game.inventory.count("gold_coin") == coins + int(record.coins) and game.rng.state == rng_state, "Actual owned-material/coin reward and independent gameplay RNG"):
			return false
		if not require(game.build.skill_points == initial_skills + (index + 1) / 4, "Four different studied types award a skill point") or not await image_frame(label + "-opened", 12, record):
			return false
		payouts.append({"plan": packed(record), "closed_body": closed, "opened_body": opened, "material_delta": game.inventory.count(record.reward_item) - material_count, "coin_delta": game.inventory.count("gold_coin") - coins, "skill_points": game.build.skill_points, "gameplay_rng_unchanged": game.rng.state == rng_state})
	press_key(KEY_J)
	if not require(game.state == "journal", "Actual J opens the field journal"):
		return false
	var journal_text := ""
	for node in game.expansion.overlay.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			journal_text += node.text + "\n"
	for record in records:
		if not require(journal_text.contains(record.name) and journal_text.contains(record.flavor), "Actual journal retains discovered name/story: " + record.name):
			return false
	if not await image_frame("30-journal-top", 12):
		return false
	for scroll in game.expansion.overlay.find_children("*", "ScrollContainer", true, false):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	if not await image_frame("31-journal-bottom", 12):
		return false
	return require(game.exploration.micro.distinct_claims().size() == 14 and game.build.skill_points == initial_skills + 3, "Fourteen studied types retain three actual skill milestones")

func run() -> void:
	before = source_hashes()
	var world := World.new()
	world.generate(SEED, EDITION)
	if not load_plans(world) or not require(source_hashes() == before, "Location reader source stability"):
		await finish(1)
		return
	var manifest := {"seed": SEED, "edition": EDITION, "examples": packed(records), "sources_before": before, "sources_after": source_hashes(), "source_stable": true}
	if "--locate-only" in OS.get_cmdline_user_args():
		FileAccess.open("/tmp/endless-compass-micro-capture-locations.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
		print("PASS: fourteen source-stable real micro plans freshly revalidated; headless data only")
		await finish(0)
		return
	if DisplayServer.get_name() == "headless":
		print("FAIL: native review must wait for explicit queued window")
		await finish(1)
		return
	var complete := await gameplay()
	manifest.frames = frames
	manifest.payouts = payouts
	manifest.fresh_hub_recipe = "Game.start_run(91,7), production FloatingHub.start(), actual KEY_E Worldgate departure; separate new-character UI flow has headless acceptance"
	manifest.discovery_ledger = game.exploration.micro.snapshot() if game != null else {}
	manifest.sources_after = source_hashes()
	manifest.source_stable = manifest.sources_after == before
	manifest.viewport = [root.size.x, root.size.y]
	FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
	print("%s: %s actual private Game7 pocket/cache/journal views; real E rewards, HubWorld exterior, no invented cells" % ["PASS" if complete and manifest.source_stable else "REJECT", frames.size()])
	await finish(0 if complete and manifest.source_stable else 1)
