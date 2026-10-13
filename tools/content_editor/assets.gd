extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const SOURCE_KINDS := {"gltf": "model", "glb": "model", "obj": "model", "fbx": "model", "png": "texture", "svg": "texture", "jpg": "texture", "jpeg": "texture", "ogg": "audio", "wav": "audio", "mp3": "audio"}
var registry := Registry.new()
var rows: Array = []
var references := {}
var portable := {}
var staged_by_source := {}

func build(store) -> void:
	rows.clear()
	references.clear()
	portable.clear()
	staged_by_source.clear()
	for asset in registry.find():
		if asset.kind != "text":
			staged_by_source[asset.source_file] = asset
	for item in store.entries("items"):
		var asset: String = item.get("asset_id", item.get("source_asset", ""))
		if item.get("world_prop", false):
			portable[asset] = true
		else:
			_mark(asset, "Item: " + item.name)
			_mark_path(item.icon, "Icon: " + item.name)
	for enemy in store.entries("enemies"):
		if enemy.has("source_asset"):
			_mark(enemy.source_asset, "Monster source: " + enemy.name)
		else:
			_queries(enemy.get("visual", {}), "Monster source: " + enemy.name)
	for path in ["res://config/world_life.json", "res://config/world_dressing.json", "res://config/world_content.json", "res://config/town_architecture.json", "res://config/ambience.json"]:
		if FileAccess.file_exists(path):
			_queries(JSON.parse_string(FileAccess.get_file_as_string(path)), path.get_file())
	_model_dependencies()
	_scan("res://import_assets", {}, "")
	rows.sort_custom(func(a, b): return a.id.naturalnocasecmp_to(b.id) < 0)

func _mark(id: String, reason: String) -> void:
	var asset := registry.get_asset(id)
	if asset.is_empty():
		return
	if not references.has(asset.id):
		references[asset.id] = []
	if reason not in references[asset.id]:
		references[asset.id].append(reason)

func _mark_path(path: String, reason: String) -> void:
	if path.begins_with("res://assets/imported/packs/"):
		_mark(path.trim_prefix("res://assets/imported/packs/"), reason)

func _model_dependencies() -> void:
	for id in references.keys():
		var asset := registry.get_asset(id)
		if asset.get("kind") != "model":
			continue
		for dependency in ResourceLoader.get_dependencies(asset.path):
			var path: String = dependency.get_slice("::", 2) if "::" in dependency else dependency
			_mark_path(path, "Dependency of " + id)
		if asset.path.get_extension().to_lower() == "gltf":
			var document = JSON.parse_string(FileAccess.get_file_as_string(asset.path))
			if document is Dictionary:
				for image in document.get("images", []):
					if image.get("uri", "").is_empty() or image.uri.begins_with("data:"):
						continue
					_mark_path(asset.path.get_base_dir().path_join(image.uri).simplify_path(), "Declared model texture: " + id)

func _queries(value, reason: String) -> void:
	if value is String:
		_mark(value, reason)
		_mark_path(value, reason)
	elif value is Array:
		for part in value:
			_queries(part, reason)
	elif value is Dictionary:
		if value.get("patterns") is Array:
			for asset in registry.find("model", value.get("tags", []), value.get("pack", "")):
				if value.patterns.any(func(pattern): return asset.id.matchn(pattern)):
					_mark(asset.id, reason + " query")
		for part in value.values():
			_queries(part, reason)

func _scan(path: String, pack: Dictionary, root: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	var metadata := path.path_join("SOURCE.json")
	if FileAccess.file_exists(metadata):
		var value = JSON.parse_string(FileAccess.get_file_as_string(metadata))
		if value is Dictionary and value.get("id") is String:
			pack = value
			root = path
	for name in directory.get_directories():
		if not name.begins_with(".") and name not in ["license_review", "archives"] and not directory.is_link(name):
			_scan(path.path_join(name), pack, root)
	for name in directory.get_files():
		var extension := name.get_extension().to_lower()
		if not SOURCE_KINDS.has(extension) or directory.is_link(name):
			continue
		var source := path.path_join(name).trim_prefix("res://")
		var asset: Dictionary = staged_by_source.get(source, {}).duplicate(true)
		if asset.is_empty():
			var relative := path.path_join(name).trim_prefix(root + "/") if not root.is_empty() else source
			asset = {"id": pack.get("id", "unregistered") + "/" + relative, "title": name.get_basename(), "kind": SOURCE_KINDS[extension], "source_file": source, "path": "res://" + source, "pack": pack.get("id", "unregistered"), "relative": relative, "pack_root": root, "tags": pack.get("categories", []), "author": pack.get("author", ""), "license": pack.get("license", ""), "source": pack.get("source", "")}
		asset.staged = staged_by_source.has(source)
		asset.references = references.get(asset.id, [])
		asset.usage = "referenced" if not asset.references.is_empty() else ("portable" if portable.has(asset.id) else "unused")
		if not asset.staged:
			asset.usage = "source"
		asset.search = (asset.id + " " + asset.title + " " + str(asset.tags) + " " + asset.usage).to_lower()
		rows.append(asset)

func report() -> Dictionary:
	var counts := {"referenced": 0, "portable": 0, "unused": 0, "source": 0}
	for asset in rows:
		counts[asset.usage] += 1
	return {"method": "Catalogue/rule references and portable availability; not a trace of spawned encounters. Source-only files retain SOURCE.json provenance where available.", "counts": counts, "assets": rows}
