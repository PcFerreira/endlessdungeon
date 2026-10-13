extends SceneTree

const Enemies = preload("res://scripts/enemy_catalog.gd")
const EnemyModels = preload("res://scripts/enemy_models.gd")
const LifeCatalog = preload("res://scripts/world_life_catalog.gd")
const LifeView = preload("res://scripts/world_life_view.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("24343e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11
	stage.add_child(camera)
	call_deferred("capture")

func capture() -> void:
	var catalog := LifeCatalog.new()
	var fauna := LifeView.new()
	var pictures := 0
	for category in ["enemy", "animal"]:
		var count: int = Enemies.TYPES.size() if category == "enemy" else catalog.data.species.size()
		for biome in [0, 2]:
			for page in range(ceili(count / 12.0)):
				var gallery := Node3D.new()
				stage.add_child(gallery)
				for slot in range(12):
					var index := page * 12 + slot
					if index >= count:
						break
					var model: Node3D
					var title: String
					if category == "enemy":
						model = EnemyModels.create(index, 31, "", biome)
						title = Enemies.TYPES[index].name
					else:
						var species: Dictionary = catalog.data.species[index]
						model = fauna._create({"kind": "animal", "asset_id": catalog.model_choices[species.id][0].id, "biome": biome, "height": species.height})
						title = species.get("name", species.id)
					assert(model.get_meta("visual_family") == EnemyModels.creatures.styles.family_for(biome))
					model.position = Vector3((slot % 4 - 1.5) * 2.3, 0, (slot / 4 - 1) * 2.1)
					gallery.add_child(model)
					EnemyModels.animate(model, "walk")
					var floor := Voxels.cube(Vector3(1.5, .1, 1.5), Color("52696c"))
					floor.position = model.position + Vector3(0, -.05, 0)
					gallery.add_child(floor)
					var label := Label3D.new()
					label.text = title
					label.position = model.position + Vector3(0, -.15, .9)
					label.font_size = 24
					label.pixel_size = .006
					label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					gallery.add_child(label)
				for direction in [-1, 1]:
					camera.position = Vector3(direction * 7, 10, direction * 15)
					camera.look_at(Vector3(0, .6, 0))
					for frame in range(8):
						await process_frame
					RenderingServer.force_draw()
					assert(root.get_texture().get_image().save_png("res://artifacts/creatures-%s-biome%s-page%s-camera%s.png" % [category, biome, page, direction]) == OK)
					pictures += 1
				gallery.queue_free()
				await process_frame
	fauna.free()
	print("PASS: %s native opposing galleries; all %s enemy and %s fauna identities rendered through actual family-aware runtime models" % [pictures, Enemies.TYPES.size(), catalog.data.species.size()])
	stage.queue_free()
	await process_frame
	quit()
