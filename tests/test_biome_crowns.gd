extends SceneTree

const Models = preload("res://scripts/biome_models.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)

func geometry(node: Node3D, placement: Transform3D = Transform3D.IDENTITY) -> Array:
	var result: Array = []
	var actual := placement * node.transform
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				result.append([actual * vertex, node.get_meta("biome_part", ""), node.mesh is CylinderMesh])
	for child in node.get_children():
		if child is Node3D:
			result.append_array(geometry(child, actual))
	return result

func _init() -> void:
	var models := Models.new()
	check(models.error.is_empty(), models.error)
	var identities := {}
	for role in ["dense_crown", "jungle_crown"]:
		check(models.supports(role), "Missing original broad canopy role: " + role)
		if not models.supports(role):
			continue
		var profile: Dictionary = models.data.roles[role]
		check(profile.get("native", false), "Crowns must be original geometry rather than stretched imported trees")
		for field in ["clearance", "trunk_width", "height", "width"]:
			var malformed: Dictionary = models.data.duplicate(true)
			malformed.roles[role][field] = 1.0 if field in ["height", "width"] else 0.0
			check(not Models.valid(malformed), "Reject unsafe crown contract: " + field)
		for biome in range(4):
			var family: String = models.items.styles.family_for(biome)
			var variants := {}
			for seed_value in range(3):
				var model: Node3D = models.create(role, biome, seed_value)
				check(model != null, "Crown construction: " + models.error)
				if model == null:
					continue
				var vertices := geometry(model)
				var overhang_min := INF
				var trunk_width := 0.0
				var crown_width := 0.0
				var crown_layers := {}
				var faceted := false
				var body_signature: Array = []
				for record in vertices:
					var vertex: Vector3 = record[0]
					body_signature.append(vertex)
					if maxf(absf(vertex.x), absf(vertex.z)) > .475 + .0001:
						overhang_min = minf(overhang_min, vertex.y)
					if record[1] == "trunk":
						trunk_width = maxf(trunk_width, 2 * maxf(absf(vertex.x), absf(vertex.z)))
					if record[1] == "crown":
						crown_width = maxf(crown_width, 2 * maxf(absf(vertex.x), absf(vertex.z)))
						crown_layers[snappedf(vertex.y, .05)] = true
					faceted = faceted or record[2]
				check(vertices.size() > 150, "Crown must have actual layered mesh vertices")
				check(overhang_min >= 2.6 - .0001 and is_finite(overhang_min), "All actual overhanging vertices must clear 2.6 cells: " + str(overhang_min))
				check(trunk_width > .15 and trunk_width <= .95, "Actual grounded trunk footprint")
				check(trunk_width <= profile.trunk_width, "Actual trunk must fit declared occupied width")
				check(crown_width >= 2.5 and crown_width > trunk_width * 4, "Actual broad canopy silhouette")
				check(crown_layers.size() >= 6, "Canopy needs several actual vertical foliage layers")
				check(faceted == (family == "flat_lowpoly"), "Actual meshes must express the selected family")
				var box := Bounds.bounds(model)
				check(absf(box.position.y) < .0001 and is_equal_approx(box.size.y, profile.height), "Grounded crown height")
				check(model.get_meta("source_asset") == "biome_geometry:%s:%s" % [family,role] and model.get_meta("representation") == "native_biome", "Truthful original source boundary")
				check(models.items.styles.family_of(model.get_meta("render_asset")) == family, "Registered crown style identity")
				var signature := hash(body_signature)
				variants[signature] = true
				identities[role + family] = signature
				var repeat: Node3D = models.create(role, biome, seed_value)
				check(geometry(repeat) == vertices, "Repeatable actual geometry")
				repeat.free()
				model.free()
			check(variants.size() == 3, "Three genuinely different crown geometries")
	for family in ["block_voxel", "flat_lowpoly"]:
		if identities.has("dense_crown" + family) and identities.has("jungle_crown" + family):
			check(identities["dense_crown" + family] != identities["jungle_crown" + family], "Dense and jungle actual crown silhouettes differ")
	check(models.templates.size() <= Models.CACHE_LIMIT, "Bounded template cache")
	print("%s: %s transformed-vertex crown checks; %s failures" % ["PASS" if failures == 0 else "REJECT",checks,failures])
	quit(1 if failures else 0)
