extends SceneTree

const World = preload("res://scripts/world.gd")
const Life = preload("res://scripts/world_life.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const Catalog = preload("res://scripts/discovery_catalog.gd")
const History = preload("res://scripts/regional_history.gd")
const Quests = preload("res://scripts/local_quests.gd")
const Exploration = preload("res://scripts/exploration.gd")

func _init() -> void:
	var life := Life.new()
	life.reset(91)
	life.world_edition = 6
	var context: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
	assert(context.get("context", {}).get("edition") == 6, "New ecology journeys retain their actual living-world edition")
	assert(Life.valid_snapshot(context, "91", 6))
	assert(not Life.valid_snapshot(context, "91", 5) and not Life.valid_snapshot(context, "92", 6))
	for invalid in [4, 5.5, 6.5, 7, "6", NAN, INF]:
		var bad := context.duplicate(true)
		bad.context.edition = invalid
		assert(not Life.valid_snapshot(bad, "91", 6))
	var absent := context.duplicate(true)
	absent.erase("context")
	assert(not Life.valid_snapshot(absent, "91", 6))
	var restored := Life.new()
	assert(restored.restore(context, 91) and restored.world_edition == 6)
	var roundtrip := restored.snapshot()
	assert(roundtrip.context.edition == 6 and roundtrip.context.seed == "91" and roundtrip.tick == context.tick and roundtrip.actors.is_empty())
	var catalog := Catalog.new()
	var counts := {"markers": 0, "townless": 0, "cross_history": 0, "quests": 0, "travelers": 0}
	for seed_value in [0, 91]:
		var world := World.new()
		world.generate(seed_value, 6)
		world.load_around(Vector2(world.start))
		life.reset(seed_value)
		life.sync(world, Vector2(world.start))
		var saved_life: Dictionary = JSON.parse_string(JSON.stringify(life.snapshot()))
		assert(Life.valid_snapshot(saved_life, str(seed_value), 6))
		assert(restored.restore(saved_life, seed_value) and restored.world_edition == 6)
		restored.sync(world, Vector2(world.start))
		for id in life.actors:
			if id.begins_with("road5:"):
				assert(restored.actors.has(id) and restored.actors[id].point.is_equal_approx(life.actors[id].point))
				counts.travelers += 1
		for x in range(-2, 3):
			for y in range(-2, 3):
				var coordinate := Vector2i(x, y)
				var region: Dictionary = world.region_at(coordinate * World.REGION_SIZE)
				var marker := Sites.plan(world, region, catalog)
				if not marker.is_empty():
					counts.markers += 1
					counts.townless += int(region.city.is_empty())
					assert(marker.generator_version == 6 and marker.region_id == "region:6:%s:%s:%s" % [seed_value, x, y])
					var snapshot := {"version": 1, "entries": {marker.id: marker}}
					assert(Exploration.valid_snapshot(JSON.parse_string(JSON.stringify(snapshot)), str(seed_value)))
					var bad := snapshot.duplicate(true)
					bad.entries[marker.id].site_cell[0] += 1
					assert(not Exploration.valid_snapshot(bad, str(seed_value)))
					assert(not Exploration.valid_snapshot(snapshot, str(seed_value + 1)))
				var history := History.new()
				var record := history.plan(world, region, marker)
				if region.city.is_empty():
					assert(record.is_empty())
					continue
				assert(not record.is_empty() and record.generator_version == 6)
				counts.cross_history += int(region.dungeons.is_empty())
				assert(history.learn(record, "book"))
				var saved: Dictionary = JSON.parse_string(JSON.stringify(history.snapshot()))
				assert(History.new().restore(saved, str(seed_value)))
				var bad_history := saved.duplicate(true)
				bad_history.records[record.region_id].site_cell[1] += 1
				assert(not History.valid_snapshot(bad_history, str(seed_value)))
				var quests := Quests.new()
				for resident in region.city.residents:
					var offer := quests.offer(world, region, record, resident)
					if offer.is_empty():
						continue
					assert(quests.accept(offer))
					assert(Quests.new().restore(JSON.parse_string(JSON.stringify(quests.snapshot())), str(seed_value)))
					var bad_quest := quests.snapshot()
					bad_quest.records[offer.id].city_cell[0] += 1
					assert(not Quests.valid_snapshot(bad_quest, str(seed_value)))
					counts.quests += 1
					break
	assert(counts.values().all(func(count): return count > 0), str(counts))
	print("PASS: edition-6 living-world context, exact edition/seed rejection, real road travelers, sparse clues and cross-region history/quest identities; ", counts)
	quit()
