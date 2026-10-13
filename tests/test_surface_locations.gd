extends SceneTree

const World = preload("res://scripts/world.gd")
const Locations = preload("res://scripts/surface_locations.gd")

func _init() -> void:
	assert(Locations.valid(Locations.DATA))
	var bad: Dictionary = Locations.DATA.duplicate(true)
	bad.locations.temple.fixtures[0].support = "unknown"
	assert(not Locations.valid(bad))
	bad = Locations.DATA.duplicate(true)
	bad.locations.church.book = "unknown_book"
	assert(not Locations.valid(bad))
	var kinds := {}
	var facings := {}
	var count := 0
	for seed_value in [0, 91]:
		var world = World.new()
		world.generate(seed_value, 5)
		for x in range(-2, 3):
			for y in range(-2, 3):
				var region: Dictionary = world.region_at(Vector2i(x, y) * World.REGION_SIZE)
				for site in region.locations:
					count += 1
					kinds[site.type] = true
					facings[site.facing] = true
					assert(site.structures.size() >= 6 and site.fixtures.size() >= 9 and site.books.size() == 1)
					world.load_around(Vector2(site.approach))
					assert(world.walkable(Vector2(site.approach)) and world.city_at(Vector2(site.approach)).is_empty())
					var visited := {site.approach: true}
					var queue: Array[Vector2i] = [site.approach]
					var limits: Rect2i = site.footprint.grow(3)
					var cursor := 0
					while cursor < queue.size():
						var cell := queue[cursor]
						cursor += 1
						for direction in World.DIRECTIONS:
							var next: Vector2i = cell + direction
							if limits.has_point(next) and not visited.has(next) and world.can_step(Vector2(cell), Vector2(next)):
								visited[next] = true
								queue.append(next)
					assert(visited.has(Vector2i(site.books[0].approach)) and visited.has(Vector2i(site.rest_point)), "Actual structural collision must leave reader/rest routes open")
					for cell in site.solid_cells:
						assert(not world.walkable(Vector2(cell)), "Rendered walls/fixtures require authoritative collision")
					var supports := {}
					for part in site.fixtures:
						if part.support != "ground":
							assert(supports.has(part.support) and part.cell == supports[part.support].cell)
							assert(is_equal_approx(part.elevation, supports[part.support].elevation + supports[part.support].height))
						supports[part.id] = part
					assert(world.site_by_id(site.id, site.cell) == site)
	assert(count > 12 and kinds.size() == 4 and facings.size() == 4)
	print("PASS: ", count, " actual independent composed sites; four purposes/facings, structural collision, streamed road-to-reader/rest connectivity, exact supported fixtures and actual identities")
	quit()
