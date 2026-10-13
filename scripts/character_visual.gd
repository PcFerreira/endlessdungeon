extends Node3D

const Player = preload("res://scripts/player_voxels.gd")
var body: Node3D
var imported := false
var rigged := true
var motion := ""
var animations: Array[AnimationPlayer] = []

func configure(class_id: String, profile) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	animations.clear()
	motion = ""
	body = Player.create(class_id, profile)
	add_child(body)
	animations.append(body.get_node("AnimationPlayer"))
	animate(false, true)
	if is_inside_tree():
		animations[0].advance(0)

func animate(moving: bool, grounded: bool) -> void:
	var desired := "Jump_Idle" if not grounded else ("Walk" if moving else "Idle")
	if desired == motion:
		return
	motion = desired
	for animation in animations:
		animation.play(desired, .12)

func attack() -> void:
	for animation in animations:
		animation.play("Attack", .06)
	motion = ""

static func animation_key(player: AnimationPlayer, desired: String) -> String:
	return desired if player.has_animation(desired) else ""

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
