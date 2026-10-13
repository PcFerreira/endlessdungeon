extends RefCounted

const PATH := "res://config/player_text.json"
static var data: Dictionary = _read()

static func _read() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(valid(value), "Invalid gameplay display-name catalogue")
	var architecture = JSON.parse_string(FileAccess.get_file_as_string("res://config/town_architecture.json"))
	value.names.architecture = {}
	for id in architecture.templates:
		value.names.architecture[id] = architecture.templates[id].name
	return value

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("names") is Dictionary:
		return false
	for group in ["items", "native", "fallbacks"]:
		if not value.names.get(group) is Dictionary:
			return false
		for id in value.names[group]:
			var text = value.names[group][id]
			if not id is String or id.is_empty() or not text is String or text.strip_edges().is_empty() or text.length() > 80 or text.contains("_") or text.contains("{") or text.contains("}"):
				return false
	return true

static func name_for(group: String, id: String, fallback: String) -> String:
	return data.names.get(group, {}).get(id, fallback)

static func key_for(group: String, id: String) -> String:
	return "gameplay.%s.%s.name" % [group, id]

static func apply_item(id: String, item: Dictionary) -> void:
	item.classification_name = item.get("classification_name", item.get("name", ""))
	var group := "items" if data.names.items.has(id) else "fallbacks"
	var key: String = id if group == "items" else item.get("slot", item.get("kind", "object"))
	if group == "fallbacks" and not data.names.fallbacks.has(key):
		key = "object"
	item.name = name_for(group, key, "Object")
	item.name_key = key_for(group, key)
