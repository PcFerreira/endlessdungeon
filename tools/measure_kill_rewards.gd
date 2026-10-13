extends SceneTree

const Game = preload("res://scripts/game.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Items = preload("res://scripts/item_catalog.gd")

class RewardLedger extends Game:
	var rewards: Array[String] = []

	func _drop(_point: Vector2, kind: String) -> void:
		rewards.append(kind)

	func _burst(_point: Vector2, _color: Color, _count: int, _spread: float) -> void:
		pass

func _initialize() -> void:
	call_deferred("measure")

func measure() -> void:
	var game := RewardLedger.new()
	game.layer = "dungeon"
	var reports := []
	var total := _counts()
	for class_id in ["mage", "sword", "spellsword"]:
		game.build.class_id = class_id
		for family_id in Areas.DUNGEONS:
			var counts := _counts()
			var pool := Enemies.dungeon_pool(family_id)
			assert(not pool.is_empty())
			game.active_dungeon = {"family": family_id}
			for seed_value in [0, 42, 12345, 87654]:
				game.run_seed = seed_value
				game.kills = 0
				game.dungeon.biome = posmod(seed_value, 4)
				game.rng.seed = seed_value
				var rng_before := game.rng.state
				for ordinal in range(1, 501):
					game.rewards.clear()
					var enemy := {"id": "", "hp": 1.0, "point": Vector2.ZERO, "kind": pool[(ordinal - 1) % pool.size()], "node": Node3D.new()}
					game.enemies.assign([enemy, {"id": "unmeasured-survivor"}])
					game._hit_enemy(enemy, 1.0)
					assert(game.rewards.count("gold_coin") == 1)
					counts.kills += 1
					var inventory_items := 0
					for id in game.rewards:
						if id in ["health", "mana"]:
							counts[id + "_orbs"] += 1
						elif id == "gold_coin":
							counts.coins += 1
						else:
							inventory_items += 1
							counts.noncoin_items += 1
							if id == "ember_shard":
								counts.shards += 1
							else:
								counts.ordinary_items += 1
								counts[Items.definitions[id].kind] += 1
					counts.coin_only_inventory_kills += int(inventory_items == 0)
					counts.multiple_inventory_item_kills += int(inventory_items > 1)
					if ordinal % 100 == 0:
						await process_frame
				assert(game.rng.state == rng_before, "Reward selection must leave combat RNG intact")
			for key in total:
				total[key] += counts[key]
			reports.append({"class": class_id, "family": family_id, "counts": counts})
	var report := {
		"method": "Production Game._hit_enemy reward calls across three classes, six dungeon families, four seeds and 500 kills per seed. Only rendering/effects are replaced by a ledger. This measures reward frequency, not combat difficulty, collection or human pacing. Coin-only inventory kills may still emit instant health/mana orbs.",
		"policy": Items.policy,
		"totals": total,
		"coin_only_inventory_fraction": float(total.coin_only_inventory_kills) / total.kills,
		"noncoin_items_per_kill": float(total.noncoin_items) / total.kills,
		"reports": reports
	}
	_validate(report)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/kill-rewards.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("PASS: complete production kill rewards; ", JSON.stringify({"totals": total, "coin_only_inventory_fraction": report.coin_only_inventory_fraction, "noncoin_items_per_kill": report.noncoin_items_per_kill}))
	var nodes: Array[Node] = []
	_owned_nodes(game, {}, nodes)
	for node in nodes:
		if is_instance_valid(node):
			node.free()
	await process_frame
	quit()

func _validate(_report: Dictionary) -> void:
	pass

func _owned_nodes(object: Object, seen: Dictionary, nodes: Array[Node]) -> void:
	if seen.has(object.get_instance_id()):
		return
	seen[object.get_instance_id()] = true
	if object is Node:
		nodes.append(object)
	for property in object.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value = object.get(property.name)
		if is_instance_valid(value) and (value is Node or value is RefCounted):
			_owned_nodes(value, seen, nodes)

func _counts() -> Dictionary:
	return {"kills": 0, "coins": 0, "shards": 0, "ordinary_items": 0, "noncoin_items": 0, "coin_only_inventory_kills": 0, "multiple_inventory_item_kills": 0, "health_orbs": 0, "mana_orbs": 0, "material": 0, "equipment": 0, "consumable": 0}
