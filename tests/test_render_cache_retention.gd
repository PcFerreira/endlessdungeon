extends SceneTree

const Cache = preload("res://scripts/render_cache.gd")
const Creatures = preload("res://scripts/creature_models.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var creatures := Creatures.new()
	for id in creatures.styles.creature_sources:
		var key := Cache.key("creature", id, "block_voxel")
		if not Cache.data.scenes.has(key):
			continue
		var path: String = Cache.data.scenes[key]
		for attempt in range(240):
			if Cache.ready("creature", id, "block_voxel"):
				break
			await process_frame
		assert(Cache.ready("creature", id, "block_voxel"))
		var body := Cache.scene("creature", id, "block_voxel")
		body.free()
		if not ResourceLoader.has_cached(path):
			push_error("Releasing a prepared actor must retain its PackedScene so another spawn does not reparse the whole file")
			quit(1)
			return
		assert(Cache.scenes.size() <= Cache.SCENE_LIMIT and Cache.loading.size() <= Cache.LOAD_LIMIT)
		print("PASS: released actor retains cached scene data for repeated spawning")
		quit()
		return
	push_error("No baked creature was available for retention verification")
	quit(1)
