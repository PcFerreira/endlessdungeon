extends SceneTree

const Bundles = preload("res://scripts/bundle_catalog.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Models = preload("res://scripts/enemy_models.gd")
const Life = preload("res://scripts/world_life_catalog.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Visual = preload("res://scripts/item_visual.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(Bundles.valid(Bundles.data))
	var registry := Registry.new()
	var life := Life.new()
	var seen := {}
	for habitat in ["town", "wild", "water"]:
		for biome in range(4):
			for salt in range(2048):
				var animal := life.species_for(habitat, biome, salt)
				if not animal.is_empty():
					seen[animal.id] = true
	assert(seen.size() == life.data.species.size(), "Every animal must have an eligible habitat")
	for species in life.data.species:
		assert(not life.model_choices[species.id].is_empty(), species.id)
		for record in life.model_choices[species.id]:
			var body := registry.instantiate(record.id)
			assert(body != null and Models.bounds(body).size.y > 0, record.id)
			body.free()
	for definition in Bundles.entries("enemies"):
		var index := Enemies.index_of(definition.id, -1)
		assert(index >= 3 and index in Enemies.dungeon_pool("dungeon_ashen_crypt"))
		var body := Models.create(index, 42)
		assert(body.get_meta("asset_id") == definition.source_asset and Models.bounds(body).size.y > 0, definition.id)
		if definition.source_pack == "bundle_voxel_creature_pack":
			for node in body.find_children("*", "MeshInstance3D", true, false):
				assert(node.get_active_material(0).vertex_color_use_as_albedo, "Voxel source colors must be visible")
		body.free()
	var models := 0
	var atlas_cells := 0
	for item in Bundles.entries("items"):
		assert(Inventory.ITEMS.has(item.id))
		var icon := Inventory.Catalog.icon(item)
		assert(icon != null and icon.get_width() > 0 and icon.get_height() > 0, item.id)
		if item.has("asset_id"):
			var body := Visual.model(item)
			assert(body != null and Models.bounds(body).size.y > 0, item.asset_id)
			body.free()
			models += 1
		if item.has("icon_region"):
			var region: Array = item.icon_region
			assert(region[0] + region[2] <= icon.atlas.get_width() and region[1] + region[3] <= icon.atlas.get_height())
			atlas_cells += 1
	var selected := {}
	var biggest := 0
	for pool in Inventory.Catalog.bundles.values():
		biggest = maxi(biggest, pool.size())
	for ordinal in range(1, Inventory.Catalog.bundles.size() * biggest + 1):
		selected[Inventory.Catalog.loot(42, ordinal)] = true
	assert(selected.size() == Bundles.data.items.size(), "Every bundled item must be reachable through the loot cycle")
	var drops := 0
	for ordinal in range(1, 10001):
		if Inventory.Catalog.should_drop(42, ordinal):
			drops += 1
	assert(drops >= 1700 and drops <= 2300, "Ordinary item frequency should follow the 20 percent policy")
	for context in Inventory.Catalog.contexts:
		for pool in Inventory.Catalog.contexts[context].values():
			for id in pool:
				assert(context in Inventory.ITEMS[id].loot_sources)
				assert((Inventory.ITEMS[id].kind == "furnishing") == (context == "chest"), "Furnishings belong in chests; ordinary gear/finds belong in enemy rolls")
	var bad: Dictionary = Bundles.data.duplicate(true)
	bad.items[0].stack = 0
	assert(not Bundles.valid(bad))
	print("PASS: %s eligible animals, %s enemy visuals/pools, %s obtainable items, %s real item models, %s atlas icons; %s/10000 ordinary item rolls and contextual chest furnishings" % [seen.size(), Bundles.data.enemies.size(), selected.size(), models, atlas_cells, drops])
	quit()
