extends RefCounted

const CAPACITY := 24
const Catalog = preload("res://scripts/item_catalog.gd")
static var ITEMS: Dictionary = Catalog.definitions
var items: Dictionary = {}
var stolen: Dictionary = {}
var equipment := {"weapon": "", "armor": "", "charm": ""}

func _init() -> void:
	reset()

func reset() -> void:
	stolen.clear()
	items = {"sanctum_sigil": 1, "health_potion": 3, "aether_potion": 2}
	equipment = {"weapon": "", "armor": "", "charm": ""}

func count(id: String) -> int:
	return items.get(id, 0)

func slots_used() -> int:
	var slots := 0
	for id in items:
		slots += ceili(float(items[id]) / ITEMS[id].stack)
	return slots

func add(id: String, quantity: int = 1) -> bool:
	if not ITEMS.has(id) or quantity <= 0 or quantity > 999 or ITEMS[id].kind == "bound":
		return false
	var before := ceili(float(count(id)) / ITEMS[id].stack)
	var after := ceili(float(count(id) + quantity) / ITEMS[id].stack)
	if slots_used() - before + after > CAPACITY:
		return false
	items[id] = count(id) + quantity
	return true

func remove(id: String, quantity: int = 1) -> bool:
	if not ITEMS.has(id) or quantity <= 0 or ITEMS[id].kind == "bound" or count(id) - stolen_count(id) < quantity or count(id) - quantity < (1 if equipment.values().has(id) else 0):
		return false
	items[id] -= quantity
	if items[id] == 0:
		items.erase(id)
	return true

func stolen_count(id: String) -> int:
	var result := 0
	for lot in stolen.values():
		if lot.item == id:
			result += int(lot.quantity)
	return result

func add_owned(id: String, owner: String = "", source: String = "") -> bool:
	if not owner.is_empty() and (source.is_empty() or stolen.has(source)):
		return false
	if not add(id):
		return false
	if not owner.is_empty():
		stolen[source] = {"item": id, "owner": owner, "quantity": 1}
	return true

func take(id: String) -> Dictionary:
	if not ITEMS.has(id) or ITEMS[id].kind == "bound" or count(id) <= (1 if equipment.values().has(id) else 0):
		return {}
	if count(id) > stolen_count(id):
		if remove(id):
			return {"item": id, "owner": "", "source": ""}
		return {}
	for source in stolen.keys():
		if stolen[source].item == id:
			var owner: String = stolen[source].owner
			return_origin(source)
			return {"item": id, "owner": owner, "source": source}
	return {}

func return_origin(source: String) -> bool:
	if not stolen.has(source):
		return false
	var lot: Dictionary = stolen[source]
	for slot in equipment:
		if equipment[slot] == lot.item and count(lot.item) == 1:
			equipment[slot] = ""
	items[lot.item] -= int(lot.quantity)
	if items[lot.item] == 0:
		items.erase(lot.item)
	stolen.erase(source)
	return true

func equip(id: String, class_id: String) -> bool:
	if count(id) <= 0 or ITEMS[id].kind != "equipment" or not ITEMS[id].classes.has(class_id):
		return false
	equipment[ITEMS[id].slot] = id
	return true

func unequip(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	equipment[slot] = ""
	return true

func bonus(key: String) -> float:
	var result := 0.0
	for id in equipment.values():
		if not id.is_empty():
			result += ITEMS[id].get(key, 0)
	return result

func snapshot() -> Dictionary:
	return {"items": items.duplicate(), "equipment": equipment.duplicate(), "stolen": stolen.duplicate(true)}

func restore(data, class_id: String) -> bool:
	if not data is Dictionary or not data.get("items") is Dictionary or not data.get("equipment") is Dictionary:
		return false
	var slots := 0
	for id in data.items:
		var quantity = data.items[id]
		if not ITEMS.has(id) or not (quantity is int or quantity is float) or not is_finite(float(quantity)) or quantity != floorf(quantity) or quantity < 1 or quantity > CAPACITY * ITEMS[id].stack:
			return false
		slots += ceili(float(quantity) / ITEMS[id].stack)
	if slots > CAPACITY or data.items.get("sanctum_sigil") != 1 or data.equipment.size() != 3:
		return false
	var provenance = data.get("stolen", {})
	if not provenance is Dictionary or provenance.size() > 4096:
		return false
	var stolen_totals := {}
	for source in provenance:
		var lot = provenance[source]
		if not source is String or source.is_empty() or source.length() > 400 or not lot is Dictionary or not lot.get("item") is String or not data.items.has(lot.item) or not lot.get("owner") is String or lot.owner.is_empty() or lot.owner.length() > 160 or lot.get("quantity") != 1:
			return false
		stolen_totals[lot.item] = stolen_totals.get(lot.item, 0) + 1
		if stolen_totals[lot.item] > data.items[lot.item]:
			return false
	for slot in equipment:
		var id = data.equipment.get(slot)
		if not id is String or (not id.is_empty() and (not ITEMS.has(id) or ITEMS[id].kind != "equipment" or ITEMS[id].slot != slot or not ITEMS[id].classes.has(class_id) or not data.items.has(id))):
			return false
	items.clear()
	for id in data.items:
		items[id] = int(data.items[id])
	equipment = data.equipment.duplicate()
	stolen = provenance.duplicate(true)
	return true
