extends SceneTree

const History = preload("res://scripts/regional_history.gd")
const World = preload("res://scripts/world.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const Catalog = preload("res://scripts/discovery_catalog.gd")
var game_script
var directory := "user://test-regional-history-%s" % Time.get_ticks_usec()

func _init() -> void:
	call_deferred("run_checks")

func definitions() -> Array:
	var result := []
	for file in DirAccess.get_files_at("res://lore/content/regional_history"):
		if file.ends_with(".json"):
			result.append(JSON.parse_string(FileAccess.get_file_as_string("res://lore/content/regional_history/" + file)))
	return result

func run_checks() -> void:
	var history := History.new(definitions())
	assert(history.errors.is_empty(), str(history.errors))
	var world := World.new()
	world.generate(91)
	var region: Dictionary = world.region_at(world.start)
	var marker := Sites.plan(world, region, Catalog.new())
	var record := history.plan(world, region, marker)
	assert(record == history.plan(world, region, marker))
	assert(record.site_id == marker.site_id)
	assert(record.city_id == region.city.id)
	assert(not record.text.contains("{") and not record.witness_text.contains("{"))
	assert(history.learn(record, "book"))
	assert(not history.learn(record, "book"))
	assert(history.learn(record, "witness"))
	assert(not history.complete(record.region_id))
	assert(history.learn(record, "landmark"))
	assert(history.complete(record.region_id))
	assert(not history.observe(record.region_id, {"kind": "supper", "phase": "active", "home_city_id": region.city.id}), "Active episodes are not completed facts")
	assert(not history.observe(record.region_id, {"kind": "supper", "phase": "aftermath", "home_city_id": "city:999:999"}), "Other towns cannot supply local facts")
	var saved: Dictionary = history.snapshot()
	var changed := definitions()
	for entry in changed:
		entry.text = "Replacement edition for future regions."
	var fresh := History.new(changed)
	assert(fresh.restore(JSON.parse_string(JSON.stringify(saved)), "91"))
	assert(fresh.snapshot() == saved, "Collected history must survive JSON and content changes")
	assert(not fresh.restore(saved, "92"))
	assert(fresh.snapshot() == saved)
	var corrupt := saved.duplicate(true)
	corrupt.records[record.region_id].sources["invented"] = true
	assert(not History.valid_snapshot(corrupt, "91"))
	var quiet := History.new(definitions()).plan(world, region, {})
	assert("landmark" not in quiet.required_sources, "Quiet regions must have completable collections")
	var bad: Dictionary = definitions()[0].duplicate(true)
	bad.requires.append("future_quest")
	assert(not History.new([bad]).errors.is_empty())
	bad = definitions()[0].duplicate(true)
	bad.text = "Unbound {future_place}"
	assert(not History.new([bad]).errors.is_empty())
	var profiles := {}
	var quiet_regions := 0
	for coordinate in [Vector2i.ZERO, Vector2i(-1,0), Vector2i(0,-1), Vector2i(2,2), Vector2i(-3,-2), Vector2i(20,-17)]:
		var local: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
		var local_marker := Sites.plan(world, local, Catalog.new())
		var local_record := history.plan(world, local, local_marker)
		assert(local_record == history.plan(world, local, local_marker))
		profiles[local_record.template_id] = true
		assert(local.dungeons.any(func(site): return site.id == local_record.site_id and site.name == local_record.site_name))
		if local_marker.is_empty():
			quiet_regions += 1
			assert("landmark" not in local_record.required_sources)
	assert(profiles.size() > 1 and quiet_regions > 0)
	if "--catalog-only" in OS.get_cmdline_user_args():
		print("PASS: regional history source catalogue, deterministic real-place bindings, quiet-region collections, immutable editions and validation")
		quit()
		return
	var runtime := History.new()
	assert(runtime.errors.is_empty())
	for definition in definitions():
		assert(runtime.definitions.any(func(entry): return entry.id == definition.id), "The shipped registry must include authored history")
	game_script = load("res://scripts/game.gd")
	await check_game()
	print("PASS: stable regional history, shared real-place facts, completable source collections, actual local-event aftermath, frozen editions and disk/home persistence")
	quit()

func new_game():
	var game = game_script.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func move_to(game, point: Vector2) -> void:
	game._generate_surface(point, false)
	game._clear_actors()
	game.player_point = point
	game.grounded = true
	game.exploration.sync()

func check_game() -> void:
	var game = new_game()
	game.start_run(91)
	var region: Dictionary = game.world.region_at(game.world.start)
	var book: Dictionary = region.city.books[0]
	move_to(game, book.approach)
	assert(game.world.walkable(book.approach))
	var rng_before: int = game.rng.state
	game.interact()
	assert(game.state == "reader", "Town book E state: %s, hint: %s, target: %s" % [game.state, game.interaction_hint(), game.expansion.target()])
	assert(game.rng.state == rng_before)
	var key := Sites.region_key(game.world, region)
	assert(game.exploration.history.records[key].sources.has("book"))
	game.expansion.close_lore()
	game.life.sync(game.world, Vector2(region.city.cell))
	var resident: Dictionary = game.life.residents().filter(func(actor): return actor.id == region.city.residents[0].id)[0]
	game.player_point = resident.point
	assert(game.expansion.open_dialogue(resident))
	assert(game.exploration.read_witness(resident))
	assert(game.state == "discovery_reader")
	assert(game.exploration.history.records[key].sources.has("witness"))
	game.exploration.close()
	assert(game.state == "dialogue")
	game.expansion.close_lore()
	var marker := Sites.plan(game.world, region, game.exploration.catalog)
	move_to(game, Vector2(marker.approach[0], marker.approach[1]))
	rng_before = game.rng.state
	game.interact()
	assert(game.state == "discovery_reader")
	assert(game.exploration.history.complete(key))
	assert(game.rng.state == rng_before)
	var frozen: String = game.exploration.entries[marker.id].text
	game.exploration.close()
	game.life.advance(75)
	assert(game.life.event_at(region.city.id).phase == "aftermath")
	game.interact()
	assert(game.exploration.history.records[key].notes.size() == 1)
	game.exploration.close()
	game.interact()
	assert(game.exploration.history.records[key].notes.size() == 1)
	assert(game.exploration.entries[marker.id].text == frozen, "Aftermath cannot rewrite a collected passage")
	game.exploration.close()
	game.life.advance(240)
	game.interact()
	assert(game.exploration.history.records[key].notes.size() == 1, "Repeated town cycles must keep bounded latest notes")
	game.exploration.close()
	assert(game.save_game(1))
	var fresh = new_game()
	assert(fresh.load_game(1))
	assert(fresh.exploration.history.snapshot() == game.exploration.history.snapshot())
	fresh._clear_actors()
	assert(fresh.use_sanctum_sigil())
	assert(fresh.leave_sanctum())
	assert(fresh.exploration.history.snapshot() == game.exploration.history.snapshot())
	var legacy: Dictionary = fresh.make_save_data()
	legacy.progress.exploration.erase("regions")
	legacy.progress.exploration.entries[marker.id].text = marker.text
	assert(game_script.Journey.restore(fresh, legacy))
	assert(fresh.exploration.history.records.is_empty())
	move_to(fresh, Vector2(marker.approach[0], marker.approach[1]))
	fresh.interact()
	assert(fresh.exploration.entries[marker.id].text == marker.text, "A legacy collected landmark passage must stay unchanged")
	assert(fresh.exploration.history.records[key].sources.has("landmark"))
	fresh.exploration.close()
	game.queue_free()
	fresh.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
