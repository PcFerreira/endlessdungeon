extends SceneTree

const Edits = preload("res://scripts/content_edits.gd")
const Store = preload("res://tools/content_editor/store.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Loot = preload("res://scripts/enemy_loot.gd")
const Inventory = preload("res://scripts/inventory.gd")
const ICON := "res://assets/items/oak_chair.svg"
var directory := "/tmp/endless-content-contracts-%s" % Time.get_ticks_usec()
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)

func material(id: String) -> Dictionary:
	return {"id": id, "name": "Contract material", "description": "A material for the persistence contract.", "kind": "material", "stack": 10, "icon": ICON, "source_pack": "editor", "loot_sources": ["enemy", "chest"]}

func reject(document: Dictionary, label: String) -> void:
	var path := directory.path_join(label + ".json")
	var store := Store.new(path)
	check(store.save(), "The empty document must persist before testing " + label)
	var original := FileAccess.get_file_as_bytes(path)
	store.document = document
	check(not store.save(), "Cannot persist " + label)
	check(FileAccess.get_file_as_bytes(path) == original, "Rejected " + label + " must preserve the existing document")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var inventory_items := Inventory.ITEMS
	var definitions := Items.definitions
	var edit_data := Edits.data
	var source := Items.source_definitions()
	var repeated := Items.source_definitions()
	var base_count := 0
	var portable_id := ""
	for id in definitions:
		if id.begins_with("editor:"):
			continue
		base_count += 1
		check(source.has(id) and repeated.has(id), "Pre-edit source catalogue retains " + id)
		if portable_id.is_empty() and id.begins_with("world_prop:"):
			portable_id = id
	check(not portable_id.is_empty(), "The runtime catalogue includes a portable item for reference consumption")
	var weapon := material("editor:contract_weapon")
	weapon.merge({"name": "Contract weapon", "kind": "equipment", "stack": 1, "slot": "weapon", "classes": ["mage"], "power": .12}, true)
	for absent in ["classes", "slot"]:
		var incomplete := weapon.duplicate(true)
		incomplete.erase(absent)
		var document := Edits.empty_document()
		document.add_items.append(incomplete)
		reject(document, "equipment-missing-" + absent)
	var document := Edits.empty_document()
	document.items.ember_shard = {"kind": "equipment"}
	reject(document, "material-patched-to-incomplete-equipment")
	var missing_pack := material("editor:contract_missing_pack")
	missing_pack.erase("source_pack")
	document = Edits.empty_document()
	document.add_items.append(missing_pack)
	reject(document, "material-missing-source-pack")
	var wrong_icon := material("editor:contract_wrong_icon")
	wrong_icon.icon = "res://scripts/content_edits.gd"
	document = Edits.empty_document()
	document.add_items.append(wrong_icon)
	reject(document, "non-texture-icon")
	var valid := Edits.empty_document()
	var ingredient := material("editor:contract_material")
	valid.add_items.append(weapon)
	valid.add_items.append(ingredient)
	var enemy_id: String = Enemies.TYPES[0].id
	valid.enemies[enemy_id] = {"drops": {"item_chance": 1.0, "entries": [{"item": weapon.id, "weight": 1}, {"item": ingredient.id, "weight": 1}, {"item": portable_id, "weight": 1}]}}
	var path := directory.path_join("valid.json")
	var store := Store.new(path)
	store.document = valid
	var published := store.save()
	check(published, "Valid equipment, material and existing portable references persist: " + store.error)
	if published:
		var restored := Store.new(path)
		check(restored.error.is_empty(), "The saved document reloads without errors")
		var effective := Edits.items(source, restored.document)
		Inventory.ITEMS = effective
		Items.definitions = effective
		Edits.data = restored.document
		var contexts := Items._contexts()
		check(contexts.get("enemy", {}).get("editor", []).has(ingredient.id), "The material participates in runtime enemy loot contexts")
		check(contexts.get("chest", {}).get("editor", []).has(weapon.id), "The equipment participates in runtime chest loot contexts")
		var inventory := Inventory.new()
		check(inventory.add(weapon.id) and inventory.equip(weapon.id, "mage"), "The saved equipment can be added and equipped")
		check(is_equal_approx(inventory.bonus("power"), .12), "The equipped item supplies its authored bonus")
		check(inventory.add(ingredient.id, 3) and inventory.count(ingredient.id) == 3, "The saved material stacks in the actual inventory")
		check(Items.icon(effective[weapon.id]) is Texture2D, "The saved equipment icon loads as a texture")
		var enemies := Edits.enemies(Enemies.TYPES, restored.document)
		var enemy: Dictionary = enemies.filter(func(entry): return entry.id == enemy_id)[0]
		var seen := {}
		for ordinal in range(1, 65):
			var reward := Loot.reward(91, ordinal, enemy, {"class": "mage"}, effective)
			check(reward in [weapon.id, ingredient.id, portable_id], "Actual rewards resolve only persisted valid references")
			if not seen.has(reward) and effective.has(reward):
				check(inventory.add(reward), "A selected reward can enter the actual inventory")
				seen[reward] = true
		check(seen.size() == 3, "All authored equipment/material/portable rewards remain available")
		var fresh := Inventory.new()
		check(fresh.restore(JSON.parse_string(JSON.stringify(inventory.snapshot())), "mage"), "Consumed edited items survive inventory JSON restore")
		check(fresh.equipment.weapon == weapon.id and fresh.count(ingredient.id) == inventory.count(ingredient.id), "Restoration retains equipment and material quantities")
	Inventory.ITEMS = inventory_items
	Items.definitions = definitions
	Edits.data = edit_data
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	if not failures.is_empty():
		print("FAIL: ", failures.size(), " content edit contract failures")
		quit(1)
		return
	print("PASS: complete pre-edit item identities, rejected unsafe definitions, persisted equipment/material/portable consumption and inventory restoration; ", base_count, " base items")
	quit()
