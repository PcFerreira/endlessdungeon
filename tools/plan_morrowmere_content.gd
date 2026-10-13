extends SceneTree

const Terrain = preload("res://scripts/dimension_terrain.gd")
const Catalog = preload("res://scripts/dimension_catalog.gd")
const CANDIDATES := [
	["bellfrost", [572,204], [860,220], [780,524], [524,340], "Chimewick", "Quiet Chimes", "Snowmender Lodge", "Frostletter Keep", "castle"],
	["ember_scar", [1468,204], [1756,220], [1676,548], [1388,348], "Kilnrest", "Ashname Garden", "Last Ember Cabin", "The Quiet Kilns", "ruin"],
	["whisperwood", [252,652], [540,668], [460,972], [172,796], "Leafwhistle", "Sleeping Roots", "Mosslamp Cottage", "The Leafbound Choir", "temple"],
	["hearthwild", [828,716], [1116,732], [1360,1184], [796,876], "Mending Green", "Lantern Rest", "Willowcup House", "Mender's Watch", "castle"],
	["prism_coast", [1532,748], [1820,764], [1740,1052], [1460,908], "Brinebright", "Saltname Steps", "Driftglass Hut", "The Manylight Steps", "temple"],
	["glasswake", [252,1228], [540,1244], [460,1548], [172,1372], "Shadecup", "Last Sundial", "Windstitch Cabin", "The Empty Gauge", "ruin"],
	["hollow_orchard", [956,1548], [1244,1564], [1164,1892], [876,1692], "Ciderbend", "Old Graft Garden", "Pippinwood House", "Seedcrown Keep", "castle"],
	["murmur_mire", [1532,1484], [1820,1500], [1716,1772], [1452,1628], "Reedstitch", "Highwater Names", "Wickreed Cabin", "The Highwater Choir", "temple"]
]
var definition: Dictionary
var terrain
var occupied: Array[Rect2i] = []
var road_boxes: Array[Rect2i] = []

func _initialize() -> void:
	definition = Catalog.definition()
	var planned_ids: Array[String] = []
	for row in CANDIDATES:
		for kind in ["village", "graveyard", "woodland_house", row[9]]:
			planned_ids.append(row[0] + "_" + kind)
	terrain = Terrain.new(definition)
	for route in definition.routes:
		if planned_ids.any(func(id): return route.id == "branch_" + id):
			continue
		for index in range(route.path.size() - 1):
			var from := Catalog.point(route.path[index])
			var to := Catalog.point(route.path[index + 1])
			road_boxes.append(Rect2i(Vector2i(mini(from.x,to.x),mini(from.y,to.y)), Vector2i(absi(from.x-to.x)+1,absi(from.y-to.y)+1)).grow(ceili(float(route.width) / 2)))
	for site in definition.sites:
		if site.id in planned_ids:
			continue
		var radius: int = Catalog.site_profile(site.type).radius
		occupied.append(Rect2i(Catalog.point(site.cell) - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1)))
	var added: Array[Dictionary] = []
	for row in CANDIDATES:
		var area: Dictionary = definition.areas.filter(func(record): return record.id == row[0])[0]
		for index in range(4):
			var kind: String = ["village", "graveyard", "woodland_house", row[9]][index]
			var radius: int = Catalog.site_profile(kind).radius
			var seed_cell := Catalog.point(row[index + 1])
			var cell := choose(seed_cell, radius, area)
			assert(cell != Vector2i(-1,-1), "No dry clear construction site near " + str(seed_cell))
			var plot := Rect2i(cell - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1))
			occupied.append(plot)
			added.append({"id": row[0] + "_" + kind, "name": row[index + 5], "type": kind, "area_id": row[0], "cell": [cell.x, cell.y]})
	var file := FileAccess.open("/tmp/morrowmere-new-sites.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(added, "\t"))
	file.close()
	print("PASS: planned %s nonoverlapping natural dry construction footprints" % added.size())
	quit()

func choose(center: Vector2i, radius: int, area: Dictionary) -> Vector2i:
	var trials: Array[Vector2i] = []
	for x in range(-80,81,4):
		for y in range(-80,81,4):
			trials.append(center + Vector2i(x,y))
	trials.sort_custom(func(a,b): return a.distance_squared_to(center) < b.distance_squared_to(center))
	for cell in trials:
		var plot := Rect2i(cell - Vector2i.ONE * radius, Vector2i.ONE * (radius * 2 + 1))
		if not Catalog.box(area.bounds).encloses(plot.grow(4)) or terrain.area_id(cell) != area.id or occupied.any(func(previous): return previous.grow(12).intersects(plot.grow(12))) or road_boxes.any(func(limits): return limits.intersects(plot.grow(3))):
			continue
		if Vector2(cell).distance_to(Vector2(Catalog.point(definition.spawn))) < 80 or Vector2(cell).distance_to(Vector2(Catalog.point(definition.return_portal))) < 80:
			continue
		var dry := true
		for x in range(plot.position.x - 3, plot.end.x + 3):
			for y in range(plot.position.y - 3, plot.end.y + 3):
				if not terrain.land_at(Vector2i(x,y)):
					dry = false
					break
			if not dry:
				break
		if dry:
			return cell
	return Vector2i(-1,-1)
