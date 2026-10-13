extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://test-surface-places-%s" % OS.get_process_id()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	call_deferred("run_checks")

func run_checks() -> void:
	game.start_run(0, 5)
	var sites := {}
	for x in range(-2, 3):
		for y in range(-2, 3):
			for site in game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE).locations:
				sites[site.type] = site
	assert(sites.size() == 4)
	var sanctuary: Vector2 = game.sanctuary
	var taken := {}
	for kind in ["ruin", "castle", "church", "temple"]:
		var site: Dictionary = sites[kind]
		game._generate_surface(site.books[0].approach, false)
		game._clear_actors()
		game.world_items.register_location()
		game.grounded = true
		assert(game.world.city_at(game.player_point).is_empty() and game.location_name() == site.name)
		assert(game.expansion.target().get("id") == site.books[0].id, "The declared reading approach must support actual E")
		assert(game.interaction_hint().contains("Read"))
		game.interact()
		assert(game.state == "reader" and game.expansion.current_book == site.books[0].book_id)
		assert(game.exploration.knowledge.state(site.id) == "visited")
		game.expansion.close_lore()
		game.player_point = site.rest_point
		game.hp = game.max_hp * .5
		game.mana = game.max_mana * .5
		assert(game.interaction_hint().contains("Rest"))
		game.interact()
		assert(game.hp == game.max_hp and game.mana == game.max_mana and game.sanctuary == sanctuary)
		game._spawn_enemy(game.player_point + Vector2(1, 0), 0)
		game.hp = game.max_hp * .5
		game.interact()
		assert(game.hp == game.max_hp * .5, "Authored wilderness shelter cannot heal through nearby danger")
		game._clear_actors()
		game.world_items.register_location()
		var sources: Array = game.world_items.registered.values().filter(func(entry): return entry.record.uid.begins_with(site.id + ":"))
		if sources.size() < 4:
			print("GOODS: ", {"site": site.id, "kind": kind, "registered": game.world_items.registered.keys(), "location_chunk": game.world_view.chunk_nodes.has(game.world.chunk_at(Vector2(site.cell)))})
		assert(sources.size() >= 4, "Actual independent places must expose their compatible individual goods")
		for entry in sources:
			assert(entry.record.owner.is_empty() and entry.node.get_meta("site_id") == site.id)
			assert(game.world_view.location_view.architecture.styles.allows(entry.record.model_id, site.biome))
			assert(game.world_view.location_view.architecture.styles.allows(entry.record.model_id, game.world.cell_info(Vector2i(game.world_items.position(entry.record).round())).biome))
			assert(entry.record.get("access_cells", []).size() <= 16)
			assert(not entry.record.uid.ends_with("reader_lectern") and not entry.record.uid.ends_with("reader_book"))
		var child: Dictionary = sources.filter(func(entry): return not entry.record.parent.is_empty() and not game.world_items.has_children(entry.record.uid))[0]
		var child_uid: String = child.record.uid
		var parent_uid: String = child.record.parent
		assert(game.world_items.registered.has(parent_uid) and game.world_items.registered[parent_uid].node.visible)
		game.player_point = game.world.safe_position(game.world_items.position(child.record))
		assert(not game.world_items.pickup(parent_uid), "Real supported goods must be taken before their support")
		var picked: bool = game.world_items.pickup(child_uid)
		if not picked:
			print("PICKUP: ", {"kind": kind, "record": child.record, "point": game.player_point, "nearby": game.world_items.nearby(), "children": game.world_items.has_children(child_uid), "state": game.state, "grounded": game.grounded, "error": game.world_items.state.error})
		assert(picked and not child.node.visible)
		assert(game.inventory.stolen.is_empty() and game.world_items.wanted(site.id).is_empty(), "Wild goods cannot acquire a fictitious city owner")
		taken[child_uid] = site
	assert(game.save_game(1))
	game.queue_free()
	await process_frame
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.load_game(1) and game.world.generator_version == 5)
	for uid in taken:
		var site: Dictionary = taken[uid]
		game._generate_surface(site.books[0].approach, false)
		game._clear_actors()
		game.world_items.register_location()
		assert(game.world_items.registered.has(uid) and not game.world_items.registered[uid].node.visible)
		assert(game.exploration.knowledge.state(site.id) == "visited")
	assert(game.use_sanctum_sigil() and game.leave_sanctum())
	assert(game.sanctuary == sanctuary and game.world.generator_version == 5)
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: all four actual independent places; physical E readers/rest/danger gate, real compatible unowned goods/support-first refusal, fixed readers, fresh disk masks/knowledge/streaming/home and unchanged sanctuary")
	quit()
