extends SceneTree

const Scenery = preload("res://scripts/scenery.gd")
const Soundscape = preload("res://scripts/soundscape.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var scenery := Scenery.new()
	for key in Scenery.MODELS:
		var model: Node3D = scenery.model(key, 1.0)
		var bounds: AABB = scenery.bounds(model)
		assert(bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.z > 0, "Imported model must have geometry: " + key)
		assert(is_equal_approx(maxf(bounds.size.x, bounds.size.z), 1.0), "Props must fit a known grid footprint: " + key)
		assert(absf(bounds.position.y) < .001, "Imported origins must be at ground level: " + key)
		assert(scenery.valid_materials(model), "Materials and textures must survive import: " + key)
		model.free()
	var music := Soundscape.new()
	root.add_child(music)
	for file in Soundscape.TRACKS.values():
		var stream: AudioStream = music.music_stream(file)
		assert(stream != null and stream.get_length() > 10, "Every supplied track must decode: " + file)
		assert(stream.loop, "Music must loop: " + file)
	assert(music.track_for("title", "overworld", 0, false) == Soundscape.TRACKS.title)
	assert(music.track_for("playing", "overworld", 0, true) == Soundscape.TRACKS.city)
	assert(music.track_for("playing", "overworld", 0, false) == Soundscape.TRACKS.forest)
	assert(music.track_for("playing", "overworld", 3, false) == Soundscape.TRACKS.frost)
	assert(music.track_for("playing", "dungeon", 1, false) == Soundscape.TRACKS.sanctum)
	music.update_context("playing", "overworld", 0, false, 0)
	assert(music.current_track == Soundscape.TRACKS.forest)
	music.update_context("playing", "overworld", 3, false, .1)
	assert(music.current_track == Soundscape.TRACKS.forest, "A brief biome crossing must not restart the score")
	music.update_context("playing", "overworld", 0, false, 2)
	assert(music.current_track == Soundscape.TRACKS.forest)
	music.update_context("playing", "dungeon", 1, false, 0)
	assert(music.current_track == Soundscape.TRACKS.sanctum, "Entering a dungeon must change music immediately")
	music.set_music_level(0)
	assert(music.music_level == 0)
	print("PASS: imported geometry/materials and grid scale; nine decoded looping tracks; biome debounce, area transitions, music volume")
	music.queue_free()
	await process_frame
	quit()
