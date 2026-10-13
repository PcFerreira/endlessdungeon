extends RefCounted

const PATH := "res://assets/landmark_cache/catalog.json"
static var enabled := true
static var data: Dictionary = _read()
static var scenes := {}

static func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not value is Dictionary or value.get("version") != 1:
		return {}
	for path in value.runtime_inputs:
		if FileAccess.get_sha256(path) != value.runtime_inputs[path]:
			return {}
	return value

static func key(part: Dictionary, family: String) -> String:
	return JSON.stringify([part.template, float(part.size[0]), float(part.size[1]), float(part.height), bool(part.get("solid", true)), family]).sha256_text()

static func scene(part: Dictionary, family: String) -> Node3D:
	if not enabled or not part.has("template"):
		return null
	var path: String = data.get("scenes", {}).get(key(part, family), "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not scenes.has(path):
		if scenes.size() >= 32:
			scenes.erase(scenes.keys()[0])
		scenes[path] = load(path)
	return scenes[path].instantiate()
