extends SceneTree

const Models = preload("res://scripts/biome_models.gd")
const WorldView = preload("res://scripts/world_view.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var models := Models.new()
var stage := Node3D.new()
var bodies := Node3D.new()
var camera := Camera3D.new()
var directory := "res://artifacts/biome-bodies"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.add_child(stage)
	stage.add_child(bodies)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("384356")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color.WHITE
	sky.ambient_light_energy = .6
	environment.environment = sky
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	light.shadow_enabled = true
	stage.add_child(light)
	var ground := Voxels.cube(Vector3(10,.08,7), Color("65736a"))
	ground.position.y = -.045
	stage.add_child(ground)
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11
	camera.look_at_from_position(Vector3(0,8,12),Vector3(0,1,0))
	call_deferred("capture")

func capture() -> void:
	var records := {}
	for role in ["giant_mushroom", "autumn_tree"]:
		for batch in [false, true]:
			for child in bodies.get_children():
				bodies.remove_child(child)
				child.queue_free()
			for row in range(2):
				var biome := row * 2
				for seed_value in range(4):
					var model := models.create(role, biome, seed_value)
					var point := Vector3(-3 + seed_value * 2,0,-1.7 + row * 3.4)
					var key := "%s:%s:%s" % [role,biome,seed_value]
					records[key] = {"source":model.get_meta("source_asset"),"render":model.get_meta("render_asset"),"representation":model.get_meta("representation")}
					if batch:
						model.free()
						var view := WorldView.new()
						bodies.add_child(view)
						view._batch_biome(view,"biome:%s:%s:%s" % [role,biome,seed_value],[Transform3D(Basis.IDENTITY,point)])
					else:
						model.position = point
						bodies.add_child(model)
					var label := Label3D.new()
					var source_name: String = role if records[key].source.begins_with("biome_geometry:") else records[key].source.get_file().get_basename()
					label.text = "%s  seed%s\n%s" % ["cube" if biome==0 else "faceted",seed_value,source_name]
					label.font_size = 30
					label.pixel_size = .003
					label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					label.position = point + Vector3(0,.1,.8)
					bodies.add_child(label)
			for frame in range(8):
				await process_frame
			RenderingServer.force_draw(false)
			assert(root.get_texture().get_image().save_png(directory.path_join(role + ("-batch" if batch else "-direct") + ".png")) == OK)
	FileAccess.open(directory.path_join("sources.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("PASS: mushroom/autumn direct and production-batched geometry across seed0..3 and both families; sources.json records actual provenance")
	quit()
