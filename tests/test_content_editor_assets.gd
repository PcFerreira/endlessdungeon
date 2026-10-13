extends SceneTree

const Store = preload("res://tools/content_editor/store.gd")
const Assets = preload("res://tools/content_editor/assets.gd")

func _initialize() -> void:
	var store := Store.new()
	store.load_catalogues()
	var index := Assets.new()
	index.build(store)
	var seen := {}
	for asset in index.rows:
		if asset.staged:
			seen[asset.id] = true
		assert(asset.usage in ["referenced", "portable", "unused", "source"])
		assert(asset.usage != "referenced" or not asset.references.is_empty())
		assert(asset.usage != "source" or not asset.staged)
	for asset in store.registry.find():
		if asset.kind != "text":
			assert(seen.has(asset.id), "All staged resources must appear, including generated source representations: " + asset.id)
	var before := store.document.duplicate(true)
	var sample: Dictionary = index.rows.filter(func(asset): return asset.staged and asset.kind == "model")[0]
	var id := store.adopt(sample, "enemies")
	assert(id.begins_with("editor:") and store.adopt(sample, "enemies") == id)
	assert(store.document.add_enemies.size() == before.add_enemies.size() + 1)
	assert(store.Edits.valid(store.document))
	assert(store.validate_references(), store.error)
	assert(store.entries("enemies").any(func(enemy): return enemy.id == id and enemy.source_asset == sample.id))
	print("PASS: full staged/source asset index, honest usage labels and idempotent model adoption with validated provenance")
	quit()
