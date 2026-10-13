extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var events: Array[String] = []
var directory := "user://combat-audio-test-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game.enter_dungeon(game.world.nearest_site(game.player_point, "dungeon"))
	game._clear_actors()
	var origin := Vector2.INF
	for cell in game.dungeon.tiles:
		var point := Vector2(cell)
		if game.dungeon.walkable(point) and game.dungeon.walkable(point + Vector2.RIGHT * 3) and game.dungeon.line_clear(point, point + Vector2.RIGHT * 3):
			origin = point
			break
	assert(origin.is_finite())
	game.player_point = origin
	game._snap_camera()
	game._spawn_enemy(origin + Vector2.RIGHT, 0)
	var enemy: Dictionary = game.enemies[0]
	enemy.hp = 10000
	game.sound.effect_played.connect(func(effect): events.append(effect))
	game._hit_enemy(enemy, 1)
	assert(events == ["impact"], "Actual accepted creature damage needs hit feedback")
	events.clear()
	game.cast("bolt")
	assert(events.is_empty(), "A failed no-target cast must stay silent")
	game.select_target(enemy)
	game.build.unlocked.assign(game.ABILITIES.keys())
	for spell in game.ABILITIES:
		game.player_point = origin
		game._snap_camera()
		game.move_heading = Vector2.RIGHT
		game.hp = game.max_hp * .5
		game.mana = game.max_mana
		game.cooldowns[spell] = 0
		game.sound.effect_times.clear()
		game.cast(spell)
		assert(events[-1] == spell and game.cooldowns[spell] > 0, "Every successful ability must play its authored cast cue")
		for shot in game.projectiles:
			shot.node.queue_free()
		game.projectiles.clear()
	game.player_point = origin
	game._snap_camera()
	game.sound.effect_times.clear()
	events.clear()
	game.cooldowns.bolt = 0
	game.cast("bolt")
	game._update_projectiles(.1)
	assert("hit_arcane" in events, "A homing projectile needs its spell impact on actual contact")
	game.sound.effect_times.clear()
	events.clear()
	game._explode(enemy.point)
	assert(events.count("fire_burst") == 1 and "hit_fire" in events)
	game.sound.effect_times.clear()
	events.clear()
	game.invulnerable = 0
	game.guard_time = 0
	game.spell_effects.clear()
	game._hurt_player(1)
	assert(events == ["hurt"])
	game._hurt_player(1)
	assert(events.size() == 1, "Invulnerability must reject both damage and its hit cue")
	game.invulnerable = 0
	game.guard_time = 3
	game._hurt_player(1)
	assert(events[-1] == "guard_hit")
	var rng_before: int = game.rng.state
	game.sound.play_spell("strike")
	assert(game.rng.state == rng_before, "Audio variants must never consume the combat random sequence")
	game.sound.effect_times.clear()
	events.clear()
	game.online.session = true
	game.cast("bolt")
	game._hit_enemy(enemy, 1)
	game._hurt_player(1)
	assert(events.is_empty(), "Offline combat sounds must not predict unsupported public actions")
	game.online.session = false
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: actual all-ability casts, rejected casts, homing contact/explosion, enemy/player/guard hits, invulnerability, combat RNG and public guards")
	quit()
