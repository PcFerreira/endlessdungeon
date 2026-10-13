extends SceneTree

const Rooms = preload("res://scripts/interior_area.gd")
const View = preload("res://scripts/interior_view.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Dressing = preload("res://scripts/interior_dressing.gd")
const Scenery = preload("res://scripts/scenery.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var area := Rooms.new()
	if area.get("biome") == null:
		printerr("FAIL: town interiors need their actual owning-city biome")
		quit(1)
		return
	check(Dressing.valid(Dressing.data), "Purposeful interior ensembles must validate")
	var broken := Dressing.data.duplicate(true)
	broken.table_contents.home[0].point = [2, 0]
	check(not Dressing.valid(broken), "Supplies must stay on their real supporting surface")
	broken = Dressing.data.duplicate(true)
	broken.table_contents.home[1].support = "missing"
	check(not Dressing.valid(broken), "Supplies require an existing support")
	var wrong := Rooms.new()
	wrong.generate({"id": "saved-role-rejection", "type": "home", "biome": 2, "variants": {"0": "native_environment:flat_lowpoly:coffin"}})
	check(wrong.props[0].kind != "native_environment:flat_lowpoly:coffin", "A compatible family must not make an incompatible saved object purpose eligible")
	var styles := Styles.new()
	var scenery := Scenery.new()
	var count := 0
	for definition in Rooms.content.entries("interiors"):
		for layout in definition.layouts:
			for biome in range(4):
				for seed_value in range(4):
					var place := {"id": "style:%s:%s:%s" % [definition.id, layout.id, seed_value], "type": definition.id, "layout_id": layout.id, "biome": biome, "use_id": "scribe" if seed_value == 3 else ""}
					var room := Rooms.new()
					room.generate(place)
					var replay := Rooms.new()
					replay.generate(place.duplicate(true))
					count += 1
					check(room.props == replay.props and room.obstacles == replay.obstacles, "Family-bound density and supported materials must replay")
					var authored: Array = Rooms.content.data.interior_defaults.props + layout.props
					for index in range(authored.size()):
						check(room.props[index].source_key == str(index), "Original authored source indices must remain stable")
						check(room.props[index].point == Vector2(authored[index].point[0], authored[index].point[1]), "Original authored fixtures must keep their positions")
					var primary: Array = room.props.filter(func(prop): return prop.solid)
					var target := mini(int(Dressing.data.fixture_cap), ceili(room.tiles.size() / float(Dressing.data.cells_per_fixture)))
					check(primary.size() >= target, "Every actual room must meet purposeful fixture density: %s/%s/%s" % [definition.id, layout.id, seed_value])
					var supports := {}
					for prop in room.props:
						check(styles.allows(prop.kind, biome) and prop.visual_family == styles.family_for(biome), "Every actual interior model must follow its owning city biome")
						check(not supports.has(prop.source_key), "Interior source keys must be unique")
						if not prop.parent.is_empty():
							check(supports.has(prop.parent), "Supplies must retain actual support identities")
							if supports.has(prop.parent):
								var support: Dictionary = supports[prop.parent]
								check(is_equal_approx(prop.elevation, support.elevation + support.height), "Supplies must touch their actual supporting top")
								check(Rect2(support.point - support.footprint * .5, support.footprint).grow(.001).encloses(Rect2(prop.point - prop.footprint * .5, prop.footprint)), "Supplies must remain inside their support footprint")
						if prop.fallback in ["table", "workbench"]:
							check(room.props.any(func(child): return child.parent == prop.source_key), "Working tables must have supporting materials")
						supports[prop.source_key] = prop
					var seen := {room.start: true}
					var queue: Array[Vector2i] = [room.start]
					var cursor := 0
					while cursor < queue.size():
						var cell := queue[cursor]
						cursor += 1
						for direction in room.DIRECTIONS:
							var next: Vector2i = cell + direction
							if not seen.has(next) and room.can_step(Vector2(cell), Vector2(next)):
								seen[next] = true
								queue.append(next)
					check(seen.has(room.exit), "Dressing must preserve physical door access")
					for readable in room.readables:
						check(seen.has(Vector2i(readable.approach)), "Dressing must preserve physical reader access")
					if room.rest_point != Vector2.ZERO:
						check(seen.has(Vector2i(room.rest_point)), "Dressing must preserve physical rest access")
					if Dressing.stores.interiors.has(definition.id):
						var point: Array = Dressing.stores.interiors[definition.id].point
						check(room.walkable(Vector2(point[0], point[1])), "Dressing must preserve the actual trade counter approach")
					if seed_value == 0:
						var view := View.new()
						view.build(room)
						check(view.biome == biome and view.visual_family == styles.family_for(biome), "Interior rendering must retain actual climate context")
						check(view.prop_nodes.size() == room.props.size(), "Every purposeful fixture/supply must render")
						for index in range(room.props.size()):
							var prop: Dictionary = room.props[index]
							var box := scenery.bounds(view.prop_nodes[index])
							check(is_equal_approx(box.size.x, prop.footprint.x) and is_equal_approx(box.size.z, prop.footprint.y), "Actual interior models must fit their declared footprints")
						for child in view.get_children():
							if child.has_meta("asset_id"):
								check(styles.allows(child.get_meta("asset_id"), biome), "Actual floors/readables/lamps/exit mat must match the biome")
						view.free()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("PASS: %s biome-bound furnished interiors; source replay/identity, purposeful density/materials, supports, rendered bounds and physical reader/rest/trade/exit access" % count if failures.is_empty() else "FAIL: interior style/density")
	quit(0 if failures.is_empty() else 1)
