extends SceneTree

const World = preload("res://scripts/world.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const History = preload("res://scripts/regional_history.gd")
const Discoveries = preload("res://scripts/discovery_catalog.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("audit")

func check(condition: bool, context: String) -> void:
	if not condition:
		failures.append(context)

func count(values: Dictionary, key: String) -> void:
	values[key] = values.get(key, 0) + 1

func audit() -> void:
	var history := History.new()
	var discoveries := Discoveries.new()
	check(history.errors.is_empty() and not history.definitions.is_empty(), "Regional history definitions must load")
	check(discoveries.errors.is_empty() and not discoveries.entries.is_empty(), "Discovery definitions must load")
	var summary := {"generator_version": World.GENERATOR_VERSION, "seeds": [0, 1, 12345, 98765], "regions": 0, "archetypes": {}, "layouts": {}, "biomes": {}, "families": {}, "histories": {}, "discovery_families": {}, "quiet_regions": 0, "duplicate_ruin_names": 0, "adjacent_same_history": 0, "adjacent_history_pairs": 0, "ruin_name_examples": [], "town_names": {}, "ruin_distances": {}, "failed_checks": []}
	for seed_value in summary.seeds:
		var world := World.new()
		world.generate(seed_value)
		var first: Dictionary = world.region_at(world.start).duplicate(true)
		var selected_histories := {}
		for x in range(-4, 5):
			for y in range(-4, 5):
				var coordinate := Vector2i(x, y)
				var region: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
				var city: Dictionary = region.city
				var label := "%s/%s" % [seed_value, coordinate]
				summary.regions += 1
				count(summary.archetypes, city.archetype_id)
				count(summary.layouts, city.layout_id)
				count(summary.biomes, str(city.biome))
				count(summary.town_names, city.name)
				var definition: Dictionary = Areas.CITIES[city.archetype_id]
				check(definition.biomes.any(func(value): return int(value) == city.biome), label + ": town climate mismatch")
				var uses := {}
				for house in city.houses:
					uses[house.use_id] = true
					check(house.interior_type == Areas.DATA.building_uses[house.use_id].interior_type, label + ": exterior/interior mismatch")
					check(city.streets.has(Vector2i(house.approach)) and world.cell_info(Vector2i(house.approach)).walkable, label + ": blocked house approach")
				for use_id in definition.required_buildings:
					check(uses.has(use_id), label + ": missing required use " + use_id)
				for lot in city.outdoor_lots:
					check(city.streets.has(Vector2i(lot.approach)) and world.cell_info(Vector2i(lot.approach)).walkable, label + ": blocked outdoor approach")
				for actor in city.residents + city.books:
					check(world.cell_info(Vector2i(actor.approach)).walkable, label + ": blocked resident/book approach")
				if region.dungeons[0].name == region.dungeons[1].name:
					summary.duplicate_ruin_names += 1
					if summary.ruin_name_examples.size() < 8:
						summary.ruin_name_examples.append({"seed": seed_value, "coordinate": [x, y], "city": city.name, "name": region.dungeons[0].name, "ids": [region.dungeons[0].id, region.dungeons[1].id]})
				for site in region.dungeons:
					count(summary.families, site.family)
					count(summary.ruin_distances, str(absi(site.cell.x - city.cell.x) + absi(site.cell.y - city.cell.y)))
					check(world.cell_info(site.cell).walkable, label + ": blocked ruin entrance")
					check(Areas.DUNGEONS[site.family].biomes.any(func(value): return int(value) == city.biome), label + ": dungeon climate mismatch")
					check(not Areas.DUNGEONS[site.family].has("required_facet") or Areas.DUNGEONS[site.family].required_facet == region.facet, label + ": dungeon facet mismatch")
				var landmark := Sites.plan(world, region, discoveries)
				if landmark.is_empty():
					summary.quiet_regions += 1
				else:
					count(summary.discovery_families, landmark.family)
					check(region.dungeons.any(func(site): return site.id == landmark.site_id and site.name == landmark.site_name), label + ": unbound clue")
					check(not landmark.text.contains("{"), label + ": unresolved clue")
				var account := history.plan(world, region, landmark)
				check(not account.is_empty(), label + ": missing account")
				if not account.is_empty():
					count(summary.histories, account.template_id)
					selected_histories[coordinate] = account.template_id
					check(History.valid_snapshot({"version": 1, "records": {account.region_id: account}}, str(seed_value)), label + ": invalid bound account")
					check(not landmark.is_empty() or "landmark" not in account.required_sources, label + ": impossible source collection")
					check(landmark.is_empty() or landmark.site_id == account.site_id, label + ": clue/account target disagreement")
		for coordinate in selected_histories:
			for step in [Vector2i.RIGHT, Vector2i.DOWN]:
				if selected_histories.has(coordinate + step):
					summary.adjacent_history_pairs += 1
					if selected_histories[coordinate] == selected_histories[coordinate + step]:
						summary.adjacent_same_history += 1
		check(world.region_at(world.start) == first, "Seed %s: plan changed after region/route cache eviction" % seed_value)
		var reversed := World.new()
		reversed.generate(seed_value)
		for x in range(4, -5, -1):
			for y in range(4, -5, -1):
				reversed.region_at(Vector2i(x, y) * World.REGION_SIZE)
		check(reversed.region_at(reversed.start) == first, "Seed %s: plan changed with reverse region load order" % seed_value)
	summary.failed_checks = failures
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output := FileAccess.open("res://artifacts/world-building-audit.json", FileAccess.WRITE)
	if output == null:
		push_error("Cannot write world-building audit")
		quit(1)
		return
	output.store_string(JSON.stringify(summary, "\t") + "\n")
	output.close()
	print("Regions: %s; archetypes: %s; layouts: %s; histories: %s" % [summary.regions, summary.archetypes, summary.layouts, summary.histories])
	print("Duplicate local ruin names: %s; adjacent repeated history: %s/%s; quiet regions: %s" % [summary.duplicate_ruin_names, summary.adjacent_same_history, summary.adjacent_history_pairs, summary.quiet_regions])
	for failure in failures:
		printerr(failure)
	print("PASS: world-building structural audit; experience and presentation require separate review" if failures.is_empty() else "FAIL: world-building structural audit")
	quit(0 if failures.is_empty() else 1)
