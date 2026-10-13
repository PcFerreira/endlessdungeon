extends SceneTree

const Cache = preload("res://scripts/render_cache.gd")
const Creatures = preload("res://scripts/creature_models.gd")
const Items = preload("res://scripts/item_models.gd")

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	assert(Cache.data.get("scenes", {}).size() >= 302)
	var creatures := Creatures.new()
	var count := 0
	for id in creatures.styles.creature_sources:
		for biome in [0, 2]:
			Cache.enabled = true
			var cached := creatures.instantiate(id, biome)
			Cache.enabled = false
			var original := creatures.instantiate(id, biome)
			compare(cached, original)
			cached.free()
			original.free()
			count += 1
		await process_frame
	var items := Items.new()
	var art = JSON.parse_string(FileAccess.get_file_as_string("res://config/biome_art.json"))
	var sources := {}
	for role in art.roles.values():
		for group in role.get("sources", {}).values():
			for source in group:
				sources[source] = true
	for source in sources:
		for family in ["block_voxel", "flat_lowpoly"]:
			Cache.enabled = true
			var cached := items.source_model(source, family)
			Cache.enabled = false
			var original := items.source_model(source, family)
			compare(cached, original)
			cached.free()
			original.free()
			count += 1
	Cache.enabled = true
	print("PASS: %s baked bodies exactly preserve original geometry, bounds, skins, animation tracks and source metadata" % count)
	quit()

func compare(cached: Node3D, original: Node3D) -> void:
	assert(cached != null and original != null)
	for field in ["source_asset", "render_asset", "visual_family", "representation"]:
		assert(cached.get_meta(field) == original.get_meta(field))
	var a := cached.find_children("*", "MeshInstance3D", true, false)
	var b := original.find_children("*", "MeshInstance3D", true, false)
	assert(a.size() == b.size())
	for index in range(a.size()):
		assert(a[index].transform.is_equal_approx(b[index].transform))
		assert(a[index].mesh.get_surface_count() == b[index].mesh.get_surface_count())
		assert((a[index].skin == null) == (b[index].skin == null))
		if a[index].skin != null:
			assert(a[index].skin.get_bind_count() == b[index].skin.get_bind_count())
			for bind in range(a[index].skin.get_bind_count()):
				assert(a[index].skin.get_bind_bone(bind) == b[index].skin.get_bind_bone(bind))
				assert(a[index].skin.get_bind_name(bind) == b[index].skin.get_bind_name(bind))
				assert(a[index].skin.get_bind_pose(bind).is_equal_approx(b[index].skin.get_bind_pose(bind)))
		for surface in range(a[index].mesh.get_surface_count()):
			assert(a[index].mesh.surface_get_arrays(surface) == b[index].mesh.surface_get_arrays(surface))
	var ap := cached.find_children("*", "AnimationPlayer", true, false)
	var bp := original.find_children("*", "AnimationPlayer", true, false)
	assert(ap.size() == bp.size())
	for index in range(ap.size()):
		assert(ap[index].get_animation_list() == bp[index].get_animation_list())
		for name in ap[index].get_animation_list():
			var aa: Animation = ap[index].get_animation(name)
			var bb: Animation = bp[index].get_animation(name)
			assert(aa.get_track_count() == bb.get_track_count())
			assert(aa.length == bb.length and aa.loop_mode == bb.loop_mode)
			for track in range(aa.get_track_count()):
				assert(aa.track_get_path(track) == bb.track_get_path(track))
				assert(aa.track_get_type(track) == bb.track_get_type(track))
				assert(aa.track_get_key_count(track) == bb.track_get_key_count(track))
				for key in range(aa.track_get_key_count(track)):
					assert(aa.track_get_key_time(track, key) == bb.track_get_key_time(track, key))
					assert(aa.track_get_key_value(track, key) == bb.track_get_key_value(track, key))
