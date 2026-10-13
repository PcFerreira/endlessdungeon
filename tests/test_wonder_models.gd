extends SceneTree

const IDS := ["clay_herbalist", "moss_listener", "lantern_peddler", "scrap_fencer", "dew_jiggler", "rime_rooker", "bog_mossback", "choir_husk"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not FileAccess.file_exists("res://scripts/wonder_models.gd"):
		print("RED: Original wonder bodies are missing")
		quit(1)
		return
	var models = load("res://scripts/wonder_models.gd")
	var silhouettes := {}
	seed(991)
	var expected := randi()
	seed(991)
	for id in IDS:
		var body: Node3D = models.create(id, "block_voxel", 17)
		root.add_child(body)
		assert(body.get_meta("wonder_id") == id and body.get_meta("representation") == "original_wonder_voxel")
		var resting := bounds(body)
		assert(resting.position.y >= -.00001 and resting.position.y < .002)
		assert(resting.size.y > .3 and resting.size.y <= 1.35)
		if IDS.find(id) < 4:
			assert(absf(resting.size.y - 1.15) < .001)
		var signature := silhouette(body)
		assert(not silhouettes.has(signature), "Each character needs its own geometry")
		silhouettes[signature] = true
		var twin: Node3D = models.create(id, "block_voxel", 17)
		assert(signature == silhouette(twin), "Appearance must be reproducible")
		twin.free()
		var faceted: Node3D = models.create(id, "flat_lowpoly", 17)
		assert(faceted.get_meta("visual_family") == "flat_lowpoly")
		assert(signature != silhouette(faceted), "Faceted bodies need different vertices")
		var diagonal := false
		for mesh in faceted.find_children("*", "MeshInstance3D", true, false):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in range(0, points.size(), 3):
				assert(normals[index].dot((points[index+2]-points[index]).cross(points[index+1]-points[index]).normalized()) > .99, "Godot faces and normals must agree")
			for normal in normals:
				if absf(normal.x) > .1 and absf(normal.z) > .1:
					diagonal = true
		assert(diagonal, "Flat geometry needs real chamfer faces")
		root.add_child(faceted)
		for visual in [body, faceted]:
			var player: AnimationPlayer = visual.get_node("AnimationPlayer")
			for action in ["Idle", "Walk", "Wave", "Attack"]:
				assert(player.has_animation(action) and player.has_animation(action.to_lower()))
				player.play(action)
				var initial := silhouette(visual)
				var moved := false
				for step in range(81):
					player.seek(player.get_animation(action).length * step / 80.0, true)
					assert(bounds(visual).position.y >= -.0001, "%s %s must stay above its ground" % [id, action])
					moved = moved or silhouette(visual) != initial
				assert(moved, "%s needs actual joint motion" % action)
			visual.free()
	assert(randi() == expected, "Art must not advance combat/global randomness")
	assert(models.create("missing") == null and models.create(IDS[0], "missing") == null)
	print("PASS: Eight distinct original wonder bodies, both geometry families, reproducible art and grounded animated joints")
	quit()

func bounds(body: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var transform: Transform3D = body.global_transform.affine_inverse() * mesh.global_transform
		for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = transform * vertex
			result = AABB(point, Vector3.ZERO) if first else result.expand(point)
			first = false
	return result

func silhouette(body: Node3D) -> int:
	var vertices := PackedVector3Array()
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var transform: Transform3D = mesh.transform
		var parent: Node3D = mesh.get_parent()
		while parent != body:
			transform = parent.transform * transform
			parent = parent.get_parent()
		for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			vertices.append(transform * vertex)
	return hash(vertices)
