extends SceneTree

const World = preload("res://scripts/world.gd")
const Grounds = preload("res://scripts/monster_areas.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Activity = preload("res://scripts/world_activity.gd")

func _initialize() -> void:
	var inhabited := {}
	for edition in [4, 6]:
		var world := World.new()
		world.generate(12345, edition)
		for coordinate in [Vector2i.ZERO, Vector2i(-1, -1), Vector2i(2, -2)]:
			var region: Dictionary = world.region_at(coordinate * world.REGION_SIZE)
			var plans := Grounds.plans(world, region)
			assert(plans.size() >= 7, "Regions need more than the original three creature grounds")
			assert(plans == Grounds.plans(world, region), "Ground planning must remain deterministic")
			assert(plans[0].id == "grounds:%s:%s:0" % [coordinate.x, coordinate.y])
			assert(plans[1].id == "grounds:%s:%s:1" % [coordinate.x, coordinate.y])
			if not region.dungeons.is_empty():
				assert(plans[2].id == "grounds:%s:%s:2" % [coordinate.x, coordinate.y])
			var chunks := {}
			for area in plans:
				assert(not area.label.is_empty() and area.radius >= 3 and area.radius <= 9)
				var center := Vector2i(floori(float(area.cell.x) / world.CHUNK_SIZE), floori(float(area.cell.y) / world.CHUNK_SIZE))
				for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					chunks[center + offset] = true
			var members := {}
			for chunk_at in chunks:
				var chunk: Dictionary = world._build_chunk(chunk_at)
				assert(chunk.spawns.size() <= 2, "Additional grounds must retain the chunk combatant cap")
				assert(chunk.spawns == world._build_chunk(chunk_at).spawns)
				for spawn in chunk.spawns:
					assert(not members.has(spawn.id), "A member must belong to exactly one chunk")
					members[spawn.id] = spawn
					assert(chunk.cells[spawn.cell].walkable and chunk.cells[spawn.cell].terrain == "land")
					assert(world.city_at(Vector2(spawn.cell), Grounds.config.clearance - 13).is_empty())
					assert(Vector2(spawn.cell).distance_to(spawn.home) <= spawn.radius)
					var info: Dictionary = chunk.cells[spawn.cell]
					assert(spawn.kind in Enemies.surface_pool(info.biome, info.facet, info.get("biome_id", "") if world.generator_version >= 6 else ""))
					inhabited["%s:%s" % [edition, spawn.area_id]] = true
			for member in members.values():
				for other in members.values():
					if member.id != other.id and member.area_id == other.area_id:
						assert(Vector2(member.cell).distance_to(other.cell) >= 2, "A pack must start with room between its members")
	assert(inhabited.size() >= 25, "Additional grounds must produce encounters, not just labels")
	var config := Activity.new().data
	assert(Activity.valid(config))
	var invalid := config.duplicate(true)
	invalid.monster_areas.biome_labels["0"] = ["Too few labels"]
	assert(not Activity.valid(invalid))
	print("PASS: expanded populated monster grounds in editions 4/6, negative regions, stable IDs, repeatable chunk spawns, biome eligibility, land/town bounds, spaced pack starts and chunk cap")
	quit()
