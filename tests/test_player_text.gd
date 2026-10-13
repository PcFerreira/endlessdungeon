extends SceneTree

const Items = preload("res://scripts/item_catalog.gd")
const Loot = preload("res://scripts/enemy_loot.gd")
const Bundles = preload("res://scripts/bundle_catalog.gd")
const Architecture = preload("res://scripts/town_architecture_catalog.gd")
const Registry = preload("res://scripts/asset_registry.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(ResourceLoader.exists("res://scripts/player_text.gd"), "Gameplay names need an authored display-name catalogue")
	var names = load("res://scripts/player_text.gd")
	var english = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lore/locales/en.json"))
	var architecture := Architecture.new()
	assert(architecture.error.is_empty())
	for id in architecture.data.templates:
		var name: String = architecture.data.templates[id].name
		assert(names.name_for("architecture", id, "") == name and not name.is_empty())
		assert(not name.to_lower().contains("medieval") and not name.to_lower().contains("exterior"))
		assert(english.messages[names.key_for("architecture", id)] == name)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/items.json")).items
	for entry in Bundles.entries("items"):
		Loot.apply_rarity(entry)
		source[entry.id] = entry
	var atlas_id := ""
	for id in source:
		var actual: Dictionary = Items.definitions[id]
		assert(actual.classification_name == source[id].name)
		assert(actual.name == english.messages[actual.name_key])
		assert(not actual.name.contains("_") and not actual.name.contains("0000") and not actual.name.to_lower().contains("medieval"))
		var expected: Dictionary = source[id].duplicate(true)
		var clean: Dictionary = actual.duplicate(true)
		for key in ["name", "name_key", "classification_name"]:
			expected.erase(key)
			clean.erase(key)
		assert(expected == clean, "Display naming must preserve every non-name item field: " + id)
		if source[id].name == "Blue Set 0000 Weapon":
			atlas_id = id
	assert(not atlas_id.is_empty() and Items.definitions[atlas_id].name == "Weapon")
	for id in Items.definitions:
		var item: Dictionary = Items.definitions[id]
		assert(not item.name.is_empty() and item.has("name_key"))
		assert(english.messages[item.name_key] == item.name)
	var choices: Dictionary = Loot.choices
	for class_id in ["mage", "sword", "spellsword"]:
		for pool in Loot.data.pools:
			Loot.choices = {}
			var original := Loot.pool(pool, class_id, source)
			Loot.choices = {}
			assert(original == Loot.pool(pool, class_id, Items.definitions), "Naming must not change loot eligibility: " + pool)
		var enemy := {"id":"wizard", "name":"Wizard"}
		var context := {"class":class_id,"biome":2,"family":"dungeon_violet_sanctum"}
		for ordinal in range(1,101):
			Loot.choices = {}
			var original := Loot.reward(91, ordinal, enemy, context, source)
			Loot.choices = {}
			assert(original == Loot.reward(91, ordinal, enemy, context, Items.definitions), "Names must preserve seeded reward IDs")
	Loot.choices = choices
	var registry := Registry.new()
	var source_asset := registry.get_asset("quaternius_modular_women/Individual Characters/glTF/Medieval.gltf")
	assert(not source_asset.is_empty() and source_asset.id.ends_with("Medieval.gltf"), "Provenance must keep its original identity")
	print("PASS: every gameplay item/architecture name and locale key; original item fields, all class/pool memberships, seeded rewards and source identities preserved")
	quit()
