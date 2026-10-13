extends SceneTree

const World = preload("res://scripts/hub_world.gd")

func _initialize() -> void:
	var world := World.new()
	world.generate(int(OS.get_environment("WORLD_SEED")), 4)
	var spawn := Vector2i(world.spawn_point().round())
	world.load_around(Vector2(spawn))
	for x in range(spawn.x - 12, spawn.x + 12):
		for y in range(spawn.y - 12, spawn.y + 12):
			var point := Vector2(x, y)
			if not world.walkable(point) or world.safe_position(point) != point:
				continue
			for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				if world.walkable(point + axis):
					continue
				print("COLLISION_PROBE " + JSON.stringify({"position": [x, y], "direction": [axis.x, axis.y]}))
				quit(0)
				return
	quit(1)
