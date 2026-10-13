extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Generator = preload("res://scripts/voxel_character_generator.gd")
const Wonder = preload("res://scripts/wonder_models.gd")
static var registry := Registry.new()

static func style_for(index: int, context: Dictionary = {}) -> Dictionary:
	return Generator.appearance(index, context)

static func create(index: int, context: Dictionary = {}) -> Node3D:
	if not context.get("wonder_id","").is_empty():
		return Wonder.create(context.wonder_id,context.get("visual_family","block_voxel"),index)
	var style := style_for(index, context)
	var result := Node3D.new()
	result.add_child(Generator.create(style))
	result.set_meta("style", style)
	result.set_meta("representation", "generated_voxel")
	result.set_meta("visual_family", "block_voxel")
	return result

static func animation_key(player: AnimationPlayer, desired: String) -> String:
	return desired if player.has_animation(desired) else ""

static func greet(actor: Node3D) -> void:
	for player in actor.find_children("*", "AnimationPlayer", true, false):
		if player.has_animation("Wave"):
			player.play("Wave", .12)

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
