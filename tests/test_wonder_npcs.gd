extends SceneTree

const World = preload("res://scripts/world.gd")
const Life = preload("res://scripts/world_life.gd")
const Roamers = preload("res://scripts/wilderness_roamers.gd")
const Catalog = preload("res://scripts/wonder_npc_catalog.gd")
const Actors = preload("res://scripts/actor_models.gd")
const Game = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	assert(_world_checks())
	assert(await _fresh_journey_checks())
	print("PASS: editions4/6/7 saved wonder identities and body families, legacy bodies, real fresh Worldgate HubWorld exterior allocation and reserved-island exclusion")
	quit()

func _world_checks() -> bool:
	assert(Catalog.valid(Catalog.DATA))
	var eligible := {}
	for biome in Catalog.Biomes.DATA.profiles:
		for choice in range(80):
			var id := Catalog.npc_for(biome,choice)
			assert(Catalog.npc_for(biome,choice) == id)
			if not id.is_empty():
				assert(biome in Catalog.npc(id).biomes)
				eligible[id] = true
	assert(eligible.size() == 4, "All four original roles must have eligible ecology pools")
	seed(918)
	var expected := randi()
	seed(918)
	Catalog.npc_for("greenwood",791)
	assert(randi() == expected, "NPC selection must leave gameplay random draws unchanged")
	var seen := {}
	var ordinary := {}
	for edition in [4,6,7]:
		var edition_seen := {}
		var world := World.new()
		world.generate(12345,edition)
		var life := Life.new()
		life.reset(12345)
		for point in [Vector2(40,100),Vector2(-96,35),Vector2(208,-120),Vector2(-208,240)]:
			world.load_around(point)
			life.sync(world,point)
			var walkers: Array = life.residents().filter(func(actor): return actor.get("roaming",false))
			assert(walkers.size() <= Roamers.MAX_ACTORS and life.actors.size() <= Life.MAX_ACTORS)
			for actor in walkers:
				ordinary[actor.roaming_profile] = true
				if not actor.get("wonder_id","").is_empty():
					seen[actor.wonder_id] = true
					edition_seen[actor.wonder_id] = true
					assert(actor.biome_id in Catalog.npc(actor.wonder_id).biomes)
					assert(not life.roamers.dialogue(actor,"topic_work",0).is_empty())
				assert(Roamers.allowed(world,actor.point,Roamers.grounds(world)))
			var snapshot: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
			assert(Life.valid_snapshot(snapshot,"12345",edition))
			var restored := Life.new()
			assert(restored.restore(snapshot,12345))
			restored.sync(world,point)
			for actor in walkers:
				assert(restored.actors.has(actor.id))
				assert(restored.actors[actor.id].get("wonder_id","") == actor.get("wonder_id",""), "A saved encounter must retain its original identity")
				if edition == 7 and not actor.get("wonder_id","").is_empty():
					for family in ["block_voxel","flat_lowpoly"]:
						var source: Dictionary = actor.duplicate(true)
						var resumed: Dictionary = restored.actors[actor.id].duplicate(true)
						source.visual_family = family
						resumed.visual_family = family
						var body := Actors.create(source.appearance,source)
						var restored_body := Actors.create(resumed.appearance,resumed)
						assert(body.get_meta("wonder_id") == actor.wonder_id and restored_body.get_meta("wonder_id") == actor.wonder_id)
						assert(body.get_meta("appearance_variant") == restored_body.get_meta("appearance_variant"))
						assert(restored_body.get_meta("visual_family") == family and restored_body.get_meta("representation") == "original_wonder_voxel")
						assert(Actors._bounds(body,Transform3D.IDENTITY).is_equal_approx(Actors._bounds(restored_body,Transform3D.IDENTITY)), "Edition7 saved NPCs must retain actual body geometry")
						body.free()
						restored_body.free()
			if not walkers.is_empty():
				var id: String = walkers[0].id
				for malformed in [null,1,"unlisted_being"]:
					var invalid := snapshot.duplicate(true)
					invalid.actors[id].wonder_id = malformed
					assert(not Life.valid_snapshot(invalid,"12345",edition))
				var invalid := snapshot.duplicate(true)
				for actor_id in invalid.actors:
					if not actor_id.begins_with("roamer:") and not actor_id.begins_with("road") and not actor_id.begins_with("watch"):
						invalid.actors[actor_id].wonder_id = "clay_herbalist"
						assert(not Life.valid_snapshot(invalid,"12345",edition))
						break
			var legacy: Dictionary = snapshot.duplicate(true)
			for record in legacy.actors.values():
				record.erase("wonder_id")
			var old_life := Life.new()
			assert(old_life.restore(legacy,12345))
			old_life.sync(world,point)
			assert(old_life.residents().filter(func(resident): return resident.get("roaming",false)).all(func(resident): return resident.get("wonder_id","").is_empty()), "Legacy save inhabitants must stay ordinary")
			if edition == 7:
				for actor in old_life.residents().filter(func(resident): return resident.get("roaming",false)):
					var body := Actors.create(actor.appearance,actor)
					assert(body.get_meta("representation") == "generated_voxel" and not body.has_meta("wonder_id"), "Unmarked edition7 records must retain ordinary voxel bodies")
					body.free()
		assert(not edition_seen.is_empty(), "Every supported tested edition must include real wonder folk")
	assert(not seen.is_empty(), "Real Endless wilderness must include original wonder folk")
	assert(ordinary.size() >= 4, "Ordinary roamer occupations must remain represented")
	return true

func _fresh_journey_checks() -> bool:
	var game := Game.new()
	var directory := "user://test-wonder-npcs-fresh-%s" % Time.get_ticks_usec()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345,World.NEW_JOURNEY_EDITION)
	game.has_journey = false
	game.begin_journey()
	assert(game.world.generator_version == 7 and game.world.get_script().resource_path == "res://scripts/hub_world.gd")
	assert(game.floating_hub.active())
	var hub = game.world.hub
	assert(game.life.roamers.sources(game.world,hub.spawn).is_empty(), "Lanternwake must retain its authored population")
	game.player_point = hub.portal + Vector2(.7,0)
	game.player_y = game.world.ground_height(game.player_point)
	game.grounded = true
	assert(game.world.walkable(game.player_point) and game.floating_hub.target().get("kind") == "depart")
	game.interact()
	assert(game.world.get_script().resource_path == "res://scripts/hub_world.gd" and not game.floating_hub.active(), "Normal Worldgate departure must retain its real HubWorld provider")
	assert(not hub.reserved.has_point(Vector2i(game.player_point.round())))
	assert(Roamers.supports(game.world,game.player_point))
	var encountered := {}
	var location := Vector2.INF
	for point in [game.player_point,Vector2(40,100),Vector2(-96,35),Vector2(208,-120),Vector2(-208,240)]:
		game.world.load_around(point)
		var sources: Array = game.life.roamers.sources(game.world,point)
		assert(sources.size() <= Roamers.MAX_ACTORS)
		for source in sources:
			assert(not hub.reserved.has_point(Vector2i(source.origin.round())))
			assert(source.spots.all(func(spot): return not hub.reserved.has_point(Vector2i(spot.round()))))
			if not source.get("wonder_id","").is_empty():
				encountered = source
				location = point
				break
		if not encountered.is_empty():
			break
	assert(not encountered.is_empty(), "Real fresh journeys must naturally stream wonder folk outside the retained HubWorld island")
	game._generate_surface(location,false)
	assert(game.life.actors.has(encountered.id))
	var actor: Dictionary = game.life.actors[encountered.id]
	assert(actor.wonder_id == encountered.wonder_id and game.world_view.npc_models.has(actor.id))
	var body: Node3D = game.world_view.npc_models[actor.id]
	assert(body.get_meta("wonder_id") == actor.wonder_id and body.get_meta("representation") == "original_wonder_voxel")
	assert(not hub.reserved.has_point(Vector2i(actor.point.round())))
	for point in [hub.spawn,hub.portal,Vector2(hub.center),Vector2(hub.reserved.position),Vector2(hub.reserved.end - Vector2i.ONE)]:
		game.world.load_around(point)
		assert(not Roamers.supports(game.world,point))
		assert(not Roamers.allowed(game.world,point,[]), "Origins and path steps must reject every reserved island position")
		assert(game.life.roamers.sources(game.world,point).is_empty())
	game.queue_free()
	await process_frame
	return true
