extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://test-dimension-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run_checks")

func new_game():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func same_record(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	if left is Dictionary and right is Dictionary:
		return left.size() == right.size() and left.keys().all(func(key): return right.has(key) and same_record(left[key], right[key]))
	if left is Array and right is Array:
		return left.size() == right.size() and range(left.size()).all(func(index): return same_record(left[index], right[index]))
	return left == right

func run_checks() -> void:
	var game = new_game()
	game.start_run(12345)
	game._clear_actors()
	var origin: Dictionary = game.make_save_data().location.duplicate(true)
	assert(game.use_sanctum_sigil())
	assert(game.inventory.add("oak_chair"))
	assert(game.furnishings.place("oak_chair", Vector2(8, 11), 0, game.inventory))
	game.refresh_sanctum_furnishings()
	game.player_point = Vector2(5, 7)
	game._snap_camera()
	var home_point: Vector2 = game.player_point
	var thread: Dictionary = game.sanctum_return.duplicate(true)
	var furniture: Dictionary = game.furnishings.snapshot()
	game.interact()
	assert(game.floating_hub.active() and not game.dimension.active)
	game.player_point = game.floating_hub.portal_point("dimension")
	game._snap_camera()
	var hub_point: Vector2 = game.player_point
	game.interact()
	assert(game.dimension.active and game.layer == "overworld")
	assert(game.dimension.outside_return == thread and game.world_items.scope() == "dimension:morrowmere")
	assert(game.world.walkable(game.player_point))
	assert(not game.world_view.living_residents and game.life.actors.is_empty())
	var town: Dictionary = game.world.authored_sites().filter(func(site): return site.type == "city")[0]
	game._generate_surface(Vector2(town.cell), false)
	assert(game.world_view.npc_models.has(town.residents[0].id), "Finite authored residents must render while procedural life is disabled")
	assert(game.world.authored_sites().size() >= 24)
	for site in game.world.authored_sites():
		game._generate_surface(Vector2(site.approach), false)
		assert(game.world.walkable(game.player_point) and game.life.actors.is_empty())
		assert(game.enemies.all(func(enemy): return game.DimensionPopulation.hostile_point_allowed(game.world, enemy.point)))
		assert(is_equal_approx(game.player_y, game.world.ground_height(game.player_point)))
		assert(not game.world_view.living_residents)
		if site.type == "city":
			for resident in site.residents:
				assert(game.world_view.npc_models.has(resident.id), "Each authored town resident must render at the revised height")
				var actor: Node3D = game.world_view.npc_models[resident.id]
				assert(is_equal_approx(actor.global_position.y, game.world.ground_height(resident.point)), "Static town actors must stand on the revised ground")
	game._generate_surface(Vector2(game.world.start), false)
	game.player_point = game.world.safe_position(game.player_point + Vector2(.31, .17))
	game._snap_camera()
	var realm_point: Vector2 = game.player_point
	assert(game.save_game(1))
	var payload: Dictionary = game.saves.read(1).data
	assert(payload.progress.dimension.active and game.saves.validate(payload))
	assert(same_record(payload.progress.dimension.outside_return, thread) and payload.home.return_journey.is_empty())
	var fresh = new_game()
	assert(fresh.load_game(1) and fresh.dimension.active)
	assert(fresh.player_point.is_equal_approx(realm_point) and fresh.world_items.scope() == "dimension:morrowmere")
	assert(same_record(fresh.dimension.outside_return, thread) and same_record(fresh.furnishings.snapshot(), furniture))
	assert(fresh.use_sanctum_sigil() and fresh.floating_hub.active() and not fresh.dimension.active)
	assert(fresh.player_point.is_equal_approx(hub_point))
	assert(fresh.world_view.living_residents)
	assert(fresh.dimension.enter() and fresh.player_point.is_equal_approx(realm_point))
	var return_gate: Vector2 = fresh.world.return_portal
	fresh._generate_surface(return_gate, false)
	assert(fresh.interaction_hint() == "E: Return to Lanternwake")
	fresh.interact()
	assert(fresh.floating_hub.active() and fresh.player_point.is_equal_approx(hub_point))
	assert(fresh.dimension.enter() and fresh.player_point.is_equal_approx(return_gate))
	assert(fresh.use_sanctum_sigil() and fresh.floating_hub.active())
	assert(fresh.use_sanctum_sigil() and fresh.layer == "sanctum" and same_record(fresh.sanctum_return, thread))
	assert(fresh.save_game(2) and fresh.load_game(2) and fresh.layer == "sanctum")
	assert(fresh.leave_sanctum() and fresh.layer == origin.layer)
	assert(fresh.player_point.is_equal_approx(Vector2(origin.point[0], origin.point[1])))
	assert(same_record(fresh.furnishings.snapshot(), furniture) and fresh.dimension.snapshot().last_point == [return_gate.x, return_gate.y])
	fresh.player_point = fresh.world.safe_position(fresh.player_point + Vector2(.31, .17))
	fresh._snap_camera()
	var renewed_point: Vector2 = fresh.player_point
	assert(fresh.use_sanctum_sigil())
	fresh.player_point = fresh.floating_hub.sanctum_portal_point()
	fresh._snap_camera()
	fresh.interact()
	assert(Vector2(fresh.dimension.outside_return.location.point[0], fresh.dimension.outside_return.location.point[1]).is_equal_approx(renewed_point), "A later Sanctum departure must retain its own current outside thread")
	assert(fresh.use_sanctum_sigil() and fresh.leave_sanctum())
	var legacy: Dictionary = fresh.make_save_data()
	legacy.progress.erase("dimension")
	assert(fresh.saves.validate(legacy) and fresh.Journey.restore(fresh, legacy))
	assert(fresh.dimension.snapshot().is_empty())
	var malformed: Dictionary = payload.duplicate(true)
	malformed.progress.dimension.last_point = [2048, 1040]
	assert(not fresh.saves.validate(malformed))
	malformed = payload.duplicate(true)
	malformed.progress.dimension.map_revision = 999
	assert(not fresh.saves.validate(malformed))
	malformed = payload.duplicate(true)
	malformed.progress.dimension.outside_return = payload.duplicate(true)
	assert(not fresh.saves.validate(malformed), "A finite realm cannot recursively suspend another active dimension")
	fresh.online.session = true
	assert(not fresh.dimension.enter() and not fresh.dimension.return_to_sanctum())
	fresh.online.session = false
	await origin_roundtrip(fresh, "dungeon")
	await origin_roundtrip(fresh, "interior")
	game.queue_free()
	fresh.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: native hub/dimension portals, exact overworld/dungeon/interior thread, last-point disk restore/reentry, furniture, malformed and legacy saves")
	quit()

func origin_roundtrip(game, layer: String) -> void:
	game.start_run(12345)
	game._clear_actors()
	if layer == "dungeon":
		var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
		game.enter_dungeon(site)
		game._clear_actors()
		game.player_point = Vector2(game.dungeon.start)
	else:
		var city: Dictionary = game.world.nearest_site(game.player_point, "city")
		var place: Dictionary = game.interiors.describe(city, city.houses[0])
		game._generate_surface(place.approach, false)
		assert(game.interiors.enter(place))
	game._snap_camera()
	game._drop(game.player_point + Vector2.RIGHT * 3, "health")
	var origin: Dictionary = game.make_save_data()
	assert(origin.location.layer == layer and game.use_sanctum_sigil())
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	game.interact()
	game.player_point = game.floating_hub.portal_point("dimension")
	game._snap_camera()
	assert(game.dimension.enter() and game.save_game(3))
	assert(game.load_game(3) and game.dimension.active and game.use_sanctum_sigil())
	assert(game.use_sanctum_sigil() and game.layer == "sanctum")
	assert(game.leave_sanctum() and game.layer == layer)
	assert(game.player_point.is_equal_approx(Vector2(origin.location.point[0], origin.location.point[1])))
	assert(game.rng.state == origin.rng_state.to_int() and game.pickups.size() == origin.pickups.size())
	if layer == "dungeon":
		assert(game.active_dungeon.id == origin.location.site_id and game.depth == origin.location.depth)
	else:
		assert(game.interiors.current.id == origin.indoors.building_id)
