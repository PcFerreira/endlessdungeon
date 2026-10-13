extends SceneTree

var directory := OS.get_cache_dir().path_join("endless-test-micro-biome-game-%s" % OS.get_process_id())
var games := []
var failures := 0
var completed := false
var catalog
var composition

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

func pockets(world) -> Array[Dictionary]:
	var groups := {}
	var visited := {}
	var anchors: Array = [world.start]
	var review = load("res://tools/biome_review_points.gd")
	for profile in review.find(world).values():
		anchors.append(profile.cell)
	for anchor in anchors:
		var grid := Vector2i(floori(float(anchor.x) / 64), floori(float(anchor.y) / 64))
		for radius in range(7):
			for x in range(grid.x - radius, grid.x + radius + 1):
				for y in range(grid.y - radius, grid.y + radius + 1):
					if maxi(absi(x - grid.x), absi(y - grid.y)) != radius:
						continue
					var feature: Dictionary = composition.feature(world.run_seed, Vector2i(x, y) * 64)
					if visited.has(feature.id):
						continue
					visited[feature.id] = true
					var record: Dictionary = catalog.plan(world, feature)
					if record.is_empty():
						continue
					if not groups.has(record.profile_id):
						groups[record.profile_id] = []
					groups[record.profile_id].append(record)
					if groups.size() >= 4:
						for profile_id in groups:
							if groups[profile_id].size() >= 2:
								var result: Array[Dictionary] = [groups[profile_id][0], groups[profile_id][1]]
								for other in groups:
									if other != profile_id:
										result.append(groups[other][0])
										if result.size() == 5:
											return result
	return []

func reach(game, record: Dictionary) -> bool:
	game._generate_surface(Vector2(record.approach), false)
	game._clear_actors()
	game.grounded = true
	var delta: Vector2 = (Vector2(record.point) - game.player_point).normalized()
	game.player_point = game.world.move_actor(game.player_point, delta)
	game._snap_camera()
	game.exploration.micro.sync(true)
	game.exploration.micro.observe()
	check(game.exploration.micro.markers.size() <= 8 and game.exploration.micro.markers.has(record.id), "actual local pockets must keep a bounded visible marker roster")
	if game.exploration.micro.markers.has(record.id):
		var model: Node3D = game.exploration.micro.markers[record.id]
		var visible_body: bool = model is MeshInstance3D and model.mesh != null or not model.find_children("*", "MeshInstance3D", true, false).is_empty()
		check(model.get_meta("representation", "") == "original_micro_biome_geometry" and model.get_meta("nonblocking", false) and visible_body, "actual pocket marker must use the original nonblocking cache body")
	return check(game.world.walkable(game.player_point) and game.player_point.distance_to(Vector2(record.point)) < 1.85 and game.exploration.micro.nearby.has(record.id) and game.exploration.micro.seen.has(record.id) and game.exploration.micro.target().get("id", "") == record.id, "actual movement from clear approach must discover, stream and target pocket " + record.id)

func press_e(game) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	game._unhandled_key_input(event)

func run_checks() -> void:
	if not ResourceLoader.exists("res://scripts/micro_biome_exploration.gd"):
		print("FAIL: actual Game microbiome rewards require the released exploration controller")
		quit(1)
		return
	catalog = load("res://scripts/micro_biome_catalog.gd")
	composition = load("res://scripts/biome_composition.gd")
	run_game_checks()
	check(completed, "actual gameplay sequence must reach its final save checks")
	for game in games:
		game.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
	check(not DirAccess.dir_exists_absolute(directory), "private microbiome saves/settings must be removed")
	if failures == 0:
		print("PASS: real generated microbiome E rewards, four distinct-type milestone, atomic full-bag rollback, replay/block rules, journal and fresh disk/Sanctum/Worldgate carry")
	quit(0 if failures == 0 else 1)

func run_game_checks() -> void:
	var game = new_game()
	game.start_run(91, 7)
	if not check(game.exploration.get("micro") != null, "actual Game must attach the microbiome exploration controller"):
		return
	var records := pockets(game.world)
	if not check(records.size() == 5 and records[0].profile_id == records[1].profile_id and records[0].id != records[1].id, "actual seed91 must provide four distinct pocket types and a separate pocket of the same type"):
		return
	print("ACTUAL POCKETS: ", records.map(func(record): return {"id": record.id, "approach": record.approach, "recipe": record.recipe}))
	game._clear_actors()
	var origin: Dictionary = game.make_save_data()
	if not check(game.use_sanctum_sigil() and game.layer == "sanctum", "real H must capture the original pre-reward journey"):
		return
	check(not game.exploration.micro.claim(records[0]), "Sanctum provider must block wilderness rewards")
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	press_e(game)
	if not check(game.floating_hub.active(), "actual study shelf E must enter Lanternwake"):
		return
	game.exploration.micro.sync(true)
	check(game.exploration.micro.nearby.is_empty() and not game.exploration.micro.claim(records[0]), "actual hub island must not expose or pay wilderness pockets")
	game._clear_actors()
	game.player_point = game.floating_hub.city().hub_portal
	game._snap_camera()
	press_e(game)
	if not check(not game.floating_hub.active() and game.world.generator_version == 7, "actual Worldgate must depart to edition7 wilderness"):
		return
	var gate: Vector2 = game.world.region_at(Vector2i(game.player_point.round())).get("hub_world_gate", Vector2.INF)
	if not check(gate.is_finite(), "real departure must have a physical return Worldgate"):
		return
	if not reach(game, records[0]):
		return
	check_blocks(game, records[0])
	check_full_bag(game, records[0])
	var skill_points: int = game.build.skill_points
	for index in range(records.size()):
		var record: Dictionary = records[index]
		if not reach(game, record):
			return
		var items: int = game.inventory.count(record.reward_item)
		var coins: int = game.inventory.count("gold_coin")
		var rng_state: int = game.rng.state
		if not check(game.interaction_hint() == game.exploration.micro.hint() and not game.exploration.micro.hint().is_empty(), "actual E hint must expose the pocket reward"):
			return
		press_e(game)
		check(game.exploration.micro.seen.has(record.id) and game.exploration.micro.claimed.has(record.id), "actual E must discover and claim pocket " + record.id)
		check(game.exploration.micro.markers[record.id].get_meta("claimed", false), "actual claimed marker must display its open cache state")
		check(game.inventory.count(record.reward_item) == items + record.quantity and game.inventory.count("gold_coin") == coins + record.coins and game.inventory.stolen_count(record.reward_item) == 0 and game.inventory.stolen_count("gold_coin") == 0, "actual E must award the defined owned material and coins")
		check(game.rng.state == rng_state, "pocket discovery/claim must preserve gameplay RNG")
		check(game.build.skill_points == skill_points + (1 if index == 4 else 0), "only four distinct CLAIMED profile types may award the first skill milestone")
		var inventory: Dictionary = game.inventory.snapshot()
		var points: int = game.build.skill_points
		press_e(game)
		check(game.inventory.snapshot() == inventory and game.build.skill_points == points and not game.exploration.micro.claim(record), "repeated E/claim must not repay a pocket or milestone")
	print("ACTUAL CLAIMS: ", {"places": game.exploration.micro.claimed.size(), "types": game.exploration.micro.distinct_claims().size(), "skill_reward": game.build.skill_points - skill_points, "coins": game.inventory.count("gold_coin")})
	check_journal(game, records)
	var ledger: Dictionary = game.exploration.micro.snapshot()
	var controller = load("res://scripts/micro_biome_exploration.gd")
	check(controller.valid(ledger, "91") and not controller.valid(ledger, "92"), "actual pocket ledger must retain the exact journey seed context")
	var invalid: Dictionary = ledger.duplicate(true)
	invalid.seen.erase(records[0].id)
	check(not game.exploration.micro.restore(invalid, "91") and game.exploration.micro.snapshot() == ledger, "invalid claimed-without-discovery restore must preserve the valid collection")
	var inventory: Dictionary = game.inventory.snapshot()
	if not check(game.saves.validate(game.make_save_data()) and game.save_game(1), "actual claimed-pocket wilderness save must validate and write"):
		return
	var fresh = new_game()
	if not check(fresh.load_game(1), "fresh Game must restore actual pocket disk save"):
		return
	check(same(fresh.exploration.micro.snapshot(), ledger) and fresh.inventory.snapshot() == inventory and fresh.build.skill_points == skill_points + 1, "fresh disk restoration must retain pocket ledgers, all rewards and milestone")
	fresh._generate_surface(gate)
	fresh._clear_actors()
	if not check(fresh.floating_hub.target().get("kind") == "return", "actual wilderness return Worldgate must be targeted"):
		return
	press_e(fresh)
	if not check(fresh.floating_hub.active(), "actual Worldgate E must return to Lanternwake"):
		return
	fresh._clear_actors()
	if not check(fresh.use_sanctum_sigil() and fresh.layer == "sanctum" and fresh.save_game(2), "actual hub H must persist rewards in Sanctum over the older original thread"):
		return
	var home = new_game()
	if not check(home.load_game(2) and home.layer == "sanctum" and home.leave_sanctum(), "fresh Sanctum disk load must resume the original pre-reward journey"):
		return
	check(same(home.exploration.micro.snapshot(), ledger) and home.inventory.snapshot() == inventory and home.build.skill_points == skill_points + 1, "home/original return must retain microbiome progress and reward milestone")
	check(same(home.make_save_data().location.point, origin.location.point), "intentional original journey position must remain exact")
	if not reach(home, records[0]):
		return
	press_e(home)
	check(home.inventory.snapshot() == inventory and home.build.skill_points == skill_points + 1 and same(home.exploration.micro.snapshot(), ledger), "loaded/original-return pocket must stay depleted and never repay")
	check(home.save_game(3), "returned pocket rewards must remain disk-saveable")
	completed = true

func check_blocks(game, record: Dictionary) -> void:
	var inventory: Dictionary = game.inventory.snapshot()
	var claimed: Dictionary = game.exploration.micro.claimed.duplicate(true)
	var original: Vector2 = game.player_point
	game.player_point += Vector2(20, 0)
	check(game.exploration.micro.target().is_empty() and not game.exploration.micro.claim(record), "distant pockets must not pay")
	game.player_point = original
	game.grounded = false
	check(game.exploration.micro.target().is_empty() and not game.exploration.micro.claim(record), "airborne claim must not pay")
	game.grounded = true
	game.online.session = true
	check(game.exploration.micro.target().is_empty() and not game.exploration.micro.claim(record), "online session must block local pocket rewards")
	game.online.session = false
	game.state = "paused"
	check(game.exploration.micro.target().is_empty() and not game.exploration.micro.claim(record), "paused claim must not pay")
	game.state = "playing"
	var forged: Dictionary = record.duplicate(true)
	forged.quantity += 1
	check(not game.exploration.micro.claim(forged), "forged rewards must not replace the authoritative generated record")
	check(game.inventory.snapshot() == inventory and game.exploration.micro.claimed == claimed, "blocked claims must preserve reward and claim state")

func check_full_bag(game, record: Dictionary) -> void:
	var inventory: Dictionary = game.inventory.snapshot()
	var full: Dictionary = inventory.duplicate(true)
	full.items = {"sanctum_sigil": 1, "health_potion": int(game.Inventory.ITEMS.health_potion.stack) * (game.Inventory.CAPACITY - 2), record.reward_item: 1}
	full.stolen = {}
	full.equipment = {"weapon": "", "armor": "", "charm": ""}
	if not check(game.inventory.restore(full, game.build.class_id) and game.inventory.slots_used() == game.Inventory.CAPACITY, "real valid full backpack must leave material stack room but no coin slot"):
		return
	check(1 + record.quantity <= int(game.Inventory.ITEMS[record.reward_item].stack) and not full.items.has("gold_coin"), "full-bag scenario must permit material insertion and fail specifically at the coin payout")
	var ledger: Dictionary = game.exploration.micro.snapshot()
	var points: int = game.build.skill_points
	press_e(game)
	check(game.inventory.snapshot() == full and same(game.exploration.micro.snapshot(), ledger) and game.build.skill_points == points, "coin-stage full-bag failure must roll back material and preserve discovery/claim ledger")
	check(game.inventory.restore(inventory, game.build.class_id), "original inventory must restore after isolated full-bag attempt")

func check_journal(game, records: Array[Dictionary]) -> void:
	game.expansion.toggle_journal()
	if not check(game.state == "journal", "actual J journal must open after pocket collection"):
		return
	var text := ""
	for control in game.expansion.overlay.find_children("*", "Control", true, false):
		if control is Label or control is Button:
			text += control.text + "\n"
	for record in records:
		check(text.contains(record.name), "actual journal must show collected pocket name: " + record.name)
		check(text.contains(record.flavor), "actual journal must retain pocket story: " + record.name)
	game.expansion.close_lore()
