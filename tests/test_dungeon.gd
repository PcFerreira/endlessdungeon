extends SceneTree

const Dungeon = preload("res://scripts/dungeon.gd")

func _init() -> void:
	for depth in [1, 2, 8, 100, 1000000]:
		for run_seed in range(40):
			var dungeon = Dungeon.new()
			dungeon.generate(run_seed, depth)
			assert(dungeon.tiles.has(dungeon.start), "Start must be walkable")
			assert(dungeon.tiles.has(dungeon.exit), "Exit must be walkable")
			assert(dungeon.start != dungeon.exit, "Exit must differ from start")
			var visited := {dungeon.start: true}
			var frontier := [dungeon.start]
			while not frontier.is_empty():
				var cell: Vector2i = frontier.pop_back()
				for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var neighbor: Vector2i = cell + step
					if dungeon.tiles.has(neighbor) and not visited.has(neighbor):
						visited[neighbor] = true
						frontier.append(neighbor)
			assert(visited.size() == dungeon.tiles.size(), "Every tile must be reachable")
			assert(dungeon.spawns.size() > 0 and dungeon.spawns.size() <= 24)
			var occupied := {}
			for spawn in dungeon.spawns:
				assert(dungeon.tiles.has(spawn.cell))
				assert(Vector2(spawn.cell).distance_to(Vector2(dungeon.start)) > 5.0)
				assert(spawn.cell != dungeon.exit)
				assert(not occupied.has(spawn.cell), "Spawns must be unique")
				occupied[spawn.cell] = true
			var replay = Dungeon.new()
			replay.generate(run_seed, depth)
			assert(replay.tiles == dungeon.tiles and replay.spawns == dungeon.spawns)
	print("PASS: 200 seeded floors; connectivity, exits, unique spawns, bounded depth, determinism")
	quit()
