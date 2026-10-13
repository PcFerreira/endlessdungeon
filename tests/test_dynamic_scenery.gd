extends SceneTree

const Registry = preload("res://scripts/asset_registry.gd")
const Scenery = preload("res://scripts/scenery.gd")

func _init() -> void:
	var registry := Registry.new()
	var scenery := Scenery.new()
	var ids: Array[String] = ["world_tree", "castle_wall"]
	if "--pipeline-fixture" in OS.get_cmdline_user_args():
		for entry in registry.find("model", ["pipeline-fixture"]):
			ids.append(entry.id)
	for id in ids:
		var model: Node3D = scenery.model(id, 1.0)
		assert(model != null, "Dynamic scenery must instantiate: " + id)
		var box: AABB = scenery.bounds(model)
		assert(is_equal_approx(maxf(box.size.x, box.size.z), 1.0), "Dynamic scenery must use the requested footprint")
		assert(absf(box.position.y) < .001, "Dynamic scenery must rest on the ground")
		assert(scenery.valid_materials(model), "Dynamic scenery must retain materials")
		model.free()
	print("PASS: dynamic scenery aliases/IDs, requested footprint, ground origin and materials")
	quit()
