extends SceneTree

const Edits = preload("res://scripts/content_edits.gd")
const Store = preload("res://tools/content_editor/store.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Shops = preload("res://scripts/stores.gd")
const Game = preload("res://scripts/game.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var path := "user://test-item-removal-%s.json" % Time.get_ticks_usec()
	var store := Store.new(path)
	store.load_catalogues()
	var original := store.base_items.duplicate(true)
	var inventory := Inventory.new()
	assert(inventory.add("ember_shard", 3))
	var saved := inventory.snapshot()
	store.document.items.ember_shard = {"removed": true}
	assert(Edits.valid(store.document), "Removal must be a supported persistent item override")
	var invalid := store.document.duplicate(true)
	invalid.items.ember_shard.removed = "yes"
	assert(not Edits.valid(invalid), "Removal must reject non-boolean values")
	assert(store.set_item_removed("health_potion", true))
	assert(not store.set_item_removed("missing-item", true))
	store.document.items.aether_potion = {"enabled": false, "name": "Edited potion"}
	assert(store.set_item_removed("aether_potion", true))
	assert(store.set_item_removed("aether_potion", false))
	assert(not store.document.items.aether_potion.enabled and store.document.items.aether_potion.name == "Edited potion", "Restore must preserve earlier edits and disabled state")
	var custom_id := store.adopt({"id": "removal-fixture", "title": "Custom item", "kind": "texture", "pack": "editor", "path": "res://assets/items/oak_chair.svg"}, "items")
	assert(store.set_item_removed(custom_id, true))
	assert(store.document.add_items.size() == 1, "Removing custom items must retain their stable save identity")
	assert(store.save(), store.error)
	var restored := Store.new(path)
	restored.load_catalogues()
	var definitions := Edits.items(restored.base_items, restored.document)
	assert(definitions.ember_shard.removed and definitions[custom_id].removed)
	assert(store.base_items == original, "Removal must preserve authored sources")
	Items.definitions = definitions
	Inventory.ITEMS = definitions
	Edits.data = restored.document
	Items.bundles = Items._bundles()
	Items.contexts = Items._contexts()
	Items.EnemyLoot.choices.clear()
	assert(inventory.restore(saved, "mage") and inventory.count("ember_shard") == 3, "Existing owned items must remain readable")
	assert(not Shops.catalog.accepts("provisions", "health_potion"))
	var source := {"id": "city:removal-fixture", "profile": "provisions"}
	var stock := {source.id: {"profile": source.profile, "stock": {"health_potion": 2}, "purse": 50}}
	assert(Shops.valid(stock), "Saved stock must remain loadable even after removal")
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = "user://removal-game-%s" % Time.get_ticks_usec()
	game.settings_path = game.save_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.run_seed = 42
	var shops := Shops.new()
	shops.game = game
	root.add_child(shops)
	assert(shops.restore(stock))
	assert(not shops.offers(source).has("health_potion"), "Saved stock must hide removed offers")
	assert(not Shops.catalog.initial(source, 42).stock.has("health_potion"))
	var enemy := {"id": "removal-fixture", "name": "Skeleton", "drops": {"entries": [{"item": "ember_shard", "weight": 1}, {"item": custom_id, "weight": 1}]}}
	assert(Items.EnemyLoot.reward(42, 1, enemy, {}, definitions).is_empty())
	for pool in Items.EnemyLoot.data.pools:
		for id in Items.EnemyLoot.pool(pool, "mage", definitions):
			assert(Items.available(definitions[id]), "Contextual enemy pools must exclude removed and disabled items")
	for ordinal in range(1, 300):
		for mode in ["any", "chest", "enemy"]:
			var id := Items.loot(42, ordinal, mode)
			assert(id.is_empty() or Items.available(definitions[id]), "Removed items must never appear in new loot")
	game._drop(Vector2.ZERO, "ember_shard")
	game._drop(Vector2.ZERO, "health_potion")
	game._drop(Vector2.ZERO, "")
	assert(game.pickups.is_empty(), "Fixed rewards must also respect removal")
	for id in definitions:
		definitions[id].removed = true
	Items.bundles = Items._bundles()
	Items.contexts = Items._contexts()
	assert(Items.loot(42, 1, "chest").is_empty(), "An exhausted catalogue must not fall back to a removed shard")
	assert(restored.set_item_removed(custom_id, false) and restored.save(), restored.error)
	assert(not Edits.items(restored.base_items, Store.new(path).document)[custom_id].removed)
	shops.queue_free()
	game.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".backup"))
	print("PASS: reversible built-in/custom removal, saved inventory/stock compatibility and contextual/fixed reward exclusion")
	quit()
