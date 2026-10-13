extends RefCounted

const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const ROLES := ["house_trim", "civic_core", "roof_charm", "street_rune", "npc_kit", "npc_charm", "episode_rug", "trade_sign"]

static func node(boxes: Array, family: String, role: String, glow: bool = false) -> MeshInstance3D:
	assert(role in ROLES and not boxes.is_empty())
	var result := Voxels.instance(Surfaces.mesh_boxes(boxes, family))
	result.set_meta("asset_id", "native_decor:%s:%s" % [family, role])
	result.set_meta("visual_family", family)
	result.set_meta("native_role", role)
	if glow:
		result.material_override = Voxels.glow(boxes[0][2])
	return result

static func bounds(node: Node3D) -> AABB:
	var result: AABB = node.mesh.get_aabb() if node is MeshInstance3D and node.mesh != null else AABB()
	for child in node.get_children():
		if child is Node3D:
			var box: AABB = child.transform * bounds(child)
			if box.size != Vector3.ZERO:
				result = box if result.size == Vector3.ZERO else result.merge(box)
	return result
