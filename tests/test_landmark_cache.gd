extends SceneTree

const Cache = preload("res://scripts/landmark_cache.gd")
const Architecture = preload("res://scripts/town_architecture.gd")
const Locations = preload("res://scripts/surface_locations.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(Cache.data.get("scenes", {}).size() >= 6, "All fixed landmark template sizes need baked geometry")
	var architecture := Architecture.new()
	var checked := {}
	for definition in Locations.DATA.locations.values():
		for part in definition.structures:
			if not part.has("template"):
				continue
			for family in ["block_voxel", "flat_lowpoly"]:
				var key := Cache.key(part, family)
				if checked.has(key):
					continue
				var cached := Cache.scene(part, family)
				var recipe: Dictionary = architecture.catalog.data.templates[part.template].duplicate(true)
				recipe.id = part.template
				recipe.theme = "generic"
				var footprint := Vector2(part.size[0], part.size[1]) - (Vector2.ONE * .10 if part.get("solid", true) else Vector2.ZERO)
				var original := architecture.build_template(recipe, footprint, part.height, family)
				assert(cached != null and not cached.has_meta("site_id"))
				assert(cached.get_meta_list().size() == original.get_meta_list().size())
				for field in original.get_meta_list():
					assert(cached.get_meta(field) == original.get_meta(field))
				var a := cached.find_children("*", "MeshInstance3D", true, false)
				var b := original.find_children("*", "MeshInstance3D", true, false)
				assert(a.size() == b.size())
				for index in range(a.size()):
					assert(a[index].transform.is_equal_approx(b[index].transform))
					assert(a[index].mesh.get_surface_count() == b[index].mesh.get_surface_count())
					for surface in range(a[index].mesh.get_surface_count()):
						assert(a[index].mesh.surface_get_arrays(surface) == b[index].mesh.surface_get_arrays(surface))
				cached.free()
				original.free()
				checked[key] = true
	print("PASS: six cached landmark bodies exactly preserve source geometry, transforms and provenance; no site identities are baked")
	quit()
