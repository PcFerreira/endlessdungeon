extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var origin := Vector2.INF
var directory := "user://expanded-spells-preview-%s" % Time.get_ticks_usec()
var captures := []

func _initialize() -> void:
	call_deferred("capture")

func frame(name: String) -> void:
	for index in range(3):
		await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/expanded-spells/%s.png" % name) == OK)
	captures.append(name)

func prepare(with_enemies: bool = true) -> void:
	game._clear_actors()
	game.state = "playing"
	game.player_point = origin
	game._snap_camera()
	game.camera.size = 16
	game.dungeon_view.reveal(game.dungeon, origin)
	game.hp = game.max_hp * .5
	game.mana = game.max_mana
	if with_enemies:
		for index in range(1, 4):
			game._spawn_enemy(origin + Vector2.RIGHT * index, 0)
			game.enemies[-1].hp = 300
			game.enemies[-1].max_hp = 300
		game.select_target(game.enemies[0])

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/expanded-spells")
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.sound.toggle_mute()
	game.start_run(12345)
	game.enter_dungeon(game.world.nearest_site(game.player_point, "dungeon"))
	for cell in game.dungeon.tiles:
		var point := Vector2(cell)
		var supported: bool = game.dungeon.walkable(point) and game.dungeon.walkable(point + Vector2.RIGHT * 3) and game.dungeon.line_clear(point, point + Vector2.RIGHT * 3)
		if supported:
			origin = point
			break
	assert(origin.is_finite(), "The real dungeon needs a clear demonstration room")
	for id in ["mage", "sword", "spellsword"]:
		game.state = "title"
		game.choose_class(id)
		game.state = "playing"
		game.build.skill_points = 12
		for skill in ["power", "reserve", "specialty", "utility", "advanced"]:
			assert(game.learn_skill(skill))
		for spell in game.CharacterBuild.CLASS_ADDITIONS[id]:
			assert(game.learn_skill(spell))
		for index in range(game.build.unlocked.size()):
			game.equip_ability(game.build.unlocked[index], index)
		prepare()
		game.interface.grimoire_selected_skill = game.CharacterBuild.CLASS_ADDITIONS[id][-1]
		game.state = "grimoire"
		await frame(id + "-grimoire")
		game.state = "playing"
		for spell in game.CharacterBuild.CLASS_ADDITIONS[id]:
			prepare(game.ABILITIES[spell].kind != "summon")
			game.cast(spell)
			assert(game.cooldowns[spell] > 0)
			game.spell_effects.step(.03)
			game.notify(game.ABILITIES[spell].name)
			await frame(spell)
	prepare()
	assert(game.summons.summon("lantern_familiar") and game.summons.summon("ancestral_warden"))
	for index in range(8):
		game.summons.step(.12)
	game.notify("Lantern Familiar and Ancestral Warden")
	await frame("companions")
	var file := FileAccess.open("res://artifacts/expanded-spells/gallery.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": game.run_seed, "dungeon": game.active_dungeon.id, "origin": [origin.x, origin.y], "captures": captures}, "\t"))
	file.close()
	game.queue_free()
	await process_frame
	for path in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(path))
	DirAccess.remove_absolute(directory)
	print("PASS: three actual learned/equipped class grimoires, nine cast effects/summons and two active companion bodies in a generated dungeon")
	quit()
