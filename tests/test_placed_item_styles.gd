extends SceneTree

const Catalog = preload("res://scripts/item_catalog.gd")
const Models = preload("res://scripts/item_models.gd")
const Furniture = preload("res://scripts/furnishing_catalog.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var renderer := Models.new()
	var count := 0
	for id in Catalog.definitions:
		var item: Dictionary = Catalog.definitions[id]
		if not item.get("world_prop", false) and item.kind != "furnishing":
			continue
		var original: Dictionary = item.duplicate(true)
		for family in ["block_voxel", "flat_lowpoly"]:
			var body: Node3D
			var spec := Furniture.definition(id)
			if not spec.is_empty():
				body = Furniture.model({"item": id, "rotation": 1}, null, family)
			else:
				body = renderer.fitted(renderer.create(item, family), Vector2(.75, .45), .6, PI / 2)
			if body == null:
				failures.append("Placement missing: %s / %s / %s" % [id, family, renderer.error if spec.is_empty() else Furniture.families.error])
				continue
			var box := Bounds.bounds(body)
			var size := Vector2(.75, .45) if spec.is_empty() else Furniture.footprint(spec, 1)
			var height: float = .6 if spec.is_empty() else spec.height
			if not box.size.is_equal_approx(Vector3(size.x, height, size.y)) or not is_zero_approx(box.position.y) or not box.size.is_finite():
				failures.append("Placement must retain exact grounded authority: %s / %s / %s" % [id, family, box])
			if renderer.styles.family_of(body.get_meta("render_asset", "")) != family:
				failures.append("Placement requires truthful family identity: " + id)
			body.free()
		assert(item == original)
		count += 1
		if count % 250 == 0:
			print("CHECKED: %s placeable sources" % count)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: %s portable/furnishing sources in both families, original item identity, exact rotated footprints/height/grounding and actual rendered family" % count if failures.is_empty() else "FAIL: %s placeable style gaps" % failures.size())
	quit(0 if failures.is_empty() else 1)
