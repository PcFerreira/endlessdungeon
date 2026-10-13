@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "WebRawRuntimeFiles"

func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
	if "web" in features and path.begins_with("res://assets/") and path.ends_with(".svg"):
		add_file(path, FileAccess.get_file_as_bytes(path), false)
