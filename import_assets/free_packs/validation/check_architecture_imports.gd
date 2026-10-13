extends SceneTree

var model_count := 0
var obj_count := 0
var texture_count := 0
var audio_count := 0
var failures: Array[String] = []

func _init() -> void:
	check_directory("res://free_packs")
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		quit(1)
		return
	print("PASS: %s GLB/glTF models instantiated, %s OBJ meshes instantiated, %s textures loaded" % [model_count, obj_count, texture_count])
	quit(0)

func check_directory(path: String) -> void:
	for directory in DirAccess.get_directories_at(path):
		check_directory(path.path_join(directory))
	for filename in DirAccess.get_files_at(path):
		var extension := filename.get_extension().to_lower()
		if extension not in ["gltf", "glb", "obj", "png", "svg", "jpg", "jpeg", "mp3", "ogg", "wav"]:
			continue
		var full_path := path.path_join(filename)
		var resource := load(full_path)
		if resource == null:
			failures.append("Cannot load: " + full_path)
		elif extension in ["gltf", "glb"]:
			if resource is not PackedScene:
				failures.append("Not a model scene: " + full_path)
				continue
			var model: Node = resource.instantiate()
			if model == null:
				failures.append("Cannot instantiate: " + full_path)
				continue
			model.free()
			model_count += 1
		elif extension == "obj":
			if resource is not ArrayMesh or resource.get_surface_count() == 0:
				failures.append("Empty or invalid OBJ mesh: " + full_path)
			else:
				var instance := MeshInstance3D.new()
				instance.mesh = resource
				instance.free()
				obj_count += 1
		elif extension in ["png", "svg", "jpg", "jpeg"]:
			if resource is not Texture2D:
				failures.append("Not a texture: " + full_path)
			texture_count += 1
		else:
			if resource is not AudioStream:
				failures.append("Not an audio stream: " + full_path)
			audio_count += 1
