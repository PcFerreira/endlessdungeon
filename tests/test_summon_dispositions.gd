extends SceneTree

const Game = preload("res://scripts/game.gd")
const Grid = preload("res://scripts/dungeon.gd")
const INPUTS := ["scripts/game.gd", "scripts/combat_summons.gd", "scripts/combat_summon_models.gd", "scripts/enemy_catalog.gd", "scripts/content_edits.gd", "config/content_edits.json"]
var directory := "user://summon-dispositions-%s" % Time.get_ticks_usec()
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("checks")

func source_hashes() -> Dictionary:
	var result := {}
	for path in INPUTS:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		print("FAIL: ", message)

func checks() -> void:
	var before := source_hashes()
	var game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(12345)
	game._clear_actors()
	var area = Grid.new()
	for x in range(15):
		for y in range(15):
			area.tiles[Vector2i(x,y)] = true
	game.dungeon = area
	game.layer = "dungeon"
	game.active_dungeon = {"name":"Summon Disposition Arena","floors":1,"family":area.family}
	game.player_point = Vector2(4,5)
	game._rebuild_navigation()
	var original: Dictionary = game.EnemyCatalog.TYPES[0].duplicate(true)
	var count := 0
	for spell in ["lantern_familiar","ancestral_warden","runic_blade"]:
		for disposition in ["neutral","passive","provoked_neutral","hostile"]:
			game._clear_actors()
			game.clear_target()
			game.player_point = Vector2(4,5)
			game.EnemyCatalog.TYPES[0] = original.duplicate(true)
			game.EnemyCatalog.TYPES[0].aggressive = disposition == "hostile"
			game.EnemyCatalog.TYPES[0].retaliates = disposition != "passive"
			if not game.summons.summon(spell):
				expect(false, "Supported production summon failed: " + spell)
				continue
			var ally: Dictionary = game.summons.allies[0]
			game._spawn_enemy(ally.point + Vector2.RIGHT * .8,0)
			if game.enemies.size() != 1:
				expect(false, "Supported production enemy failed: " + spell)
				continue
			var enemy: Dictionary = game.enemies[0]
			enemy.hp = 1000
			enemy.active = false
			if disposition == "provoked_neutral":
				game._hit_enemy(enemy,1)
				expect(enemy.active, "Actual player damage must provoke the retaliating neutral")
			var hp: float = enemy.hp
			var target: Dictionary = game.summons._target(ally)
			var peaceful: bool = disposition in ["neutral","passive"]
			expect(target.is_empty() if peaceful else target == enemy, "%s must %s %s when unselected" % [spell,"leave alone" if peaceful else "assist against",disposition])
			game.summons.step(.1)
			expect(enemy.hp == hp if peaceful else enemy.hp < hp, "%s health policy for %s: before%s after%s" % [spell,disposition,hp,enemy.hp])
			if peaceful:
				expect(not enemy.active, "%s must not provoke an unselected %s" % [spell,disposition])
			expect(game.selected_target.is_empty(), "Disposition checks must preserve the unselected case")
			print("DISPOSITION: ", {"spell":spell,"kind":disposition,"selected":false,"auto_target":not target.is_empty(),"before_hp":hp,"after_hp":enemy.hp,"active":enemy.active})
			count += 1
	game.EnemyCatalog.TYPES[0] = original
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	var after := source_hashes()
	expect(before == after, "Source changed during summon disposition acceptance")
	expect(count == 12, "All three production companions must exercise all four dispositions")
	print("SOURCE_HASHES: ", {"before":before,"after":after})
	if failures.is_empty():
		print("PASS: twelve actual production summon/disposition cases; unprovoked neutral/passive health and aggro preserved, real provocation assistance and hostile combat retained; definitions restored and private saves cleaned")
	else:
		print("FAIL: ", failures.size(), " summon disposition checks")
	quit(0 if failures.is_empty() else 1)
