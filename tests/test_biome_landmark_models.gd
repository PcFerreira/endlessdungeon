extends SceneTree

const Catalog = preload("res://scripts/biome_landmark_catalog.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", message)

func inside(mesh: Mesh, point: Vector3) -> bool:
	var direction := Vector3(.812, .217, .541).normalized()
	var hits: Array[Vector3] = []
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index in range(0, vertices.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(point, direction, vertices[index], vertices[index + 1], vertices[index + 2])
			if hit != null:
				hits.append(hit)
	return hits.size() % 2 == 1

func open_basin(mesh: Mesh, point: Vector3) -> bool:
	var origin := Vector3(point.x, 3, point.z)
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index in range(0, vertices.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN, vertices[index], vertices[index + 1], vertices[index + 2])
			if hit != null and hit.y > .78 and hit.y < 3:
				return false
	return true

func _init() -> void:
	if not FileAccess.file_exists("res://scripts/biome_landmark_models.gd"):
		check(false, "Original blueprint-compatible landmark builder is missing")
		quit(1)
		return
	var Models = load("res://scripts/biome_landmark_models.gd")
	var models = Models.new()
	var shapes := {}
	for kind in Catalog.KINDS:
		var profile := Catalog.by_id(kind)
		profile.biome_id = "greenwood"
		var untouched := profile.duplicate(true)
		for family in ["block_voxel", "flat_lowpoly"]:
			var structural := {}
			var states := {}
			for claimed in [false, true]:
				var model: Node3D = models.create(profile, family, claimed)
				check(model != null, "Landmark body: " + kind)
				if model == null:
					continue
				var bounds := Bounds.bounds(model)
				check(bounds.size.x <= 7.0001 and bounds.size.z <= 7.0001 and bounds.size.y <= 8.0001, "Actual landmark volume limit")
				check(absf(bounds.position.y + .25) < .0001 and is_equal_approx(bounds.end.y, profile.body_height), "Ground-aligned foundation and exact structure height")
				var body: MeshInstance3D = model.get_node("Structure")
				var foundation: MeshInstance3D = model.get_node("Foundation")
				check(body.get_meta("obstructing", false) and not foundation.get_meta("obstructing", false), "Only solid structures use avatar cutaway")
				var arrays: Array = body.mesh.surface_get_arrays(0)
				if kind == "well":
					for x in [-.28, .28]:
						for z in [-1.28, -.72]:
							check(open_basin(body.mesh, Vector3(x, .73, z)), "Actual well water basin top is open instead of hidden beneath a broad roof")
				structural[claimed] = hash(arrays)
				check(Array(arrays[Mesh.ARRAY_NORMAL]).any(func(normal): return maxf(absf(normal.x), maxf(absf(normal.y), absf(normal.z))) < .99) == (family == "flat_lowpoly"), "Actual block/faceted geometry")
				var half: Vector2i = profile.size / 2
				for x in range(-half.x, half.x + 1):
					for y in range(-half.y, half.y + 1):
						var cell := Vector2i(x, y)
						check(inside(body.mesh, Vector3(x, .4, y)) == profile.solid_local.has(cell), "Actual lower structural volume matches exact solid mask: %s %s %s" % [kind, family, cell])
				for height in [.4, 1.2, 2.0]:
					check(not inside(body.mesh, Vector3(profile.door_local.x, height, profile.door_local.y)), "Actual visible doorway stays open at actor heights")
				for vertex in arrays[Mesh.ARRAY_VERTEX]:
					if vertex.y > 0 and vertex.y < 2.2:
						var cell := Vector2i(floori(vertex.x + .5), floori(vertex.z + .5))
						check(profile.solid_local.has(cell), "Lower structural vertices never occupy undeclared open floor: " + kind)
				var glowing := 0
				var signatures: Array = []
				for part in model.find_children("*", "MeshInstance3D", true, false):
					check(not part is CollisionObject3D, "Geometry builder adds no separate physical authority")
					check(part.get_meta("source_asset") == model.get_meta("source_asset") and part.get_meta("visual_family") == family, "Truthful part source/family")
					var material: StandardMaterial3D = part.get_active_material(0)
					if material.emission_enabled:
						glowing += 1
						check((part.transform * part.mesh.get_aabb()).position.y >= 2.2 if kind == "mage_tower" else true, "Mage glyph glow remains above player clearance")
						signatures.append(material.emission)
					else:
						signatures.append(part.mesh.surface_get_arrays(0))
				check(glowing >= 2 if kind == "mage_tower" else true, "Mage tower has actual emissive upper windows")
				states[claimed] = hash(signatures)
				check(model.get_meta("original_landmark_geometry", false) and model.get_meta("kind") == kind, "Original landmark identity")
				for turn in range(4):
					var rotated: Vector3 = Basis(Vector3.UP, turn * PI / 2) * Vector3(profile.door_local.x, 0, profile.door_local.y)
					var expected: Vector2i = Catalog.rotate(profile.door_local, turn)
					check(Vector2(rotated.x, rotated.z).distance_to(Vector2(expected)) < .0001, "Actual quarterturn agrees with physical doorway blueprint")
				shapes[kind + family] = structural[claimed]
				model.free()
			check(structural.get(false) == structural.get(true), "Claimed state preserves actual structural walls/door/floor")
			if kind in Catalog.CACHE_KINDS or kind in ["monolith", "shrine", "ruined_arch"]:
				check(states.get(false) != states.get(true), "Actual open cache/activated rune changes visible body")
		check(profile == untouched, "Builder never mutates shared blueprint")
		var bad := profile.duplicate(true)
		bad.door_local = Vector2i.ZERO
		check(models.create(bad, "block_voxel") == null, "Reject renderer blueprint drift")
	for family in ["block_voxel", "flat_lowpoly"]:
		var signatures := {}
		for kind in Catalog.KINDS:
			signatures[shapes.get(kind + family)] = true
		check(signatures.size() == 8, "Eight actual distinct structural silhouettes")
	var retained_profile := Catalog.by_id("monolith")
	retained_profile.biome_id = "greenwood"
	var retained: Node3D = models.create(retained_profile, "block_voxel")
	var retained_arrays: Array = retained.get_node("Structure").mesh.surface_get_arrays(0)
	for biome in ["desert", "frostlands", "haunted_hollows"]:
		for kind in Catalog.KINDS:
			var profile := Catalog.by_id(kind)
			profile.biome_id = biome
			for family in ["block_voxel", "flat_lowpoly"]:
				for claimed in [false, true]:
					var body: Node3D = models.create(profile, family, claimed)
					check(body != null, "Additional actual palette/state body")
					body.free()
	check(retained.get_node("Structure").mesh.surface_get_arrays(0) == retained_arrays, "Live body resources survive bounded template eviction")
	retained.free()
	check(models.templates.size() <= Models.CACHE_LIMIT and Models.CACHE_LIMIT <= 32, "Bounded original template references")
	print("%s: %s actual landmark mask/door/body/family/state checks; %s failures" % ["PASS" if failures == 0 else "REJECT", checks, failures])
	quit(1 if failures else 0)
