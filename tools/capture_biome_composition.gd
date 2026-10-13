extends SceneTree

const Game = preload("res://scripts/game.gd")
const World = preload("res://scripts/world.gd")
const Points = preload("res://tools/biome_review_points.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const Micro = preload("res://scripts/micro_biome_catalog.gd")
const SEED := 91
const EDITION := 7
const RADIUS := 16
const SOURCE_PATHS := ["tools/capture_biome_composition.gd", "tools/biome_review_points.gd", "scripts/game.gd", "scripts/world.gd", "scripts/hub_world.gd", "scripts/floating_hub.gd", "scripts/world_view.gd", "scripts/terrain_mesh_data.gd", "scripts/biome_catalog.gd", "scripts/biome_composition.gd", "scripts/biome_models.gd", "scripts/biome_atmosphere.gd", "scripts/world_ambience.gd", "scripts/micro_biome_catalog.gd", "scripts/micro_biome_view.gd", "scripts/micro_biome_exploration.gd", "scripts/exploration.gd", "scripts/foraging.gd", "scripts/forage_catalog.gd", "scripts/expansion.gd", "scripts/interface.gd", "scripts/save_store.gd", "scripts/integer_text.gd", "scripts/voxel_kit.gd", "scripts/dungeon_surfaces.gd", "scripts/item_models.gd", "scripts/environment_styles.gd", "scripts/animated_model_style.gd", "scripts/decor_geometry.gd", "scripts/render_cache.gd", "scripts/render_warmup.gd", "scripts/streaming_data.gd", "config/biomes.json", "config/biome_composition.json", "config/biome_art.json", "config/biome_atmosphere.json", "config/micro_biomes.json", "config/foraging.json", "config/world_ambience.json", "config/environment_styles.json", "config/item_styles.json", "assets/render_cache/catalog.json", "assets/world_construction/catalog.json", "assets/biome_cutaway.gdshader", "assets/world_cutaway.gdshader"]
var game
var directory := "res://artifacts/biome-composition"
var private_directory := "user://biome-composition-preview-%s" % Time.get_ticks_usec()
var before := {}
var frames: Array = []
var failed := false

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("run")

func source_hashes() -> Dictionary:
	var result := {}
	for path in SOURCE_PATHS:
		result[path] = FileAccess.get_sha256("res://" + path) if FileAccess.file_exists("res://" + path) else "MISSING"
	return result

func safe_land(world, point: Vector2i, id: String) -> bool:
	if world._natural_water(point) or world.biome_at(point).biome_id != id:
		return false
	var region: Dictionary = world.region_at(point)
	if world._road_at(point, region):
		return false
	for site in World.sites_in(region):
		if site.footprint.grow(2).has_point(point):
			return false
	var info: Dictionary = world.cell_info(point)
	return info.terrain == "land" and info.walkable and not info.get("composition_motif", "").is_empty()

func neighborhood(world, center: Vector2i, id: String) -> Dictionary:
	var total := 0
	var dry := 0
	var same := 0
	for x in range(-RADIUS, RADIUS + 1, 4):
		for y in range(-RADIUS, RADIUS + 1, 4):
			var point := center + Vector2i(x, y)
			total += 1
			if not world._natural_water(point):
				dry += 1
			if world.biome_at(point).biome_id == id:
				same += 1
	return {"sample_count": total, "dry_fraction": float(dry) / total, "same_biome_fraction": float(same) / total}

func actual_records(world, center: Vector2i) -> Dictionary:
	var rows: Array = []
	var zones := {}
	var props := {}
	var details := {}
	for x in range(-RADIUS, RADIUS + 1):
		for y in range(-RADIUS, RADIUS + 1):
			var point := center + Vector2i(x, y)
			var info: Dictionary = world.cell_info(point)
			var zone: String = info.get("composition_zone", "")
			zones[zone] = zones.get(zone, 0) + 1
			if not info.prop.is_empty():
				props[info.prop] = props.get(info.prop, 0) + 1
			if not info.detail.is_empty():
				details[info.detail] = details.get(info.detail, 0) + 1
			rows.append({"cell": [point.x, point.y], "height": info.height, "terrain": info.terrain, "walkable": info.walkable, "biome_id": info.biome_id, "biome_mix": info.biome_mix, "prop": info.prop, "detail": info.detail, "zone": zone, "motif": info.get("composition_motif", ""), "feature_id": info.get("composition_feature", ""), "micro_biome_id": info.get("micro_biome_id", ""), "micro_biome_name": info.get("micro_biome_name", "")})
	return {"radius": RADIUS, "zones": zones, "props": props, "details": details, "cells": rows}

func locate(world) -> Dictionary:
	var anchors := Points.find(world)
	var result := {}
	for id in Composition.DATA.profiles:
		var anchor: Vector2i = anchors[id].cell
		if id == "coast":
			var verified: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/micro-biomes/plans-seed91.json"))
			var coordinates: Array = verified.examples.coast.center
			var center := Vector2i(coordinates[0], coordinates[1])
			var focus := Composition.feature(SEED, center)
			var plan := Micro.plan(world, focus)
			if plan.is_empty() or not safe_land(world, center, id):
				print("FAIL: current actual coast micro feature must retain real land/water/approach eligibility")
				failed = true
				continue
			result[id] = {"center": [center.x, center.y], "anchor": [anchor.x, anchor.y], "center_kind": "active_water_required_micro_feature", "micro_id": plan.id, "micro_name": plan.name, "actual_water_cell": [plan.water_cell.x, plan.water_cell.y], "feature": {"id": focus.id, "center": [center.x, center.y], "turn": focus.turn, "active": focus.active}, "neighborhood": neighborhood(world, center, id), "actual": actual_records(world, center)}
			print("LOCATED: coast actual Tide Garden ", center, " honest dry/same neighborhood ", result[id].neighborhood)
			continue
		var search_anchors: Array[Vector2i] = [anchor]
		if id == "coast":
			for point in [Vector2i(-24064, -9216), Vector2i(-24074, -9210)]:
				if world.biome_at(point).biome_id == id and not world._natural_water(point):
					search_anchors.append(point)
			for x in range(-24, 25):
				for y in range(-24, 25):
					var point := Vector2i(x, y) * 1024
					if world.biome_at(point).biome_id == id and not world._natural_water(point) and point not in search_anchors:
						search_anchors.append(point)
					if search_anchors.size() >= 20:
						break
				if search_anchors.size() >= 20:
					break
		var seen := {}
		var candidates: Array = []
		for search_anchor in search_anchors:
			for radius in range(5):
				for x in range(-radius, radius + 1):
					for y in range(-radius, radius + 1):
						if maxi(absi(x), absi(y)) != radius:
							continue
						var focus := Composition.feature(SEED, search_anchor + Vector2i(x, y) * Composition.FEATURE_SIZE)
						if seen.has(focus.id):
							continue
						seen[focus.id] = true
						var center: Vector2i = focus.center
						if not focus.active or not safe_land(world, center, id):
							continue
						var area := neighborhood(world, center, id)
						if area.dry_fraction < .6 or (id != "coast" and area.same_biome_fraction < .6):
							continue
						var score: float = area.dry_fraction + area.same_biome_fraction - Vector2(center - anchor).length() * .0001
						candidates.append({"center": center, "focus": focus, "neighborhood": area, "score": score})
				if candidates.size() >= 3:
					break
			if candidates.size() >= 3:
				break
		if candidates.is_empty() and id == "coast":
			for search_anchor in search_anchors:
				for x in range(-32, 33, 4):
					for y in range(-32, 33, 4):
						var point := search_anchor + Vector2i(x, y)
						if not safe_land(world, point, id):
							continue
						var area := neighborhood(world, point, id)
						if area.dry_fraction < .6:
							continue
						var focus := Composition.feature(SEED, point)
						candidates.append({"center": point, "focus": focus, "neighborhood": area, "score": area.dry_fraction + area.same_biome_fraction, "shore_context": true})
				if not candidates.is_empty():
					break
		if candidates.is_empty():
			print("FAIL: no actual active dry focal area for ", id, " near ", anchor)
			failed = true
			continue
		candidates.sort_custom(func(a, b): return a.score > b.score)
		var choice: Dictionary = candidates[0]
		var center: Vector2i = choice.center
		var feature_center: Vector2i = choice.focus.center
		result[id] = {"center": [center.x, center.y], "anchor": [anchor.x, anchor.y], "center_kind": "natural_shore_context" if choice.get("shore_context", false) else "active_feature_center", "feature": {"id": choice.focus.id, "center": [feature_center.x, feature_center.y], "turn": choice.focus.turn, "active": choice.focus.active}, "neighborhood": choice.neighborhood, "actual": actual_records(world, center)}
		print("LOCATED: ", id, " ", center, " dry=", choice.neighborhood.dry_fraction, " same=", choice.neighborhood.same_biome_fraction, " zones=", result[id].actual.zones, " props=", result[id].actual.props)
	return result

func clean_private(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):
		clean_private(path.path_join(folder))
	DirAccess.remove_absolute(path)

func finish(code: int) -> void:
	if game != null:
		game.queue_free()
		await process_frame
	clean_private(ProjectSettings.globalize_path(private_directory))
	quit(code)

func wait_renderer() -> bool:
	game.set_process(true)
	for index in range(600):
		if not game.render_warmup.busy and (game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay)):
			return true
		await process_frame
	print("FAIL: current real renderer warmup/overlay removal did not finish")
	return false

func frame(id: String, reverse: bool, selection: Dictionary) -> bool:
	if not await wait_renderer():
		return false
	game.surface_zoom = 22
	game.camera_yaw = PI / 4 + (PI if reverse else 0)
	game.target_yaw = game.camera_yaw
	game._snap_camera()
	game.camera.size = 22
	game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
	for index in range(24):
		await process_frame
	if game.render_warmup.busy or game.warmup_overlay != null and is_instance_valid(game.warmup_overlay):
		print("FAIL: actual loading overlay/warmup returned before image")
		return false
	if source_hashes() != before:
		print("FAIL: source publication crossed native capture")
		return false
	RenderingServer.force_draw(false)
	var name := id + ("-reverse.png" if reverse else "-front.png")
	if root.get_texture().get_image().save_png(directory.path_join(name)) != OK:
		return false
	frames.append({"image": name, "biome_id": id, "point": [game.player_point.x, game.player_point.y], "requested_center": selection.center, "camera_yaw": game.camera_yaw, "camera_size": game.camera.size, "layer": game.layer, "ambience_profile": game.ambience.profile, "warmup_busy": game.render_warmup.busy, "loading_overlay_absent": game.warmup_overlay == null or not is_instance_valid(game.warmup_overlay), "micro_markers": game.exploration.micro.markers.keys()})
	return true

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--output="):
			directory = argument.trim_prefix("--output=")
	before = source_hashes()
	var world := World.new()
	world.generate(SEED, EDITION)
	var selection := locate(world)
	if source_hashes() != before:
		print("FAIL: source publication crossed headless location discovery")
		failed = true
	var manifest := {"seed": SEED, "edition": EDITION, "renderer": "Game/WorldView", "camera_size": 22, "selection": selection, "sources_before": before, "sources_after": source_hashes(), "source_stable": source_hashes() == before, "valid_selection": not failed}
	if "--locate-only" in arguments:
		FileAccess.open("/tmp/endless-compass-biome-composition-locations.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
		var focal_count := selection.values().filter(func(area): return area.center_kind.begins_with("active_")).size()
		print("%s: %s real edition7 review areas (%s active focal centers, %s shore contexts); headless data discovery only" % ["REJECT" if failed else "PASS", selection.size(), focal_count, selection.size() - focal_count])
		await finish(1 if failed else 0)
		return
	if failed or DisplayServer.get_name() == "headless":
		print("FAIL: native captures require a valid location set and an explicitly handed-off native window")
		await finish(1)
		return
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	game = Game.new()
	game.records_enabled = false
	game.save_directory = private_directory
	game.settings_path = private_directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run(SEED, EDITION)
	for id in selection:
		var coordinates: Array = selection[id].center
		var center := Vector2(coordinates[0], coordinates[1])
		game._generate_surface(center, false)
		if game.player_point.distance_to(center) > .01 or game.world.cell_info(Vector2i(game.player_point.round())).biome_id != id:
			print("FAIL: real Game moved away from verified focal center for ", id)
			failed = true
			break
		if actual_records(game.world, Vector2i(center)) != selection[id].actual:
			print("FAIL: actual Game neighborhood differs from discovered real World cells for ", id)
			failed = true
			break
		if not await wait_renderer():
			failed = true
			break
		for index in range(2):
			await process_frame
		game.set_process(false)
		for index in range(10):
			game.ambience.update(game, 1.0)
		for reverse in [false, true]:
			if not await frame(id, reverse, selection[id]):
				failed = true
				break
		if failed:
			break
	manifest.frames = frames
	manifest.viewport = [root.size.x, root.size.y]
	manifest.atmosphere_settle_seconds = 10
	manifest.sources_after = source_hashes()
	manifest.source_stable = manifest.sources_after == before
	failed = failed or not manifest.source_stable
	FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
	print("%s: %s actual edition7 Game composition review views; no invented cells or props" % ["REJECT" if failed else "PASS", frames.size()])
	await finish(1 if failed else 0)
