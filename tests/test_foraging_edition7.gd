extends SceneTree

const Game = preload("res://scripts/game.gd")
const Catalog = preload("res://scripts/forage_catalog.gd")
const Foraging = preload("res://scripts/foraging.gd")
var directory := "user://test-foraging-edition7-%s" % OS.get_process_id()
var games := []
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> bool:
	if not condition:
		print("FAIL: " + message)
		failures += 1
	return condition

func new_game():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	games.append(game)
	return game

func patch(world) -> Dictionary:
	var center := Vector2i(floori(float(world.start.x) / Catalog.DATA.spacing), floori(float(world.start.y) / Catalog.DATA.spacing))
	for radius in range(19):
		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):
				if maxi(absi(x - center.x), absi(y - center.y)) != radius:
					continue
				var record := Catalog.plan(world, Vector2i(x, y))
				if not record.is_empty():
					return record
	return {}

func run_checks() -> void:
	run_game_checks()
	for game in games:
		game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
	if failures == 0:
		print("PASS: actual edition7 E harvest, clean reward, disk/fresh-Game restoration, physical Sanctum return and streaming depletion; legacy identities preserved")
	quit(0 if failures == 0 else 1)

func run_game_checks() -> void:
	var game = new_game()
	game.start_run(91, 7)
	var record := patch(game.world)
	if not check(not record.is_empty() and record.id.begins_with("endless:91:7@"), "actual World7 must allocate a reachable material patch"):
		return
	game._generate_surface(record.point, false)
	game._clear_actors()
	game.foraging.sync(true)
	if not check(game.world.walkable(record.point) and game.foraging.target().get("id", "") == record.id, "generated patch must be loaded on clear land and physically interactable"):
		return
	var quantity: int = game.inventory.count(record.item)
	var rng_state: int = game.rng.state
	game.interact()
	if not check(game.inventory.count(record.item) == quantity + record.quantity and game.inventory.stolen_count(record.item) == 0 and game.foraging.harvested.has(record.id) and not game.foraging.nodes.has(record.id) and game.rng.state == rng_state, "real E harvest must award clean material once without consuming gameplay RNG"):
		return
	var depletion: Dictionary = game.foraging.snapshot()
	print("Actual edition7 harvested: ", record.id, " ", record.item, " x", record.quantity)
	check(Foraging.valid(depletion, "91"), "real edition7 harvested ledger must validate")
	check(game.saves.validate(game.make_save_data()), "real harvested edition7 save envelope must validate")
	if not check(game.save_game(1), "real harvested edition7 save must write to disk: " + game.saves.last_error):
		return
	var fresh = new_game()
	if not check(fresh.load_game(1), "fresh Game must restore the harvested edition7 disk save"):
		return
	check(fresh.world.generator_version == 7 and fresh.foraging.snapshot() == depletion and fresh.inventory.count(record.item) == quantity + record.quantity, "fresh restoration must retain edition, reward and depletion")
	fresh._clear_actors()
	fresh.foraging.sync(true)
	check(not fresh.foraging.nodes.has(record.id), "fresh disk restoration must not respawn the harvested patch")
	if not check(fresh.use_sanctum_sigil() and fresh.layer == "sanctum", "actual H must reach Sanctum after harvesting"):
		return
	if not check(fresh.save_game(2), "Sanctum with suspended harvested7 journey must write to disk"):
		return
	var home = new_game()
	if not check(home.load_game(2) and home.layer == "sanctum", "fresh Game must restore the actual Sanctum disk location"):
		return
	if not check(home.use_sanctum_sigil() and home.layer == "overworld" and home.world.generator_version == 7 and home.player_point.is_equal_approx(record.point), "actual H must return to the original edition7 harvested location"):
		return
	home._clear_actors()
	home.foraging.sync(true)
	check(home.foraging.snapshot() == depletion and not home.foraging.nodes.has(record.id) and home.inventory.count(record.item) == quantity + record.quantity, "Sanctum disk return must retain reward and prevent duplicate collection")
	home._generate_surface(record.point + Vector2(90, 90), false)
	home._generate_surface(record.point, false)
	home._clear_actors()
	home.foraging.sync(true)
	check(not home.foraging.nodes.has(record.id) and not home.foraging.harvest(record), "unload/reload must not repay depleted7 patch")
	check(home.save_game(3), "returned harvested7 journey must remain disk-saveable")
	for edition in [4, 5, 6, 7]:
		check(Foraging.valid({"endless:91:%s@-2000000,2000000" % edition: true}, "91"), "supported old/new endless identities and coordinate boundaries must remain valid")
	for id in ["endless:91:3@0,0", "endless:91:8@0,0", "endless:92:7@0,0", "endless:91:7@2000001,0", "endless:91:7@0.5,0"]:
		check(not Foraging.valid({id: true}, "91"), "unsupported/malformed harvested identity must remain invalid: " + id)
