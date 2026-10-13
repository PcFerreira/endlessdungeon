extends SceneTree

const Game = preload("res://scripts/game.gd")
var game

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/life-preview-saves"
	root.add_child(game)
	game.set_physics_process(false)
	call_deferred("capture")

func capture() -> void:
	game.set_physics_process(false)
	game.start_run(12345)
	game.notification_time = 0
	var city: Dictionary = game.world.region_at(game.world.start).city
	game.player_point = Vector2(city.cell) + Vector2(0,8)
	game._snap_camera()
	await move_for(8)
	await frame("life-town-routines")
	game.life.advance(32)
	await move_for(5)
	assert(game.life.event_at(city.id).kind == "supper")
	await frame("life-fountain-supper")
	var resident: Dictionary = game.life.actors[city.residents[1].id]
	game.player_point = resident.point + Vector2(.65,0)
	game._snap_camera()
	game.interact()
	assert(game.state == "dialogue")
	game.expansion.talk("topic_local_life")
	await frame("life-local-dialogue")
	var tick: int = game.life.tick
	var poses := {}
	for id in game.life_view.animations:
		for player in game.life_view.animations[id]:
			poses[player] = player.current_animation_position
	for index in range(8):
		await process_frame
	assert(game.life.tick == tick)
	for player in poses:
		assert(is_equal_approx(poses[player], player.current_animation_position))
	game.expansion.close_lore()
	game.player_point = Vector2(city.cell) + Vector2(0,8)
	game._snap_camera()
	game.life.advance(110)
	await move_for(4)
	await frame("life-local-delivery")
	game.life.advance(25)
	game.life_view.sync(game)
	await frame("life-delivery-aftermath")
	var found := false
	for x in range(-3,4):
		if found:
			break
		for y in range(-3,4):
			game._generate_surface(Vector2(x * Game.World.REGION_SIZE + 8,y * Game.World.REGION_SIZE + 8), false)
			var wildlife: Array = game.life.actors.values().filter(func(actor): return actor.id.begins_with("habitat:"))
			if not wildlife.is_empty():
				game.player_point = game.world.safe_position(wildlife[0].point + Vector2(0,5), 3)
				game._snap_camera()
				await move_for(3)
				await frame("life-wilderness-group")
				found = true
				break
	assert(found, "The normal streamed world must contain eligible wilderness groups")
	game._generate_surface(Vector2(game.world.start), false)
	game.world_view.visible = false
	game.interface.set_process(false)
	game.interface.hide()
	game.player.visible = false
	var floor_model: MeshInstance3D = game.Voxels.cube(Vector3(12,.08,7), Color("666850"))
	floor_model.position = Vector3(city.cell.x, game.world.ground_height(city.cell) - .05, city.cell.y + 1.2)
	game.add_child(floor_model)
	game.camera.size = 12
	game.life.actors.clear()
	game.life.cities.clear()
	for index in range(game.life.catalog.data.species.size()):
		var definition: Dictionary = game.life.catalog.data.species[index]
		var choices: Array = game.life.catalog.model_choices[definition.id]
		var point := Vector2(city.cell) + Vector2((index % 5 - 2) * 1.8, floorf(index / 5.0) * 2.4)
		game.life.actors[definition.id] = {"id": definition.id, "kind": "animal", "species": definition.id, "asset_id": choices[0].id, "height": definition.height, "idle": definition.idle, "walk": definition.walk, "point": point, "heading": Vector2.DOWN, "moving": false}
	game.life_view.sync(game)
	for id in game.life_view.models:
		var label := Label3D.new()
		label.text = id.capitalize()
		label.font_size = 24
		label.pixel_size = .009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = game.life.actors[id].height + .35
		game.life_view.models[id].add_child(label)
	game.player_point = Vector2(city.cell) + Vector2(0,4)
	game._snap_camera()
	await frame("life-nine-species")
	assert(game.life_view.models.size() == 9)
	for id in game.life_view.models:
		var model: Node3D = game.life_view.models[id]
		assert(game.life_view.Actors._bounds(model, Transform3D.IDENTITY).size.y > .1)
	floor_model.queue_free()
	game.player.visible = true
	game.interface.show()
	game.interface.set_process(true)
	game._generate_surface(Vector2(game.world.start), false)
	var samples := []
	for index in range(600):
		game.life.advance(1.0 / 60)
		var before := Time.get_ticks_usec()
		game.life.step(game.world, Vector2(city.cell) + Vector2(0,9), 1.0 / 60)
		samples.append(Time.get_ticks_usec() - before)
	samples.sort()
	print("Living coordinator CPU only: median %s us, p95 %s us, max %s us; %s samples; excludes rendering, streaming and other systems" % [samples[300], samples[570], samples[-1], samples.size()])
	print("PASS: native resident routines, supper/delivery/aftermath, actual E dialogue, frozen modal animation, streamed wilderness group and nine fauna models")
	game.queue_free()
	await process_frame
	quit()

func move_for(seconds: int) -> void:
	for index in range(seconds * 60):
		game.life.advance(1.0 / 60)
		game.life.step(game.world, game.player_point, 1.0 / 60)
		game.life_view.sync(game)
		await process_frame

func frame(label: String) -> void:
	game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
	for index in range(6):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) == OK)
