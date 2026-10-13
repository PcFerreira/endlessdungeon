extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Profiles = preload("res://scripts/asset_profiles.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Text = preload("res://scripts/player_text.gd")
static var registry := Registry.new()
static var asset_items: Dictionary = {}

static func extend(items: Dictionary) -> void:
	for id in items:
		var asset: String = items[id].get("asset_id", "")
		if not asset.is_empty():
			asset_items[asset] = id
	for asset in registry.find("model"):
		if asset_items.has(asset.id):
			continue
		var id: String = "world_prop:" + asset.id
		items[id] = {"id": id, "name": Text.name_for("items", id, "Furnishing"), "kind": "furnishing", "stack": 10, "description": "A movable object from the world. Place it from your backpack.", "icon": "res://assets/items/oak_chair.svg", "asset_id": asset.id, "world_prop": true}
		asset_items[asset.id] = id
	var models := Scenery.MODELS.duplicate()
	for key in Profiles.MODELS:
		models[key] = Profiles.MODELS[key][0]
	for key in models:
		var id: String = "world_native:" + key
		items[id] = {"id": id, "name": Text.name_for("native", str(key), "Furnishing"), "kind": "furnishing", "stack": 10, "description": "A movable world object. Place it from your backpack.", "icon": "res://assets/items/oak_chair.svg", "scenery_key": key, "world_prop": true}
		asset_items[key] = id
	var styles := Styles.new(registry)
	assert(styles.error.is_empty(), "Native portable styles need a valid family catalogue")
	for family in styles.data.families:
		for role in styles.data.roles + styles.data.get("cultural_roles", []):
			var asset: String = styles.native_id(family, role)
			var id: String = "world_native:" + asset
			items[id] = {"id": id, "name": Text.name_for("native", str(role), "Furnishing"), "kind": "furnishing", "stack": 10, "description": "A movable world object. Place it from your backpack.", "icon": "res://assets/items/oak_chair.svg", "scenery_key": asset, "native_role": role, "visual_family": family, "world_prop": true}
			asset_items[asset] = id

static func for_asset(key: String) -> String:
	var asset := registry.get_asset(key)
	return asset_items.get(asset.get("id", key), "")
