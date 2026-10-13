extends Node3D

const Registry = preload("res://scripts/asset_registry.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const Catalog = preload("res://scripts/ambience_catalog.gd")
const WISP_CAP := Catalog.WISP_CAP
const CUE_CAP := 4
static var catalog: Dictionary = Catalog.load_data()
var registry := Registry.new()
var source_pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_construction/catalog.json")).roles
var weather_enabled := true
var weather := "clear"
var rain: CPUParticles3D
var streams: Dictionary = {}
var beds: Array[AudioStreamPlayer] = []
var cues: Array[AudioStreamPlayer3D] = []
var steps: Array[AudioStreamPlayer] = []
var listener := AudioListener3D.new()
var wisp_root := Node3D.new()
var wisps: Array[Node3D] = []
var anchors: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var clock := 0.0
var active := false
var profile: Dictionary = {}
var current_bed := ""
var pending_bed := ""
var pending_time := 0.0
var active_bed := 0
var cue_cursor := 0
var step_cursor := 0
var context_timer := 0.0
var cue_timer := 5.0
var step_distance := 0.0
var previous_point := Vector2.ZERO
var previous_layer := ""
var previous_grounded := true
var journey_seed := -1
var anchor_point := Vector2(INF, INF)
var visual_key := ""
var glow := 0.0
var cues_played := 0
var steps_played := 0

static func profile_for(layer: String, biome: int, city: bool, water: bool) -> Dictionary:
	var result: Dictionary = catalog.locations.get(layer, catalog.surface[posmod(biome, catalog.surface.size())]).duplicate(true)
	if layer == "overworld":
		if water:
			var cue: String = result.get("water_cue", catalog.water.cue)
			result.merge(catalog.water, true)
			result.cue = cue
		if city:
			result.merge(catalog.town, true)
	result.color = Color(result.color)
	result.wisps = clampi(int(result.wisps), 0, WISP_CAP)
	return result

static func weather_for(seed_value: int, region_id: String, biome: int) -> String:
	var allowed: bool = catalog.weather.biomes.any(func(value): return int(value) == biome)
	return "rain" if allowed and (hash("rain:%s:%s" % [seed_value,region_id]) & 0x7fffffff) % int(catalog.weather.region_modulus) == 0 else "clear"

func _ready() -> void:
	add_child(wisp_root)
	add_child(listener)
	if DisplayServer.get_name() == "headless":
		return
	listener.make_current()
	_setup_rain()
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Ambience"
		player.volume_linear = 0
		add_child(player)
		beds.append(player)
		var footstep := AudioStreamPlayer.new()
		footstep.bus = "Effects"
		footstep.volume_db = -22
		add_child(footstep)
		steps.append(footstep)
	for index in range(CUE_CAP):
		var player := AudioStreamPlayer3D.new()
		player.bus = "Ambience"
		player.unit_size = 5
		player.max_distance = 18
		player.volume_db = -19
		add_child(player)
		cues.append(player)

func update(game, delta: float) -> void:
	active = game.has_journey and game.state == "playing"
	wisp_root.visible = active and game.layer != "interior"
	listener.position = Vector3(game.player_point.x, game.player_y + 1, game.player_point.y)
	if game.run_seed != journey_seed:
		journey_seed = game.run_seed
		rng.seed = hash("ambience:%s" % journey_seed)
		visual_key = ""
		clock = 0
		cue_timer = 5
		context_timer = 0
		previous_layer = ""
	var changed_layer: bool = previous_layer != game.layer
	context_timer -= delta
	if context_timer <= 0 or changed_layer:
		context_timer = .4
		var biome := 0
		var city := false
		var water := false
		var identity: String = str(game.run_seed) + ":" + game.layer
		weather = "clear"
		if game.layer == "overworld":
			var cell := Vector2i(game.player_point.round())
			biome = game.world.cell_info(cell).biome
			var region: Dictionary = game.world.region_at(cell)
			var settlement: Dictionary = game.world.city_at(game.player_point)
			identity = region.city.get("id", "region:%s:%s:%s" % [game.world.generator_version, region.coordinate.x, region.coordinate.y])
			if weather_enabled:
				weather = weather_for(game.run_seed, identity, biome)
			city = not settlement.is_empty()
			for direction in game.world.DIRECTIONS:
				water = water or game.world.cell_info(cell + direction * 2).terrain == "water"
		profile = profile_for(game.layer, biome, city, water)
		profile.hard_ground = game.layer != "overworld" or city
		if catalog.bed_pools.has(profile.bed):
			profile.bed = _source_choice(catalog.bed_pools[profile.bed], hash(identity))
		if weather == "rain":
			profile.bed = _source_choice(catalog.weather.rain_pool, hash(identity))
			profile.cue = "wonder"
	if rain != null:
		rain.visible = active and weather == "rain"
		rain.emitting = rain.visible
		rain.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		rain.position = Vector3(game.player_point.x,game.player_y + 5,game.player_point.y)
	if pending_bed != profile.bed:
		pending_bed = profile.bed
		pending_time = 0
	pending_time += delta
	if active and (changed_layer or current_bed.is_empty() or pending_time >= 1.5) and current_bed != pending_bed:
		_change_bed(pending_bed, game.sound)
	var busy: bool = game.enemies.any(func(enemy): return enemy.active and enemy.point.distance_to(game.player_point) < 8)
	for index in range(beds.size()):
		var target := (.20 if busy else .50) if active and index == active_bed else 0.0
		beds[index].volume_linear = move_toward(beds[index].volume_linear, target, delta * .35)
		if index != active_bed and beds[index].volume_linear <= .001:
			beds[index].stop()
	if not active:
		for voice in cues:
			voice.stop()
		for voice in steps:
			if voice.get_meta("footstep", false):
				voice.stop()
		previous_point = game.player_point
		previous_grounded = game.grounded
		step_distance = 0
		return
	clock += delta
	if changed_layer:
		step_distance = 0
		previous_point = game.player_point
		previous_grounded = game.grounded
		cue_timer = 4
		play_effect("door_open" if game.layer == "interior" or previous_layer == "interior" else "", game.sound)
	previous_layer = game.layer
	var distance: float = game.player_point.distance_to(previous_point)
	if distance < 1.5 and game.grounded and previous_grounded:
		step_distance += distance
	if not previous_grounded and game.grounded:
		play_effect("step_stone" if profile.hard_ground else "step_grass", game.sound, -18)
	if step_distance >= .72:
		step_distance = fmod(step_distance, .72)
		play_effect("step_stone" if profile.hard_ground else "step_grass", game.sound)
	previous_point = game.player_point
	previous_grounded = game.grounded
	cue_timer -= delta
	if cue_timer <= 0:
		cue_timer = rng.randf_range(9, 19)
		if not busy:
			var source_found := false
			if game.layer == "overworld":
				for actor in game.life.actors.values():
					if actor.kind == "npc" and actor.role == "relic_mender" and not actor.get("moving", false) and actor.point.distance_to(game.player_point) < 7:
						play_cue("book_page", Vector3(actor.point.x,game.world.ground_height(actor.point) + 1,actor.point.y), game.sound)
						source_found = true
						break
			if not source_found:
				var offset := Vector3(rng.randf_range(-7,7), 1.4, rng.randf_range(-7,7))
				play_cue(profile.cue, listener.position + offset, game.sound)
	var key: String = "%s:%s:%s" % [game.layer, profile.bed, profile.color.to_html()]
	if visual_key != key or game.player_point.distance_to(anchor_point) > 9:
		visual_key = key
		_place_wisps(game)
	glow = maxf(0, glow - delta)
	for index in range(wisps.size()):
		var phase := clock * .6 + index * 2.4
		wisps[index].position = anchors[index] + Vector3(sin(phase) * .3, sin(phase * 1.6) * .16, cos(phase) * .3)
		wisps[index].rotation.y = phase
		wisps[index].scale = Vector3.ONE * (1 + sin(phase * 2) * .10 + glow * .12)

func _change_bed(id: String, sound) -> void:
	current_bed = id
	if beds.is_empty():
		return
	active_bed = 1 - active_bed
	var incoming := beds[active_bed]
	incoming.stop()
	incoming.volume_linear = 0
	incoming.stream = _stream(id, sound, true)
	if incoming.stream != null:
		incoming.play()

func _stream(id: String, sound, loop: bool = false) -> AudioStream:
	var key := "%s:%s" % [id, loop]
	if not streams.has(key):
		var source: AudioStream = sound.sounds.get(id) if id in ["wonder", "aether"] else registry.resource(id)
		if source == null:
			return null
		var stream: AudioStream = source.duplicate()
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = loop
		streams[key] = stream
	return streams.get(key)

func play_cue(id: String, point: Vector3, sound) -> void:
	if cues.is_empty() or not active or sound.muted or sound.ambience_level == 0:
		return
	var source := id
	if catalog.cue_pools.has(id):
		var roles: Array = catalog.cue_pools[id]
		source = _source_choice(roles[rng.randi_range(0, roles.size() - 1)], rng.randi())
	var stream := _stream(source, sound)
	if stream == null:
		return
	var voice := cues[cue_cursor]
	cue_cursor = (cue_cursor + 1) % cues.size()
	voice.position = point
	voice.stream = stream
	voice.pitch_scale = rng.randf_range(.94, 1.06) if id == "wonder" else 1.0
	voice.play()
	cues_played += 1

func play_effect(id: String, sound, volume_db: float = -22) -> void:
	if id.is_empty() or steps.is_empty() or sound.muted or sound.sfx_level == 0:
		return
	var source: String = _source_choice(catalog.effect_pools[id], rng.randi()) if catalog.effect_pools.has(id) else id
	var stream := _stream(source, sound)
	if stream == null:
		return
	var voice := steps[step_cursor]
	step_cursor = (step_cursor + 1) % steps.size()
	voice.volume_db = volume_db
	voice.set_meta("footstep", id.begins_with("step_"))
	voice.stream = stream
	voice.pitch_scale = rng.randf_range(.93, 1.07)
	voice.play()
	steps_played += 1

func _source_choice(role: String, seed_value: int) -> String:
	var choices: Array = source_pools.get(role, [])
	return "" if choices.is_empty() else choices[posmod(seed_value, choices.size())]

func _setup_rain() -> void:
	rain = CPUParticles3D.new()
	rain.amount = int(catalog.weather.particles)
	rain.lifetime = 1.4
	rain.local_coords = true
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(8,.4,8)
	rain.direction = Vector3.DOWN
	rain.spread = 4
	rain.gravity = Vector3.ZERO
	rain.initial_velocity_min = 3.6
	rain.initial_velocity_max = 4.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(.012,.26)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(.65,.83,.95,.25)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = material
	rain.mesh = mesh
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	add_child(rain)

func react(sound) -> void:
	glow = 1.0
	play_cue("wonder", listener.position + Vector3(0,1,0), sound)

func _place_wisps(game) -> void:
	for child in wisps:
		wisp_root.remove_child(child)
		child.queue_free()
	wisps.clear()
	anchors.clear()
	anchor_point = game.player_point
	for index in range(mini(profile.wisps, WISP_CAP)):
		var point: Vector2 = game.player_point
		var found := false
		for attempt in range(12):
			var angle := rng.randf() * TAU
			point = game.player_point + Vector2(cos(angle), sin(angle)) * rng.randf_range(3.5, 7.5)
			if game.dungeon.walkable(point):
				found = true
				break
		if not found:
			continue
		var wisp := Node3D.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = profile.color
		var body := Voxels.cube(Vector3(.14,.14,.14), profile.color)
		body.material_override = material
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisp.add_child(body)
		for side in [-1,1]:
			var eye := Voxels.cube(Vector3(.025,.03,.025), Color("334660"))
			eye.position = Vector3(side * .035, .014, .076)
			wisp.add_child(eye)
			var wing := Voxels.cube(Vector3(.095,.025,.06), profile.color.lightened(.25))
			wing.position = Vector3(side * .125, .02, 0)
			wisp.add_child(wing)
		var height: float = game.world.ground_height(point) if game.layer == "overworld" else game.dungeon.ground_height(point)
		anchors.append(Vector3(point.x, height + 1.25, point.y))
		wisp_root.add_child(wisp)
		wisps.append(wisp)

func _exit_tree() -> void:
	for voice in beds + steps:
		voice.stop()
		voice.stream = null
	for voice in cues:
		voice.stop()
		voice.stream = null
	streams.clear()
