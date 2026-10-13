extends RefCounted

const Biomes = preload("res://scripts/biome_catalog.gd")
static var DATA: Dictionary = _read()

static func _read() -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://config/foraging.json"))
	assert(valid(value),"Invalid foraging catalogue")
	return value

static func integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == int(value) and value >= low and value <= high

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("items") is Dictionary or value.items.is_empty() or not value.get("biomes") is Dictionary:
		return false
	for key in ["spacing", "max_nodes", "ledger_limit"]:
		if not integer(value.get(key),1,65536):
			return false
	for key in ["patch_chance", "reach"]:
		if not (value.get(key) is float or value.get(key) is int) or not is_finite(value[key]) or value[key] <= 0 or value[key] > (1 if key == "patch_chance" else 2):
			return false
	if value.spacing < 3 or value.spacing > 12 or value.max_nodes > 128:
		return false
	for id in value.items:
		var item = value.items[id]
		if not id is String or not id.begins_with("forage_") or not item is Dictionary or item.get("kind") != "material" or not integer(item.get("stack"),1,99) or not integer(item.get("trade_value"),1,99) or item.get("rarity") not in ["common","uncommon","rare"]:
			return false
		for key in ["name", "description", "icon", "forage_color"]:
			if not item.get(key) is String or item[key].is_empty():
				return false
		if not item.icon.begins_with("res://assets/foraging/") or not item.icon.ends_with(".svg") or ".." in item.icon or not FileAccess.file_exists(item.icon) or not Color.html_is_valid(item.forage_color) or item.get("forage_shape") not in ["herb","berry","fungus","mineral","shell"]:
			return false
		var yield_range = item.get("yield")
		if not yield_range is Array or yield_range.size() != 2 or not integer(yield_range[0],1,3) or not integer(yield_range[1],int(yield_range[0]),3):
			return false
	if value.biomes.size() != Biomes.DATA.profiles.size():
		return false
	for biome in Biomes.DATA.profiles:
		var profile = value.biomes.get(biome)
		if not profile is Dictionary or profile.get("habitat") != "land" or not profile.get("entries") is Array or profile.entries.is_empty():
			return false
		for entry in profile.entries:
			if not entry is Dictionary or not value.items.has(entry.get("item")) or not integer(entry.get("weight"),1,32):
				return false
	return true

static func scope(world) -> String:
	var realm = world.get("dimension_id")
	if realm is String and not realm.is_empty():
		return "realm:%s:%s" % [realm,world.map_version]
	return "endless:%s:%s" % [world.run_seed,world.generator_version]

static func plan(world, grid: Vector2i) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = hash("forage:%s:%s:%s" % [scope(world),grid.x,grid.y])
	if random.randf() >= DATA.patch_chance:
		return {}
	var cell := grid * int(DATA.spacing) + Vector2i(random.randi_range(0,int(DATA.spacing) - 1),random.randi_range(0,int(DATA.spacing) - 1))
	var info: Dictionary = world.cell_info(cell)
	if not info.get("walkable",false) or info.get("terrain", "") != "land" or not info.get("hub_id", "").is_empty() or not world.city_at(Vector2(cell),4).is_empty():
		return {}
	var region: Dictionary = world.region_at(cell)
	for house in region.get("city", {}).get("houses", []):
		if house.footprint.grow(2).has_point(cell):
			return {}
	for site in region.get("dungeons", []) + region.get("locations", []):
		if Vector2(cell).distance_to(Vector2(site.cell)) < 4 or (site.has("footprint") and site.footprint.grow(2).has_point(cell)):
			return {}
	var biome: String = info.get("biome_id",Biomes.LEGACY_IDS[int(info.biome)])
	if not DATA.biomes.has(biome):
		return {}
	var entries: Array = DATA.biomes[biome].entries
	var weight := 0
	for entry in entries:
		weight += int(entry.weight)
	var roll := random.randi_range(1,weight)
	var item := ""
	for entry in entries:
		roll -= int(entry.weight)
		if roll <= 0:
			item = entry.item
			break
	var amount: Array = DATA.items[item]["yield"]
	return {"id":"%s@%s,%s" % [scope(world),grid.x,grid.y],"grid":grid,"point":Vector2(cell),"item":item,"quantity":random.randi_range(int(amount[0]),int(amount[1])),"biome_id":biome,"biome":int(info.biome)}
