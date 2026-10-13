extends SceneTree

const Build = preload("res://scripts/character_build.gd")

func _init() -> void:
	for class_id in ["mage", "sword", "spellsword"]:
		var build := Build.new()
		build.reset(class_id)
		assert(build.action_bar.size() == 10 and build.unlocked.size() == 4)
		assert(not build.learn("power"), "Learning must require a skill point")
		build.skill_points = 8
		assert(not build.learn("advanced"), "Advanced abilities must require their parent node")
		assert(build.learn("power") and build.skill_points == 7)
		assert(build.learn("specialty"))
		var spell: String = build.tree()[3].ability
		assert(build.unlocked.has(spell))
		assert(build.equip(spell, 4) and build.action_bar[4] == spell)
		assert(build.equip(spell, 9) and build.action_bar[4].is_empty() and build.action_bar[9] == spell, "Equipping must move an ability without duplication")
		assert(not build.equip("unavailable", 0))
		assert(build.learn("advanced"))
		assert(build.learn("power") and build.learn("power"))
		var points := build.skill_points
		assert(not build.learn("power") and build.skill_points == points, "Maxed nodes must not spend points")
		build.reset(class_id)
		assert(build.skill_points == 0 and build.ranks.is_empty(), "A new character must reset progression")
	print("PASS: three classes; skill costs, prerequisites, rank caps, unlocks, ten-slot assignment, character reset")
	quit()
