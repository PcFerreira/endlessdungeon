extends SceneTree

const Soundscape = preload("res://scripts/soundscape.gd")
const Build = preload("res://scripts/character_build.gd")

func _initialize() -> void:
	var script = load("res://scripts/combat_audio.gd")
	assert(script != null, "Combat audio needs sourced cast and hit recordings")
	assert(script.valid(script.data))
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_audio/SOURCE.json"))
	for record in provenance.assets:
		assert(FileAccess.get_sha256(record.path) == record.sha256 and FileAccess.get_sha256("res://" + record.source) == record.source_sha256, "Adopted effects and originals must match their provenance hashes")
	for spell in Build.ABILITIES:
		assert(script.data.effects.has(spell), "Every learned ability needs its own cast sound profile")
		assert(script.data.effects.has(script.hit_for(spell)))
	for profile in script.data.effects.values():
		for clip in profile.files:
			var path: String = script.data.clips[clip]
			var stream: AudioStream = load(path)
			assert(stream != null and stream.get_length() > .02 and stream.get_length() <= 2, "Effects must decode as short one-shots")
			if stream is AudioStreamWAV:
				assert(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED)
			elif stream is AudioStreamOggVorbis:
				assert(not stream.loop)
	var bad: Dictionary = script.data.duplicate(true)
	bad.clips.arcane = "res://assets/combat_audio/../music/secret.wav"
	assert(not script.valid(bad))
	var sound := Soundscape.new()
	root.add_child(sound)
	var selected := []
	for index in range(4):
		assert(sound.play_effect("strike"))
		selected.append(sound.last_effect.path)
	assert(selected[0] != selected[1] and selected[0] == selected[3], "Variants cycle without consuming hero randomness")
	assert(sound.play_hit("nova") and sound.last_effect.id == "hit_frost")
	assert(not sound.play_hit("nova"), "One area strike must not flood the mixer with simultaneous identical hits")
	sound.muted = true
	assert(not sound.play_effect("fire") and not sound.play_effect("unknown"))
	sound.muted = false
	sound.set_sfx_level(0)
	assert(not sound.play_effect("fire"))
	sound.queue_free()
	print("PASS: sourced ability/hit one-shots, decoded non-looping streams, bounded paths, independent variants, burst suppression and effects mute")
	quit()
