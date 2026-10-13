extends SceneTree

var catalog
var models
var examples := {"npcs": {}, "ambient": {}, "enemies": {}, "dungeon": {}}
var directory := "res://artifacts/wonder-folk/check-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	assert(ResourceLoader.exists("res://scripts/wonder_catalog.gd"), "The first original wonder folk need their shipped runtime catalog")
	catalog = load("res://scripts/wonder_catalog.gd")
	assert(ResourceLoader.exists("res://scripts/wonder_models.gd"), "The first original wonder folk need their runtime animated bodies")
	models = load("res://scripts/wonder_models.gd")
	assert(_catalog_checks())
	assert(await _model_checks())
	if "--models-only" in OS.get_cmdline_user_args():
		print("PASS: first-eight original catalogues, ecology-specific source pools, distinct two-family geometry, independent appearance RNG and working animation tracks")
		quit()
		return
	assert(_world_checks())
	if "--allocation-only" in OS.get_cmdline_user_args():
		print("PASS: first-eight catalogues, distinct animated models and actual naturally allocated ecology fixtures")
		quit()
		return
	assert(await _game_checks())
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var fixture := FileAccess.open(directory.path_join("examples.json"), FileAccess.WRITE)
	fixture.store_string(JSON.stringify(examples, "\t"))
	fixture.close()
	print("WONDER_FIXTURES: " + ProjectSettings.globalize_path(directory.path_join("examples.json")))
	print("PASS: original first-eight wonder folk, distinct animated bodies, real ecological allocation, peaceful and neutral behavior, actual dialogue/trade, combat rewards and disk/home persistence")
	quit()

func _catalog_checks() -> bool:
	assert(catalog.valid(catalog.DATA) and catalog.DATA.npcs.size() == 4 and catalog.DATA.creatures.size() == 4)
	var enemies = load("res://scripts/enemy_catalog.gd")
	var biomes = load("res://scripts/biome_catalog.gd")
	var areas = load("res://scripts/area_catalog.gd")
	var invalid: Dictionary = catalog.DATA.duplicate(true)
	invalid.creatures.dew_jiggler.damage = 1
	assert(not catalog.valid(invalid), "Peaceful wildlife cannot acquire damage through a malformed catalogue")
	invalid = catalog.DATA.duplicate(true)
	invalid.creatures.bog_mossback.biomes = ["missing_ecology"]
	assert(not catalog.valid(invalid), "Placement must reference a real biome")
	invalid = catalog.DATA.duplicate(true)
	invalid.npcs.clay_herbalist.trade_profile = "missing_store"
	assert(not catalog.valid(invalid))
	var new_enemy_ids: Array = catalog.enemy_definitions().map(func(definition): return definition.id)
	assert(new_enemy_ids.size() == 2)
	for id in catalog.DATA.creatures:
		var creature: Dictionary = catalog.DATA.creatures[id]
		if creature.disposition == "peaceful":
			assert(id not in new_enemy_ids and not enemies.TYPES.any(func(definition): return definition.id == id), "Peaceful wonder wildlife must stay outside enemy targeting and rewards")
			assert(catalog.ambient(id).asset_id == "wonder:" + id)
		else:
			assert(enemies.TYPES.count(enemies.TYPES[enemies.index_of(id)]) == 1 and enemies.TYPES[enemies.index_of(id)].id == id)
		for biome_id in biomes.DATA.profiles:
			var pool: Array = enemies.surface_pool(int(biomes.DATA.profiles[biome_id].climates[0]), "", biome_id)
			assert(pool.any(func(kind): return enemies.TYPES[kind].id == id) == (creature.disposition != "peaceful" and biome_id in creature.biomes), "Surface eligibility must use actual fourteen-profile ecology for " + id + "/" + biome_id)
			var sightings := {}
			for salt in range(90):
				var ambient: Dictionary = catalog.ambient_for(biome_id, salt)
				if not ambient.is_empty():
					assert(ambient.disposition == "peaceful" and biome_id in ambient.biomes)
					sightings[ambient.id] = true
			assert(sightings.has(id) == (creature.disposition == "peaceful" and biome_id in creature.biomes))
		for family in areas.DUNGEONS:
			assert(enemies.dungeon_pool(family).any(func(kind): return enemies.TYPES[kind].id == id) == (creature.disposition != "peaceful" and family in creature.families), "Crypt selection cannot leak into unrelated dungeon families")
	var neutral: Dictionary = enemies.TYPES[enemies.index_of("bog_mossback")]
	assert(not enemies.should_engage(neutral, false, true) and enemies.after_hit(neutral, false))
	var hostile: Dictionary = enemies.TYPES[enemies.index_of("choir_husk")]
	assert(enemies.should_engage(hostile, false, true))
	return true

func _model_checks() -> bool:
	var definitions: Dictionary = catalog.DATA.npcs.duplicate()
	definitions.merge(catalog.DATA.creatures)
	var fingerprints := {}
	var bounds_script = load("res://scripts/enemy_models.gd")
	for family in ["block_voxel", "flat_lowpoly"]:
		var distinct := {}
		for id in definitions:
			seed(813)
			var expected := randi()
			seed(813)
			var body: Node3D = models.create(id, family, 41)
			assert(randi() == expected, "Appearance cannot consume global gameplay randomness")
			assert(body != null and body.get_meta("wonder_id") == id and body.get_meta("visual_family") == family)
			assert(body.get_meta("representation") == "original_wonder_voxel", "New nonhuman bodies cannot silently use existing imported actors")
			var signature := _geometry(body)
			assert(not distinct.has(signature), "Different creature and resident identities need different geometry")
			distinct[signature] = true
			fingerprints[id + ":" + family] = signature
			var repeat: Node3D = models.create(id, family, 41)
			assert(_geometry(repeat) == signature and repeat.get_meta("appearance_variant") == body.get_meta("appearance_variant"))
			repeat.free()
			var bounds: AABB = bounds_script.bounds(body)
			assert(bounds.position.y >= -.001 and bounds.size.y >= .3 and bounds.size.y <= 1.5 and bounds.size.x <= 1.4 and bounds.size.z <= 1.4, "Original bodies must fit safe grounded actor footprints")
			root.add_child(body)
			await process_frame
			var player: AnimationPlayer = body.get_node("AnimationPlayer")
			for action in ["Idle", "Walk", "Wave", "Attack"]:
				assert(player.has_animation(action))
				var clip: Animation = player.get_animation(action)
				assert(clip.length > 0 and clip.get_track_count() > 0)
				for track in range(clip.get_track_count()):
					assert(body.get_node_or_null(NodePath(clip.track_get_path(track).get_concatenated_names())) != null, "Animation tracks must address real model joints")
				player.play(action)
				player.advance(0)
				var start := _pose(body)
				player.advance(clip.length * .23)
				assert(_pose(body) != start, "Named clips must visibly change the actor's actual joint transforms")
				assert(bounds_script.bounds(body).position.y >= -.002, "Limb poses cannot sink below the actor's ground")
			body.queue_free()
			await process_frame
		assert(distinct.size() == 8)
	for id in definitions:
		assert(fingerprints[id + ":block_voxel"] != fingerprints[id + ":flat_lowpoly"], "Faceted compatibility requires different geometry, not a metadata label")
	return true

func _geometry(body: Node3D) -> String:
	var pieces := []
	for part in body.find_children("*", "MeshInstance3D", true, false):
		assert(part.mesh != null and part.mesh.get_surface_count() > 0)
		for surface in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			assert(not arrays[Mesh.ARRAY_VERTEX].is_empty() and not arrays[Mesh.ARRAY_COLOR].is_empty())
			pieces.append([part.get_parent().position, arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL]])
	assert(not pieces.is_empty())
	return str(pieces).sha256_text()

func _pose(body: Node3D) -> Array:
	var result := []
	for child in body.get_children():
		if child is Node3D:
			result.append(child.transform)
	return result

func _world_checks() -> bool:
	var world = load("res://scripts/world.gd").new()
	var life = load("res://scripts/world_life.gd").new()
	var enemies = load("res://scripts/enemy_catalog.gd")
	var roamers = load("res://scripts/wilderness_roamers.gd")
	world.generate(91, 6)
	life.reset(91)
	var points: Dictionary = load("res://tools/biome_review_points.gd").find(world)
	for biome_id in points:
		if _biome_examples_complete(biome_id):
			continue
		var source: Vector2 = Vector2(points[biome_id].cell)
		for offset in [Vector2.ZERO, Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0), Vector2(0, -16), Vector2(32, 16), Vector2(-32, -16), Vector2(48, 0), Vector2(0, 48), Vector2(-48, 0), Vector2(0, -48)]:
			var center: Vector2 = source + offset
			world.load_around(center)
			var global_before: int = _seeded_sample()
			life.sync(world, center)
			assert(randi() == global_before, "Ecological life allocation cannot spend global combat randomness")
			assert(life.actors.size() <= life.MAX_ACTORS)
			for actor in life.actors.values():
				var wonder: String = actor.get("wonder_id", "")
				if actor.kind == "npc" and not wonder.is_empty():
					assert(catalog.DATA.npcs.has(wonder) and world.cell_info(Vector2i(actor.origin)).biome_id in catalog.DATA.npcs[wonder].biomes)
					assert(roamers.allowed(world, actor.point, roamers.grounds(world)), "Peaceful strange residents must retain traversable paths outside actual monster hazards")
					if not examples.npcs.has(wonder):
						examples.npcs[wonder] = _example(actor.id, actor.point, center, biome_id)
				if actor.kind == "animal" and catalog.DATA.creatures.has(actor.species):
					assert(catalog.DATA.creatures[actor.species].disposition == "peaceful")
					assert(world.cell_info(Vector2i(actor.origin)).biome_id in catalog.DATA.creatures[actor.species].biomes)
					assert(world.walkable(actor.point) and actor.asset_id == "wonder:" + actor.species)
					if not examples.ambient.has(actor.species) and actor.spots.size() > 1:
						examples.ambient[actor.species] = _example(actor.id, actor.point, center, biome_id)
			for chunk in world.chunks.values():
				assert(chunk.spawns.size() <= 2)
				for spawn in chunk.spawns:
					var definition: Dictionary = enemies.TYPES[spawn.kind]
					if not definition.has("wonder_id"):
						continue
					var info: Dictionary = world.cell_info(spawn.cell)
					assert(info.biome_id in definition.habitat.biome_ids and info.walkable and info.terrain == "land")
					assert(world.city_at(Vector2(spawn.cell), 4).is_empty() and Vector2(spawn.cell).distance_to(spawn.home) <= spawn.radius)
					if not examples.enemies.has(definition.id):
						examples.enemies[definition.id] = _example(spawn.id, Vector2(spawn.cell), center, info.biome_id)
			if _biome_examples_complete(biome_id):
				break
	_collect_enemy_examples(world, points)
	_collect_crypt(world, world.start)
	if examples.dungeon.is_empty():
		_collect_crypt(world, points.greenwood.cell)
	assert(examples.npcs.size() == 4, "All four original resident occupations must actually appear in native procedural life")
	assert(examples.ambient.size() == 2, "Both peaceful original species must actually appear in native ecological habitats")
	assert(examples.enemies.size() == 2, "Neutral and hostile original encounters must have naturally allocated grounds")
	assert(not examples.dungeon.is_empty(), "The choir husk must populate a real procedural crypt floor")
	print("Wonder allocation: 4 real strange residents, 2 actual peaceful animal habitats and 2 natural enemy grounds in fourteen-profile native world")
	return true

func _collect_enemy_examples(world, points: Dictionary) -> void:
	var grounds = load("res://scripts/monster_areas.gd")
	var enemies = load("res://scripts/enemy_catalog.gd")
	for id in ["bog_mossback", "choir_husk"]:
		if examples.enemies.has(id):
			continue
		var definition: Dictionary = catalog.DATA.creatures[id]
		for biome_id in definition.biomes:
			var anchor: Vector2i = points[biome_id].cell
			var center := Vector2i(floori(float(anchor.x) / world.REGION_SIZE), floori(float(anchor.y) / world.REGION_SIZE))
			for radius in range(4):
				for x in range(center.x - radius, center.x + radius + 1):
					for y in range(center.y - radius, center.y + radius + 1):
						if examples.enemies.has(id) or maxi(absi(x - center.x), absi(y - center.y)) != radius:
							continue
						var region: Dictionary = world.region_at(Vector2i(x, y) * world.REGION_SIZE)
						for area in grounds.plans(world, region):
							if world.cell_info(area.cell).get("biome_id", "") not in definition.biomes:
								continue
							var chunk_at: Vector2i = world.chunk_at(Vector2(area.cell))
							for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
								var chunk: Dictionary = world._build_chunk(chunk_at + offset)
								for spawn in chunk.spawns:
									if enemies.TYPES[spawn.kind].id != id:
										continue
									var info: Dictionary = chunk.cells[spawn.cell]
									assert(info.get("biome_id", "") in definition.biomes and info.walkable and info.terrain == "land")
									assert(world.city_at(Vector2(spawn.cell), 4).is_empty() and Vector2(spawn.cell).distance_to(spawn.home) <= spawn.radius)
									examples.enemies[id] = _example(spawn.id, Vector2(spawn.cell), Vector2(area.cell), info.biome_id)
								if examples.enemies.has(id):
									break
							if examples.enemies.has(id):
								break
				if examples.enemies.has(id):
					break
			if examples.enemies.has(id):
				break

func _collect_crypt(world, anchor: Vector2i) -> void:
	var dungeon = load("res://scripts/dungeon.gd").new()
	var enemies = load("res://scripts/enemy_catalog.gd")
	var center := Vector2i(floori(float(anchor.x) / world.REGION_SIZE), floori(float(anchor.y) / world.REGION_SIZE))
	for radius in range(4):
		for x in range(center.x - radius, center.x + radius + 1):
			for y in range(center.y - radius, center.y + radius + 1):
				if maxi(absi(x - center.x), absi(y - center.y)) != radius:
					continue
				for site in world.region_at(Vector2i(x, y) * world.REGION_SIZE).dungeons:
					if site.family not in catalog.DATA.creatures.choir_husk.families:
						continue
					for floor_index in range(1, int(site.floors) + 1):
						dungeon.generate(site.seed, floor_index, site.family, world._biome_at(site.cell))
						for index in range(dungeon.spawns.size()):
							var spawn: Dictionary = dungeon.spawns[index]
							if enemies.TYPES[spawn.kind].id == "choir_husk":
								examples.dungeon = {"site_id": site.id, "site_cell": [site.cell.x, site.cell.y], "floor": floor_index, "family": site.family, "id": "%s:floor%s:enemy%s" % [site.id, floor_index, index], "point": [spawn.cell.x, spawn.cell.y]}
								return

func _seeded_sample() -> int:
	seed(1237)
	var expected := randi()
	seed(1237)
	return expected

func _example(id: String, point: Vector2, source: Vector2, biome_id: String) -> Dictionary:
	return {"id": id, "point": [point.x, point.y], "source": [source.x, source.y], "biome_id": biome_id}

func _biome_examples_complete(biome_id: String) -> bool:
	for id in catalog.DATA.npcs:
		if biome_id in catalog.DATA.npcs[id].biomes and not examples.npcs.has(id):
			return false
	for id in catalog.DATA.creatures:
		if catalog.DATA.creatures[id].disposition == "peaceful" and biome_id in catalog.DATA.creatures[id].biomes and not examples.ambient.has(id):
			return false
	return true

func _game_checks() -> bool:
	var game = load("res://scripts/game.gd").new()
	game.records_enabled = false
	game.save_directory = directory.path_join("preview-saves")
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(91, 6)
	game.begin_journey()
	for id in examples.npcs:
		assert(await _npc_game(game, id))
	for id in examples.ambient:
		assert(await _ambient_game(game, id))
	assert(await _neutral_game(game))
	assert(await _hostile_game(game))
	assert(await _crypt_game(game))
	game.queue_free()
	await process_frame
	return true

func _load_example(game, record: Dictionary) -> void:
	game.life.reset(91)
	game._generate_surface(Vector2(record.source[0], record.source[1]), false)
	game.grounded = true
	game.state = "playing"

func _approach(game, point: Vector2, reach: float = .7) -> Vector2:
	for offset in [Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach), Vector2.ZERO]:
		var candidate: Vector2 = point + offset
		if game.world.walkable(candidate) and game.world.line_clear(candidate, point) and absf(game.world.ground_height(candidate) - game.world.ground_height(point)) < .5:
			game.player_point = candidate
			game.player_y = game.world.ground_height(candidate)
			game._snap_camera()
			return candidate
	return Vector2.INF

func _npc_game(game, wonder_id: String) -> bool:
	var record: Dictionary = examples.npcs[wonder_id]
	_load_example(game, record)
	assert(game.life.actors.has(record.id))
	var actor: Dictionary = game.life.actors[record.id]
	assert(actor.kind == "npc" and actor.wonder_id == wonder_id and not game.valid_enemy(actor))
	assert(game.world_view.npc_models.has(actor.id))
	var body: Node3D = game.world_view.npc_models[actor.id]
	assert(body.get_meta("wonder_id") == wonder_id and body.get_meta("representation") == "original_wonder_voxel")
	var appearance: int = body.get_meta("appearance_variant")
	var family: String = body.get_meta("visual_family")
	assert(_approach(game, actor.point).is_finite())
	assert(game.expansion.target().get("id", "") == actor.id and game.interaction_hint().contains(catalog.DATA.npcs[wonder_id].name.to_lower()))
	game.select_target(actor)
	assert(game.selected_target.is_empty(), "Talking residents must never become combat targets")
	var rng_before: int = game.rng.state
	game.interact()
	assert(game.state == "dialogue" and game.expansion.speaker.id == actor.id)
	assert(not game.expansion.dialogue_text.is_empty())
	game.expansion.talk("topic_work")
	assert(game.expansion.dialogue_text == catalog.DATA.npcs[wonder_id].work, "The actual work callback must use the new resident's original authored occupation")
	game.expansion.talk("topic_route")
	assert(game.expansion.dialogue_text.contains(actor.city_name))
	var paused: Dictionary = game.life.snapshot()
	game._physics_process(.5)
	assert(game.life.snapshot() == paused, "Dialogue must pause new resident movement")
	assert(game.rng.state == rng_before, "Appearance and dialogue cannot consume combat RNG")
	if not actor.wonder_trade_profile.is_empty():
		assert(_npc_trade(game, actor))
	else:
		assert(not game.expansion.overlay.find_children("*", "Button", true, false).any(func(button): return button.text == "Trade"), "A dialogue-only resident cannot advertise an unsupported trade service")
		game.expansion.close_lore()
	var point: Vector2 = actor.point
	assert(game.save_game(1) and game.load_game(1))
	assert(game.life.actors.has(actor.id) and game.life.actors[actor.id].point.is_equal_approx(point))
	assert(game.life.actors[actor.id].wonder_id == wonder_id and game.world_view.npc_models[actor.id].get_meta("appearance_variant") == appearance and game.world_view.npc_models[actor.id].get_meta("visual_family") == family)
	assert(game.use_sanctum_sigil() and game.layer == "sanctum")
	var home_tick: int = game.life.tick
	game.simulate(2)
	assert(game.life.tick == home_tick and game.leave_sanctum())
	assert(game.life.actors.has(actor.id) and game.life.actors[actor.id].wonder_id == wonder_id and game.life.actors[actor.id].point.is_equal_approx(point))
	assert(game.world_view.npc_models[actor.id].get_meta("appearance_variant") == appearance)
	print("Wonder real resident: " + wonder_id + " / E, work, route, service, disk and home")
	await process_frame
	return true

func _npc_trade(game, actor: Dictionary) -> bool:
	var rng_before: int = game.rng.state
	var buttons: Array[Node] = game.expansion.overlay.find_children("*", "Button", true, false).filter(func(button): return button.text == "Trade")
	assert(buttons.size() == 1, "Supported resident trade must have a real dialogue action")
	buttons[0].emit_signal("pressed")
	assert(game.state == "store" and game.stores.current.wonder_actor == actor.id)
	var store_id: String = game.stores.current.id
	assert(store_id == "city:wonder:" + actor.id and game.stores.target().id == store_id)
	var material := "forage_bramble_berries"
	assert(game.inventory.add(material, 2))
	var before: Dictionary = game.inventory.snapshot()
	var purse: int = game.stores.records[store_id].purse
	game.stores.records[store_id].purse = 0
	assert(not game.stores.sell(material) and game.inventory.snapshot() == before, "A strange traveling shop must retain the finite-purse rollback rule")
	game.stores.records[store_id].purse = purse
	var coins: int = game.inventory.count("gold_coin")
	var price: int = maxi(1, floori(game.stores.catalog.price(material) * game.stores.catalog.data.buyback_fraction))
	assert(game.stores.sell(material) and game.inventory.count(material) == int(before.items.get(material, 0)) - 1 and game.inventory.count("gold_coin") == coins + price)
	assert(game.stores.records[store_id].purse == purse - price and game.inventory.stolen_count("gold_coin") == 0)
	var stock: int = game.stores.records[store_id].stock[material]
	var point: Vector2 = game.player_point
	game.player_point = actor.point + Vector2(3, 0)
	before = game.inventory.snapshot()
	assert(not game.stores.sell(material) and game.inventory.snapshot() == before, "Leaving the actual resident must invalidate an open trade")
	game.player_point = point
	game.stores.close()
	assert(game.state == "playing")
	assert(game.rng.state == rng_before, "A strange resident's stock, pricing and transaction must preserve combat RNG")
	var source: Dictionary = actor.duplicate(true)
	source.id = "roamer:999:999:0"
	assert(not game.stores.open_wonder(source), "Invented resident records cannot open free shops")
	var saved: Dictionary = game.make_save_data()
	assert(game.saves.validate(saved) and game.save_game(2) and game.load_game(2))
	assert(game.stores.records[store_id].stock[material] == stock and game.stores.records[store_id].purse == purse - price, "New resident shops must preserve finite stock and purse on disk")
	assert(game.life.actors.has(actor.id))
	return true

func _ambient_game(game, wonder_id: String) -> bool:
	var record: Dictionary = examples.ambient[wonder_id]
	_load_example(game, record)
	assert(game.life.actors.has(record.id))
	var actor: Dictionary = game.life.actors[record.id]
	assert(actor.kind == "animal" and actor.species == wonder_id and actor.asset_id == "wonder:" + wonder_id)
	assert(game.life_view.models.has(actor.id))
	var body: Node3D = game.life_view.models[actor.id]
	assert(body.get_meta("representation") == "original_wonder_voxel" and body.get_meta("source_asset") == actor.asset_id)
	assert(not game.valid_enemy(actor) and not game.enemies.any(func(enemy): return enemy.species == wonder_id))
	game.select_target(actor)
	assert(game.selected_target.is_empty())
	var kills: int = game.kills
	var before: Vector2 = actor.point
	var rng_before: int = game.rng.state
	var excursion := 0.0
	for frame in range(360):
		game.life.advance(.1)
		game.life.step(game.world, actor.origin + Vector2(18, 18), .1)
		excursion = maxf(excursion, actor.point.distance_to(before))
	assert(excursion > .05 and game.world.walkable(actor.point), "Peaceful wildlife must physically wander on supported ground")
	game.life_view.sync(game)
	assert(game.kills == kills and game.rng.state == rng_before and not actor.has("hp"), "Peaceful wildlife cannot acquire hostile health or rewards")
	var counterfeit: Dictionary = game.make_save_data()
	counterfeit.progress.life.actors[actor.id].asset_id = "wonder:bog_mossback"
	assert(not game.saves.validate(counterfeit), "Saved peaceful identities cannot carry a hostile body source")
	var point: Vector2 = actor.point
	assert(game.save_game(3) and game.load_game(3))
	assert(game.life.actors.has(actor.id) and game.life.actors[actor.id].species == wonder_id and game.life.actors[actor.id].asset_id == "wonder:" + wonder_id and game.life.actors[actor.id].point.is_equal_approx(point))
	assert(game.life_view.models[actor.id].get_meta("representation") == "original_wonder_voxel")
	assert(_safe_near(game, point).is_finite() and game.use_sanctum_sigil() and game.leave_sanctum())
	assert(game.life.actors.has(actor.id) and game.life.actors[actor.id].species == wonder_id and game.life.actors[actor.id].point.is_equal_approx(point))
	print("Wonder peaceful wildlife: " + wonder_id + " / real movement, no combat, disk and home")
	await process_frame
	return true

func _neutral_game(game) -> bool:
	var record: Dictionary = examples.enemies.bog_mossback
	_load_example(game, record)
	var found: Array = game.enemies.filter(func(enemy): return enemy.id == record.id)
	assert(found.size() == 1 and found[0].species == "bog_mossback")
	var enemy: Dictionary = found[0]
	assert(enemy.model.get_meta("wonder_id") == "bog_mossback" and enemy.model.get_meta("representation") == "original_wonder_voxel")
	_keep_enemy(game, enemy)
	assert(_approach(game, enemy.point).is_finite())
	var hp: float = game.hp
	var health: float = enemy.hp
	var rng_before: int = game.rng.state
	for frame in range(30):
		game._update_enemies(.1)
	assert(not enemy.active and enemy.windup == 0 and game.hp == hp and enemy.hp == health, "A nearby neutral creature must not initiate combat")
	assert(game.summons.summon("lantern_familiar"))
	var ally: Dictionary = game.summons.allies[0]
	assert(game.summons._target(ally).is_empty(), "A real companion must ignore an unselected passive neutral")
	game.summons.step(.2)
	assert(enemy.hp == health and not enemy.active)
	game.summons.clear()
	assert(game.rng.state == rng_before, "Idle territory and appearance must preserve combat RNG")
	game._hit_enemy(enemy, 1)
	assert(enemy.active and enemy.hp == health - 1, "An actual direct hit must activate retaliation")
	enemy.attack = 0
	game._update_enemies(.1)
	assert(enemy.windup > 0, "The retaliating melee creature must enter a real telegraphed attack")
	var variant: String = enemy.variant
	assert(variant.begins_with("wonder:bog_mossback:") and game.save_game(1) and game.load_game(1))
	found = game.enemies.filter(func(actor): return actor.id == record.id)
	assert(found.size() == 1 and found[0].variant == variant and is_equal_approx(found[0].hp, health - 1))
	assert(found[0].model.get_meta("representation") == "original_wonder_voxel")
	assert(_safe_near(game, found[0].point).is_finite())
	game._update_enemies(.1)
	assert(game.use_sanctum_sigil() and game.leave_sanctum())
	found = game.enemies.filter(func(actor): return actor.id == record.id)
	assert(found.size() == 1 and found[0].variant == variant and is_equal_approx(found[0].hp, health - 1))
	print("Wonder neutral encounter: real passive proximity, companion exclusion, first-hit retaliation and disk/home descriptor/health")
	await process_frame
	return true

func _hostile_game(game) -> bool:
	var record: Dictionary = examples.enemies.choir_husk
	_load_example(game, record)
	var found: Array = game.enemies.filter(func(enemy): return enemy.id == record.id)
	assert(found.size() == 1 and found[0].species == "choir_husk")
	var enemy: Dictionary = found[0]
	assert(enemy.model.get_meta("wonder_id") == "choir_husk" and enemy.model.get_meta("representation") == "original_wonder_voxel")
	_keep_enemy(game, enemy)
	assert(_approach(game, enemy.point, 2).is_finite())
	enemy.attack = 0
	game._update_enemies(.1)
	assert(enemy.active and enemy.windup > 0, "Hostile haunted creatures must begin real ranged telegraphs on sight")
	for frame in range(10):
		game._update_enemies(.1)
	assert(game.projectiles.any(func(shot): return shot.hostile), "The new crypt threat must actually cast its supported ranged attack")
	game.select_target(enemy)
	assert(game.selected_target == enemy)
	var kills: int = game.kills
	game._hit_enemy(enemy, 100000)
	assert(game.kills == kills + 1 and game.selected_target.is_empty() and game.encounter_states[record.id].hp == 0)
	assert(game.pickups.any(func(pickup): return pickup.kind == "gold_coin"), "Hostile wonder deaths must retain normal coin rewards")
	for frame in range(100):
		game._update_projectiles(.1)
	assert(game.save_game(2) and game.load_game(2))
	assert(game.kills == kills + 1 and not game.enemies.any(func(actor): return actor.id == record.id), "A naturally allocated hostile death must remain defeated on disk")
	assert(_safe_near(game, Vector2(record.point[0], record.point[1])).is_finite())
	assert(game.use_sanctum_sigil() and game.leave_sanctum())
	assert(not game.enemies.any(func(actor): return actor.id == record.id) and game.encounter_states[record.id].hp == 0)
	print("Wonder hostile encounter: real ranged telegraph/projectile, kill/coin reward and disk/home defeat persistence")
	await process_frame
	return true

func _keep_enemy(game, retained: Dictionary) -> void:
	for enemy in game.enemies.duplicate():
		if enemy == retained:
			continue
		enemy.node.queue_free()
		game.enemies.erase(enemy)

func _safe_near(game, anchor: Vector2) -> Vector2:
	for distance in [12, 16, 20]:
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var point: Vector2 = game.world.safe_position(anchor + direction * distance)
			if not game.world.walkable(point):
				continue
			game.player_point = point
			game._snap_camera()
			if game.sanctum_problem().is_empty():
				return point
	return Vector2.INF

func _crypt_game(game) -> bool:
	var record: Dictionary = examples.dungeon
	var cell := Vector2i(record.site_cell[0], record.site_cell[1])
	var site: Dictionary = game.world.site_by_id(record.site_id, cell)
	assert(not site.is_empty() and site.type == "dungeon" and site.family == record.family and record.floor <= site.floors)
	game._generate_surface(Vector2(site.cell), false)
	game.enter_dungeon(site)
	if game.depth != record.floor:
		game.depth = record.floor
		game._generate_floor()
	assert(game.layer == "dungeon" and game.dungeon.family == record.family)
	var found: Array = game.enemies.filter(func(enemy): return enemy.id == record.id)
	assert(found.size() == 1 and found[0].species == "choir_husk")
	var enemy: Dictionary = found[0]
	assert(enemy.model.get_meta("representation") == "original_wonder_voxel" and enemy.model.get_meta("wonder_id") == "choir_husk", "Real crypt encounters must use their own original bell-rib body, including the dungeon model branch")
	game.player_point = enemy.point
	game.select_target(enemy)
	game.interface._process(0)
	assert(game.interface.target_status.text == "%s / %s" % [ceili(enemy.hp), ceili(enemy.max_hp)], "Fractional dungeon scaling must not display health above its own maximum")
	var variant: String = enemy.variant
	assert(game.save_game(3) and game.load_game(3))
	found = game.enemies.filter(func(actor): return actor.id == record.id)
	assert(found.size() == 1 and found[0].variant == variant and found[0].model.get_meta("wonder_id") == "choir_husk")
	game._hit_enemy(found[0], 100000)
	assert(game.save_game(3) and game.load_game(3) and not game.enemies.any(func(actor): return actor.id == record.id))
	print("Wonder real procedural crypt: original choir body, generated floor eligibility and descriptor/defeat disk persistence")
	await process_frame
	return true
