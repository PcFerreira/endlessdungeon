extends SceneTree

const Biomes = preload("res://scripts/biome_catalog.gd")

func center(zone: Vector2i, seed_value: int) -> Vector2:
	var jitter := Vector2(Biomes.salt(seed_value, str(zone) + ":x") % 1000, Biomes.salt(seed_value, str(zone) + ":y") % 1000) / 1000.0 * .4 + Vector2.ONE * .3
	return (Vector2(zone) + jitter) * float(Biomes.DATA.zone_size)

func junction(a: Vector2, b: Vector2, c: Vector2) -> Vector2:
	var determinant := 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	if absf(determinant) < .001:
		return Vector2(INF, INF)
	return Vector2((a.length_squared() * (b.y - c.y) + b.length_squared() * (c.y - a.y) + c.length_squared() * (a.y - b.y)) / determinant, (a.length_squared() * (c.x - b.x) + b.length_squared() * (a.x - c.x) + c.length_squared() * (b.x - a.x)) / determinant)

func distance(first: Color, second: Color) -> float:
	return Vector3(first.r, first.g, first.b).distance_to(Vector3(second.r, second.g, second.b))

func climate(heat: float, rain: float) -> int:
	return 3 if heat < -.22 else (2 if heat > .23 else (0 if rain > 0 else 1))

func check(context: Dictionary) -> void:
	assert(Biomes.valid_cell(context) and context.has("biome_mix"))
	var json: Dictionary = JSON.parse_string(JSON.stringify(context))
	assert(Biomes.valid_cell(json) and Biomes.palette_key(json) == Biomes.palette_key(context))
	for key in ["color", "earth", "rock"]:
		assert(Biomes.color_for(json, key).is_equal_approx(Biomes.color_for(context, key)))
	var reordered: Dictionary = context.duplicate(true)
	reordered.biome_mix.reverse()
	assert(Biomes.valid_cell(reordered) and Biomes.palette_key(reordered) == Biomes.palette_key(context))

func _init() -> void:
	var worst := 0.0
	var evidence := {}
	var samples := 0
	for seed_value in [0, 91]:
		var centers: Array[Vector2] = []
		for x in range(-1, 2):
			for y in range(-1, 2):
				centers.append(center(Vector2i(x, y), seed_value))
		for a in range(centers.size()):
			for b in range(a + 1, centers.size()):
				for c in range(b + 1, centers.size()):
					var intersection := junction(centers[a], centers[b], centers[c])
					if not intersection.is_finite() or absf(intersection.x) > Biomes.DATA.zone_size or absf(intersection.y) > Biomes.DATA.zone_size:
						continue
					var radius := intersection.distance_to(centers[a])
					if centers.any(func(point): return intersection.distance_to(point) < radius - 1):
						continue
					for x in range(-2, 3):
						for y in range(-2, 3):
							var point := Vector2i(intersection.round()) + Vector2i(x, y)
							var context := Biomes.sample(point, 0, seed_value, 0, .5)
							check(context)
							for step in [Vector2i.RIGHT, Vector2i.DOWN]:
								var neighboring := Biomes.sample(point + step, 0, seed_value, 0, .5)
								var change := distance(Biomes.color_for(context), Biomes.color_for(neighboring))
								samples += 1
								if change > worst:
									worst = change
									evidence = {"seed": seed_value, "point": point, "step": step, "first": context, "second": neighboring}
	print("JUNCTION: ", worst, " ", evidence)
	assert(samples > 0 and worst < .085, "Actual one-pixel triple junctions must not change a positive-weight secondary abruptly")
	var boundary_worst := 0.0
	var boundary_changes := 0
	for base in range(4):
		var heat := -.5 if base == 3 else (.5 if base == 2 else 0.0)
		var rain := -.5 if base == 1 else .5
		for x in range(-6000, 6000, 8):
			var first := Biomes.sample(Vector2i(x, 1000), base, 91, heat, rain)
			var second := Biomes.sample(Vector2i(x + 1, 1000), base, 91, heat, rain)
			check(first)
			check(second)
			boundary_changes += int(first.biome_id != second.biome_id)
			for key in ["color", "earth", "rock"]:
				boundary_worst = maxf(boundary_worst, distance(Biomes.color_for(first, key), Biomes.color_for(second, key)))
	assert(boundary_changes > 0 and boundary_worst < .085, "All climate palettes stay gradual through spatial boundaries")
	var climate_worst := 0.0
	for point in [Vector2i(2541, 2331), Vector2i(-2560, -2560), Vector2i.ZERO]:
		for threshold in [-.22, .23]:
			for rain in [-.5, -.00001, 0.0, .00001, .5]:
				var before := Biomes.sample(point, climate(threshold - .00001, rain), 0, threshold - .00001, rain)
				var after := Biomes.sample(point, climate(threshold + .00001, rain), 0, threshold + .00001, rain)
				check(before)
				check(after)
				for key in ["color", "earth", "rock"]:
					climate_worst = maxf(climate_worst, distance(Biomes.color_for(before, key), Biomes.color_for(after, key)))
		for heat in [-.22, 0.0, .23]:
			var before := Biomes.sample(point, climate(heat, -.00001), 0, heat, -.00001)
			var after := Biomes.sample(point, climate(heat, .00001), 0, heat, .00001)
			check(before)
			check(after)
			for key in ["color", "earth", "rock"]:
				climate_worst = maxf(climate_worst, distance(Biomes.color_for(before, key), Biomes.color_for(after, key)))
	assert(climate_worst < .085, "Climate thresholds and their rain intersections must preserve the same continuous mixture")
	for base in range(4):
		var heat := -.5 if base == 3 else (.5 if base == 2 else 0.0)
		var rain := -.5 if base == 1 else .5
		var shore := Biomes.sample(Vector2i(2541, 2331), base, 0, heat, rain, true)
		check(shore)
		assert(shore.biome_id == "coast" and shore.biome == base)
		var coastal: Array = shore.biome_mix.filter(func(part): return part.id == "coast")
		assert(coastal.size() == 1 and coastal[0].weight == .75)
	var context := Biomes.sample(Vector2i(2541, 2331), 0, 0, 0, .5)
	for invalid in [null, {}, [], [{"id": "unknown", "weight": 1.0}], [{"id": "greenwood", "weight": 0}], [{"id": "greenwood", "weight": NAN}], [{"id": "greenwood", "weight": INF}], [{"id": "greenwood", "weight": .1}, {"id": "marsh", "weight": .9}], [{"id": "greenwood", "weight": .5}], [{"id": "greenwood", "weight": .5}, {"id": "greenwood", "weight": .5}]]:
		var bad: Dictionary = context.duplicate(true)
		bad.biome_mix = invalid
		assert(not Biomes.valid_cell(bad))
	var oversized := []
	for id in Biomes.DATA.profiles.keys().slice(0, 9):
		oversized.append({"id": id, "weight": .125})
	assert(not Biomes.valid_mix(oversized))
	var fallback := {"biome": 2, "biome_id": "desert", "biome_secondary": "desert", "biome_blend": 0.0}
	assert(Biomes.valid_cell(fallback) and Biomes.color_for(fallback).is_equal_approx(Color(Biomes.DATA.profiles.desert.color)))
	print("PASS: actual triple junctions, all spatial palettes, climate/rain corners, coastal ownership, normalized quantized mixtures, JSON/cache identity and malformed records; ", {"junction_samples": samples, "junction_max": worst, "boundary_max": boundary_worst, "climate_max": climate_worst})
	quit()
