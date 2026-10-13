extends RefCounted

const CATALOG_PATH := "res://assets/imported/catalog.json"
const RESOURCE_EXTENSIONS := ["gltf", "glb", "obj", "png", "svg", "jpg", "jpeg", "ogg", "wav", "mp3"]
var error := ""
var _assets: Dictionary = {}
var _aliases: Dictionary = {}
var _resources: Dictionary = {}
var _colored_materials: Dictionary = {}

func _init(path: String = CATALOG_PATH) -> void:
	reload(path)

func reload(path: String = CATALOG_PATH) -> bool:
	if not FileAccess.file_exists(path):
		error = "Missing asset catalog: " + path
		return false
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not document is Dictionary or document.get("version") != 1 or not document.get("assets") is Array:
		error = "Invalid asset catalog: " + path
		return false
	var assets: Dictionary = {}
	var aliases: Dictionary = {}
	for entry in document.assets:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("kind") is String or not entry.get("tags") is Array or not entry.get("aliases") is Array:
			error = "Invalid asset record in " + path
			return false
		if assets.has(entry.id) or aliases.has(entry.id):
			error = "Duplicate asset ID: " + entry.id
			return false
		if entry.kind != "text":
			var resource_path: String = entry.get("path", "")
			if not resource_path.begins_with("res://assets/imported/packs/") or ".." in resource_path.split("/") or resource_path.get_extension().to_lower() not in RESOURCE_EXTENSIONS:
				error = "Invalid asset resource path: " + resource_path
				return false
		elif not entry.get("text") is String:
			error = "Missing text for " + entry.id
			return false
		assets[entry.id] = entry.duplicate(true)
		for alias in entry.aliases:
			if not alias is String or alias.is_empty() or assets.has(alias) or aliases.has(alias):
				error = "Duplicate or invalid asset alias"
				return false
			aliases[alias] = entry.id
	_assets = assets
	_aliases = aliases
	_resources.clear()
	_colored_materials.clear()
	error = ""
	return true

func get_asset(id: String) -> Dictionary:
	var key: String = _aliases.get(id, id)
	return _assets.get(key, {}).duplicate(true)

func find(kind: String = "", tags: Array = [], pack: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = _assets.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary = _assets[id]
		if not kind.is_empty() and entry.kind != kind:
			continue
		if not pack.is_empty() and entry.get("pack", "") != pack:
			continue
		var matches := true
		for tag in tags:
			if tag not in entry.tags:
				matches = false
				break
		if matches:
			result.append(entry.duplicate(true))
	return result

func resource(id: String) -> Resource:
	var entry := get_asset(id)
	if entry.is_empty() or entry.kind == "text":
		return null
	var key: String = entry.id
	if not _resources.has(key):
		if not ResourceLoader.exists(entry.path):
			error = "Asset has not been imported by Godot: " + entry.path
			return null
		var loaded: Resource = load(entry.path)
		if loaded == null:
			error = "Cannot load asset: " + entry.path
			return null
		_resources[key] = loaded
	return _resources[key]

func instantiate(id: String) -> Node3D:
	var entry := get_asset(id)
	if entry.is_empty() or entry.kind != "model":
		return null
	var loaded := resource(id)
	var result := Node3D.new()
	if loaded is PackedScene:
		var model: Node = loaded.instantiate()
		if not model is Node3D:
			model.free()
			result.free()
			error = "Model scene has no 3D root: " + id
			return null
		result.add_child(model)
	elif loaded is Mesh:
		var mesh := MeshInstance3D.new()
		mesh.mesh = loaded
		result.add_child(mesh)
	else:
		result.free()
		return null
	result.scale = Vector3.ONE * float(entry.get("scale", 1.0))
	var rotation: Array = entry.get("rotation_degrees", [0, 0, 0])
	var offset: Array = entry.get("offset", [0, 0, 0])
	result.rotation_degrees = Vector3(rotation[0], rotation[1], rotation[2])
	result.position = Vector3(offset[0], offset[1], offset[2])
	result.set_meta("asset_id", entry.id)
	_vertex_colors(result)
	return result

func _vertex_colors(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var colored_surface: bool = (node.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0
			var material = node.get_active_material(surface)
			if colored_surface and material is StandardMaterial3D and not material.vertex_color_use_as_albedo:
				var key: int = material.get_instance_id()
				if not _colored_materials.has(key):
					var colored: StandardMaterial3D = material.duplicate()
					colored.vertex_color_use_as_albedo = true
					_colored_materials[key] = colored
				node.set_surface_override_material(surface, _colored_materials[key])
	for child in node.get_children():
		_vertex_colors(child)

func text(id: String) -> String:
	var entry := get_asset(id)
	return entry.get("text", "") if entry.get("kind") == "text" else ""

func books() -> Dictionary:
	var result: Dictionary = {}
	for entry in find("text", ["book"]):
		result[entry.id] = entry
	return result

func dialogue_lines() -> Array[Dictionary]:
	return find("text", ["dialogue"])
