extends SceneTree

var model_count := 0
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
	print("PASS: %s models instantiated, %s textures loaded, %s audio streams loaded" % [model_count, texture_count, audio_count])
	quit(0)

func check_directory(path: String) -> void:
	for directory in DirAccess.get_directories_at(path):
		check_directory(path.path_join(directory))
	for filename in DirAccess.get_files_at(path):
		var extension := filename.get_extension().to_lower()
		if extension not in ["gltf", "glb", "png", "svg", "jpg", "jpeg", "mp3", "ogg", "wav"]:
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
		elif extension in ["png", "svg", "jpg", "jpeg"]:
			if resource is not Texture2D:
				failures.append("Not a texture: " + full_path)
			texture_count += 1
		else:
			if resource is not AudioStream:
				failures.append("Not an audio stream: " + full_path)
			audio_count += 1
