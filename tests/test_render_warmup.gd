extends SceneTree

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	if not ResourceLoader.exists("res://scripts/render_warmup.gd"):
		push_error("Native shader variants need a real rendered warmup before walking")
		quit(1)
		return
	var Warmup = load("res://scripts/render_warmup.gd")
	var warmup = Warmup.new()
	root.add_child(warmup)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	var source := MeshInstance3D.new()
	source.mesh = BoxMesh.new()
	source.material_override = material
	var before: Color = material.albedo_color
	warmup.configure([source], null)
	if DisplayServer.get_name() == "headless":
		assert(not warmup.busy and warmup.viewport == null, "Headless fixtures must not wait for nonexistent GPU frames")
	else:
		for attempt in range(600):
			await process_frame
			if not warmup.busy:
				break
		assert(not warmup.busy and warmup.rendered_variants >= 4 and warmup.rendered_draw_calls > 0, "Warmup must draw ordinary, instanced and four/eight-weight skinned geometry before reporting readiness")
		assert(warmup.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and warmup.samples.get_child_count() == 0, "Completed warmup must stop drawing and release temporary probes")
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 18
		root.add_child(camera)
		camera.make_current()
		var sun := DirectionalLight3D.new()
		sun.shadow_enabled = true
		root.add_child(sun)
		var main_warmup = Warmup.new()
		root.add_child(main_warmup)
		main_warmup.configure([source], null, camera, sun)
		for attempt in range(600):
			await process_frame
			if not main_warmup.busy:
				break
		assert(not main_warmup.busy and main_warmup.rendered_draw_calls > 0 and camera.is_current() and sun.shadow_enabled, "Main-viewport warmup must draw variants and restore the camera and sunlight")
		main_warmup.warm_scene()
		camera.size = 9
		await RenderingServer.frame_pre_draw
		assert(camera.size >= 160 and main_warmup.busy, "Actual loading draws must retain wide coverage after another camera snap")
		for attempt in range(600):
			await process_frame
			if not main_warmup.busy:
				break
		assert(not main_warmup.busy and camera.size == 18, "The completed loading draws restore the player's original zoom")
		main_warmup.queue_free()
		camera.queue_free()
		sun.queue_free()
	assert(material.albedo_color == before and source.material_override == material and source.get_parent() == null, "Warmup must preserve source materials and scene ownership")
	source.free()
	warmup.queue_free()
	await process_frame
	print("PASS: native rendered variants before readiness, inactive cleanup, source preservation and headless bypass")
	quit()
