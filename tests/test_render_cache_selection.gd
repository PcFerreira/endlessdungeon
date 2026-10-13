extends SceneTree

const Cache = preload("res://scripts/render_cache.gd")

func _initialize() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Cache.PATH))
	if Cache.data.get("scenes", {}).size() != source.scenes.size():
		push_error("Changing the scenery selection catalogue must not disable unchanged baked creature and source geometry")
		quit(1)
		return
	var path := "user://render-selection-%s.json" % Time.get_ticks_usec()
	source.runtime_inputs["res://config/biome_art.json"] = "changed scenery selection"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
	assert(Cache._read(path).scenes == source.scenes)
	source.runtime_inputs["res://config/creature_styles.json"] = "changed geometry rules"
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(source))
	file.close()
	assert(Cache._read(path).is_empty(), "Actual model recipe changes must still invalidate the geometry cache")
	DirAccess.remove_absolute(path)
	print("PASS: scenery selection changes preserve existing source-body cache lookups")
	quit()
