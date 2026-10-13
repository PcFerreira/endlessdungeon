extends SceneTree

func _initialize() -> void:
	root.add_child.call_deferred(preload("res://tests/release_runtime_probe.gd").new())
