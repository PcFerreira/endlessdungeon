extends SceneTree

const Soundscape = preload("res://scripts/soundscape.gd")
var sound := Soundscape.new()
var recorder := AudioEffectRecord.new()
var combined := PackedByteArray()
var phases := []
var minimum_peak := 32767

func _initialize() -> void:
	root.add_child(sound)
	call_deferred("checks")

func peak(stream: AudioStreamWAV) -> int:
	var result := 0
	for index in range(0, stream.data.size(), 2):
		result = maxi(result, absi(stream.data.decode_s16(index)))
	return result

func record(effect: String, duration: float = -1) -> AudioStreamWAV:
	recorder.set_recording_active(true)
	var accepted := sound.play_effect(effect)
	var wait_time := duration
	if wait_time < 0:
		assert(accepted)
		wait_time = sound.effect_streams[sound.last_effect.path].get_length() / sound.last_effect.pitch + .15
	await create_timer(wait_time).timeout
	recorder.set_recording_active(false)
	var stream: AudioStreamWAV = recorder.get_recording()
	assert(stream != null and not stream.data.is_empty())
	return stream

func checks() -> void:
	assert(DisplayServer.get_name() != "headless", "Run this check with the native audio driver")
	sound.set_music_level(0)
	sound.set_ambience_level(0)
	sound.set_sfx_level(.75)
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, recorder)
	var rate := int(AudioServer.get_mix_rate())
	var profile_count: int = sound.CombatAudio.data.effects.size()
	for effect in sound.CombatAudio.data.effects:
		var stream: AudioStreamWAV = await record(effect)
		var maximum := peak(stream)
		assert(maximum > 15 and maximum < 32760, "Each sourced cue must reach the native mixer without clipping")
		minimum_peak = mini(minimum_peak, maximum)
		phases.append({"effect": effect, "path": sound.last_effect.path, "peak": maximum, "start_frame": combined.size() / 4, "frames": stream.data.size() / 4})
		combined.append_array(stream.data)
		assert(sound.players.size() == 8)
	sound.set_sfx_level(0)
	assert(peak(await record("bolt", .25)) == 0, "The effects slider must mute the actual master output")
	sound.set_sfx_level(.2)
	var quiet: AudioStreamWAV = await record("bolt")
	sound.set_sfx_level(.8)
	var loud: AudioStreamWAV = await record("bolt")
	assert(peak(loud) > peak(quiet) * 2.5, "The effects slider must change actual output amplitude")
	sound.toggle_mute()
	assert(peak(await record("bolt", .25)) == 0)
	sound.toggle_mute()
	var preview := AudioStreamWAV.new()
	preview.format = AudioStreamWAV.FORMAT_16_BITS
	preview.stereo = true
	preview.mix_rate = rate
	preview.data = combined
	assert(preview.save_to_wav("res://artifacts/combat-audio-preview.wav") == OK)
	var file := FileAccess.open("res://artifacts/combat-audio-preview.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"mix_rate": rate, "phases": phases}, "\t"))
	file.close()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	sound.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("PASS: all %s native cast/contact cues audible and unclipped, bounded voices, effects/master mute, measured volume change and indexed mixer preview; minimum peak %s" % [profile_count, minimum_peak])
	quit()
