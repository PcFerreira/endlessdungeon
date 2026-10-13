extends RefCounted

const PATH := "res://assets/bundles/catalog.json"
static var data: Dictionary = _load_catalog()

static func _load_catalog() -> Dictionary:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	if not valid(document):
		push_error("Invalid creature/item bundle catalogue: " + PATH)
		return {"enemies": [], "animals": [], "items": []}
	return document

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1:
		return false
	var ids := {}
	for section in ["enemies", "animals", "items"]:
		if not document.get(section) is Array:
			return false
		for entry in document[section]:
			if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or ids.has(entry.id) or not entry.get("name") is String or not entry.get("source_asset") is String:
				return false
			ids[entry.id] = true
			if section == "items":
				if entry.get("kind") not in ["consumable", "equipment", "material", "furnishing"] or not entry.get("icon") is String or not entry.get("description") is String or not number(entry.get("stack")) or entry.stack < 1 or entry.stack > 99 or entry.stack != int(entry.stack):
					return false
				if entry.kind == "equipment" and (entry.get("slot") not in ["weapon", "armor", "charm"] or not entry.get("classes") is Array or entry.classes.is_empty() or not entry.classes.all(func(value): return value in ["mage", "sword", "spellsword"])):
					return false
				for key in ["restore_health", "restore_mana", "hp", "mana", "power"]:
					if entry.has(key) and (not number(entry[key]) or entry[key] < 0 or entry[key] > 100):
						return false
				if entry.has("icon_region") and (not entry.icon_region is Array or entry.icon_region.size() != 4 or not entry.icon_region.all(func(value): return number(value) and value >= 0) or entry.icon_region[2] <= 0 or entry.icon_region[3] <= 0):
					return false
			else:
				for key in ["height", "speed", "weight"]:
					if not number(entry.get(key)) or entry[key] <= 0 or entry[key] > 10:
						return false
				if section == "enemies":
					if not query(entry.get("visual")) or not entry.get("habitat") is Dictionary or not entry.get("ranged") is bool:
						return false
					for key in ["biomes", "facets", "families"]:
						if not entry.habitat.get(key) is Array:
							return false
					if not biomes(entry.habitat.biomes) or not entry.habitat.facets.all(func(value): return value is String) or not entry.habitat.families.all(func(value): return value is String):
						return false
					for key in ["hp", "reach", "damage", "windup", "period"]:
						if not number(entry.get(key)) or entry[key] <= 0 or entry[key] > 1000:
							return false
				else:
					if not query(entry.get("models")) or not biomes(entry.get("biomes")) or not entry.get("habitats") is Array or entry.habitats.is_empty() or not entry.habitats.all(func(value): return value in ["town", "wild", "water"]) or entry.get("medium", "land") not in ["land", "water", "air"]:
						return false
	return true

static func query(value) -> bool:
	return value is Dictionary and value.get("tags") is Array and value.get("pack") is String and value.get("patterns") is Array and not value.patterns.is_empty() and value.tags.all(func(tag): return tag is String) and value.patterns.all(func(pattern): return pattern is String and not pattern.is_empty())

static func biomes(value) -> bool:
	return value is Array and value.all(func(biome): return number(biome) and biome >= 0 and biome <= 3 and biome == int(biome))

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func entries(section: String) -> Array:
	return data.get(section, []).duplicate(true)
