extends SceneTree

const Loot = preload("res://scripts/enemy_loot.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(Loot.valid(Loot.data))
	var supported := {}
	for class_id in ["mage","sword","spellsword"]:
		for name in Loot.data.pools:
			var pool := Loot.pool(name, class_id, Items.definitions)
			assert(not pool.is_empty(), name + ":" + class_id)
			for id in pool:
				var item: Dictionary = Items.definitions[id]
				assert(item.kind != "furnishing")
				assert(item.kind != "equipment" or class_id in item.classes)
				supported[id] = true
	for item in Items.Bundles.data.items:
		assert(item.kind == "furnishing" or supported.has(item.id), "Every ordinary bundled item needs a real eligible source: " + item.id)
	var scenarios := [
		{"enemy":{"id":"wolf","name":"Wolf"},"context":{"class":"mage","biome":0,"facet":"","family":""}},
		{"enemy":{"id":"skeleton","name":"Skeleton"},"context":{"class":"sword","biome":-1,"facet":"","family":"dungeon_ashen_crypt"}},
		{"enemy":{"id":"wizard","name":"Wizard"},"context":{"class":"mage","biome":-1,"facet":"","family":"dungeon_violet_sanctum"}},
		{"enemy":{"id":"golem","name":"Golem"},"context":{"class":"spellsword","biome":-1,"facet":"","family":"dungeon_quarry_depths"}}
	]
	var stats := []
	for scenario in scenarios:
		var counts := {"items":0,"equipment":0,"consumable":0,"material":0,"rare":0}
		for ordinal in range(1,501):
			var id := Items.enemy_reward(42, ordinal, scenario.enemy, scenario.context)
			assert(id == Items.enemy_reward(42, ordinal, scenario.enemy, scenario.context), "Rewards must reconstruct without consuming global RNG")
			if id.is_empty():
				continue
			var item: Dictionary = Items.definitions[id]
			assert(item.kind != "furnishing")
			assert(item.kind != "equipment" or scenario.context["class"] in item.classes)
			counts.items += 1
			counts[item.kind] += 1
			counts.rare += int(Loot.rarity(item) == "rare")
		stats.append({"scenario":scenario.enemy.name,"stats":counts})
	assert(Loot.table(scenarios[0].enemy,scenarios[0].context) != Loot.table(scenarios[2].enemy,scenarios[2].context))
	var bad: Dictionary = Loot.data.duplicate(true)
	bad.profiles[0].weights.remains = .2
	assert(not Loot.valid(bad))
	bad = Loot.data.duplicate(true)
	bad.profiles[0].weights.unknown_pool = 10
	assert(not Loot.valid(bad))
	bad = Loot.data.duplicate(true)
	bad.rarity_bonuses.rare.power = "unbounded"
	assert(not Loot.valid(bad))
	print("PASS: real enemy/habitat/family pools, all ordinary items eligible, class compatibility, available rarity weights and independent deterministic rewards; ", JSON.stringify(stats))
	quit()
