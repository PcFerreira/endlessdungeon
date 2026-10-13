extends SceneTree

const Game = preload("res://scripts/game.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
var directory := "user://test-sparse-region-%s" % OS.get_process_id()
var game

func _initialize() -> void:
	call_deferred("run_checks")

func new_game():
	var value := Game.new()
	value.records_enabled = false
	value.save_directory = directory
	value.settings_path = directory.path_join("settings.cfg")
	root.add_child(value)
	value.set_physics_process(false)
	return value

func move_to(point: Vector2) -> void:
	game._generate_surface(point, false)
	game._clear_actors()
	game.grounded = true
	game.exploration.sync()

func run_checks() -> void:
	game = new_game()
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
				var history: Dictionary = game.exploration.regional_record(region)
				for resident in region.city.residents:
					if not game.exploration.quests.state.offer(game.world, region, history, resident).is_empty():
						origin = region
						break
	assert(not marker.is_empty() and not origin.is_empty())
	move_to(Vector2(marker.approach[0], marker.approach[1]))
	assert(game.world.city_at(game.player_point).is_empty())
	assert(game.exploration.target().get("id") == marker.id)
	var rendered: Node3D = game.exploration.view.markers[marker.id]
	assert(game.exploration.view.models.styles.allows(rendered.get_meta("asset_id"), marker.biome))
	assert(rendered.get_meta("source_asset") == marker.model_id)
	var rng_before: int = game.rng.state
	game.interact()
	assert(game.state == "discovery_reader" and game.exploration.entries.has(marker.id))
	assert(game.rng.state == rng_before and game.exploration.history.records.is_empty())
	game.exploration.mark_site(marker.id)
	assert(game.waypoint.id == marker.site_id)
	game.exploration.close()
	move_to(Vector2(origin.city.cell) + Vector2(0, 3))
	var giver := {}
	var offer := {}
	for resident in game.life.residents():
		if resident.city_id != origin.city.id:
			continue
		var candidate: Dictionary = game.exploration.quests.for_resident(resident)
		if not candidate.is_empty():
			giver = resident
			offer = candidate
			break
	assert(not giver.is_empty())
	game.player_point = giver.point
	assert(game.expansion.open_dialogue(giver))
	assert(game.exploration.quests.open_resident(giver) and game.exploration.quests.accept(offer.id))
	game.exploration.quests.close()
	game.expansion.close_lore()
	var book: Dictionary = origin.city.books[0]
	game.player_point = book.approach
	game.interact()
	assert(game.state == "reader" and game.exploration.quests.state.records[offer.id].phase == "inscription")
	game.expansion.close_lore()
	game.exploration.mark_history(offer.region_id)
	assert(game.waypoint.id == offer.site_id)
	var site: Dictionary = game.world.site_by_id(offer.site_id, Vector2i(offer.site_cell[0], offer.site_cell[1]))
	assert(not site.is_empty() and site.coordinate != origin.coordinate)
	move_to(Vector2(site.approach))
	game.interact()
	assert(game.layer == "dungeon" and game.active_dungeon.id == offer.site_id)
	game._clear_actors()
	var archive: Dictionary = game.dungeon.readables[0]
	assert(reachable(game.dungeon, game.dungeon.start, Vector2i(archive.approach)))
	game.player_point = archive.approach
	game.interact()
	assert(game.state == "reader" and game.exploration.quests.state.records[offer.id].phase == "return")
	game.expansion.close_lore()
	assert(game.save_game(1))
	var saved: Dictionary = game.exploration.snapshot()
	game.queue_free()
	await process_frame
	game = new_game()
	assert(game.load_game(1) and game.world.generator_version == 5)
	assert(game.exploration.snapshot() == saved)
	game._clear_actors()
	assert(game.use_sanctum_sigil() and game.leave_sanctum())
	assert(game.exploration.snapshot() == saved)
	game.return_to_surface()
	move_to(Vector2(origin.city.cell) + Vector2(0, 3))
	var live: Dictionary = game.life.residents().filter(func(resident): return resident.id == giver.id)[0]
	game.player_point = live.point
	assert(game.expansion.open_dialogue(live) and game.exploration.quests.open_resident(live))
	assert(game.exploration.quests.report(offer.id, offer.answer))
	assert(game.inventory.count(offer.reward.item) == 1)
	assert(not game.exploration.quests.report(offer.id, offer.answer))
	game.exploration.quests.close()
	game.expansion.close_lore()
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = new_game()
	assert(game.load_game(1) and game.inventory.count(offer.reward.item) == 1)
	assert(not game.exploration.quests.state.claim(offer.id, game.inventory))
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: actual town-free clue/source-family E, exact atlas target, neighboring-dungeon quest dialogue/ledger/physical entry/archive/return/reward, fresh disk/home reconstruction and duplicate-reward refusal")
	quit()

func reachable(area, start: Vector2i, end: Vector2i) -> bool:
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var point: Vector2i = queue.pop_back()
		if point == end:
			return true
		for direction in area.DIRECTIONS:
			var next: Vector2i = point + direction
			if not visited.has(next) and area.can_step(Vector2(point), Vector2(next)):
				visited[next] = true
				queue.append(next)
	return false
