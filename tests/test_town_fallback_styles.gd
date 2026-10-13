extends SceneTree

const World = preload("res://scripts/world.gd")
const View = preload("res://scripts/world_view.gd")
const Architecture = preload("res://scripts/town_architecture.gd")
const Bounds = preload("res://scripts/decor_geometry.gd")
const Models = preload("res://scripts/world_voxels.gd")

class MissingArchitecture extends Architecture:
	func build(_house: Dictionary, _city: Dictionary) -> Node3D:
		return null
	func civic(_city: Dictionary) -> Node3D:
		return null

class MissingView extends View:
	func _constructed(parent: Node3D, anchor: String, context: Dictionary, salt: int, point: Vector3) -> Node3D:
		return null if anchor.begins_with("lot_") else super._constructed(parent, anchor, context, salt, point)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	world.generate(12345)
	var original: Dictionary = world.region_at(world.start).city.duplicate(true)
	for shape in ["gable", "hip", "flat"]:
		var house: Dictionary = original.houses[0].duplicate(true)
		house.architecture.roof_shape = shape
		var mesh := Models.house(house, 2, "flat_lowpoly")
		var sloped := false
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in range(0, vertices.size(), 3):
				assert((vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).dot(normals[index]) < 0, "Fallback faces must preserve visible Godot winding")
				if normals[index].y > .01 and normals[index].y < .99:
					sloped = true
		assert(sloped == (shape != "flat"), "Faceted gable/hip roofs require real pitched surfaces")
		assert(mesh.get_aabb().is_equal_approx(Models.house(house, 2).get_aabb()))
	for biome in range(4):
		var city: Dictionary = original.duplicate(true)
		city.biome = biome
		for resident in city.residents:
			resident.biome = biome
		var plan: Dictionary = city.duplicate(true)
		var view := MissingView.new()
		view.architecture = MissingArchitecture.new()
		var root := Node3D.new()
		view._build_city(root, city)
		var styles = view.construction.catalog.styles
		var count := 0
		for part in root.get_children():
			if not part.has_meta("fallback_role"):
				continue
			if not styles.allows(part.get_meta("render_asset", ""), biome):
				printerr("FAIL: missing-source town forms require actual owning-family geometry")
				root.free()
				view.free()
				quit(1)
				return
			assert(is_equal_approx(part.get_meta("render_height"), Bounds.bounds(part).end.y))
			var angled := false
			var arrays: Array = part.mesh.surface_get_arrays(0)
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				if maxf(absf(normal.x), maxf(absf(normal.y), absf(normal.z))) < .99:
					angled = true
			assert(angled == (styles.family_for(biome) == "flat_lowpoly"), "Fallback family must be actual geometry, not just metadata")
			var original_mesh: ArrayMesh
			var role: String = part.get_meta("fallback_role")
			if role == "house":
				var house: Dictionary = city.houses.filter(func(entry): return entry.id == part.get_meta("source_uid"))[0]
				original_mesh = Models.house(house, biome)
			elif role == "civic_tower":
				original_mesh = Models.tower(city.style)
			else:
				var lot: Dictionary = city.outdoor_lots.filter(func(entry): return entry.id == part.get_meta("source_uid"))[0]
				original_mesh = Models.outdoor_lot(lot)
			assert(part.mesh.get_aabb().is_equal_approx(original_mesh.get_aabb()), "Fallback bounds must preserve the existing source recipe")
			count += 1
		assert(count == city.houses.size() + city.outdoor_lots.size() + 1)
		assert(city == plan)
		root.free()
		view.free()
	print("PASS: actual forced missing house/civic/lot resources in four climates, truthful family identities, measured bounds and unchanged city plans")
	quit()
