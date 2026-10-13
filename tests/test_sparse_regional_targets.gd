extends SceneTree

const World = preload("res://scripts/world.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const Catalog = preload("res://scripts/discovery_catalog.gd")
const History = preload("res://scripts/regional_history.gd")
const Quests = preload("res://scripts/local_quests.gd")
const Exploration = preload("res://scripts/exploration.gd")
const Models = preload("res://scripts/item_models.gd")
const View = preload("res://scripts/discovery_view.gd")

func _init() -> void:
	var catalog := Catalog.new()
	var counts := {"markers": 0, "townless": 0, "quiet": 0, "cross_history": 0, "quests": 0}
	for seed_value in [0, 91]:
		var world := World.new()
		world.generate(seed_value, 5)
		for x in range(-2, 3):
			for y in range(-2, 3):
				var coordinate := Vector2i(x, y)
				var region: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
				var marker := Sites.plan(world, region, catalog)
				assert(marker == Sites.plan(world, region, catalog), "Sparse clues must replay independent of region-cache eviction")
				if World.sites_in(region).is_empty():
					counts.quiet += 1
					assert(marker.is_empty(), "Completely site-free regions remain quiet")
				if not marker.is_empty():
					counts.markers += 1
					counts.townless += int(region.city.is_empty())
					assert(not world.site_by_id(marker.site_id, Vector2i(marker.site_cell[0], marker.site_cell[1])).is_empty())
					assert(Sites.Targets.valid_city(seed_value, marker.city_id))
					var point := Vector2i(marker.point[0], marker.point[1])
					var approach := Vector2i(marker.approach[0], marker.approach[1])
					assert(world.cell_info(point).walkable and world.cell_info(approach).walkable)
					assert(world.cell_info(approach).terrain in ["road", "bridge", "paving"] and world.cell_info(point).terrain not in ["road", "bridge", "paving", "water"])
					world.load_around(Vector2(approach))
					assert(world.can_step(Vector2(approach), Vector2(point)) and world.line_clear(Vector2(approach), Vector2(point)))
					assert(world.move_actor(Vector2(approach), Vector2(point - approach)).is_equal_approx(Vector2(point)))
					var snapshot := {"version": 1, "entries": {marker.id: marker}}
					assert(Exploration.valid_snapshot(JSON.parse_string(JSON.stringify(snapshot)), str(seed_value)))
					var bad := snapshot.duplicate(true)
					bad.entries[marker.id].site_cell[0] += 1
					assert(not Exploration.valid_snapshot(bad, str(seed_value)), "Clues reject a real ID with an invented target cell")
				var history := History.new()
				var record := history.plan(world, region, marker)
				if region.city.is_empty():
					assert(record.is_empty(), "Town-free clues cannot invent a ledger or witness")
					continue
				assert(not record.is_empty() and record.city_id == region.city.id)
				assert(not world.site_by_id(record.site_id, Vector2i(record.site_cell[0], record.site_cell[1])).is_empty())
				if region.dungeons.is_empty():
					counts.cross_history += 1
					assert(not record.site_id.begins_with("ruin:%s:%s:" % [x, y]))
				assert(history.learn(record, "book") and history.learn(record, "witness"))
				if "landmark" in record.required_sources:
					assert(history.learn(record, "landmark"))
				assert(history.complete(record.region_id))
				var saved: Dictionary = JSON.parse_string(JSON.stringify(history.snapshot()))
				assert(History.new().restore(saved, str(seed_value)))
				var bad_history: Dictionary = saved.duplicate(true)
				bad_history.records[record.region_id].site_cell[1] += 1
				assert(not History.valid_snapshot(bad_history, str(seed_value)))
				var quests := Quests.new()
				for resident in region.city.residents:
					var offer := quests.offer(world, region, record, resident)
					if offer.is_empty():
						continue
					assert(offer.site_id == record.site_id and quests.accept(offer))
					assert(quests.record_ledger(offer.id, region.city.id, offer.town_book))
					assert(quests.inspect(offer.id, {"site_id": offer.site_id, "depth": 1, "book_id": offer.ruin_book, "point": [4, 7]}))
					assert(Quests.new().restore(JSON.parse_string(JSON.stringify(quests.snapshot())), str(seed_value)))
					var bad_quest: Dictionary = quests.snapshot()
					bad_quest.records[offer.id].city_cell[0] += 1
					assert(not Quests.valid_snapshot(bad_quest, str(seed_value)))
					counts.quests += 1
					break
	assert(counts.markers > 0 and counts.townless > 0 and counts.quiet > 0 and counts.cross_history > 0 and counts.quests > 0, str(counts))
	var models := Models.new()
	var view := View.new()
	for definition in catalog.entries:
		for family in ["block_voxel", "flat_lowpoly"]:
			var source: String = catalog.models(definition)[0].id
			var body := models.source_model(source, family)
			assert(body != null, models.error)
			var source_bounds := Models.Bounds.bounds(body)
			body.free()
			var model := view.create({"model_id": source, "biome": 0 if family == "block_voxel" else 2, "marker_width": definition.marker_width, "marker_height": definition.marker_height})
			assert(model != null and model.get_meta("source_asset") == source and models.styles.family_of(model.get_meta("asset_id")) == family)
			var bounds := Models.Bounds.bounds(model)
			assert(is_equal_approx(maxf(bounds.size.x, bounds.size.z), definition.marker_width) and is_equal_approx(bounds.size.x / bounds.size.z, source_bounds.size.x / source_bounds.size.z) and is_equal_approx(bounds.size.y, definition.marker_height) and absf(bounds.position.y) < .001)
			model.free()
	view.free()
	print("PASS: sparse real-road clues, preserved quiet regions, actual neighboring dungeon histories/quests, exact seed-bound targets, completable sources and JSON restoration; ", counts)
	quit()
