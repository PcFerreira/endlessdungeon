extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var directory := "user://monster-pack-preview-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("capture")

func frame(label: String, center: Vector2) -> void:
	game.camera_focus = game.to_world(center)
	game.camera.position = game.camera_focus + Vector3(sin(game.camera_yaw) * 20, 14, cos(game.camera_yaw) * 20)
	game.camera.look_at(game.camera_focus)
	game.camera.size = 18
	game.world_view.update_visibility(center, game.world.ground_height(center), game.camera_yaw)
	for index in range(8):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)

func open_patch(center: Vector2) -> Vector2:
	for x in range(-8, 9):
		for y in range(-8, 9):
			var point := center + Vector2(x,y)
			if not game.world.city_at(point, 4).is_empty():
				continue
			var clear := true
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var next := point + Vector2(dx,dy)
					clear = clear and game.world.walkable(next) and absf(game.world.ground_height(next) - game.world.ground_height(point)) <= .5
			if clear:
				return point
	return Vector2.INF

func capture() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345, 6)
	game.begin_journey()
	var grounds: Array = game.world.MonsterAreas.plans(game.world, game.world.region_at(game.world.start))
	var home := Vector2.INF
	var kind := 0
	for area in grounds:
		if int(area.id.get_slice(":", 3)) < 3:
			continue
		game._generate_surface(Vector2(area.cell), false)
		var members: Array = game.enemies.filter(func(enemy): return enemy.grounds.area_id == area.id)
		if members.size() < 3:
			continue
		home = open_patch(Vector2(area.cell))
		if home == Vector2.INF:
			continue
		kind = members[0].kind
		game.player_point = game.world.safe_position(Vector2(area.cell))
		game.notify(area.label + " / naturally generated pack")
		await frame("monster-expanded-ground", Vector2(area.cell))
		break
	assert(home != Vector2.INF, "An added ground needs a visible natural pack and reachable spacing fixture")
	game._clear_actors()
	game.life.actors.clear()
	game.player_point = game.world.safe_position(home + Vector2(0,10))
	game._snap_camera()
	for index in range(3):
		game._spawn_enemy(home, kind, "spacing-preview:%s" % index)
		game.enemies[-1].grounds = {"home": home, "radius": 7, "cell": Vector2i(home) + [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN][index]}
		game.enemies[-1].attack = 100.0
	game.notify("Spacing stress fixture: three creatures sharing one point")
	await frame("monster-pack-overlap-fixture", home)
	for index in range(240):
		game._update_enemies(1.0 / 60)
	for enemy in game.enemies:
		for other in game.enemies:
			if enemy.id != other.id:
				assert(enemy.point.distance_to(other.point) + .05 >= enemy.spacing_radius + other.spacing_radius)
	game.notify("The pack spreads out at normal movement speed")
	await frame("monster-pack-spaced", home)
	game.queue_free()
	await process_frame
	var folder := DirAccess.open(directory)
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("PASS: native added-ground natural encounter and exact-overlap pack recovery captures")
	quit()
