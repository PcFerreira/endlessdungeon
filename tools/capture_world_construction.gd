extends SceneTree

const Game = preload("res://scripts/game.gd")
const Construction = preload("res://scripts/world_construction.gd")
const Scenery = preload("res://scripts/scenery.gd")
var game
var construction := Construction.new()
var scenery := Scenery.new()

func _initialize() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = "res://artifacts/construction-preview-saves"
	root.add_child(game)
	call_deferred("capture")

func capture() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1280,800)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_run(12345)
	game.has_journey = true
	game.state = "playing"
	var city: Dictionary = game.world.region_at(game.world.start).city
	await _frame("town")
	for lot in city.outdoor_lots:
		game.player_point = Vector2(lot.approach)
		game._snap_camera()
		await _frame(lot.kind)
	var site: Dictionary = game.world.nearest_site(game.player_point, "dungeon")
	game._generate_surface(Vector2(site.cell) + Vector2.DOWN * 2)
	await _frame("entrance")
	game.target_yaw = PI * 1.25
	game.camera_yaw = game.target_yaw
	game._snap_camera()
	await _frame("entrance-reverse")
	game.state = "paused"
	game.world_view.visible = false
	game.life_view.visible = false
	game.actors.visible = false
	game.player.visible = false
	game.interface.visible = false
	game.expansion.visible = false
	game.exploration.visible = false
	var stage := Node3D.new()
	game.add_child(stage)
	game.camera_yaw = PI / 4
	for recipe in construction.catalog.data.recipes:
		for child in stage.get_children():
			stage.remove_child(child)
			child.queue_free()
		var context := {"region_id":"preview", "city_type":recipe.get("city_types", ["city_market"])[0], "biome":recipe.get("biomes", [1])[0], "family":recipe.get("families", [""])[0]}
		var model := construction.build(construction.catalog.plan(recipe, context,12345))
		assert(model != null, recipe.id)
		stage.add_child(model)
		var size := Vector3(recipe.footprint[0] + 1,.08,recipe.footprint[1] + 1)
		var floor: MeshInstance3D = game.Voxels.cube(size, Color("627277"))
		floor.position.y = -.04
		stage.add_child(floor)
		var scale: float = maxf(recipe.footprint[0],recipe.footprint[1])
		game.camera.position = Vector3(6,7,8)
		game.camera.look_at(Vector3(0,.4,0))
		game.camera.size = maxf(4.5,scale * 2)
		await _frame("recipe-" + recipe.id, false)
	print("PASS: native contextual market/farm/entrance scenes, reverse entrance, and every supported construction recipe")
	game.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func _frame(name: String, update: bool = true) -> void:
	if update:
		game.ambience.context_timer = 0
		game.ambience.update(game,2)
		game._snap_camera()
	for frame in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	assert(root.get_texture().get_image().save_png("res://artifacts/construction-%s.png" % name) == OK)
