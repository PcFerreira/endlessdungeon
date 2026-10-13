extends SceneTree

const Soundscape = preload("res://scripts/soundscape.gd")
const Ambience = preload("res://scripts/world_ambience.gd")
const Actors = preload("res://scripts/actor_models.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")

class Plain extends RefCounted:
	const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	func cell_info(_cell: Vector2i) -> Dictionary:
		return {"biome": 0, "terrain": "land"}
	func region_at(_cell: Vector2i) -> Dictionary:
		return {"city": {"cell": Vector2i.ZERO}}
	func city_distance(point: Vector2, center: Vector2i) -> float:
		return point.distance_to(center)
	func walkable(_point: Vector2) -> bool:
		return true
	func ground_height(_point: Vector2) -> float:
		return 0.0

class Fixture extends Node3D:
	var has_journey := true
	var state := "playing"
	var layer := "overworld"
	var player_point := Vector2(30,30)
	var player_y := 0.0
	var grounded := true
	var run_seed := 12345
	var world := Plain.new()
	var dungeon := world
	var enemies: Array = []
	var life := {"actors": {}}
	var sound

var sound := Soundscape.new()
var ambience := Ambience.new()
var fixture := Fixture.new()
var environment_record := AudioEffectRecord.new()
var effects_record := AudioEffectRecord.new()

func _initialize() -> void:
	ambience.weather_enabled = false
	root.add_child(sound)
	fixture.sound = sound
	root.add_child(fixture)
	fixture.add_child(ambience)
	call_deferred("run_checks")

func _process(delta: float) -> bool:
	if is_instance_valid(ambience) and is_instance_valid(fixture):
		ambience.update(fixture, delta)
	return false

func run_checks() -> void:
	assert(DisplayServer.get_name() != "headless", "Run with native audio/rendering")
	root.size = Vector2i(1280,800)
	_attach_recorder("Ambience", environment_record)
	_attach_recorder("Effects", effects_record)
	for role in sound.world_music:
		if role.begins_with("music_"):
			for id in sound.world_music[role]:
				var stream := sound.music_stream(id)
				assert(stream != null and stream.get_length() > 1 and stream.loop)
	await create_timer(1.6).timeout
	assert(ambience.beds.size() == 2 and ambience.cues.size() == Ambience.CUE_CAP and ambience.steps.size() == 2)
	var forest := ambience.beds[ambience.active_bed]
	assert(forest.playing and forest.volume_linear > .4)
	forest.seek(maxf(0, forest.stream.get_length() - .15))
	await create_timer(.5).timeout
	assert(forest.playing and forest.get_playback_position() < 1, "WAV bed must actually loop")
	fixture.layer = "dungeon"
	await create_timer(.25).timeout
	assert(ambience.beds[0].playing and ambience.beds[1].playing, "Beds must crossfade")
	await create_timer(1.6).timeout
	assert(not ambience.beds[1 - ambience.active_bed].playing)
	var dungeon := ambience.beds[ambience.active_bed]
	dungeon.seek(maxf(0, dungeon.stream.get_length() - .15))
	await create_timer(.5).timeout
	assert(dungeon.playing and dungeon.get_playback_position() < 1, "Ogg bed must actually loop")
	fixture.player_point += Vector2.RIGHT
	await process_frame
	assert(ambience.steps_played > 0)
	await create_timer(.35).timeout
	ambience.react(sound)
	assert(ambience.cues_played > 0)
	ambience.play_effect("book_open", sound)
	await create_timer(.4).timeout
	fixture.state = "paused"
	await create_timer(.2).timeout
	var clock: float = ambience.clock
	await create_timer(1.5).timeout
	assert(ambience.clock == clock and ambience.beds[ambience.active_bed].volume_linear < .001)
	assert(ambience.cues.all(func(voice): return not voice.playing))
	fixture.state = "playing"
	fixture.layer = "sanctum"
	await create_timer(1.6).timeout
	assert(ambience.current_bed == "aether" and ambience.beds[ambience.active_bed].playing)
	sound.set_ambience_level(0)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")))
	assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))
	sound.set_ambience_level(.65)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	_save_recording("Ambience", environment_record, "ambience-mix")
	_save_recording("Effects", effects_record, "ambience-footsteps")
	var legacy_glass := ambience._stream("kenney_impact_sounds/Audio/impactGlass_light_002.ogg",sound)
	assert(legacy_glass != null and legacy_glass.get_length() > 0)
	var voice := AudioStreamPlayer.new()
	voice.bus = "Effects"
	voice.volume_db = -12
	voice.stream = legacy_glass
	root.add_child(voice)
	var legacy_record := AudioEffectRecord.new()
	_attach_recorder("Effects",legacy_record)
	voice.play()
	await create_timer(legacy_glass.get_length() + .1).timeout
	_save_recording("Effects",legacy_record,"world-legacy-glass")
	voice.queue_free()
	await _capture_gallery()
	print("PASS: native WAV/Ogg looping, bounded voices, crossfade, footsteps/book cues, spatial magical chimes, pause/resume, independent ambience mute, non-silent recordings and NPC gallery")
	fixture.queue_free()
	sound.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()

func _attach_recorder(bus: String, recorder: AudioEffectRecord) -> void:
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), recorder)
	recorder.set_recording_active(true)

func _save_recording(bus: String, recorder: AudioEffectRecord, name: String) -> void:
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	assert(recording != null and recording.data.size() > 10000)
	var data := recording.data
	var peak := 0
	for index in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(index)))
	assert(peak > 100, "Native %s mixer must receive non-silent samples" % bus)
	assert(recording.save_to_wav("res://artifacts/%s.wav" % name) == OK)
	AudioServer.remove_bus_effect(AudioServer.get_bus_index(bus), 0)

func _capture_gallery() -> void:
	fixture.state = "paused"
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	fixture.add_child(camera)
	camera.position = Vector3(8,10,11)
	camera.look_at(Vector3(0,.5,1))
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_energy = 1.5
	fixture.add_child(sun)
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.background_mode = Environment.BG_COLOR
	sky.environment.background_color = Color("182739")
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color("d6def0")
	sky.environment.ambient_light_energy = .7
	fixture.add_child(sky)
	var roles: Array = Ambience.catalog.npc_roles.keys()
	for index in range(12):
		var point := Vector3((index % 4) * 2.7 - 4, 0, (index / 4) * 2.2 - 1.1)
		var floor := Voxels.cube(Vector3(2.4,.15,1.9), Color("445c62"))
		floor.position = point - Vector3(0,.075,0)
		fixture.add_child(floor)
		var model := Actors.create(index, {"id": "resident:%s" % index, "role": roles[index % roles.size()]})
		model.position = point
		fixture.add_child(model)
		var label := Label3D.new()
		label.text = roles[index % roles.size()].replace("_", " ")
		label.position = point + Vector3(0,1.55,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 20
		label.pixel_size = .008
		fixture.add_child(label)
	await create_timer(.4).timeout
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png("res://artifacts/ambience-npc-gallery.png") == OK)
