extends SceneTree

const Game = preload("res://scripts/game.gd")
const Catalog = preload("res://scripts/dimension_catalog.gd")
var directory := "user://test-dimension-revision-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("checks")

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func equivalent(left, right) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return float(left) == float(right)
	if left is Dictionary and right is Dictionary:
		return left.size() == right.size() and left.keys().all(func(key): return right.has(key) and equivalent(left[key], right[key]))
	if left is Array and right is Array:
		return left.size() == right.size() and range(left.size()).all(func(index): return equivalent(left[index], right[index]))
	return left == right

func old_water_point(world) -> Vector2:
	for x in range(64, 1984, 32):
		for z in range(64, 1984, 32):
			var point := Vector2i(x, z)
			var former_land: bool = world.definition.areas.any(func(area): return Catalog.box(area.bounds).has_point(point))
			var info: Dictionary = world.cell_info(point)
			if former_land and info.terrain == "water" and not info.walkable:
				return Vector2(point)
	return Vector2.INF

func organic_title_point(world) -> Vector2:
	for x in range(128, 1920, 64):
		for z in range(128, 1920, 64):
			var cell := Vector2i(x, z)
			var actual: Dictionary = world.area_at(cell)
			if actual.is_empty():
				continue
			for area in world.definition.areas:
				if Catalog.box(area.bounds).has_point(cell) and area.id != actual.id:
					return Vector2(cell)
	return Vector2.INF

func checks() -> void:
	var definition := Catalog.definition()
	assert(definition.map_version == 2 and definition.get("compatible_revisions", []).any(func(revision): return revision == 1), "The released terrain must explicitly declare revision1 compatibility")
	var game = fresh()
	game.start_run(12345)
	game._clear_actors()
	assert(game.inventory.add("gold_coin", 17))
	game.hp = 43
	assert(game.use_sanctum_sigil())
	game.player_point = game.floating_hub.sanctum_portal_point()
	game._snap_camera()
	assert(game.floating_hub.from_sanctum())
	game.player_point = game.floating_hub.portal_point("dimension")
	game._snap_camera()
	assert(game.dimension.enter())
	var previous: Dictionary = game.make_save_data()
	var point := old_water_point(game.world)
	assert(is_finite(point.x) and is_finite(point.y), "The organic map fixture requires a former land point now covered by water")
	previous.progress.dimension.map_revision = 1
	previous.progress.dimension.last_point = [point.x, point.y]
	previous.location.point = [point.x, point.y]
	assert(game.saves.write(1, previous), "An explicitly compatible realm save must pass normal disk validation")
	var restored = fresh()
	assert(restored.load_game(1) and restored.dimension.active)
	assert(restored.world.map_version == 2 and restored.dimension.map_revision == 2)
	assert(not restored.player_point.is_equal_approx(point) and restored.world.walkable(restored.player_point), "Former land under new water must relocate onto supported terrain")
	var migrated: Dictionary = restored.make_save_data()
	for key in ["seed", "generator_version", "rng_state", "build", "character", "inventory"]:
		assert(equivalent(previous[key], migrated[key]), "Migration must preserve " + key)
	for key in ["encounters", "floors", "claimed", "cities", "discovery", "lore", "life", "furnishings", "world_items", "stores"]:
		assert(equivalent(previous.progress[key], migrated.progress[key]), "Migration must preserve progress " + key)
	assert(equivalent(previous.progress.get("foraging", {}), migrated.progress.get("foraging", {})))
	assert(migrated.stats.hp == previous.stats.hp)
	assert(equivalent(migrated.progress.dimension.outside_return, previous.progress.dimension.outside_return))
	assert(migrated.progress.dimension.last_point == [restored.player_point.x, restored.player_point.y])
	assert(restored.save_game(2) and restored.saves.read(2).data.progress.dimension.map_revision == 2)
	var title_point := organic_title_point(restored.world)
	assert(is_finite(title_point.x), "The revised map must expose a curved area boundary beyond the old placement rectangles")
	var saved_point: Vector2 = restored.player_point
	restored.player_point = title_point
	var area: Dictionary = restored.world.area_at(Vector2i(title_point))
	assert(restored.location_name() == "%s / %s" % [area.name, restored.world.definition.name])
	restored.player_point = saved_point
	for revision in [0, 1.5, 999]:
		var invalid: Dictionary = previous.duplicate(true)
		invalid.progress.dimension.map_revision = revision
		assert(not restored.saves.validate(invalid), "An undeclared map revision must be rejected")
	assert(restored.use_sanctum_sigil() and restored.use_sanctum_sigil() and restored.layer == "sanctum")
	var origin: Dictionary = previous.progress.dimension.outside_return
	assert(restored.leave_sanctum() and restored.player_point.is_equal_approx(Vector2(origin.location.point[0], origin.location.point[1])))
	game.queue_free()
	restored.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: declared revision1 disk migration, current terrain safe relocation, canonical revision2 save, preserved hero/progress/original thread and undeclared revision rejection")
	quit()
