extends SceneTree

const World = preload("res://scripts/world.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	check(World.NEW_JOURNEY_EDITION == 7, "Fresh journeys need the composition generation contract")
	if not failures.is_empty():
		finish()
		return
	var world := World.new()
	world.generate(91, 7)
	var legacy := World.new()
	legacy.generate(91, 6)
	var composer = load("res://scripts/biome_composition.gd")
	var statistics := {}
	for id in World.Biomes.DATA.profiles:
		var ecology := {"biome": 3 if id in ["frostlands", "crystal_tundra"] else 0, "biome_id": id, "biome_mix": [{"id": id, "weight": 1.0}]}
		var low := 1000.0
		var high := 0.0
		var focal := 0
		var quiet := 0
		var adjacent_delta := 0.0
		for x in range(-64, 65, 2):
			for y in range(-64, 65, 2):
				var point := Vector2i(x, y)
				var sample: Dictionary = composer.sample(91, point, ecology)
				check(sample == composer.sample(91, point, ecology), id + " seeded replay")
				low = minf(low, sample.density)
				high = maxf(high, sample.density)
				quiet += int(sample.zone == "clearing")
				focal += int(not sample.prop_override.is_empty() or not sample.detail_override.is_empty())
				var next: Dictionary = composer.sample(91, point + Vector2i.RIGHT, ecology)
				adjacent_delta = maxf(adjacent_delta, absf(next.grove - sample.grove))
		check(high - low > 30 and quiet > 30 and focal > 0, id + " needs occupied stands, quiet clearings and an actual focal arrangement")
		check(adjacent_delta < .25, id + " correlated patches must cross cell/chunk boundaries smoothly")
		statistics[id] = {"density_range": [low, high], "quiet": quiet, "focal": focal}
	var marsh := {"biome": 0, "biome_id": "marsh", "biome_mix": [{"id": "marsh", "weight": 1.0}]}
	var dry_marsh: Dictionary = composer.sample(91, Vector2i(-22571, -3115), marsh)
	var wet_marsh: Dictionary = composer.sample(91, Vector2i(-22571, -3115), marsh, true)
	check(not dry_marsh.details.has("biome:reeds") and not dry_marsh.details.has("biome:lily"), "Dry marsh understory must avoid unrelated scattered water plants")
	check(wet_marsh.details.has("biome:reeds"), "Real wet-edge marsh must retain reeds even outside active focal groups")
	var mixed := {"biome": 0, "biome_id": "dense_forest", "biome_mix": [{"id": "dense_forest", "weight": .5}, {"id": "meadows", "weight": .5}]}
	var a := mixed.duplicate(true)
	a.biome_mix = [{"id": "dense_forest", "weight": 1.0}]
	var b := mixed.duplicate(true)
	b.biome_mix = [{"id": "meadows", "weight": 1.0}]
	for point in [Vector2i(-17, -16), Vector2i(0, 0), Vector2i(16, 15), Vector2i(63, 64)]:
		var center: Dictionary = composer.sample(91, point, mixed)
		check(is_equal_approx(center.density, (composer.sample(91, point, a).density + composer.sample(91, point, b).density) * .5), "Mixtures retain weighted stand density")
	var protected := 0
	for x in range(-1, 2):
		for y in range(-1, 2):
			var region: Dictionary = world.region_at(Vector2i(x, y) * World.REGION_SIZE)
			for point in region.roads:
				var info: Dictionary = world.cell_info(point)
				var before: Dictionary = legacy.cell_info(point)
				check(info.walkable == before.walkable and info.prop.is_empty() and info.detail.is_empty() and info.height == before.height, "Composition must preserve actual road/bridge approach cells including structural collision")
				protected += 1
			for site in World.sites_in(region):
				var info: Dictionary = world.cell_info(site.cell)
				check(info.prop.is_empty() and info.detail.is_empty(), "Composition must leave actual sites clear")
	check(protected > 100, "Test actual protected routes")
	world.load_around(Vector2(world.start))
	check(world.chunks.size() == 25 and world.regions.size() <= 32 and world.route_plans.size() <= 128, "Composition must retain streaming bounds")
	print("Composition sampled statistics: ", statistics, "; protected roads ", protected)
	finish()

func finish() -> void:
	for failure in failures:
		print("FAIL: ", failure)
	if failures.is_empty():
		print("PASS: all14 correlated stands, quiet clearings, focal arrangements, mixed density, seeded negative/chunk-boundary replay and actual protected world roads/sites")
	quit(0 if failures.is_empty() else 1)
