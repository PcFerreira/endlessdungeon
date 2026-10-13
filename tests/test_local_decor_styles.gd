extends SceneTree

const World = preload("res://scripts/world.gd")
const Style = preload("res://scripts/town_style.gd")
const Magic = preload("res://scripts/town_magic.gd")
const Actors = preload("res://scripts/actor_models.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Decor = preload("res://scripts/decor_geometry.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Types = preload("res://scripts/town_types.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const LifeView = preload("res://scripts/world_life_view.gd")
var failures: Array[String] = []

class EpisodeLife extends RefCounted:
	var cities := {}
	var episode := {}
	func event_at(_id: String) -> Dictionary:
		return episode

func check_models(node: Node, biome: int, styles) -> void:
	for part in node.find_children("*", "MeshInstance3D", true, false):
		if not part.has_meta("asset_id") or not styles.allows(str(part.get_meta("asset_id", "")), biome):
			failures.append("Decorative mesh needs an actual family identity: " + str(part.name))
		var angled := false
		for surface in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				if not vertex.is_finite():
					failures.append("Decorative geometry must stay finite")
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				if maxf(absf(normal.x), maxf(absf(normal.y), absf(normal.z))) < .99:
					angled = true
		if styles.family_for(biome) == "flat_lowpoly" and str(part.get_meta("asset_id", "")).begins_with("native_decor:") and not angled:
			failures.append("Faceted decorative forms need actual angled geometry: " + str(part.get_meta("asset_id", "")))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	world.generate(12345)
	var city: Dictionary = world.region_at(world.start).city.duplicate(true)
	var styles := Styles.new()
	assert(styles.family_of("native_decor:block_voxel:unknown_role").is_empty())
	var models := {}
	for house in city.houses:
		var width: float = house.footprint.size.y if house.facing.x != 0 else house.footprint.size.x
		var length: float = house.footprint.size.x if house.facing.x != 0 else house.footprint.size.y
		var model := Node3D.new()
		model.position = Vector3(100, 20, -300)
		var height: float = house.height + 2.4
		var body := Voxels.cube(Vector3(width - .1, height, length - .1), Color.WHITE)
		body.position.y = height * .5
		model.add_child(body)
		models[house.id] = model
	var fountain := Node3D.new()
	var support := Voxels.cube(Vector3(1, 3.1, 1), Color.WHITE)
	support.position.y = 1.55
	fountain.add_child(support)
	var profiles: Dictionary = Areas.DATA.magic_profiles.duplicate(true)
	for id in Types.DATA.types:
		profiles[id] = Types.magic_profile(Types.DATA.types[id])
	var compositions := 0
	for biome in range(4):
		city.biome = biome
		for theme in Style.STYLES:
			city.exterior_profile = {"style": theme, "color": "db9b63", "accent": "d3a8eb"}
			var decor := Style.new()
			decor.build(city, null, models)
			check_models(decor, biome, styles)
			for part in decor.get_children():
				var house: Dictionary = city.houses.filter(func(entry): return entry.id == part.get_meta("house_id"))[0]
				var actual: AABB = part.get_meta("support_bounds")
				assert(actual == Decor.bounds(models[house.id]))
				assert(part.mesh.get_aabb().end.y <= actual.end.y + .08 and part.mesh.get_aabb().position.y >= 0)
			decor.free()
			compositions += 1
		for id in profiles:
			city.magic = Magic.plan(city, id, profiles[id], 12345)
			var magic := Magic.new()
			magic.build(city, models, fountain)
			check_models(magic, biome, styles)
			assert(magic.floating[0].mesh.get_aabb().position.y + magic.origins[0].y - .07 >= 3.3999)
			for light in magic.floating.slice(1):
				var actual: AABB = Decor.bounds(models[light.get_meta("house_id")])
				assert(is_equal_approx(light.get_meta("support_height"), actual.end.y))
				assert(light.position.y - .12 - .07 > actual.end.y)
			var point: Vector3 = magic.floating[0].position
			magic._process(.4)
			assert(magic.floating[0].position != point)
			magic.free()
			compositions += 1
		for role in Actors.Generator.catalog.data.roles:
			var actor := Actors.create(0, {"id": "town:test:npc:0", "city_id": "town:test", "role": role, "biome": biome})
			assert(actor.get_meta("representation") == "generated_voxel")
			assert(actor.get_meta("style").palette_id in Actors.Generator.catalog.data.biomes[str(biome)])
			actor.free()
	for model in models.values():
		model.free()
	fountain.free()
	world.load_around(city.cell)
	var life := EpisodeLife.new()
	var view := LifeView.new()
	root.add_child(view)
	var episodes := 0
	for biome in range(4):
		city.biome = biome
		life.cities = {city.id: city}
		for visual in ["crates", "meal", "banner", "books", "market"]:
			for phase in ["active", "aftermath"]:
				life.episode = {"instance_id": "fixture:%s:%s:%s" % [biome, visual, phase], "phase": phase, "label": "Actual supplies", "visual": visual}
				view._update_episode({"life": life, "world": world, "enemies": [], "player_point": Vector2(city.cell)})
				check_models(view.episode_root, biome, styles)
				var props: Array = view.episode_root.get_children().filter(func(node): return node is Node3D and not node is Label3D)
				if visual == "meal":
					var rug: AABB = props[0].transform * Decor.bounds(props[0])
					assert(is_zero_approx(rug.position.y))
					for prop in props.slice(1):
						assert(is_equal_approx((prop.transform * Decor.bounds(prop)).position.y, rug.end.y))
				elif visual in ["books", "market"]:
					var table: AABB = props[0].transform * Decor.bounds(props[0])
					for prop in props.slice(1):
						var box: AABB = prop.transform * Decor.bounds(prop)
						assert(is_equal_approx(box.position.y, table.end.y))
						assert(box.position.x >= table.position.x and box.end.x <= table.end.x and box.position.z >= table.position.z and box.end.z <= table.end.z)
				episodes += 1
				await process_frame
	view.queue_free()
	await process_frame
	if not failures.is_empty():
		printerr("FAIL: " + failures[0])
		quit(1)
		return
	print("PASS: %s accent/magic compositions, every NPC role and %s episode/phase compositions in four climates; actual angled family geometry, source-bound fitting, moving fountain/roof clearance and exact supply supports" % [compositions, episodes])
	quit()
