extends SceneTree

const Catalog = preload("res://scripts/item_catalog.gd")
const Models = preload("res://scripts/item_models.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var renderer := Models.new()
	assert(renderer.styles.error.is_empty(), renderer.styles.error)
	assert(Catalog.definitions.gold_coin.icon != Catalog.definitions.ember_shard.icon)
	var count := 0
	var categories := {}
	for id in Catalog.definitions:
		var item: Dictionary = Catalog.definitions[id]
		if item.get("world_prop", false):
			continue
		var original: Dictionary = item.duplicate(true)
		for family in ["block_voxel", "flat_lowpoly"]:
			var body := renderer.create(item, family)
			if body == null:
				failures.append("Actual item body missing: %s / %s / %s" % [id, family, renderer.error])
				continue
			var box := Bounds.bounds(body)
			if box.size.x <= 0 or box.size.y <= 0 or box.size.z <= 0 or not box.position.is_finite() or not box.size.is_finite():
				failures.append("Actual item requires finite 3D geometry: " + id)
			if body.get_meta("visual_family", "") != family or renderer.styles.family_of(body.get_meta("render_asset", "")) != family:
				failures.append("Actual item needs truthful family/source identity: " + id)
			categories[body.get_meta("representation")] = categories.get(body.get_meta("representation"), 0) + 1
			body.free()
		assert(item == original, "Item presentation cannot mutate stats/source identity")
		count += 1
		if count % 250 == 0:
			print("CHECKED: %s items" % count)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: %s actual item definitions in both families; 3D bounds, real source identity, original stats and representations %s" % [count, categories] if failures.is_empty() else "FAIL: %s item family gaps" % failures.size())
	quit(0 if failures.is_empty() else 1)
