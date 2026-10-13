extends SceneTree

const World = preload("res://scripts/finite_world.gd")
const Catalog = preload("res://scripts/dimension_catalog.gd")
const Constructions = preload("res://scripts/dimension_constructions.gd")

func _initialize() -> void:
	var world := World.new()
	world.generate(12345, 6)
	var data := world.dimension_record()
	var updated := 0
	for recipe in data.sites:
		var site: Dictionary = world.authored_sites().filter(func(record): return record.id.ends_with(":site:" + recipe.id))[0]
		for index in range(recipe.get("residents", []).size()):
			var route: Array = []
			if recipe.type == "city":
				var home: Array = recipe.residents[index].offset
				var dx := -2 if index in [1, 2, 3] else 2
				route = [home, [home[0], home[1] + 2], [home[0] + dx, home[1] + 2], [home[0] + dx, home[1]]]
			elif recipe.type == "village":
				route = [[[-3, 6], [-6, 6], [-6, 8], [-3, 8]], [[4, 7], [6, 7], [6, 8], [4, 8]], [[0, 5], [0, 3], [2, 3], [2, 5]], [[0, 9], [0, 12], [-2, 12], [-2, 9]]][index]
			else:
				route = [[0, 5], [0, 8], [3, 8], [3, 7], [0, 7]]
			var request: Dictionary = recipe.duplicate(true)
			request.residents[index].route = route
			assert(Constructions.valid_site_recipe(request), "Open-ground route must stay clear of " + recipe.id + " construction")
			for waypoint in range(route.size()):
				var from := Vector2(site.cell) + Vector2(route[waypoint][0], route[waypoint][1])
				var next := (waypoint + 1) % route.size()
				var to := Vector2(site.cell) + Vector2(route[next][0], route[next][1])
				for step in range(41):
					var point := from.lerp(to, step / 40.0)
					assert(world._supported(point), "Body-clearance failure in " + recipe.id)
					if site.has("rest_point"):
						assert(point.distance_to(site.rest_point) >= 2, "Walking residents cannot mask E-rest at " + recipe.id)
					for book in site.books:
						assert(point.distance_to(book.approach) >= 2, "Walking residents cannot mask E-read at " + recipe.id)
			recipe.residents[index].route = route
			updated += 1
	assert(Catalog.valid(data))
	var file := FileAccess.open("/tmp/morrowmere-open-area-routes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	print("PASS: %s existing citizens use body-clear two-dimensional court/clearing loops with usable rest/read targets" % updated)
	quit()
