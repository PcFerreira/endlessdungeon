extends SceneTree

const Game = preload("res://scripts/game.gd")
const Decor = preload("res://scripts/decor_geometry.gd")
var directory := "user://test-local-decor-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func verify(game, city: Dictionary) -> Dictionary:
	var identity := {}
	var styles = game.world_view.construction.catalog.styles
	var models: Dictionary = game.world_view.find_children("*", "Node3D", true, false).filter(func(node): return node.has_meta("house_models") and node.get_meta("house_models").has(city.houses[0].id))[0].get_meta("house_models")
	var charms := 0
	var signs := 0
	for node in game.world_view.find_children("*", "MeshInstance3D", true, false):
		var id: String = node.get_meta("asset_id", "")
		if not id.begins_with("native_decor:"):
			continue
		assert(styles.allows(id, city.biome))
		if node.get_meta("native_role") == "roof_charm" and models.has(node.get_meta("house_id")):
			var top := Decor.bounds(models[node.get_meta("house_id")]).end.y
			assert(node.position.y - .12 - .07 > top)
			identity[node.get_meta("house_id")] = [id, node.get_meta("support_height")]
			charms += 1
		elif node.get_meta("native_role") == "trade_sign":
			signs += 1
	assert(charms == city.magic.roof_charms.size() and signs > 0)
	for actor in game.life.actors.values():
		if actor.kind == "npc" and actor.city_id == city.id and (not actor.get("traveling", false) or actor.id.begins_with("watch:")):
			var model: Node3D = game.life_view.models[actor.id]
			for node in model.get_child(1).find_children("*", "MeshInstance3D", true, false):
				assert(styles.allows(node.get_meta("asset_id"), city.biome))
	return identity

func run() -> void:
	var game = fresh()
	game.start_run(12345)
	game.begin_journey()
	var cities := {}
	for x in range(-12, 13):
		for y in range(-12, 13):
			var city: Dictionary = game.world.region_at(Vector2i(x, y) * game.world.REGION_SIZE).city
			if not cities.has(city.biome):
				cities[city.biome] = city
			if cities.size() == 4:
				break
		if cities.size() == 4:
			break
	assert(cities.size() == 4)
	for biome in range(4):
		var city: Dictionary = cities[biome]
		var plan: Dictionary = city.duplicate(true)
		game._generate_surface(Vector2(city.cell) + Vector2(0, 3), false)
		var identity := verify(game, city)
		assert(game.world.region_at(city.cell).city == plan, "Presentation must not mutate authored city plans")
		var random_before: int = game.rng.state
		assert(game.save_game(1))
		game.queue_free()
		await process_frame
		game = fresh()
		assert(game.load_game(1) and game.rng.state == random_before)
		assert(verify(game, game.world.region_at(city.cell).city) == identity)
	print("PASS: actual four-climate decorative/sign/NPC family geometry, imported roof clearance, unchanged generated plans, fresh-scene disk and combat RNG")
	game.queue_free()
	await process_frame
	quit()
