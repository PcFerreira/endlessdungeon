extends RefCounted

const STAGES := {"rumor": 0, "seen": 1, "visited": 2}
var seed := ""
var sites: Dictionary = {}

static func point(value) -> bool:
	return value is Array and value.size() == 2 and value.all(func(number): return (number is int or number is float) and is_finite(number) and number == floorf(number) and absf(number) < 10000000)

static func text(value) -> bool:
	return value is String and not value.is_empty() and value.length() <= 512

static func valid_snapshot(data, expected_seed: String = "") -> bool:
	if data is Dictionary and data.is_empty():
		return true
	if not data is Dictionary or data.get("version") != 1 or not data.get("seed") is String or not data.get("sites") is Dictionary:
		return false
	if not data.seed.is_empty() and (not data.seed.is_valid_int() or (not expected_seed.is_empty() and data.seed != expected_seed)):
		return false
	if data.seed.is_empty() and not data.sites.is_empty():
		return false
	for id in data.sites:
		var record = data.sites[id]
		if not text(id) or not record is Dictionary or record.get("id") != id or not text(record.get("name")) or not text(record.get("type")) or record.get("state") not in STAGES or not point(record.get("cell")):
			return false
	return true

func reset() -> void:
	seed = ""
	sites.clear()

func state(id: String) -> String:
	return sites.get(id, {}).get("state", "")

func remember(site: Dictionary, stage: String, run_seed: String) -> bool:
	if stage not in STAGES or not run_seed.is_valid_int() or (not seed.is_empty() and seed != run_seed):
		return false
	var cell = site.get("cell")
	if cell is Vector2i or cell is Vector2:
		cell = [cell.x, cell.y]
	var record := {"id": site.get("id"), "name": site.get("name"), "type": site.get("type"), "cell": cell, "state": stage}
	if not valid_snapshot({"version": 1, "seed": run_seed, "sites": {site.get("id"): record}}, run_seed):
		return false
	var previous: Dictionary = sites.get(site.id, {})
	if not previous.is_empty():
		if previous.type != record.type or previous.cell != record.cell or STAGES[previous.state] >= STAGES[stage]:
			return false
	record.cell = [int(cell[0]), int(cell[1])]
	seed = run_seed
	sites[site.id] = record
	return true

func visible_sites(candidates: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in candidates:
		var stage := state(site.id)
		if stage.is_empty():
			continue
		var record: Dictionary = sites[site.id]
		if record.type != site.type or Vector2(record.cell[0], record.cell[1]) != Vector2(site.cell):
			continue
		var entry: Dictionary = site.duplicate()
		entry.knowledge = stage
		result.append(entry)
	return result

func snapshot() -> Dictionary:
	return {"version": 1, "seed": seed, "sites": sites.duplicate(true)}

func restore(data: Dictionary, expected_seed: String = "") -> bool:
	if not valid_snapshot(data, expected_seed):
		return false
	reset()
	seed = data.get("seed", "")
	for id in data.get("sites", {}):
		var record: Dictionary = data.sites[id].duplicate(true)
		record.cell = [int(record.cell[0]), int(record.cell[1])]
		sites[id] = record
	return true
