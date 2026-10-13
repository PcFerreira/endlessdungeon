extends SceneTree

const Edits = preload("res://scripts/content_edits.gd")
const Store = preload("res://tools/content_editor/store.gd")

func _initialize() -> void:
	var document := Edits.empty_document()
	document.enemies.crypt_skeleton = {"hp": 120.0, "damage": 24.0, "level": 3, "level_mode": "fixed", "facing_degrees": 180.0, "drops": {"coins": 2, "item_chance": 1.0, "shard_chance": 0.0, "entries": [{"item": "ember_shard", "weight": 1}]}}
	document.items.ember_shard = {"stack": 50, "name": "Workbench shard"}
	assert(Edits.valid(document))
	var enemies := [{"id": "crypt_skeleton", "hp": 58.0, "damage": 12.0, "speed": 1.2}]
	var changed := Edits.enemies(enemies, document)
	assert(changed[0].hp == 120 and enemies[0].hp == 58, "Overrides must preserve authored catalogue data")
	assert(changed[0].speed == 1.2)
	var stats := Edits.combat_stats(changed[0], 8)
	assert(stats.level == 3 and is_equal_approx(stats.hp, 151.2) and is_equal_approx(stats.damage, 27.36))
	var original := Edits.combat_stats({"hp": 58.0, "damage": 12.0}, 8)
	assert(is_equal_approx(original.hp, 58 * (1 + 7 * .13)))
	assert(is_equal_approx(original.damage, 12 * (1 + 7 * .07)))
	for value in [-1, 1.1, "bad", null]:
		var invalid := document.duplicate(true)
		invalid.enemies.crypt_skeleton.drops.item_chance = value
		assert(not Edits.valid(invalid))
	var invalid := document.duplicate(true)
	invalid.enemies.crypt_skeleton.hp = 0
	assert(not Edits.valid(invalid))
	invalid = document.duplicate(true)
	invalid.enemies.crypt_skeleton.unrecognized_stat = 100
	assert(not Edits.valid(invalid))
	var path := "user://test-content-edits-%s.json" % Time.get_ticks_usec()
	var store := Store.new(path)
	store.document = document
	assert(store.save(), store.error)
	var restored := Store.new(path)
	assert(restored.document.enemies.crypt_skeleton.hp == 120)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(Edits.empty_document()))
	file.close()
	assert(not restored.save() and restored.error.contains("changed"), "A stale editor must not overwrite another writer")
	assert(store.document.enemies.crypt_skeleton.hp == 120)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: additive edits, real level scaling, invalid data rejection, atomic persistence and stale-writer protection")
	quit()
