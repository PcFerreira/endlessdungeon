extends Node

const SAMPLE_RATE := 22050
const NOTES := {"bolt": [540.0, .12], "fire": [170.0, .30], "nova": [820.0, .42], "blink": [380.0, .23], "impact": [90.0, .28], "hurt": [130.0, .18], "pickup": [1040.0, .14], "gate": [660.0, .65]}
const TRACKS := {
	"title": "Fantascape_Looping.ogg",
	"city": "Netherplace_Looping.ogg",
	"forest": "Lost-Jungle_Looping.ogg",
	"meadow": "Fantascape_Looping.ogg",
	"desert": "Fantasy_Game_Background_Looping.ogg",
	"frost": "Our-Mountain_v003_Looping.mp3",
	"coast": "City-Beneath-the-Waves_v001.mp3",
	"crypt": "Misty-Bog_Looping.ogg",
	"sanctum": "Spells-a-Brewin_Looping.ogg",
	"tomb": "Strange-Phenomenon_Looping.ogg"
}
var players: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var music_cache: Dictionary = {}
var current_track := ""
var pending_track := ""
var context := ""
var pending_time := 0.0
var active_music := 0
var fade: Tween
var music_level := .7
var sfx_level := 1.0
var sounds: Dictionary = {}
var cursor := 0
var muted := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for bus in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_linear = 0
		add_child(player)
		music_players.append(player)
	set_music_level(music_level)
	set_sfx_level(sfx_level)
	for index in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		player.volume_db = -14
		add_child(player)
		players.append(player)
	for key in NOTES:
		sounds[key] = _tone(NOTES[key][0], NOTES[key][1])

func music_stream(file: String) -> AudioStream:
	if not music_cache.has(file):
		var stream: AudioStream = load("res://assets/music/" + file)
		stream.loop = true
		music_cache[file] = stream
	return music_cache[file]

func track_for(state: String, layer: String, biome: int, city: bool, coast: bool = false) -> String:
	if state == "title":
		return TRACKS.title
	if layer == "sanctum":
		return TRACKS.sanctum
	if layer == "dungeon":
		return TRACKS[["crypt", "sanctum", "tomb"][biome % 3]]
	if city:
		return TRACKS.city
	if coast:
		return TRACKS.coast
	return TRACKS[["forest", "meadow", "desert", "frost"][biome % 4]]

func update_context(state: String, layer: String, biome: int, city: bool, delta: float, coast: bool = false) -> void:
	var desired := track_for(state, layer, biome, city, coast)
	var area := "title" if state == "title" else layer
	if desired != pending_track:
		pending_track = desired
		pending_time = 0
	pending_time += delta
	if desired != current_track and (current_track.is_empty() or area != context or pending_time >= 1.75):
		_change_track(desired)
	context = area

func _change_track(file: String) -> void:
	current_track = file
	if music_players.is_empty():
		return
	if fade != null:
		fade.kill()
	var outgoing := music_players[active_music]
	active_music = 1 - active_music
	var incoming := music_players[active_music]
	incoming.stop()
	incoming.stream = music_stream(file)
	incoming.volume_linear = 0
	incoming.play()
	fade = create_tween().set_parallel(true)
	fade.tween_property(incoming, "volume_linear", 1.0, 2.0)
	fade.tween_property(outgoing, "volume_linear", 0.0, 2.0)
	fade.chain().tween_callback(outgoing.stop)

func set_music_level(value: float) -> void:
	music_level = clampf(value, 0, 1)
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(music_level, .0001)) - 10)
		AudioServer.set_bus_mute(bus, music_level == 0)

func set_sfx_level(value: float) -> void:
	sfx_level = clampf(value, 0, 1)
	var bus := AudioServer.get_bus_index("Effects")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_level, .0001)))
		AudioServer.set_bus_mute(bus, sfx_level == 0)

func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	var count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var envelope := minf(time * 70, 1.0) * pow(1.0 - time / duration, 2.0)
		var phase := TAU * frequency * (time + .35 * time * time)
		var sample := (sin(phase) * .65 + sin(phase * 1.5) * .20 + sin(phase * 2) * .10) * envelope * .4
		data.encode_s16(index * 2, int(sample * 32767))
	stream.data = data
	return stream

func play_spell(spell: String) -> void:
	if muted or players.is_empty():
		return
	var player := players[cursor]
	cursor = (cursor + 1) % players.size()
	player.stream = sounds[spell]
	player.play()

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)

func _exit_tree() -> void:
	if fade != null:
		fade.kill()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	sounds.clear()
