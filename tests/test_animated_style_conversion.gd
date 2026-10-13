extends SceneTree

const Voxelizer = preload("res://scripts/town_model_voxelizer.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const Style = preload("res://scripts/animated_model_style.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)

func _initialize() -> void:
	var script: Script = Voxelizer.new().get_script()
	if script.get_script_method_list().filter(func(method): return method.name == "voxelize" and method.args.size() >= 3).is_empty():
		printerr("FAIL: style conversion must preserve skin/bone attributes")
		quit(1)
		return
	call_deferred("run")

func attributes(mesh: Mesh, skinned: bool, context: String = "synthetic") -> void:
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		check(vertices.size() > 0 and arrays[Mesh.ARRAY_COLOR] != null, "Converted geometry must retain real vertices and sampled source colors")
		for vertex in vertices:
			check(vertex.is_finite(), "Converted model vertices must stay finite")
		for color in arrays[Mesh.ARRAY_COLOR]:
			check(is_finite(color.r) and is_finite(color.g) and is_finite(color.b), "Converted sampled colors must stay finite")
		for index in range(0, vertices.size(), 3):
			check((vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).dot(normals[index]) < 0, "Converted visible faces must preserve Godot winding")
		if not skinned:
			return
		check(arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null, "Converted animated meshes must retain bone/weight attributes")
		if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			return
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		check(weights.size() == vertices.size() * 4, "Every converted vertex needs four normalized skin lanes")
		for index in range(0, weights.size(), 4):
			var total := 0.0
			for offset in range(4):
				check(weights[index + offset] >= 0 and is_finite(weights[index + offset]), "Skin weights must be finite and nonnegative")
				total += weights[index + offset]
			check(absf(total - 1) < .0001, "Converted skin weights must sum to one within mesh-storage precision: %s / %s" % [context, total])

func run() -> void:
	var degenerate := Voxelizer._weights(Vector2.ZERO, Vector2.ONE, Vector2(2, 2), Vector2(.5, .5))
	check(degenerate.is_finite() and is_equal_approx(degenerate.x + degenerate.y + degenerate.z, 1), "Collapsed projected triangles must produce finite corner weights")
	var primitive := BoxMesh.new()
	primitive.size = Vector3(2, 1, 1)
	var arrays := primitive.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var colors := PackedColorArray()
	for vertex in vertices:
		bones.append_array(PackedInt32Array([0 if vertex.x < 0 else 1, 0, 0, 0]))
		weights.append_array(PackedFloat32Array([1, 0, 0, 0]))
		colors.append(Color.RED if vertex.x < 0 else Color.BLUE)
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_COLOR] = colors
	var original := ArrayMesh.new()
	original.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	original.surface_set_material(0, Voxels.material())
	var renderer := Style.new()
	for family in ["block_voxel", "flat_lowpoly"]:
		var source := Node3D.new()
		var part := MeshInstance3D.new()
		part.mesh = original
		source.add_child(part)
		check(renderer.convert(source, family, 12), "Synthetic two-bone style conversion must succeed")
		attributes(part.mesh, true)
		check(part.mesh.get_aabb().is_equal_approx(original.get_aabb()), "Style conversion must preserve the actual source bounds")
		var result: Array = part.mesh.surface_get_arrays(0)
		check(1 in result[Mesh.ARRAY_BONES], "Both source bone influences must survive conversion")
		check(original.surface_get_arrays(0) == arrays, "Conversion must not mutate source mesh arrays")
		source.free()
	var registry := Registry.new()
	var sources := []
	for query in [{"pack": "quaternius_ultimate_monsters", "pattern": "*Orc.gltf"}, {"pack": "quaternius_cube_world", "pattern": "*Animals/glTF/Cat.gltf"}, {"pack": "kaykit_skeletons", "pattern": "*Characters/gltf/Skeleton_Mage.glb"}]:
		var models: Array = registry.find("model", [], query.pack).filter(func(asset): return asset.id.matchn(query.pattern))
		check(not models.is_empty(), "Representative animated source must exist: " + query.pack)
		if not models.is_empty():
			sources.append(models[0].id)
	var skinned_count := 0
	var moving_rigs := 0
	for id in sources:
		for family in ["block_voxel", "flat_lowpoly"]:
			var source := registry.instantiate(id)
			root.add_child(source)
			var rig := source.find_children("*", "Skeleton3D", true, false)
			var players := source.find_children("*", "AnimationPlayer", true, false)
			var records := []
			for part in source.find_children("*", "MeshInstance3D", true, false):
				records.append({"node": part, "mesh": part.mesh, "skin": part.skin, "skeleton": part.skeleton, "transform": part.transform})
			check(renderer.convert(source, family, 12), "Actual animated source conversion must succeed: " + id + " / " + renderer.error)
			check(source.find_children("*", "Skeleton3D", true, false) == rig and source.find_children("*", "AnimationPlayer", true, false) == players, "Actual rig and clip hierarchy must survive conversion")
			for record in records:
				var part: MeshInstance3D = record.node
				check(part.skin == record.skin and part.skeleton == record.skeleton and part.transform == record.transform, "Actual skin binding and mesh-local transforms must remain unchanged")
				var skinned: bool = record.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES] != null
				if skinned:
					skinned_count += 1
				attributes(part.mesh, skinned, "%s / %s / %s" % [id, family, part.name])
			check(not players.is_empty(), "Actual source must retain playable clips")
			for player in players:
				var clips: PackedStringArray = player.get_animation_list()
				if not clips.is_empty():
					var walking: Array = Array(clips).filter(func(clip): return clip.to_lower().contains("walk"))
					var clip: String = walking[0] if not walking.is_empty() else clips[0]
					player.play(clip)
					player.advance(.1)
					var before := []
					for skeleton in rig:
						for bone in range(skeleton.get_bone_count()):
							before.append(skeleton.get_bone_pose(bone))
					player.advance(.25)
					var after := []
					for skeleton in rig:
						for bone in range(skeleton.get_bone_count()):
							after.append(skeleton.get_bone_pose(bone))
					if before != after:
						moving_rigs += 1
					check(player.current_animation == clip, "Converted source must still play its actual animation")
			source.queue_free()
			await process_frame
	check(skinned_count > 0, "Acceptance must exercise actual skinned assets, not just rigid node animation")
	check(moving_rigs >= sources.size() * 2, "Both derivatives of every source must actually change their bone poses")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: synthetic two-bone attributes/bounds/colors/immutability and %s actual sources in both styles, with %s skinned meshes and preserved playable rig hierarchies" % [sources.size(), skinned_count] if failures.is_empty() else "FAIL: animated style conversion")
	quit(0 if failures.is_empty() else 1)
