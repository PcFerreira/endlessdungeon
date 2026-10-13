extends RefCounted

const Inventory = preload("res://scripts/inventory.gd")
const MAX_RECORDS := 4096
const MAX_LOCAL := 128
const MAX_STACK := 4
var removed: Dictionary = {}
var placed: Array[Dictionary] = []
var crimes: Dictionary = {}
var bases: Dictionary = {}
var next_id := 1
var checkpoint := ""
var claim_cache: Dictionary = {}
var error := ""

func reset() -> void:
	removed.clear()
	placed.clear()
	crimes.clear()
	bases.clear()
	next_id = 1
	checkpoint = ""
	claim_cache.clear()
	error = ""

func pickup(record: Dictionary, inventory) -> bool:
	error = ""
	if not valid_record(record):
		error = "This object cannot be taken."
		return false
	if placed.any(func(child): return child.parent == record.uid):
		error = "Take the objects on this support first."
		return false
	var index := -1
	for i in range(placed.size()):
		if placed[i].uid == record.uid:
			index = i
	if index >= 0:
		record = placed[index]
	if index < 0 and (removed.has(record.uid) or removed.size() >= MAX_RECORDS):
		error = "This object is already taken, or your world has reached its object limit."
		return false
	var owner: String = record.get("owner", "")
	var source: String = record.get("source", record.uid) if not owner.is_empty() else ""
	if not inventory.add_owned(record.item, owner, source):
		error = "Your backpack is full. The object stays here."
		return false
	if index >= 0:
		placed.remove_at(index)
	else:
		removed[record.uid] = record.duplicate(true)
		if not owner.is_empty() and not crimes.has(owner):
			crimes[owner] = "demand"
		claim_cache.erase(owner)
	return true

func place(item: String, scope: String, point: Vector2, rotation: int, inventory, extra: Dictionary = {}) -> bool:
	error = ""
	var candidate := {"uid": "p:%s" % next_id, "item": item, "scope": scope, "point": [point.x, point.y], "rotation": rotation, "owner": "", "source": "", "parent": ""}
	for key in extra:
		if key not in ["parent", "footprint", "height", "elevation", "solid"]:
			error = "Unsupported placement data."
			return false
	candidate.merge(extra, true)
	if not valid_record(candidate) or not valid_stacks(placed + [candidate]):
		error = "This placement is invalid."
		return false
	if placed.size() >= MAX_RECORDS or placed.filter(func(record): return record.scope == scope).size() >= MAX_LOCAL:
		error = "This area holds up to %s placed objects." % MAX_LOCAL
		return false
	var taken: Dictionary = inventory.take(item)
	if taken.is_empty():
		error = "Unequip this item before placing it."
		return false
	var record: Dictionary = candidate
	record.owner = taken.owner
	record.source = taken.source
	placed.append(record)
	next_id += 1
	return true

func wanted(city_id: String) -> Dictionary:
	if claim_cache.has(city_id):
		return claim_cache[city_id].duplicate(true)
	var items := {}
	for record in removed.values():
		if record.get("owner", "") == city_id:
			items[record.item] = items.get(record.item, 0) + 1
	var result := {}
	if not items.is_empty():
		result = {"city_id": city_id, "status": crimes.get(city_id, "demand"), "hostile": crimes.get(city_id, "demand") == "hostile", "items": items, "count": items.values().reduce(func(total, amount): return total + amount, 0)}
	claim_cache[city_id] = result
	while claim_cache.size() > 256:
		claim_cache.erase(claim_cache.keys()[0])
	return result.duplicate(true)

func refuse_return(city_id: String) -> bool:
	if wanted(city_id).is_empty():
		return false
	crimes[city_id] = "hostile"
	claim_cache.erase(city_id)
	return true

func return_stolen(city_id: String, inventory) -> bool:
	if wanted(city_id).is_empty():
		return false
	var returning := {}
	for record in placed:
		if record.owner == city_id:
			returning[record.uid] = true
	for record in placed:
		if record.owner != city_id and returning.has(record.parent):
			error = "Take the other objects off the city's property before returning it."
			return false
	for uid in removed.keys():
		if removed[uid].get("owner", "") != city_id:
			continue
		var retained: bool = inventory.stolen.has(uid) or placed.any(func(record): return record.source == uid)
		if not retained:
			error = "Recover the city's missing goods before asking for peace."
			return false
	for uid in removed.keys():
		if removed[uid].get("owner", "") != city_id:
			continue
		inventory.return_origin(uid)
		placed = placed.filter(func(record): return record.source != uid)
		removed.erase(uid)
	crimes.erase(city_id)
	claim_cache.erase(city_id)
	error = ""
	return true

func claim_base(site_id: String, cleared: bool) -> bool:
	if not cleared or site_id.is_empty() or bases.has(site_id) or bases.size() >= MAX_RECORDS:
		error = "Clear every floor and claim the final chest before taking this base."
		return false
	bases[site_id] = {}
	error = ""
	return true

func snapshot() -> Dictionary:
	return {"version": 1, "next_id": next_id, "removed": removed.duplicate(true), "placed": placed.duplicate(true), "crimes": crimes.duplicate(), "bases": bases.duplicate(true), "checkpoint": checkpoint}

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_stacks(records: Array) -> bool:
	var ids := {}
	for record in records:
		ids[record.uid] = record
	for record in records:
		var seen := {record.uid: true}
		var child: Dictionary = record
		var parent: String = record.parent
		while not parent.is_empty():
			if seen.has(parent) or seen.size() >= MAX_STACK:
				return false
			seen[parent] = true
			if not ids.has(parent):
				if parent.begins_with("p:"):
					return false
				break
			var support: Dictionary = ids[parent]
			if support.scope != record.scope:
				return false
			if not is_equal_approx(float(child.get("elevation", 0)), float(support.get("elevation", 0)) + float(support.get("height", .45))):
				return false
			var size: Array = child.get("footprint", [.35, .35])
			var support_size: Array = support.get("footprint", [.35, .35])
			var child_box := Rect2(Vector2(child.point[0], child.point[1]) - Vector2(size[0], size[1]) * .5, Vector2(size[0], size[1]))
			var support_box := Rect2(Vector2(support.point[0], support.point[1]) - Vector2(support_size[0], support_size[1]) * .5, Vector2(support_size[0], support_size[1]))
			if not support_box.grow(.001).encloses(child_box):
				return false
			child = support
			parent = support.parent
	return true

static func valid_record(record) -> bool:
	if not record is Dictionary:
		return false
	for key in ["uid", "item", "scope", "owner", "parent"]:
		if not record.get(key) is String or record[key].length() > 400:
			return false
	if record.uid.is_empty() or record.scope.is_empty() or not Inventory.ITEMS.has(record.item) or Inventory.ITEMS[record.item].kind == "bound":
		return false
	if not record.get("point") is Array or record.point.size() != 2 or not record.point.all(func(value): return number(value) and absf(value) <= 9600000):
		return false
	if record.has("rotation") and (not number(record.rotation) or record.rotation != int(record.rotation) or int(record.rotation) not in [0, 1, 2, 3]):
		return false
	for key in ["footprint"]:
		if record.has(key) and (not record[key] is Array or record[key].size() != 2 or not record[key].all(func(value): return number(value) and value > 0 and value <= 6)):
			return false
	for key in ["height", "elevation"]:
		if record.has(key) and (not number(record[key]) or record[key] < 0 or record[key] > (18 if key == "elevation" else 6)):
			return false
	if record.has("solid") and not record.solid is bool:
		return false
	for key in ["blocked_cells", "access_cells"]:
		if not record.has(key):
			continue
		if not record[key] is Array or record[key].size() > 16:
			return false
		for cell in record[key]:
			if not cell is Array or cell.size() != 2 or not cell.all(func(value): return number(value) and value == int(value) and absf(value) <= 9600000):
				return false
	return true

static func valid(data) -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not number(data.get("next_id")) or data.next_id != int(data.next_id) or data.next_id < 1 or data.next_id > 2000000000:
		return false
	for key in ["removed", "crimes", "bases"]:
		if not data.get(key) is Dictionary or data[key].size() > MAX_RECORDS:
			return false
	if not data.get("placed") is Array or data.placed.size() > MAX_RECORDS:
		return false
	var seen := {}
	var local := {}
	var sources := {}
	var owners := {}
	for uid in data.removed:
		var record = data.removed[uid]
		if not valid_record(record) or uid != record.uid:
			return false
		if not record.owner.is_empty():
			owners[record.owner] = true
	for record in data.placed:
		if not valid_record(record) or not record.get("source") is String or not record.uid.begins_with("p:") or not record.uid.substr(2).is_valid_int() or record.uid.substr(2).to_int() < 1 or record.uid.substr(2).to_int() >= data.next_id or seen.has(record.uid):
			return false
		seen[record.uid] = true
		local[record.scope] = local.get(record.scope, 0) + 1
		if local[record.scope] > MAX_LOCAL:
			return false
		if not record.owner.is_empty():
			if not data.removed.has(record.source) or data.removed[record.source].owner != record.owner or data.removed[record.source].item != record.item or sources.has(record.source):
				return false
			sources[record.source] = true
		elif not record.source.is_empty():
			return false
	for city in data.crimes:
		if not city is String or not owners.has(city) or data.crimes[city] not in ["demand", "hostile"]:
			return false
	if not valid_stacks(data.placed):
		return false
	for site in data.bases:
		if not site is String or site.is_empty() or site.length() > 160 or not data.bases[site] is Dictionary:
			return false
		var base: Dictionary = data.bases[site]
		if base.is_empty():
			continue
		if not base.get("scope") is String or not number(base.get("floor")) or base.floor != int(base.floor) or base.floor < 1 or base.floor > 20:
			return false
		if base.scope != "dungeon:%s:floor%s" % [site, int(base.floor)]:
			return false
		for key in ["point", "cell"]:
			if not base.get(key) is Array or base[key].size() != 2 or not base[key].all(func(value): return number(value) and absf(value) <= 9600000):
				return false
	if not data.get("checkpoint", "") is String or (not data.get("checkpoint", "").is_empty() and (not data.bases.has(data.checkpoint) or data.bases[data.checkpoint].is_empty())):
		return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	reset()
	if data.is_empty():
		return true
	removed = data.removed.duplicate(true)
	placed.assign(data.placed.duplicate(true))
	crimes = data.crimes.duplicate()
	bases = data.bases.duplicate(true)
	next_id = int(data.next_id)
	checkpoint = data.get("checkpoint", "")
	return true
