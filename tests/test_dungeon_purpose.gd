extends SceneTree

const Dungeon = preload("res://scripts/dungeon.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Dressing = preload("res://scripts/dungeon_dressing.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _initialize() -> void:
	var density_sample := Dungeon.new()
	density_sample.generate(12345, 1, "dungeon_ashen_crypt")
	var sample_count: int = density_sample.decorations.filter(func(prop): return prop.get("room_index", -1) == 0).size()
	if sample_count < ceili(density_sample.rooms[0].get_area() / 7.0):
		printerr("FAIL: room-size density requires several furnished groups rather than one sparse corner")
		quit(1)
		return
	var store: Array = density_sample.decorations.filter(func(prop): return prop.get("room_index", -1) == 2)
	check(store.all(func(prop): return prop.has("wall")), "The attendant store needs edge storage and an open working floor")
	var working_sample := Dungeon.new()
	working_sample.generate(12345, 1, "dungeon_violet_sanctum")
	var desks: Array = working_sample.decorations.filter(func(prop): return prop.get("room_index", -1) == 0 and prop.recipe_id == "registration")
	check(desks.size() == 1, "A registration room needs one main desk with surrounding records and seating")
	if not failures.is_empty():
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
		return
	check(Dressing.valid(Dressing.data), "All dungeon families need supported room ensembles")
	var invalid := Dressing.data.duplicate(true)
	invalid.templates.registration.contents.clear()
	check(not Dressing.valid(invalid), "An empty table cannot claim a working desk purpose")
	invalid = Dressing.data.duplicate(true)
	invalid.templates.registration.contents[0].point = [2, 2]
	check(not Dressing.valid(invalid), "Work materials must remain on their supporting desk")
	invalid = Dressing.data.duplicate(true)
	invalid.families.dungeon_ashen_crypt["Burial chamber"] = ["burial"]
	check(not Dressing.valid(invalid), "A room needs an ensemble rather than one arbitrary prop")
	for family in Areas.DUNGEONS:
		print("Auditing purpose and density: " + family)
		for seed_value in range(12):
			for depth in [1, 8, 20]:
				var dungeon := Dungeon.new()
				dungeon.generate(seed_value, depth, family)
				var replay := Dungeon.new()
				replay.generate(seed_value, depth, family)
				check(dungeon.decorations == replay.decorations, "Room purpose must replay deterministically")
				for index in range(dungeon.rooms.size()):
					var furnishings: Array = dungeon.decorations.filter(func(prop): return prop.get("room_index", -1) == index)
					check(furnishings.size() >= ceili(dungeon.rooms[index].get_area() / 7.0), "Every actual room needs density in proportion to its size: %s/%s/%s/%s" % [family, seed_value, depth, index])
				for prop in dungeon.decorations:
					check(prop.get("room_role", "") in dungeon.room_roles, "Every dungeon prop needs its actual room role")
					check(not prop.get("purpose", "").is_empty(), "Every dungeon prop needs a purpose")
					if prop.kind == "table":
						check(not prop.get("contents", []).is_empty(), "Dungeon tables need visible work materials")
					if family in ["dungeon_ashen_crypt", "dungeon_verdant_tomb"]:
						check(prop.kind not in ["bed", "table"], "Burial families must use burial/memorial assets")
					check(prop.get("room_index", -1) >= 0, "Purpose must bind to a concrete room")
				var seen := {dungeon.start: true}
				var queue := [dungeon.start]
				while not queue.is_empty():
					var cell: Vector2i = queue.pop_back()
					for direction in dungeon.DIRECTIONS:
						var next: Vector2i = cell + direction
						if not seen.has(next) and dungeon.can_step(Vector2(cell), Vector2(next)) and dungeon.move_actor(Vector2(cell), Vector2(direction)).is_equal_approx(Vector2(next)):
							seen[next] = true
							queue.append(next)
				check(seen.has(dungeon.exit), "Purposeful dressing must preserve the physical exit route: %s/%s/%s" % [family, seed_value, depth])
				for readable in dungeon.readables:
					check(seen.has(Vector2i(readable.approach)), "Purposeful dressing must preserve book access: %s/%s/%s" % [family, seed_value, depth])
				for spawn in dungeon.spawns:
					check(seen.has(spawn.cell), "Every enemy must remain physically reachable: %s/%s/%s" % [family, seed_value, depth])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: 216 family floors; actual room purposes, visibly equipped tables, burial assets, deterministic dressing and physical book/exit access" if failures.is_empty() else "FAIL: dungeon purpose")
	quit(0 if failures.is_empty() else 1)
