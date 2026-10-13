extends RefCounted

const PATH := "res://assets/render_cache/catalog.json"
static var enabled := true
static var baking := false
static var records := {}
static var data: Dictionary = _read()
static var scenes := {}
static var loading := {}
static var failed := {}
const SCENE_LIMIT := 32
const LOAD_LIMIT := 2

static func _read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("version") != 1:
		return {}
	for input in value.get("runtime_inputs", {}):
		if input == "res://config/biome_art.json":
			continue
		if FileAccess.get_sha256(input) != value.runtime_inputs[input]:
			return {}
	return value

static func key(category: String, id: String, family: String) -> String:
	return JSON.stringify([category, id, family]).sha256_text()

static func ready(category: String, id: String, family: String) -> bool:
	var path: String = data.get("scenes", {}).get(key(category, id, family), "")
	if not enabled or path.is_empty() or DisplayServer.get_name() == "headless":
		return true
	poll()
	if scenes.has(path) or failed.has(path):
		return true
	if not loading.has(path) and loading.size() < LOAD_LIMIT:
		if ResourceLoader.load_threaded_request(path, "PackedScene", false) == OK:
			loading[path] = true
	return false

static func poll() -> void:
	for path in loading.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_keep(path, ResourceLoader.load_threaded_get(path))
			loading.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			failed[path] = true
			loading.erase(path)

static func _keep(path: String, packed: PackedScene) -> void:
	scenes.erase(path)
	scenes[path] = packed
	while scenes.size() > SCENE_LIMIT:
		scenes.erase(scenes.keys()[0])

static func scene(category: String, id: String, family: String) -> Node3D:
	var path: String = data.get("scenes", {}).get(key(category, id, family), "")
	if not enabled or path.is_empty() or not ResourceLoader.exists(path):
		return null
	poll()
	if not scenes.has(path):
		_keep(path, ResourceLoader.load_threaded_get(path) if loading.has(path) else load(path))
		loading.erase(path)
	var packed: PackedScene = scenes[path]
	_keep(path, packed)
	return packed.instantiate()

static func remember(category: String, id: String, family: String, node: Node3D) -> void:
	if not baking:
		return
	var hash := key(category, id, family)
	if records.has(hash):
		return
	var copy: Node3D = node.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	copy.scene_file_path = ""
	_owners(copy, copy)
	var packed := PackedScene.new()
	assert(packed.pack(copy) == OK)
	var path := "res://assets/render_cache/%s.scn" % hash
	assert(ResourceSaver.save(packed, path) == OK)
	copy.free()
	records[hash] = path

static func _owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""
		child.owner = root
		_owners(child, root)
