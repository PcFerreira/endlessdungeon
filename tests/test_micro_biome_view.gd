extends SceneTree

var failures := 0
var count := 0

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures += 1
		print("FAIL: ", message)

func geometry(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var actual := transform * node.transform
	var result := {"vertices": [], "colors": [], "normals": []}
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				result.vertices.append(actual * vertex)
			result.colors.append_array(Array(arrays[Mesh.ARRAY_COLOR]))
			result.normals.append_array(Array(arrays[Mesh.ARRAY_NORMAL]))
	for child in node.get_children():
		check(not child is CollisionObject3D and not child is CollisionShape3D, "Cache markers remain nonblocking")
		if child is Node3D:
			var nested := geometry(child, actual)
			for key in result:
				result[key].append_array(nested[key])
	return result

func _init() -> void:
	if not FileAccess.file_exists("res://scripts/micro_biome_view.gd"):
		check(false, "Original micro-biome cache builder is missing")
		quit(1)
		return
	var builder = load("res://scripts/micro_biome_view.gd").new()
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/micro_biomes.json"))
	var snapshots := {}
	var recipes := {}
	var bodies := 0
	for biome in catalogue.profiles:
		for definition in catalogue.profiles[biome]:
			var profile: Dictionary = definition.duplicate(true)
			profile.biome_id = biome
			var original := profile.duplicate(true)
			for family in ["block_voxel", "flat_lowpoly"]:
				var states := {}
				for claimed in [false, true]:
					var body: Node3D = builder.build(profile, family, claimed)
					check(body != null, "Actual recipe cache: " + profile.id)
					if body == null:
						continue
					var data := geometry(body)
					check(data.vertices.size() >= 144, "Original visible body vertices")
					var maximum := Vector3(-INF, -INF, -INF)
					var minimum := Vector3(INF, INF, INF)
					for vertex in data.vertices:
						minimum = minimum.min(vertex)
						maximum = maximum.max(vertex)
					check(minimum.y >= -.00001 and maximum.y <= .55, "Grounded body below .55-cell height")
					check(maxf(absf(minimum.x), absf(maximum.x)) <= .3 and maxf(absf(minimum.z), absf(maximum.z)) <= .3, "Actual vertices fit .6-cell placement")
					check(data.colors.size() == data.vertices.size() and data.colors.any(func(color): return color != Color.WHITE), "Actual biome/recipe vertex palette")
					var beveled: bool = data.normals.any(func(normal): return maxf(absf(normal.x), maxf(absf(normal.y), absf(normal.z))) < .99)
					check(beveled == (family == "flat_lowpoly"), "Actual block/faceted family geometry")
					check(body.get_meta("source_asset") == "native_micro_biome:%s:%s" % [family, profile.recipe] and body.get_meta("representation") == "original_micro_biome_geometry", "Truthful generated source")
					check(body.get_meta("visual_family") == family and body.get_meta("claimed") == claimed, "Marker state metadata")
					states[claimed] = hash(data.vertices)
					var repeat: Node3D = builder.build(profile, family, claimed)
					check(repeat != body and geometry(repeat) == data, "Repeatable independent marker nodes")
					if family == "block_voxel" and not claimed:
						recipes[profile.recipe] = hash(data.vertices)
					snapshots[profile.id + family + str(claimed)] = data
					repeat.free()
					body.free()
					bodies += 1
				check(states.get(false) != states.get(true), "Opened cache changes actual geometry")
			check(profile == original, "Builder does not mutate catalogue/profile")
	check(recipes.values().size() == recipes.values().reduce(func(acc, value): acc[value] = true; return acc, {}).size(), "Each recipe has a distinct actual flourish")
	check(builder.templates.size() <= builder.CACHE_LIMIT and builder.CACHE_LIMIT < 32, "Bounded mesh templates after all112 body combinations")
	check(builder.build({"recipe": "unknown"}, "block_voxel", false) == null, "Reject unknown recipe")
	check(builder.build({"recipe": "fairy_ring"}, "unknown", false) == null, "Reject unknown family")
	var probe: Dictionary = catalogue.profiles.greenwood[0].duplicate(true)
	probe.biome_id = "greenwood"
	var first: Node3D = builder.build(probe, "block_voxel", false)
	probe.biome_id = "volcanic_wastes"
	var second: Node3D = builder.build(probe, "block_voxel", false)
	check(geometry(first).colors != geometry(second).colors, "Actual biome palette changes the same cache recipe")
	first.free()
	second.free()
	print("%s: %s original marker bodies, %s recipes, %s geometry/state/cache checks; %s failures" % ["PASS" if failures == 0 else "REJECT", bodies, recipes.size(), count, failures])
	quit(1 if failures else 0)
