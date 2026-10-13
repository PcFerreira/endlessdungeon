extends SceneTree

const Catalog = preload("res://scripts/item_catalog.gd")

func _init() -> void:
	var report := {"enemy_item_chance": Catalog.policy.enemy_item_chance, "seeds": [], "scope": "Current ordinary kill chance and item-selection APIs; physical pickup and merchant integration are separate checks"}
	for seed_value in [0, 1, 12345, 98765]:
		var sample := {"seed": seed_value, "kills": 10000, "item_drops": 0, "categories": {}, "source_packs": {}, "unique_items": {}, "invalid_items": []}
		for ordinal in range(1, sample.kills + 1):
			if not Catalog.should_drop(seed_value, ordinal):
				continue
			var id: String = "health_potion" if ordinal % 4 == 0 else Catalog.loot(seed_value, ordinal, "enemy")
			if not Catalog.definitions.has(id):
				sample.invalid_items.append(id)
				continue
			var item: Dictionary = Catalog.definitions[id]
			sample.item_drops += 1
			sample.categories[item.kind] = sample.categories.get(item.kind, 0) + 1
			var pack: String = item.get("source_pack", "base")
			sample.source_packs[pack] = sample.source_packs.get(pack, 0) + 1
			sample.unique_items[id] = true
		sample.unique_items = sample.unique_items.size()
		sample.observed_item_chance = float(sample.item_drops) / sample.kills
		report.seeds.append(sample)
		print("Seed %s: %.2f%% items; categories=%s; unique=%s" % [seed_value, sample.observed_item_chance * 100, sample.categories, sample.unique_items])
	var file := FileAccess.open("res://artifacts/loot-balance-audit.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write loot balance audit")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	if report.seeds.any(func(sample): return not sample.invalid_items.is_empty()):
		printerr("FAIL: ordinary loot selected undefined items")
		quit(1)
		return
	print("PASS: measured 40,000 ordinary reward decisions; balance and contextual eligibility require separate acceptance")
	quit()
