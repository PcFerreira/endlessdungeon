extends SceneTree

const World = preload("res://scripts/world.gd")
const Biomes = preload("res://scripts/biome_catalog.gd")
const ANCHOR := Vector2i(-22528, 5120)
const RADIUS := 64
const LIMIT := .085
const PALETTES := ["color", "earth", "rock"]

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)

func coast_weight(context: Dictionary) -> float:
	for part in context.biome_mix:
		if part.id == "coast":
			return part.weight
	return 0.0

func color_distance(first: Color, second: Color) -> float:
	return Vector3(first.r, first.g, first.b).distance_to(Vector3(second.r, second.g, second.b))

func shoreline() -> void:
	var world := World.new()
	world.generate(91, 6)
	var dry := {}
	for x in range(-RADIUS, RADIUS + 2):
		for y in range(-RADIUS, RADIUS + 2):
			var point := ANCHOR + Vector2i(x, y)
			if not world._natural_water(point):
				dry[point] = world.biome_at(point)
	var samples := 0
	var onsets := 0
	var worst := {}
	for palette in PALETTES:
		worst[palette] = {"distance": 0.0}
	for x in range(-RADIUS, RADIUS + 1):
		for y in range(-RADIUS, RADIUS + 1):
			var point := ANCHOR + Vector2i(x, y)
			if not dry.has(point):
				continue
			var first: Dictionary = dry[point]
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var neighbor: Vector2i = point + direction
				if not dry.has(neighbor):
					continue
				var second: Dictionary = dry[neighbor]
				samples += 1
				onsets += int((coast_weight(first) > 0) != (coast_weight(second) > 0))
				for palette in PALETTES:
					var difference := color_distance(Biomes.color_for(first, palette), Biomes.color_for(second, palette))
					if difference > worst[palette].distance:
						worst[palette] = {"distance": difference, "first": point, "second": neighbor, "first_coast": coast_weight(first), "second_coast": coast_weight(second)}
	check(samples > 100, "Actual shoreline must contain neighboring naturally dry samples")
	check(onsets > 0, "Actual shoreline must include coast onset between neighboring naturally dry cells")
	var rendered := {}
	for palette in PALETTES:
		check(worst[palette].distance < LIMIT, "%s one-cell shoreline seam %s exceeds %s" % [palette, worst[palette], LIMIT])
		for key in ["first", "second"]:
			if not worst[palette].has(key):
				continue
			var point: Vector2i = worst[palette][key]
			if rendered.has(point):
				continue
			var region := world.region_at(point)
			var info := world.cell_info(point)
			var footprint := false
			for site in World.sites_in(region):
				footprint = footprint or site.footprint.has_point(point)
			check(info.terrain == "land" and not world._road_at(point, region) and not footprint, "Worst naturally dry seam must use real unmodified land at %s" % point)
			for surface in PALETTES:
				check(Biomes.color_for(info, surface).is_equal_approx(Biomes.color_for(dry[point], surface)), "Rendered %s palette must retain actual natural shoreline sample at %s" % [surface, point])
			rendered[point] = {"terrain": info.terrain, "primary": info.biome_id, "coast": coast_weight(info)}
	print("SHORELINE: ", {"seed": 91, "anchor": ANCHOR, "naturally_dry_pairs": samples, "onsets": onsets, "worst": worst, "rendered_worst": rendered})

func scalar_strength() -> void:
	var samples := 0
	var worst := 0.0
	for seed_value in [0, 91]:
		for point in [ANCHOR, Vector2i(2541, 2331), Vector2i.ZERO]:
			for climate in range(4):
				var heat := -.5 if climate == 3 else (.5 if climate == 2 else 0.0)
				var rain := -.5 if climate == 1 else .5
				var none := Biomes.sample(point, climate, seed_value, heat, rain, 0.0)
				check(none == Biomes.sample(point, climate, seed_value, heat, rain, false), "Zero coast strength preserves the false sampler contract")
				var full := Biomes.sample(point, climate, seed_value, heat, rain, 1.0)
				check(full == Biomes.sample(point, climate, seed_value, heat, rain, true), "Full coast strength preserves the true sampler contract")
				check(coast_weight(none) == 0 and coast_weight(full) == .75, "Coast strength endpoints retain zero and three-quarter ownership")
				var previous: Dictionary = none
				for step in range(129):
					var strength := float(step) / 128
					var current := Biomes.sample(point, climate, seed_value, heat, rain, strength)
					check(Biomes.valid_cell(current), "Scalar coast strength must produce a finite normalized quantized valid cell")
					var weight := coast_weight(current)
					check(weight >= coast_weight(previous), "Increasing coast strength must not decrease quantized coast ownership")
					check(absf(weight - .75 * strength) <= 1.0 / 16, "Quantized coast ownership stays within one weight unit of its continuous target")
					for palette in PALETTES:
						worst = maxf(worst, color_distance(Biomes.color_for(previous, palette), Biomes.color_for(current, palette)))
					previous = current
					samples += 1
	check(worst < LIMIT, "Scalar coast interpolation has bounded palette steps: %s" % worst)
	print("SCALAR: ", {"samples": samples, "palette_max": worst})

func cold_vegetation() -> void:
	var world := World.new()
	world.generate(91, 6)
	world.temperature.noise_type = FastNoiseLite.TYPE_CELLULAR
	world.temperature.frequency = 0
	world.temperature.seed = 0
	var heat := world.temperature.get_noise_2d(0, 0)
	check(heat < -.22, "Real zero-frequency temperature noise must produce constant cold")
	if heat >= -.22:
		return
	var candidates := 0
	var props: Array[Dictionary] = []
	for x in range(-RADIUS, RADIUS + 1):
		for y in range(-RADIUS, RADIUS + 1):
			var point := ANCHOR + Vector2i(x, y)
			if world._natural_water(point):
				continue
			var context := world.biome_at(point)
			var weight := coast_weight(context)
			if context.biome_id == "coast" or weight <= 0 or weight >= .5:
				continue
			var threshold := float(world._hash("ecotone:%s:%s" % [point.x, point.y]) % 1024) / 1024
			var cumulative := 0.0
			var selected := ""
			for component in context.biome_mix:
				if threshold >= cumulative and threshold < cumulative + component.weight:
					selected = component.id
				cumulative += component.weight
			if selected != "coast":
				continue
			var region := world.region_at(point)
			if world._road_at(point, region):
				continue
			var footprint := false
			for site in World.sites_in(region):
				footprint = footprint or site.footprint.has_point(point)
			if footprint:
				continue
			candidates += 1
			var info := world.cell_info(point)
			if info.prop.is_empty():
				continue
			check(info.biome == 3 and info.biome_id != "coast", "Actual partial cold coast prop must retain inland primary")
			check(info.prop in ["pine", "rock"], "Selected cold coast vegetation at %s must be pine/rock, got %s" % [point, info.prop])
			props.append({"point": point, "primary": info.biome_id, "coast": weight, "prop": info.prop})
			if props.size() >= 8:
				break
		if props.size() >= 8:
			break
	check(not props.is_empty(), "Bounded actual shoreline must contain nonempty cold coast-selected props with inland primary")
	print("COLD VEGETATION: ", {"heat": heat, "selected_dry_candidates": candidates, "actual_props": props})

func legacy_terrain() -> void:
	var current := World.new()
	current.generate(91, 6)
	var samples := 0
	for edition in [4, 5]:
		var legacy := World.new()
		legacy.generate(91, edition)
		var info = legacy.cell_info(ANCHOR)
		check(info is Dictionary and info.has("terrain") and info.has("prop") and info.has("biome") and not info.has("biome_mix"), "Actual edition %s cell_info must return its legacy terrain/vegetation record" % edition)
		for x in range(-RADIUS, RADIUS + 1, 8):
			for y in range(-RADIUS, RADIUS + 1, 8):
				var point := ANCHOR + Vector2i(x, y)
				check(legacy._raw_height(point) == current._raw_height(point), "Coastal weighting preserves edition %s quantized terrain" % edition)
				check(legacy._natural_water(point) == current._natural_water(point), "Coastal weighting preserves edition %s natural water classification" % edition)
				var context := legacy.biome_at(point)
				check(context.biome_id == Biomes.LEGACY_IDS[context.biome] and not context.has("biome_mix") and context.biome_blend == 0, "Legacy ecology remains numeric climate with an unmixed legacy profile")
				samples += 1
	print("LEGACY: ", {"height_water_ecology_samples": samples})

func _init() -> void:
	shoreline()
	scalar_strength()
	cold_vegetation()
	legacy_terrain()
	if failures.is_empty():
		print("PASS: actual dry shoreline palettes, scalar monotonic quantized coast strength, cold coastal vegetation and legacy terrain/water/ecology")
	quit(0 if failures.is_empty() else 1)
