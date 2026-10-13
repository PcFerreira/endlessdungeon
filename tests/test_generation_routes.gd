extends SceneTree

const World = preload("res://scripts/world.gd")

func _init() -> void:
	for seed_value in range(64):
		for center in [Vector2i.ONE * (World.REGION_SIZE / 2), -Vector2i.ONE * (World.REGION_SIZE / 2)]:
			var world := World.new()
			world.generate(seed_value)
			world.load_around(Vector2(center))
			var origin: Vector2i = center + Vector2i(0, 3)
			var seen := {origin: true}
			var queue := [origin]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for direction in World.DIRECTIONS:
					var next: Vector2i = cell + direction
					if seen.has(next) or not world.tiles.has(next) or not world.can_step(Vector2(cell), Vector2(next)):
						continue
					if not world.move_actor(Vector2(cell), Vector2(direction)).is_equal_approx(Vector2(next)):
						continue
					seen[next] = true
					queue.append(next)
			for site in world.region_at(center).dungeons:
				assert(seen.has(site.cell + Vector2i(0, 2)), "The actual character footprint must reach each entrance: seed %s, %s" % [seed_value, center])
	print("PASS: 128 positive/negative regions; physical walking routes from sanctuary to dungeon entrances")
	quit()
