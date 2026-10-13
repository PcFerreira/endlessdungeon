extends SceneTree

const Game = preload("res://scripts/game.gd")
const Rooms = preload("res://scripts/interior_area.gd")
var game
var directory := "user://test-interiors-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	root.add_child(game)
	call_deferred("run_checks")

func run_checks() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	game.begin_journey()
	var city: Dictionary = game.world.nearest_site(game.player_point, "city")
	var types := {}
	for house in city.houses:
		var place: Dictionary = game.interiors.describe(city, house)
		types[place.type] = true
		game._generate_surface(place.approach)
		var outside: Vector2 = game.player_point
		assert(game.interaction_hint().begins_with("E: Enter"))
		game.interact()
		assert(game.layer == "interior" and game.enemies.is_empty())
		assert(game.dungeon.walkable(game.player_point))
		assert(game.interiors.current.id == place.id)
		var area := Rooms.new()
		area.generate(place)
		assert(area.tiles == game.dungeon.tiles)
		assert(area.walkable(Vector2(area.start)) and area.walkable(Vector2(area.exit)))
		var path := [Vector2(area.start)]
		var visited := {area.start: true}
		while not path.is_empty():
			var point: Vector2 = path.pop_front()
			for direction in area.DIRECTIONS:
				var next := point + Vector2(direction)
				if not visited.has(Vector2i(next)) and area.walkable(next):
					visited[Vector2i(next)] = true
					path.append(next)
		for readable in area.readables:
			assert(visited.has(Vector2i(readable.approach)))
		assert(game.save_game(1))
		var payload: Dictionary = game.saves.read(1).data
		assert(payload.location.layer == "interior")
		var invalid := payload.duplicate(true)
		invalid.indoors.building_id = "missing"
		assert(not game.Journey.restore(game, invalid))
		invalid = payload.duplicate(true)
		invalid.indoors.return_journey = payload.duplicate(true)
		assert(not game.saves.validate(invalid), "Indoor returns must not recurse")
		var fresh = Game.new()
		fresh.records_enabled = false
		fresh.save_directory = directory
		root.add_child(fresh)
		fresh.set_physics_process(false)
		assert(fresh.load_game(1) and fresh.layer == "interior")
		assert(fresh.interiors.current.id == place.id)
		fresh.interiors.leave()
		assert(fresh.layer == "overworld" and fresh.player_point.is_equal_approx(outside))
		fresh.queue_free()
		await process_frame
		assert(game.use_sanctum_sigil())
		assert(game.save_game(2))
		assert(game.use_sanctum_sigil() and game.layer == "interior")
		game.player_point = Vector2(game.dungeon.exit)
		game.interact()
		assert(game.layer == "overworld" and game.player_point.is_equal_approx(outside))
	assert(types.size() >= 5)
	var legacy: Dictionary = game.make_save_data()
	legacy.erase("indoors")
	assert(game.saves.validate(legacy) and game.Journey.restore(game, legacy))
	print("PASS: five enterable place types, connected furnished rooms/readables, exact exits, fresh-scene indoor saves, Sanctum round-trip, invalid/nested return rejection and legacy saves")
	game.queue_free()
	await process_frame
	quit()
