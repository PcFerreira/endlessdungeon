extends SceneTree

const Dungeon = preload("res://scripts/dungeon.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const View = preload("res://scripts/dungeon_view.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Surfaces = preload("res://scripts/dungeon_surfaces.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sample := Dungeon.new()
	if sample.get("biome") == null:
		printerr("FAIL: dungeon generation must receive its actual owning entrance biome")
		quit(1)
		return
	var styles := Styles.new()
	var scenery := Scenery.new()
	var count := 0
	for family in Areas.DUNGEONS:
		for seed_value in [0, 12345]:
			for depth in [1, 8, 20]:
				var baseline := Dungeon.new()
				baseline.generate(seed_value, depth, family, 0)
				for biome in range(4):
					var dungeon := Dungeon.new()
					dungeon.generate(seed_value, depth, family, biome)
					count += 1
					check(dungeon.biome == biome, "Dungeon context must retain the actual entrance climate")
					check(dungeon.tiles == baseline.tiles and dungeon.rooms == baseline.rooms and dungeon.spawns == baseline.spawns and dungeon.obstacles == baseline.obstacles, "Style adaptation must preserve layout, collision, combat spawns and generation RNG")
					var replay := Dungeon.new()
					replay.generate(seed_value, depth, family, biome)
					check(dungeon.decorations == replay.decorations, "Biome-bound room ensembles must replay")
					for index in range(dungeon.rooms.size()):
						check(dungeon.decorations.filter(func(prop): return prop.room_index == index).size() >= ceili(dungeon.rooms[index].get_area() / 7.0), "Style selection must retain purposeful room-size density")
					for prop in dungeon.decorations:
						check(styles.allows(prop.model_id, biome) and prop.visual_family == styles.family_for(biome), "Every room fixture must belong to the owning biome family")
						check(not Items.for_asset(prop.model_id).is_empty(), "Family-adapted fixtures must retain real portable identity")
						for part in prop.contents:
							check(styles.allows(part.model_id, biome) and part.visual_family == prop.visual_family, "Supported supplies must share their fixture's biome family")
					if seed_value == 12345 and depth == 1:
						var view := View.new()
						view.build(dungeon, depth, true)
						check(view.biome == biome and view.palette == Areas.DUNGEONS[family].palette, "Owning biome and dungeon stone palette must remain distinct")
						for root in view.cell_nodes.values():
							for child in root.get_children():
								if child is MeshInstance3D or (child is Node3D and child.has_meta("asset_id")):
									check(styles.allows(child.get_meta("asset_id", ""), biome), "Actual rendered surfaces, walls, readables, torches and supplies must be classified for the owning biome")
						for entry in view.dressing_nodes.values():
							check(entry.record.visual_family == styles.family_for(biome) and styles.allows(entry.record.model_id, biome), "Portable dungeon descriptors must retain actual rendered model/family identity")
							var box := scenery.bounds(entry.node)
							check(is_equal_approx(box.size.x, entry.record.footprint.x) and is_equal_approx(box.size.z, entry.record.footprint.y), "Family-adapted fixture geometry must remain within its physical footprint")
						var closed := view.chest.mesh.get_aabb()
						view.open_chest()
						check(styles.allows(view.chest.get_meta("asset_id"), biome) and view.chest.mesh.get_aabb().end.y > closed.end.y, "Opening a chest must retain biome style and show its real raised lid")
						view.update_camera(PI * 1.25)
						for wall in view.wall_nodes:
							check(styles.allows(wall.node.get_meta("asset_id"), biome), "Camera wall cutaways must retain actual surface style")
						for child in view.get_children():
							if child.has_meta("asset_id"):
								check(styles.allows(child.get_meta("asset_id"), biome), "Required stairs must retain their actual biome family")
						for child in view.portal.get_children():
							if child.has_meta("asset_id"):
								check(styles.allows(child.get_meta("asset_id"), biome), "Reward chests and gate motes must retain their actual biome family")
						view.free()
	for visual_family in styles.data.families:
		for role in Surfaces.ROLES:
			var id: String = Surfaces.id(visual_family, role)
			check(styles.family_of(id) == visual_family, "Native dungeon structure identities must classify explicitly")
			var mesh := Surfaces.mesh(role, visual_family, 1)
			check(mesh.get_surface_count() > 0 and mesh.get_aabb().size.length() > 0, "Native dungeon structures must contain actual visible meshes")
			for surface in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				for index in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
					var a: int = indices[index] if not indices.is_empty() else index
					var b: int = indices[index + 1] if not indices.is_empty() else index + 1
					var c: int = indices[index + 2] if not indices.is_empty() else index + 2
					check((vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a]) < 0, "Native structural faces must use Godot's visible clockwise winding")
	check(styles.family_of("native_dungeon:block_voxel:unknown").is_empty(), "Unknown native dungeon structures must remain unclassified")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: %s biome-bound dungeon floors; all fixtures/supplies, actual rendered structures/readables/torches/chests, preserved density/layout/RNG/portable geometry and camera cutaways" % count if failures.is_empty() else "FAIL: dungeon styles")
	quit(0 if failures.is_empty() else 1)
