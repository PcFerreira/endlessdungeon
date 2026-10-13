extends SceneTree

const World = preload("res://scripts/hub_world.gd")

func _initialize() -> void:
	var world := World.new()
	world.generate(int(OS.get_environment("WORLD_SEED")), 4)
	world.load_around(world.spawn_point())
	for x in range(world.bounds.position.x + 2, world.bounds.end.x - 2):
		if posmod(x, World.CHUNK_SIZE) != 0:
			continue
		for y in range(world.bounds.position.y + 2, world.bounds.end.y - 2):
			var point := Vector2(float(x) - .3, y)
			if not world.walkable(point) or world.safe_position(point) != point:
				continue
			if world.move_actor(point, Vector2.RIGHT * 1.5).distance_to(point + Vector2.RIGHT * 1.5) > .001:
				continue
			print("CHUNK_CROSSING_PROBE " + JSON.stringify({"position": [point.x, point.y], "direction": [1, 0]}))
			quit(0)
			return
	quit(1)
