extends SceneTree

const Registry = preload("res://scripts/asset_registry.gd")

func _init() -> void:
	var registry := Registry.new()
	assert(registry.error.is_empty(), registry.error)
	assert(not registry.find("model", ["castle"]).is_empty())
	assert(not registry.find("model", ["voxel"], "quaternius_cube_world").is_empty())
	assert(registry.get_asset("world_tree").id.begins_with("quaternius_cube_world/"))
	var first: Node3D = registry.instantiate("world_tree")
	var second: Node3D = registry.instantiate("world_tree")
	assert(first != null and second != null and first != second)
	assert(_meshes(first) > 0)
	first.free()
	second.free()
	for entry in registry.find("model"):
		var model: Node3D = registry.instantiate(entry.id)
		assert(model != null and _meshes(model) > 0, entry.id)
		model.free()
	var books: Dictionary = registry.books()
	assert(books.has("book_waiting_cup"))
	assert(books.book_waiting_cup.text.contains("Grandmother"))
	assert(not books.book_waiting_cup.text.contains("Reliability:"))
	assert(not registry.dialogue_lines().is_empty())
	assert(registry.text("book_waiting_cup") == books.book_waiting_cup.text)
	assert(registry.instantiate("book_waiting_cup") == null)
	assert(registry.resource("missing_asset") == null)
	var changed: Dictionary = registry.get_asset("world_tree")
	changed.tags.clear()
	assert(not registry.get_asset("world_tree").tags.is_empty(), "Callers cannot alter stored metadata")
	assert(not registry.reload("res://missing-catalog.json"))
	assert(registry.books().has("book_waiting_cup"), "Failed reload must retain the previous usable catalog")
	assert(registry.reload())
	if "--pipeline-fixture" in OS.get_cmdline_user_args():
		assert(registry.text("pipeline_new_book") == "A new authored passage.\n")
		assert(registry.text("pipeline_new_line") == "A new authored line.")
		var tested_kinds: Array[String] = []
		for entry in registry.find("", ["pipeline-fixture"]):
			var loaded := registry.resource(entry.id)
			if entry.kind == "model":
				assert(loaded is Mesh, "OBJ must load as a mesh")
				var instance := registry.instantiate(entry.id)
				assert(instance != null and _meshes(instance) > 0)
				instance.free()
			elif entry.kind == "texture":
				assert(loaded is Texture2D and loaded.get_width() > 0)
			elif entry.kind == "audio":
				assert(loaded is AudioStream and loaded.get_length() > 0)
			tested_kinds.append(entry.kind)
		assert("model" in tested_kinds and "texture" in tested_kinds and "audio" in tested_kinds)
	print("PASS: runtime asset discovery, tag/alias queries, instantiated models, authored books/dialogue, safe failed reload")
	quit()

func _meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _meshes(child)
	return count
