extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/icon_item_geometry.gd"):
		printerr("FAIL: icon-only world items need actual family-aware 3D geometry")
		quit(1)
		return
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)

func run() -> void:
	var geometry = load("res://scripts/icon_item_geometry.gd").new()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(1, 7):
		image.set_pixel(3, y, Color("c8cbd5") if y < 5 else Color("88603d"))
	image.set_pixel(2, 5, Color("f2c567"))
	image.set_pixel(4, 5, Color("f2c567"))
	var before := image.get_data()
	var bodies := []
	for family in ["block_voxel", "flat_lowpoly"]:
		var mesh: ArrayMesh = geometry.mesh(image, family)
		check(mesh != null, "A sparse actual icon silhouette must become a real mesh")
		if mesh == null:
			continue
		check(mesh.get_aabb().size.x > 0 and mesh.get_aabb().size.y > 0 and mesh.get_aabb().size.z > 0, "Icon derivatives need actual depth")
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		check(vertices.size() > 0 and arrays[Mesh.ARRAY_COLOR] != null, "Icon geometry must preserve source colors")
		var angled := false
		for index in range(0, vertices.size(), 3):
			check(vertices[index].is_finite(), "Icon geometry must remain finite")
			check((vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).dot(normals[index]) < 0, "Icon geometry must have visible Godot winding")
			if maxf(absf(normals[index].x), maxf(absf(normals[index].y), absf(normals[index].z))) < .99:
				angled = true
		check(angled == (family == "flat_lowpoly"), "Faceted icon geometry must differ from actual voxel faces")
		bodies.append(mesh)
	check(bodies.size() == 2 and bodies[0].get_aabb().is_equal_approx(bodies[1].get_aabb()), "Family conversion must retain the same source silhouette bounds")
	check(image.get_data() == before, "Icon extrusion must preserve original image bytes")
	image.fill(Color.TRANSPARENT)
	check(geometry.mesh(image, "block_voxel") == null, "An empty image must not invent an item body")
	var converter = load("res://scripts/animated_model_style.gd").new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.2, .8)
	for family in ["block_voxel", "flat_lowpoly"]:
		var body := MeshInstance3D.new()
		body.mesh = plane
		check(converter.convert(body, family, 12, true), "A planar source needs a finite physical family derivative")
		var box: AABB = body.mesh.get_aabb()
		check(box.size.is_finite() and box.size.x > 0 and box.size.y > 0 and box.size.z > 0, "Thin source conversion must create finite thickness before fitting")
		body.free()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: actual sparse icon colors, transparent silhouette, source bytes, real depth, distinct family geometry and visible winding" if failures.is_empty() else "FAIL: icon item geometry")
	quit(0 if failures.is_empty() else 1)
