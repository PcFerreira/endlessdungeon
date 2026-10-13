extends SceneTree

var directory := OS.get_cache_dir().path_join("endless-test-biome-landmark-game-%s" % OS.get_process_id())
var games := []
var failures := 0
var completed := false
var catalog
var composition
const KINDS := ["monolith", "well", "watchtower", "mage_tower", "tomb", "ruined_cottage", "shrine", "ruined_arch"]

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if not condition:
		print("FAIL: " + message)
		failures += 1
	return condition

func same(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	if left is Dictionary and right is Dictionary:
		return left.size() == right.size() and left.keys().all(func(key): return right.has(key) and same(left[key], right[key]))
	if left is Array and right is Array:
		return left.size() == right.size() and range(left.size()).all(func(index): return same(left[index], right[index]))
	return left == right

func new_game():
	var game = load("res://scripts/game.gd").new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	games.append(game)
	return game

func press_e(game) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	game._unhandled_key_input(event)

func panel_text(parent: Node) -> String:
	var text := ""
	for control in parent.find_children("*", "Control", true, false):
		if control is Label or control is Button or control is RichTextLabel:
			text += control.text + "\n"
	return text

func cleanup() -> void:
	for game in games:
		game.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
	check(not DirAccess.dir_exists_absolute(directory), "private landmark saves/settings must be removed")

func run_checks() -> void:
	if not ResourceLoader.exists("res://scripts/biome_landmark_catalog.gd") or not ResourceLoader.exists("res://scripts/biome_landmark_exploration.gd"):
		print("FAIL: actual biome construction interactions require the released landmark catalogue and controller")
		quit(1)
		return
	catalog = load("res://scripts/biome_landmark_catalog.gd")
	composition = load("res://scripts/biome_composition.gd")
	run_game_checks()
	check(completed, "actual landmark sequence must reach its final disk checks")
	await cleanup()
	if failures == 0:
		print("PASS: all eight real construction kinds, actual solid/open plot movement, E stories/cache rewards/safe wells, atomic rollback, journal and fresh disk/Sanctum/Worldgate persistence")
	quit(0 if failures == 0 else 1)

func constructions(world) -> Array[Dictionary]:
	var found := {}
	var visited := {}
	var anchors: Array = [world.start]
	var review = load("res://tools/biome_review_points.gd")
	for profile in review.find(world).values():
		anchors.append(profile.cell)
	for anchor in anchors:
		var grid := Vector2i(floori(float(anchor.x) / 64), floori(float(anchor.y) / 64))
		for radius in range(9):
			for x in range(grid.x - radius, grid.x + radius + 1):
				for y in range(grid.y - radius, grid.y + radius + 1):
					if maxi(absi(x - grid.x), absi(y - grid.y)) != radius:
						continue
					var feature: Dictionary = composition.feature(world.run_seed, Vector2i(x, y) * 64)
					if visited.has(feature.id):
						continue
					visited[feature.id] = true
					var record: Dictionary = catalog.plan(world, feature)
					if record.is_empty() or found.has(record.kind):
						continue
					found[record.kind] = record
					if found.size() == KINDS.size():
						var result: Array[Dictionary] = []
						for kind in KINDS:
							result.append(found[kind])
						return result
	print("ACTUAL CONSTRUCTION SEARCH: ", found.keys())
	return []

func reach(game, record: Dictionary) -> bool:
	game._generate_surface(Vector2(record.approach_far), false)
	game._clear_actors()
	game.grounded = true
	if not check(game.player_point.is_equal_approx(Vector2(record.approach_far)) and game.world.line_clear(game.player_point, Vector2(record.point)), "real two-step approach must remain supported and see the open door: " + record.kind):
		return false
	for point in [record.approach, record.point]:
		var next: Vector2 = game.world.move_actor(game.player_point, Vector2(point) - game.player_point)
		if not check(next.is_equal_approx(Vector2(point)), "actual movement must reach the open construction doorway: " + record.kind):
			return false
		game.player_point = next
		game._snap_camera()
	game.exploration.landmarks.sync(true)
	game.exploration.landmarks.observe()
	check(game.exploration.landmarks.markers.size() <= 6 and game.exploration.landmarks.planned.size() <= 32 and game.exploration.landmarks.markers.has(record.id), "actual constructions must retain bounded visible models and local plans")
	if game.exploration.landmarks.markers.has(record.id):
		var model: Node3D = game.exploration.landmarks.markers[record.id]
		var door: Vector3 = model.transform * Vector3(record.door_local.x, 0, record.door_local.y)
		check(model.get_meta("landmark_id", "") == record.id and is_equal_approx(door.x, float(record.point.x)) and is_equal_approx(door.z, float(record.point.y)), "actual construction model quarterturn must match its physical door")
	return check(game.exploration.landmarks.nearby.has(record.id) and game.exploration.landmarks.seen.has(record.id) and game.exploration.landmarks.target().get("id", "") == record.id, "actual approach must discover and target construction: " + record.kind)

func check_plot(game, record: Dictionary) -> void:
	var solid_probe := false
	for x in range(record.footprint.position.x, record.footprint.end.x):
		for y in range(record.footprint.position.y, record.footprint.end.y):
			var cell := Vector2i(x, y)
			var info: Dictionary = game.world.cell_info(cell)
			var solid: bool = record.solid_cells.has(cell)
			check(info.walkable == (not solid), "actual solid/open cell mask must match the generated construction: %s %s" % [record.kind, cell])
			if solid:
				check(not game.world.walkable(Vector2(cell)), "actual wall volume must reject actor clearance")
				if not solid_probe:
					for direction in game.world.DIRECTIONS:
						var origin := cell + Vector2i(direction)
						if not record.footprint.has_point(origin) or record.solid_cells.has(origin) or not game.world.walkable(Vector2(origin)):
							continue
						var moved: Vector2 = game.world.move_actor(Vector2(origin), Vector2(cell - origin))
						check(moved.distance_to(Vector2(origin)) < .8 and game.world.walkable(moved), "actual movement must stop at a construction wall")
						solid_probe = true
						break
			else:
				check(is_equal_approx(game.world.ground_height(Vector2(cell)), float(record.height)), "actual clear plot must use its authored flat ground height")
	check(record.solid_cells.is_empty() or solid_probe, "actual construction must expose a tested wall boundary")
	check(game.world.walkable(Vector2(record.point)) and game.world.walkable(Vector2(record.approach)) and game.world.walkable(Vector2(record.approach_far)), "open door and both approach steps must have real actor clearance")

func run_game_checks() -> void:
	var game = new_game()
	game.start_run(91, 7)
	if not check(game.exploration.get("landmarks") != null, "actual Game must attach its landmark controller"):
		return
	var records := constructions(game.world)
	if not check(records.size() == KINDS.size(), "actual seed91 must provide all eight construction kinds in the bounded ecology search"):
		return
	print("ACTUAL CONSTRUCTIONS: ", records.map(func(record): return {"id": record.id, "kind": record.kind, "door": record.point, "approach_far": record.approach_far}))
	game._clear_actors()
	var origin: Dictionary = game.make_save_data()
	if not check(game.use_sanctum_sigil(), "actual H must preserve the original pre-construction journey"):
		return
	check(not game.exploration.landmarks.claim(records[2]), "Sanctum must block wilderness construction rewards")
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	press_e(game)
	if not check(game.floating_hub.active(), "actual study shelf E must reach Lanternwake"):
		return
	game.exploration.landmarks.sync(true)
	check(game.exploration.landmarks.nearby.is_empty() and not game.exploration.landmarks.claim(records[2]), "authored hub island must not expose or pay wilderness constructions")
	game._clear_actors()
	game.player_point = game.floating_hub.city().hub_portal
	game._snap_camera()
	press_e(game)
	if not check(not game.floating_hub.active(), "actual Worldgate E must depart to natural HubWorld exterior"):
		return
	var gate: Vector2 = game.world.region_at(Vector2i(game.player_point.round())).get("hub_world_gate", Vector2.INF)
	if not check(gate.is_finite(), "actual departure must preserve a physical return gate"):
		return
	var points: int = game.build.skill_points
	for record in records:
		if not reach(game, record):
			return
		check_plot(game, record)
		if record.interaction == "well":
			check_well(game, record)
			continue
		if record.kind == "watchtower":
			check_blocks(game, record)
			check_full_bag(game, record)
		var inventory: Dictionary = game.inventory.snapshot()
		var material: int = game.inventory.count(record.reward_item) if not record.reward_item.is_empty() else 0
		var coins: int = game.inventory.count("gold_coin")
		var rng_state: int = game.rng.state
		var waypoint: Dictionary = game.waypoint.duplicate(true)
		check(game.interaction_hint() == game.exploration.landmarks.hint() and not game.exploration.landmarks.hint().is_empty(), "actual E hint must expose the generated construction")
		press_e(game)
		check(game.exploration.landmarks.claimed.has(record.id), "actual E must record a construction once: " + record.kind)
		if record.interaction == "cache":
			check(game.inventory.count(record.reward_item) == material + record.quantity and game.inventory.count("gold_coin") == coins + record.coins and game.inventory.stolen_count(record.reward_item) == 0 and game.inventory.stolen_count("gold_coin") == 0, "actual E must award exact owned material and coins")
		else:
			var text := panel_text(game.exploration.overlay)
			check(game.inventory.snapshot() == inventory and game.state == "discovery_reader" and text.contains(record.name) and text.contains(record.flavor), "actual story construction E must open its name and text without inventory farming")
			check(game.waypoint == waypoint, "construction stories must not invent linked-site waypoints")
			game.exploration.landmarks.close()
		check(game.rng.state == rng_state and game.build.skill_points == points and game.layer == "overworld", "landmark interaction must preserve RNG, skill points and the physical world layer")
		var earned: Dictionary = game.inventory.snapshot()
		press_e(game)
		if game.state != "playing":
			game.exploration.landmarks.close()
		check(game.inventory.snapshot() == earned and game.build.skill_points == points and not game.exploration.landmarks.claim(record), "repeated construction E must never repay or award skill farming")
	check_journal(game, records)
	check_legacy_exploration(game)
	var ledger: Dictionary = game.exploration.landmarks.snapshot()
	var inventory: Dictionary = game.inventory.snapshot()
	var controller = load("res://scripts/biome_landmark_exploration.gd")
	check(controller.valid(ledger, "91") and not controller.valid(ledger, "92"), "actual construction collection must retain the exact journey seed")
	var invalid: Dictionary = ledger.duplicate(true)
	invalid.seen.erase(records[2].id)
	check(not game.exploration.landmarks.restore(invalid, "91") and game.exploration.landmarks.snapshot() == ledger, "invalid claimed-without-discovery restore must preserve valid construction progress")
	if not check(game.saves.validate(game.make_save_data()) and game.save_game(1), "actual construction progress must validate and write to disk"):
		return
	var fresh = new_game()
	if not check(fresh.load_game(1), "fresh Game must load actual construction progress"):
		return
	check(same(fresh.exploration.landmarks.snapshot(), ledger) and fresh.inventory.snapshot() == inventory, "fresh disk must restore stories, well visits and cache rewards")
	fresh._generate_surface(gate)
	fresh._clear_actors()
	if not check(fresh.floating_hub.target().get("kind") == "return", "actual wilderness gate must offer its hub return"):
		return
	press_e(fresh)
	fresh._clear_actors()
	if not check(fresh.floating_hub.active() and fresh.use_sanctum_sigil() and fresh.save_game(2), "actual return gate and H must persist construction progress in home"):
		return
	var home = new_game()
	if not check(home.load_game(2) and home.layer == "sanctum" and home.leave_sanctum(), "fresh Sanctum disk load must resume the older original journey"):
		return
	check(same(home.exploration.landmarks.snapshot(), ledger) and home.inventory.snapshot() == inventory and home.build.skill_points == points, "home/original return must retain all construction collection and owned rewards")
	check(same(home.make_save_data().location.point, origin.location.point), "intentional original journey position must remain exact")
	if not reach(home, records[2]):
		return
	press_e(home)
	check(home.inventory.snapshot() == inventory and same(home.exploration.landmarks.snapshot(), ledger), "loaded and original-return construction must stay claimed")
	check(home.save_game(3), "returned construction collection must remain disk-saveable")
	completed = true

func check_blocks(game, record: Dictionary) -> void:
	var inventory: Dictionary = game.inventory.snapshot()
	var claimed: Dictionary = game.exploration.landmarks.claimed.duplicate(true)
	var point: Vector2 = game.player_point
	game.player_point += Vector2(20, 0)
	check(game.exploration.landmarks.target().is_empty() and not game.exploration.landmarks.claim(record), "distant construction reward must be blocked")
	game.player_point = point
	game.grounded = false
	check(game.exploration.landmarks.target().is_empty() and not game.exploration.landmarks.claim(record), "airborne construction reward must be blocked")
	game.grounded = true
	game.online.session = true
	check(game.exploration.landmarks.target().is_empty() and not game.exploration.landmarks.claim(record), "online construction reward must be blocked")
	game.online.session = false
	game.state = "paused"
	check(game.exploration.landmarks.target().is_empty() and not game.exploration.landmarks.claim(record), "paused construction reward must be blocked")
	game.state = "playing"
	var forged: Dictionary = record.duplicate(true)
	forged.quantity += 1
	check(not game.exploration.landmarks.claim(forged), "forged construction rewards must be rejected")
	check(game.inventory.snapshot() == inventory and game.exploration.landmarks.claimed == claimed, "blocked rewards must preserve inventory and claim collection")

func check_full_bag(game, record: Dictionary) -> void:
	var inventory: Dictionary = game.inventory.snapshot()
	var full: Dictionary = inventory.duplicate(true)
	full.items = {"sanctum_sigil": 1, "health_potion": int(game.Inventory.ITEMS.health_potion.stack) * (game.Inventory.CAPACITY - 2), record.reward_item: 1}
	full.stolen = {}
	full.equipment = {"weapon": "", "armor": "", "charm": ""}
	if not check(game.inventory.restore(full, game.build.class_id) and game.inventory.slots_used() == game.Inventory.CAPACITY and 1 + record.quantity <= int(game.Inventory.ITEMS[record.reward_item].stack), "full construction backpack must permit material stacking but lack a coin slot"):
		return
	var ledger: Dictionary = game.exploration.landmarks.snapshot()
	press_e(game)
	check(game.inventory.snapshot() == full and same(game.exploration.landmarks.snapshot(), ledger), "coin-stage full-bag failure must roll back material and keep the construction unclaimed")
	check(game.inventory.restore(inventory, game.build.class_id), "actual inventory must restore after isolated rollback attempt")

func check_well(game, record: Dictionary) -> void:
	var inventory: Dictionary = game.inventory.snapshot()
	var full: Dictionary = inventory.duplicate(true)
	full.items = {"sanctum_sigil": 1, "health_potion": int(game.Inventory.ITEMS.health_potion.stack) * (game.Inventory.CAPACITY - 1)}
	full.stolen = {}
	full.equipment = {"weapon": "", "armor": "", "charm": ""}
	if not check(game.inventory.restore(full, game.build.class_id) and game.inventory.slots_used() == game.Inventory.CAPACITY, "safe well must be usable with a real full backpack"):
		return
	game.hp = maxf(1, game.max_hp - 17)
	game.mana = maxf(0, game.max_mana - 11)
	var rng_state: int = game.rng.state
	var points: int = game.build.skill_points
	press_e(game)
	check(game.hp == game.max_hp and game.mana == game.max_mana and game.inventory.snapshot() == full and game.rng.state == rng_state and game.build.skill_points == points, "actual safe well E must refill resources without a slot, reward, skill or RNG cost")
	var ledger: Dictionary = game.exploration.landmarks.snapshot()
	press_e(game)
	check(game.inventory.snapshot() == full and game.rng.state == rng_state and game.build.skill_points == points and same(game.exploration.landmarks.snapshot(), ledger), "repeated well rest must not farm rewards or duplicate collection")
	var danger := Vector2.INF
	for x in range(-4, 5):
		for y in range(-4, 5):
			var point: Vector2 = game.player_point + Vector2(x, y)
			if point.distance_to(game.player_point) >= 2 and game.world.walkable(point) and game.world.line_clear(game.player_point, point):
				danger = point
				break
		if danger.is_finite():
			break
	if check(danger.is_finite(), "actual well must have a nearby clear line-visible combat probe point"):
		game._spawn_enemy(danger, 0)
		game.hp = maxf(1, game.max_hp - 17)
		game.mana = maxf(0, game.max_mana - 11)
		var hp: float = game.hp
		var mana: float = game.mana
		rng_state = game.rng.state
		check(not game.enemies.is_empty() and not game.sanctum_problem().is_empty(), "real nearby Game enemy must activate the existing rest danger rule")
		press_e(game)
		check(game.hp == hp and game.mana == mana and game.inventory.snapshot() == full and game.rng.state == rng_state, "actual well E must not refill during nearby real combat")
	game._clear_actors()
	check(game.inventory.restore(inventory, game.build.class_id), "actual reward inventory must restore after backpack-free well test")

func check_journal(game, records: Array[Dictionary]) -> void:
	game.expansion.toggle_journal()
	if not check(game.state == "journal", "actual field journal must open after construction interactions"):
		return
	var text := panel_text(game.expansion.overlay)
	for record in records:
		check(text.contains(record.name), "actual journal must list the construction name: " + record.kind)
	var ledger: Dictionary = game.exploration.landmarks.snapshot()
	var inventory: Dictionary = game.inventory.snapshot()
	for record in records:
		game.exploration.landmarks.open_saved(record.id)
		text = panel_text(game.exploration.overlay)
		check(game.state == "discovery_reader" and text.contains(record.name) and text.contains(record.flavor), "actual saved journal entry must reopen its exact construction story: " + record.kind)
		game.exploration.landmarks.close()
		check(game.state == "journal" and same(game.exploration.landmarks.snapshot(), ledger) and game.inventory.snapshot() == inventory, "Back to journal must preserve collection and rewards")
	game.expansion.close_lore()

func check_legacy_exploration(game) -> void:
	var older: Dictionary = game.exploration.snapshot().duplicate(true)
	older.erase("landmarks")
	var save: Dictionary = game.make_save_data().duplicate(true)
	save.progress.exploration = older
	check(game.saves.validate(save), "existing exploration save without optional landmark field must remain valid")
	var state = load("res://scripts/exploration.gd").new()
	if check(state.restore(older, "91"), "off-tree legacy Exploration snapshot must restore without a landmark field"):
		check(state.landmarks.seen.is_empty() and state.landmarks.claimed.is_empty(), "legacy optional landmark omission must restore an empty collection")
		var restored: Dictionary = state.snapshot()
		for key in older:
			check(same(restored[key], older[key]), "legacy exploration restore must preserve existing collection: " + key)
	state.free()
