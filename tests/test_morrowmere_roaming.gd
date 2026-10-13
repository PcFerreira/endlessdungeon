extends SceneTree

const Game = preload("res://scripts/game.gd")
const Population = preload("res://scripts/dimension_population.gd")
var directory := "user://test-morrowmere-roaming-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_run(12345)
	game._clear_actors()
	assert(game.use_sanctum_sigil())
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	assert(game.floating_hub.from_sanctum())
	game.player_point = game.floating_hub.portal_point("dimension")
	game._snap_camera()
	assert(game.dimension.enter())
	var residents := Population.resident_records(game.world)
	assert(residents.size() == 64, "The route update must preserve all64 authored identities")
	var minimum_span := Vector2.INF
	var moved := {}
	for resident in residents:
		game._generate_surface(resident.home, false)
		assert(game.population.actors.has(resident.id))
		var actor: Dictionary = game.population.actors[resident.id]
		var minimum: Vector2 = actor.point
		var maximum: Vector2 = actor.point
		var travelled := 0.0
		var phase_changes := 0
		for frame in range(128):
			var before: Vector2 = actor.point
			var phase: int = actor.route_index
			game.population.step(.25)
			minimum = minimum.min(actor.point)
			maximum = maximum.max(actor.point)
			travelled += before.distance_to(actor.point)
			phase_changes += int(phase != actor.route_index)
			assert(game.world._supported(actor.point), "Actual route motion must remain body-clear: " + resident.id)
			assert(is_equal_approx(game.population.models[resident.id].position.y, game.world.ground_height(actor.point)))
		var span := maximum - minimum
		assert(span.x > .5 and span.y > .5 and travelled > 3 and phase_changes >= 2, "Actual citizen must traverse both open-area axes: %s span=%s distance=%s phases=%s" % [resident.id, span, travelled, phase_changes])
		minimum_span = minimum_span.min(span)
		moved[resident.id] = true
		assert(game.population.actors.size() <= Population.ACTIVE_LIMIT and game.life.actors.is_empty())
	assert(moved.size() == 64)
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: all64 actual authored citizens traverse both courtyard/clearing axes with supported bodies, changing route phases and bounded actor counts; minimum span=%s" % minimum_span)
	quit()
