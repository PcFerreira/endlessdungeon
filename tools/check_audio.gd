extends SceneTree

const Soundscape = preload("res://scripts/soundscape.gd")
var sound := Soundscape.new()

func _initialize() -> void:
	root.add_child(sound)
	call_deferred("run_checks")

func run_checks() -> void:
	assert(DisplayServer.get_name() != "headless", "Run this check with the native audio driver")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), recorder)
	recorder.set_recording_active(true)
	sound.update_context("title", "overworld", 0, false, 0)
	await create_timer(2.2).timeout
	assert(sound.music_players[sound.active_music].playing)
	assert(is_equal_approx(sound.music_players[sound.active_music].volume_linear, 1))
	var player := sound.music_players[sound.active_music]
	player.seek(player.stream.get_length() - .25)
	await create_timer(.65).timeout
	assert(player.playing and player.get_playback_position() < 1, "Ogg must loop across its end")
	sound.update_context("playing", "dungeon", 0, false, 0)
	sound.play_spell("bolt")
	await create_timer(.7).timeout
	assert(sound.music_players[0].playing and sound.music_players[1].playing, "Both tracks must play during the crossfade")
	await create_timer(1.5).timeout
	assert(not sound.music_players[1 - sound.active_music].playing, "The outgoing stream must stop after fading")
	assert(sound.music_players[sound.active_music].get_playback_position() > 1)
	sound._change_track(Soundscape.TRACKS.frost)
	await create_timer(2.2).timeout
	player = sound.music_players[sound.active_music]
	player.seek(player.stream.get_length() - .25)
	await create_timer(.65).timeout
	assert(player.playing and player.get_playback_position() < 1, "MP3 must loop across its end")
	sound.set_music_level(0)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	sound.set_music_level(.7)
	recorder.set_recording_active(false)
	var recording: AudioStreamWAV = recorder.get_recording()
	assert(recording != null and recording.data.size() > 10000)
	var peak := 0
	for index in range(0, recording.data.size(), 2):
		peak = maxi(peak, absi(recording.data.decode_s16(index)))
	assert(peak > 100, "The native mixer must receive audible samples")
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	assert(recording.save_to_wav("res://artifacts/music-crossfade.wav") == OK)
	AudioServer.remove_bus_effect(AudioServer.get_bus_index("Music"), 0)
	print("PASS: native Ogg/MP3 playback and end looping, simultaneous crossfade, outgoing stop, independent mute, non-silent mixer recording (peak %s)" % peak)
	sound.queue_free()
	await process_frame
	await create_timer(.15).timeout
	quit()
