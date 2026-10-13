extends SceneTree

const Quests = preload("res://scripts/local_quests.gd")
const History = preload("res://scripts/regional_history.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const Discovery = preload("res://scripts/discovery_catalog.gd")
const World = preload("res://scripts/world.gd")
const Inventory = preload("res://scripts/inventory.gd")
var game_script
var directory := "user://test-local-quests-%s" % Time.get_ticks_usec()

func definitions() -> Array:
	var result := []
	for file in DirAccess.get_files_at("res://lore/content/local_quests"):
		if file.ends_with(".json"):
			result.append(JSON.parse_string(FileAccess.get_file_as_string("res://lore/content/local_quests/" + file)))
	return result

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var quests := Quests.new(definitions())
	assert(quests.errors.is_empty(), str(quests.errors))
	var world := World.new()
	world.generate(91)
	var region: Dictionary = world.region_at(world.start)
	var history := History.new().plan(world, region, Sites.plan(world, region, Discovery.new()))
	var giver: Dictionary = region.city.residents[0]
	var offer := quests.offer(world, region, history, giver)
	assert(not offer.is_empty())
	var wilderness := region.duplicate(true)
	wilderness.city = {}
	wilderness.dungeons = []
	assert(quests.offer(world, wilderness, history, giver).is_empty())
	assert(History.new().plan(world, wilderness, {}).is_empty())
	assert(Sites.plan(world, wilderness, Discovery.new()).is_empty())
	assert(offer == quests.offer(world, region, history, giver))
	assert(offer.site_id == history.site_id and offer.giver_id == giver.id)
	assert(quests.accept(offer))
	assert(not quests.accept(offer))
	assert(not quests.inspect(offer.id, {"site_id": offer.site_id, "depth": 1, "book_id": offer.ruin_book, "point": [4,7]}), "A town ledger is required first")
	assert(quests.record_ledger(offer.id, region.city.id, offer.town_book))
	assert(not quests.inspect(offer.id, {"site_id": "ruin:999:999:0", "depth": 1, "book_id": offer.ruin_book, "point": [4,7]}))
	assert(quests.inspect(offer.id, {"site_id": offer.site_id, "depth": offer.site_floors, "book_id": offer.ruin_book, "point": [4,7]}))
	assert(not quests.report(offer.id, "other-resident", offer.answer))
	var wrong: String = "different" if offer.answer == "same" else "same"
	assert(not quests.report(offer.id, giver.id, wrong))
	assert(quests.report(offer.id, giver.id, offer.answer))
	assert(offer.id not in quests.active)
	assert(not quests.report(offer.id, giver.id, offer.answer))
	var inventory := Inventory.new()
	inventory.items = {"sanctum_sigil": 1, "health_potion": 460}
	assert(inventory.slots_used() == inventory.CAPACITY)
	assert(not quests.claim(offer.id, inventory))
	assert(not quests.records[offer.id].reward_claimed)
	assert(inventory.remove("health_potion", 20))
	assert(quests.claim(offer.id, inventory))
	assert(not quests.claim(offer.id, inventory))
	assert(inventory.count(offer.reward.item) == 1)
	var saved: Dictionary = quests.snapshot()
	var changed := definitions()
	for entry in changed:
		entry.version = 2
		entry.text = "Replacement offer for future travelers."
	var fresh := Quests.new(changed)
	assert(fresh.restore(JSON.parse_string(JSON.stringify(saved)), "91"))
	assert(fresh.snapshot() == saved)
	assert(not fresh.restore(saved, "92"))
	var invalid := saved.duplicate(true)
	invalid.records[offer.id].evidence.site_id = "ruin:99:99:0"
	assert(not Quests.valid_snapshot(invalid, "91"))
	var bad: Dictionary = definitions()[0].duplicate(true)
	bad.requires.append("future_puzzle")
	assert(not Quests.new([bad]).errors.is_empty())
	var limited := Quests.new(definitions())
	for index in range(Quests.MAX_ACTIVE + 1):
		var local: Dictionary = world.region_at(Vector2i(index + 1, -1) * World.REGION_SIZE)
		var account := History.new().plan(world, local, Sites.plan(world, local, Discovery.new()))
		var request := limited.offer(world, local, account, local.city.residents[0])
		assert(limited.accept(request) == (index < Quests.MAX_ACTIVE))
	if "--catalog-only" in OS.get_cmdline_user_args():
		print("PASS: local quest definitions, real-place binding, staged evidence, comparison, atomic delayed rewards and JSON validation")
		quit()
		return
	assert(Quests.new().definitions.size() >= definitions().size(), "Shipped lore registry must include local quests")
	game_script = load("res://scripts/game.gd")
	await check_game()
	print("PASS: actual local quest acceptance, town ledger and ruin inspection, return report, one-time furnishing reward, frozen editions and disk/home/legacy persistence")
	quit()

func new_game():
	var game = game_script.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func reachable(area, origin: Vector2i, destination: Vector2i) -> bool:
	var visited := {origin: true}
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		if cell == destination:
			return true
		for step in area.DIRECTIONS:
			var next: Vector2i = cell + step
			if not visited.has(next) and area.can_step(Vector2(cell), Vector2(next)):
				visited[next] = true
				queue.append(next)
	return false

func check_game() -> void:
	var game = new_game()
	game.start_run(91)
	game._clear_actors()
	var region: Dictionary = game.world.region_at(game.world.start)
	var giver: Dictionary = game.life.residents().filter(func(actor): return actor.id == region.city.residents[0].id)[0]
	game.player_point = giver.point
	assert(game.expansion.open_dialogue(giver))
	var controller = game.exploration.quests
	var offer: Dictionary = controller.for_resident(giver)
	assert(controller.open_resident(giver))
	assert(controller.accept(offer.id))
	controller.close()
	game.expansion.close_lore()
	var book: Dictionary = region.city.books[0]
	game.player_point = book.approach
	game.interact()
	assert(controller.state.records[offer.id].ledger_read)
	game.expansion.close_lore()
	var site: Dictionary = region.dungeons.filter(func(entry): return entry.id == offer.site_id)[0]
	game.enter_dungeon(site)
	game._clear_actors()
	var archive: Dictionary = game.dungeon.readables[0]
	assert(reachable(game.dungeon, game.dungeon.start, Vector2i(archive.approach)), "The real archive must have a physical walking route")
	game.player_point = archive.approach
	controller.sync_marker()
	assert(controller.marker.visible)
	var rng_before: int = game.rng.state
	game.interact()
	assert(game.state == "reader")
	assert(controller.state.records[offer.id].phase == "return")
	assert(game.rng.state == rng_before)
	game.expansion.close_lore()
	assert(game.save_game(1))
	var restored = new_game()
	assert(restored.load_game(1))
	assert(restored.exploration.quests.state.snapshot() == controller.state.snapshot())
	restored._clear_actors()
	assert(restored.use_sanctum_sigil())
	assert(restored.leave_sanctum())
	assert(restored.exploration.quests.state.snapshot() == controller.state.snapshot())
	restored.return_to_surface()
	restored._generate_surface(Vector2(region.city.cell), false)
	restored._clear_actors()
	var live: Dictionary = restored.life.residents().filter(func(actor): return actor.id == giver.id)[0]
	restored.player_point = live.point
	assert(restored.expansion.open_dialogue(live))
	var quest_ui = restored.exploration.quests
	assert(quest_ui.open_resident(live))
	assert(quest_ui.report(offer.id, offer.answer))
	assert(quest_ui.state.records[offer.id].reward_claimed)
	assert(restored.inventory.count(offer.reward.item) == 1)
	assert(not quest_ui.report(offer.id, offer.answer))
	quest_ui.close()
	assert(restored.expansion.dialogue_text.contains(offer.completion))
	restored.expansion.close_lore()
	assert(restored.save_game(1))
	var completed = new_game()
	assert(completed.load_game(1))
	assert(completed.inventory.count(offer.reward.item) == 1)
	assert(not completed.exploration.quests.state.claim(offer.id, completed.inventory), "Disk reload cannot repeat a reward")
	var legacy: Dictionary = restored.make_save_data()
	legacy.progress.exploration.erase("quests")
	assert(game_script.Journey.restore(restored, legacy))
	assert(restored.exploration.quests.state.records.is_empty())
	game.queue_free()
	restored.queue_free()
	completed.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
