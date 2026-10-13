extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Sites = preload("res://scripts/discovery_sites.gd")
const History = preload("res://scripts/regional_history.gd")
const Areas = preload("res://scripts/area_catalog.gd")
const Furnishings = preload("res://scripts/furnishing_catalog.gd")
const MAX_ACTIVE := 4
const PASSAGES := ["title", "author", "text", "ledger_prompt", "inscription", "finding", "completion"]
var definitions: Array[Dictionary] = []
var records: Dictionary = {}
var by_region: Dictionary = {}
var by_giver: Dictionary = {}
var active: Array[String] = []
var errors: Array[String] = []

func _init(entries: Array = []) -> void:
	var source: Array = Registry.new().find("text", ["local-quest"]) if entries.is_empty() else entries
	for entry in source:
		if not _valid_definition(entry):
			errors.append("Invalid local quest: " + str(entry.get("id", "unknown") if entry is Dictionary else "unknown"))
			continue
		if definitions.any(func(existing): return existing.id == entry.id):
			errors.append("Duplicate local quest: " + entry.id)
			continue
		definitions.append(entry.duplicate(true))
	definitions.sort_custom(func(a, b): return a.id < b.id)

static func _strings(value) -> bool:
	return value is Array and not value.is_empty() and value.all(func(text): return History._text(text) and text.length() <= 128)

static func _choices(value, answer) -> bool:
	if not value is Array or value.size() < 2 or value.size() > 4 or not answer is String:
		return false
	var ids := {}
	for choice in value:
		if not choice is Dictionary or not History._text(choice.get("id"), true) or choice.id.length() > 128 or not History._text(choice.get("label"), true) or choice.label.length() > 128 or ids.has(choice.id):
			return false
		ids[choice.id] = true
	return ids.has(answer)

static func _reward(value) -> bool:
	return value is Dictionary and History._text(value.get("item"), true) and value.item.length() <= 512 and History._integer(value.get("quantity"), 1, 9)

static func _valid_definition(entry) -> bool:
	if not entry is Dictionary or not History._text(entry.get("id"), true) or entry.id.length() > 128 or not History._integer(entry.get("version"), 1, 1000000):
		return false
	for field in PASSAGES:
		if not History._text(entry.get(field)) or entry[field].length() > (128 if field in ["title", "author"] else 1500):
			return false
		if not History._text(entry[field].replace("{city_name}", "Town").replace("{dungeon_name}", "Ruin"), true):
			return false
	if not _strings(entry.get("history_motifs")) or not _strings(entry.get("giver_roles")) or not entry.get("requires") is Array or entry.requires != ["compare_inscription"]:
		return false
	if not entry.get("target") is Dictionary or entry.target.get("kind") != "ruin_archive" or not History._text(entry.target.get("label"), true) or entry.target.label.length() > 128:
		return false
	return _choices(entry.get("choices"), entry.get("answer")) and _reward(entry.get("reward")) and not Furnishings.definition(entry.reward.item).is_empty()

func offer(world, region: Dictionary, history: Dictionary, resident: Dictionary) -> Dictionary:
	if region.get("city", {}).is_empty():
		return {}
	if history.is_empty() or resident.get("city_id") != region.city.id or not resident.get("id", "").begins_with(region.city.id + ":npc:"):
		return {}
	if by_region.has(history.region_id):
		var saved: Dictionary = records[by_region[history.region_id]]
		return saved if saved.giver_id == resident.id else {}
	var pool: Array[Dictionary] = []
	for entry in definitions:
		if history.motif in entry.history_motifs and resident.role in entry.giver_roles:
			pool.append(entry)
	if pool.is_empty() or region.city.books.is_empty():
		return {}
	var sites: Array = History.Targets.dungeons(world, region).filter(func(site): return site.id == history.site_id)
	if sites.is_empty():
		return {}
	var site: Dictionary = sites[0]
	var salt: int = hash("local-quest:1:%s" % history.region_id) & 0x7fffffff
	var definition: Dictionary = pool[salt % pool.size()]
	var result := {"id": "quest:%s:%s@%s" % [history.region_id, definition.id, int(definition.version)], "region_id": history.region_id, "run_seed": str(world.run_seed), "template_id": definition.id, "template_version": int(definition.version), "giver_id": resident.id, "city_id": region.city.id, "city_name": region.city.name, "city_cell": [region.city.cell.x, region.city.cell.y], "site_id": site.id, "site_name": site.name, "site_cell": [site.cell.x, site.cell.y], "site_floors": site.floors, "history_id": history.template_id, "history_version": history.template_version, "ledger_text": history.text + "\n\n" + history.book_text, "town_book": region.city.books[0].book_id, "ruin_book": Areas.DUNGEONS[site.family].book, "target": definition.target.duplicate(true), "choices": definition.choices.duplicate(true), "answer": definition.answer, "reward": definition.reward.duplicate(true), "phase": "ledger", "ledger_read": false, "evidence": {}, "reported_choice": "", "reward_claimed": false}
	for field in PASSAGES:
		result[field] = definition[field].replace("{city_name}", region.city.name).replace("{dungeon_name}", site.name)
	result.reward.quantity = int(result.reward.quantity)
	return result

func accept(offer: Dictionary) -> bool:
	if offer.is_empty() or records.has(offer.id) or by_region.has(offer.region_id) or active.size() >= MAX_ACTIVE:
		return false
	if not valid_snapshot({"version": 1, "records": {offer.id: offer}}, offer.run_seed):
		return false
	records[offer.id] = offer.duplicate(true)
	by_region[offer.region_id] = offer.id
	by_giver[offer.giver_id] = offer.id
	active.append(offer.id)
	return true

func record_ledger(id: String, city_id: String, book_id: String) -> bool:
	if not records.has(id):
		return false
	var record: Dictionary = records[id]
	if record.phase != "ledger" or record.city_id != city_id or record.town_book != book_id:
		return false
	record.ledger_read = true
	record.phase = "inscription"
	return true

func inspect(id: String, evidence: Dictionary) -> bool:
	if not records.has(id):
		return false
	var record: Dictionary = records[id]
	if record.phase != "inscription" or not _evidence(evidence, record):
		return false
	record.evidence = evidence.duplicate(true)
	record.phase = "return"
	return true

func report(id: String, giver_id: String, choice: String) -> bool:
	if not records.has(id):
		return false
	var record: Dictionary = records[id]
	if record.phase != "return" or giver_id != record.giver_id or choice != record.answer:
		return false
	record.reported_choice = choice
	record.phase = "completed"
	active.erase(id)
	return true

func claim(id: String, inventory) -> bool:
	if not records.has(id):
		return false
	var record: Dictionary = records[id]
	if record.phase != "completed" or record.reward_claimed or not inventory.add(record.reward.item, int(record.reward.quantity)):
		return false
	record.reward_claimed = true
	return true

static func _point(value) -> bool:
	return value is Array and value.size() == 2 and value.all(func(number): return History._integer(number, -9999999, 9999999))

static func _evidence(value, record: Dictionary) -> bool:
	return value is Dictionary and value.get("site_id") == record.site_id and value.get("book_id") == record.ruin_book and History._integer(value.get("depth"), 1, int(record.site_floors)) and _point(value.get("point"))

func snapshot() -> Dictionary:
	return {"version": 1, "records": records.duplicate(true)}

func reset() -> void:
	records.clear()
	by_region.clear()
	by_giver.clear()
	active.clear()

static func valid_snapshot(data, seed_value: String = "") -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not data.get("records") is Dictionary:
		return false
	var active := 0
	var regions := {}
	for id in data.records:
		var record = data.records[id]
		if not id is String or not record is Dictionary or record.get("id") != id or not History._integer(record.get("template_version"), 1, 1000000) or not History._integer(record.get("history_version"), 1, 1000000) or not History._integer(record.get("site_floors"), 1, 1000):
			return false
		if regions.has(record.get("region_id", "")):
			return false
		regions[record.get("region_id", "")] = true
		for field in PASSAGES + ["region_id", "run_seed", "template_id", "giver_id", "city_id", "city_name", "site_id", "site_name", "history_id", "town_book", "ruin_book", "ledger_text"]:
			if not History._text(record.get(field), true) or (field not in PASSAGES and field != "ledger_text" and record[field].length() > 512):
				return false
		if not record.run_seed.is_valid_int() or (not seed_value.is_empty() and record.run_seed != seed_value) or not _point(record.get("city_cell")) or not _point(record.get("site_cell")):
			return false
		var fields: PackedStringArray = record.region_id.split(":")
		if fields.size() != 5 or fields[0] != "region" or not fields[1].is_valid_int() or int(fields[1]) < 1 or fields[2] != record.run_seed or not fields[3].is_valid_int() or not fields[4].is_valid_int():
			return false
		if record.city_id != "city:%s:%s" % [int(fields[3]), int(fields[4])] or not record.giver_id.begins_with(record.city_id + ":npc:"):
			return false
		if int(fields[1]) >= 5:
			if not History.Targets.valid_city(record.run_seed.to_int(), record.city_id, record.city_cell) or not History.Targets.valid_dungeon(record.run_seed.to_int(), record.site_id, record.site_cell, Vector2i(int(fields[3]), int(fields[4]))):
				return false
		elif not record.site_id.begins_with("ruin:%s:%s:" % [int(fields[3]), int(fields[4])]):
			return false
		if id != "quest:%s:%s@%s" % [record.region_id, record.template_id, int(record.template_version)] or not _choices(record.get("choices"), record.get("answer")) or not _reward(record.get("reward")):
			return false
		if not record.get("target") is Dictionary or record.target.get("kind") != "ruin_archive" or not History._text(record.target.get("label"), true):
			return false
		if record.get("phase") not in ["ledger", "inscription", "return", "completed"] or not record.get("ledger_read") is bool or not record.get("reward_claimed") is bool or not record.get("evidence") is Dictionary:
			return false
		if record.ledger_read != (record.phase != "ledger") or (record.phase in ["ledger", "inscription"] and not record.evidence.is_empty()) or (record.phase in ["return", "completed"] and not _evidence(record.evidence, record)):
			return false
		if record.get("reported_choice") != (record.answer if record.phase == "completed" else "") or (record.reward_claimed and record.phase != "completed"):
			return false
		if record.phase != "completed":
			active += 1
	return active <= MAX_ACTIVE

func restore(data: Dictionary, seed_value: String = "") -> bool:
	if not valid_snapshot(data, seed_value):
		return false
	reset()
	for id in data.get("records", {}):
		var record: Dictionary = data.records[id].duplicate(true)
		for field in ["template_version", "history_version", "site_floors"]:
			record[field] = int(record[field])
		for field in ["city_cell", "site_cell"]:
			record[field] = [int(record[field][0]), int(record[field][1])]
		record.reward.quantity = int(record.reward.quantity)
		if not record.evidence.is_empty():
			record.evidence.depth = int(record.evidence.depth)
			record.evidence.point = [int(record.evidence.point[0]), int(record.evidence.point[1])]
		records[id] = record
		by_region[record.region_id] = id
		by_giver[record.giver_id] = id
		if record.phase != "completed":
			active.append(id)
	return true
