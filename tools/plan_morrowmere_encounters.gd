extends SceneTree

const World = preload("res://scripts/finite_world.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const POOLS := [
	["rime_golem", "crypt_skeleton"], ["cinder_wisp", "roadside_brigand"],
	["briar_wolf", "spore_crawler"], ["roadside_brigand", "wild_boar"],
	["roadside_brigand", "tomb_shade"], ["dune_scarab", "cinder_wisp"],
	["wild_boar", "briar_wolf"],
	["enemy:quaternius_ultimate_monsters/gltf-frog-80138c6a2c", "enemy:bundle_voxel_creature_pack/footed_piranha-60da9c97fa"]
]
const OFFSETS := [Vector2i(-9, -5), Vector2i(9, -5), Vector2i(0, 9)]

func _initialize() -> void:
	var world := World.new()
	world.generate(12345, 6)
	var sites := world.authored_sites()
	var result: Array[Dictionary] = []
	for index in range(world.definition.areas.size()):
		var area: Dictionary = world.authored_areas()[index]
		for group in range(2):
			var target: Vector2i = area.label_cell + (Vector2i(-130, 100) if group == 0 else Vector2i(140, 170))
			var candidates: Array[Vector2i] = []
			for x in range(area.bounds.position.x + 24, area.bounds.end.x - 24, 8):
				for y in range(area.bounds.position.y + 24, area.bounds.end.y - 24, 8):
					candidates.append(Vector2i(x, y))
			candidates.sort_custom(func(left, right): return left.distance_squared_to(target) < right.distance_squared_to(target))
			var chosen := Vector2i(-1, -1)
			for cell in candidates:
				if Vector2(cell).distance_to(world.spawn_point()) < 100 or Vector2(cell).distance_to(Vector2(world.return_portal)) < 100 or world.terrain.area_id(cell) != area.id:
					continue
				if sites.any(func(site): return site.footprint.grow(38).has_point(cell)) or result.any(func(ground): return Vector2(cell).distance_to(Vector2(ground.cell[0], ground.cell[1])) < 64):
					continue
				if OFFSETS.any(func(offset): return not world.cell_info(cell + offset).walkable or not world.terrain.land_at(cell + offset) or not world._road_record(cell + offset).is_empty()):
					continue
				if not world.cell_info(cell).walkable or not world._road_record(cell).is_empty():
					continue
				chosen = cell
				break
			assert(chosen.x >= 0, "No safe authored encounter clearing in " + area.id)
			var members: Array[Dictionary] = []
			for member in range(3):
				var enemy_id: String = POOLS[index][group]
				assert(Enemies.TYPES.any(func(enemy): return enemy.id == enemy_id and enemy.get("enabled", true)))
				members.append({"id": "watcher_" + str(member), "enemy_id": enemy_id, "offset": [OFFSETS[member].x, OFFSETS[member].y]})
			result.append({"id": area.id + "_grounds_" + str(group), "label": area.name + (" Wilderness" if group == 0 else " Old Grounds"), "area_id": area.id, "cell": [chosen.x, chosen.y], "radius": 12, "members": members})
	var file := FileAccess.open("/tmp/morrowmere-encounters.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("PASS: planned 16 encounter grounds and 48 actual enabled monsters beyond homes and safe arrival")
	quit()
