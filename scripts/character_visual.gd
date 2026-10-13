extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const Registry = preload("res://scripts/asset_registry.gd")
static var registry := Registry.new()
var body: Node3D
var imported := false
var motion := ""
var animations: Array[AnimationPlayer] = []

func configure(class_id: String, profile) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	animations.clear()
	motion = ""
	imported = profile.model != "custom"
	if not imported:
		body = Voxels.instance(Voxels.character(class_id, profile))
		add_child(body)
		return
	body = Node3D.new()
	add_child(body)
	var source: Node3D = registry.instantiate(profile.model)
	body.add_child(source)
	for animation in source.find_children("*", "AnimationPlayer", true, false):
		animations.append(animation)
		for key in ["Idle", "Walk", "Jump_Idle"]:
			var clip := animation_key(animation, key)
			if not clip.is_empty():
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if animation.has_animation("Idle"):
			animation.play("Idle")
			animation.advance(0)
	var bounds := _bounds(body, Transform3D.IDENTITY)
	var scale_factor := 1.1 / bounds.size.y
	body.scale = Vector3.ONE * scale_factor
	body.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_factor
	animate(false, true)

func animate(moving: bool, grounded: bool) -> void:
	var desired := "Jump_Idle" if not grounded else ("Walk" if moving else "Idle")
	if desired == motion:
		return
	motion = desired
	for animation in animations:
		var key := animation_key(animation, desired)
		if not key.is_empty():
			animation.play(key, .12)

static func animation_key(player: AnimationPlayer, desired: String) -> String:
	for candidate in (["Walk", "Walking_A", "Walking_B"] if desired == "Walk" else [desired]):
		if player.has_animation(candidate):
			return candidate
	return ""

func visual_bounds() -> AABB:
	return _bounds(body, Transform3D.IDENTITY)

static func _bounds(node: Node3D, parent: Transform3D) -> AABB:
	var transform := parent * node.transform
	var result := AABB()
	if node is MeshInstance3D:
		result = transform * node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var box := _bounds(child, transform)
			if box.size != Vector3.ZERO:
				result = box if result.size == Vector3.ZERO else result.merge(box)
	return result
