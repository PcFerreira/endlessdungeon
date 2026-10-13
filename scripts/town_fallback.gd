extends RefCounted

const Models = preload("res://scripts/world_voxels.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const ROLES := ["house", "civic_tower", "market_lot", "farm_lot"]

static func model(role: String, family: String, data: Dictionary, biome: int = 0) -> MeshInstance3D:
	assert(role in ROLES)
	var mesh: ArrayMesh
	match role:
		"house": mesh = Models.house(data, biome, family)
		"civic_tower": mesh = Models.tower(int(data.style), family)
		"market_lot", "farm_lot": mesh = Models.outdoor_lot(data, family)
	var body := Voxels.instance(mesh)
	var id := "native_town:%s:%s" % [family, role]
	body.set_meta("asset_id", id)
	body.set_meta("render_asset", id)
	body.set_meta("visual_family", family)
	body.set_meta("fallback_role", role)
	body.set_meta("render_height", mesh.get_aabb().end.y)
	body.set_meta("source_uid", data.get("id", ""))
	return body
