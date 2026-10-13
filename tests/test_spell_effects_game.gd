extends SceneTree

const Game = preload("res://scripts/game.gd")
var directory := "user://spell-effects-test-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var script = load("res://scripts/spell_effects.gd")
	assert(script != null, "Expanded spells need real timed effects and readable cast visuals")
	var game := Game.new()
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
	for index in range(1, 4):
		game._spawn_enemy(origin + Vector2.RIGHT * index, 0)
		game.enemies[-1].hp = 1000
		game.enemies[-1].max_hp = 1000
	var first: Dictionary = game.enemies[0]
	game.select_target(first)
	game.build.unlocked.assign(game.ABILITIES.keys())
	game.cast("ice_lance")
	assert(game.spell_effects.immobilized(first) and game.cooldowns.ice_lance > 0)
	assert(game.spell_effects.get_child_count() > 0, "New spells must produce actual geometry effects")
	var point: Vector2 = first.point
	game._update_enemies(.25)
	assert(first.point == point and first.windup == 0, "Frozen creatures must not move or complete an attack")
	game.spell_effects.clear()
	game.mana = game.max_mana
	var healths := game.enemies.map(func(enemy): return enemy.hp)
	game.cast("chain_lightning")
	for index in range(3):
		assert(game.enemies[index].hp < healths[index], "Lightning must chain through actual nearby creatures")
	game.mana = game.max_mana
	game.cast("cinder_brand")
	var burned: float = first.hp
	game.spell_effects.step(1.1)
	assert(first.hp < burned, "The brand must cause actual timed damage")
	game.spell_effects.clear()
	game.hp = 30
	game.mana = game.max_mana
	game.cast("siphon_touch")
	assert(game.hp > 30 and game.hp <= game.max_hp)
	game.mana = game.max_mana
	game.cast("aegis")
	game.invulnerable = 0
	game.guard_time = 0
	var before: float = game.hp
	game._hurt_player(20)
	assert(game.hp == before and game.spell_effects.barrier == 25, "Aegis absorbs finite incoming damage")
	game.invulnerable = 0
	game._hurt_player(30)
	assert(game.hp == before - 5 and game.spell_effects.barrier == 0)
	game.mana = game.max_mana
	game.cast("quake_strike")
	assert(game.spell_effects.immobilized(first))
	game.spell_effects.step(1.1)
	assert(not game.spell_effects.immobilized(first))
	game.mana = game.max_mana
	game.cast("lantern_familiar")
	assert(game.summons.allies.size() == 1 and game.cooldowns.lantern_familiar > 0)
	var ally: Dictionary = game.summons.allies[0]
	var ally_hp: float = ally.hp
	var owner_hp: float = game.hp
	for enemy in game.enemies:
		enemy.attack = 10
		enemy.windup = 0
	first.windup = .05
	game._update_enemies(.1)
	game._update_projectiles(.1)
	assert(ally.hp < ally_hp and game.hp == owner_hp, "Actual enemy attacks must strike a nearer companion instead of the owner")
	var data: Dictionary = game.make_save_data()
	for spell in game.CharacterBuild.NEW_ABILITIES:
		data.stats.cooldowns.erase(spell)
	assert(game.Journey.restore(game, data), "A real fifteen-cooldown legacy envelope must load after expansion")
	for spell in game.CharacterBuild.NEW_ABILITIES:
		assert(game.cooldowns[spell] == 0)
	assert(game.summons.allies.is_empty() and game.spell_effects.barrier == 0, "Temporary conjurations clear across restore")
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: actual freeze/chain/burn/life drain/barrier/quake/summon, geometry, expiry and old cooldown restore")
	quit()
