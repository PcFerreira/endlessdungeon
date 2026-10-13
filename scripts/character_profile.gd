extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Wardrobe = preload("res://scripts/player_wardrobe.gd")
static var registry := Registry.new()
const CLASS_CLOTHING := {
	"mage": {"class_default": "Apprentice robes", "mage_scholar": "Scholar mantle", "mage_battlemage": "Battlemage armor"},
	"sword": {"class_default": "Vanguard armor", "sword_duelist": "Duelist coat", "sword_sentinel": "Sentinel plate"},
	"spellsword": {"class_default": "Runewarden coat", "spellsword_spellblade": "Spellblade armor", "spellsword_cloak": "Arcane cloak"}
}
static var CLOTHING: Dictionary = _clothing()
const ANCESTRIES := {"human": "Human", "elf": "Elf", "dwarf": "Dwarf", "orc": "Orc", "halfling": "Halfling"}
static var SKINS: Array[Color] = Wardrobe.colors("skins")
static var HAIR: Array[Color] = Wardrobe.colors("hair_colors")
static var OUTFITS: Array[Color] = Wardrobe.colors("cloth_colors")
static var HEADS: Dictionary = _heads()
const CHOICE_FIELDS := ["body_type", "beard", "headwear", "outerwear", "gloves", "boots", "belt", "accessory"]
var appearance_version := 2
var display_name := "Wanderer"
var ancestry := "human"
var skin := 0
var hair := 0
var outfit := 0
var head := "short"
var costume := "class_default"
var model := "custom"
var body_type := "regular"
var beard := "none"
var headwear := "none"
var outerwear := "none"
var gloves := "none"
var boots := "travel"
var belt := "plain"
var accessory := "none"
var trim := 4
var trousers := 5
var boots_color := 7
var outer_color := 7
var headwear_color := 0
var eye_color := 0
var eye_shape := 0
var migration_notice := ""

static func _clothing() -> Dictionary:
	var result: Dictionary = CLASS_CLOTHING.duplicate(true)
	for class_id in result:
		for id in Wardrobe.data.collections.costume:
			result[class_id][id] = Wardrobe.data.collections.costume[id].label
	return result

static func _heads() -> Dictionary:
	var result := {"hood": "Hood", "beard": "Beard"}
	for id in Wardrobe.data.collections.head:
		result[id] = Wardrobe.data.collections.head[id].label
	return result

static func premades() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in Wardrobe.data.presets:
		result.append({"id": id, "display_name": Wardrobe.data.presets[id].label, "pack": "generated_voxel", "geometry": "voxel"})
	return result

static func valid_model(id: String) -> bool:
	return id == "custom" or Wardrobe.data.presets.has(id)

static func legacy_model(id: String) -> bool:
	var entry := registry.get_asset(id)
	return not entry.is_empty() and entry.kind == "model" and ("player" in entry.tags or ("npc" in entry.tags and "/Characters/" in entry.path))

static func options(key: String, class_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if key == "model":
		result.append({"id": "custom", "label": "Custom wanderer"})
		for entry in premades():
			result.append({"id": entry.id, "label": entry.display_name})
	elif Wardrobe.COLOR_FIELDS.has(key):
		var palette: Array = Wardrobe.data[Wardrobe.COLOR_FIELDS[key]]
		for index in range(palette.size()):
			result.append({"id": index, "label": palette[index].label, "color": Color(palette[index].color)})
	elif key == "ancestry":
		for id in ANCESTRIES:
			result.append({"id": id, "label": ANCESTRIES[id]})
	elif key == "body_type":
		for id in Wardrobe.data.body_types:
			result.append({"id": id, "label": Wardrobe.data.body_types[id].label})
	elif key == "eye_shape":
		for index in range(3):
			result.append({"id": index, "label": ["Open gaze", "Quiet gaze", "Keen gaze"][index]})
	elif key == "costume":
		for id in CLOTHING.get(class_id, {}):
			result.append({"id": id, "label": CLOTHING[class_id][id]})
	else:
		for id in Wardrobe.data.collections.get(key, {}):
			result.append({"id": id, "label": Wardrobe.data.collections[key][id].label})
	return result

func clothing_for(class_id: String) -> String:
	return costume if CLOTHING[class_id].has(costume) else "class_default"

func snapshot() -> Dictionary:
	var result := {"appearance_version": 2, "name": display_name, "ancestry": ancestry, "head": head, "costume": costume, "model": model, "eye_shape": eye_shape}
	for key in CHOICE_FIELDS + Wardrobe.COLOR_FIELDS.keys():
		result[key] = get(key)
	return result

static func preset_snapshot(id: String, _class_id: String, name: String = "Wanderer") -> Dictionary:
	if not Wardrobe.data.presets.has(id):
		return {}
	var result := new().snapshot()
	result.merge(Wardrobe.data.presets[id].fields, true)
	result.model = id
	result.name = name
	return result

func restore(data, class_id: String = "") -> bool:
	if not data is Dictionary or not data.get("name") is String or not ANCESTRIES.has(data.get("ancestry")) or not HEADS.has(data.get("head")):
		return false
	var name: String = data.name.strip_edges()
	if name.is_empty() or name.length() > 24:
		return false
	for index in range(name.length()):
		if name.unicode_at(index) < 32 or name.unicode_at(index) == 127:
			return false
	var version = data.get("appearance_version", 1)
	if not Wardrobe.number(version) or version != int(version) or int(version) not in [1, 2]:
		return false
	var candidate := new().snapshot()
	candidate.merge(data, true)
	var model_id = candidate.model
	if not model_id is String:
		return false
	var notice := ""
	if not valid_model(model_id):
		if version != 1 or not legacy_model(model_id):
			return false
		candidate.model = "custom"
		notice = "Your former character model now uses an editable voxel body."
	if version == 1:
		if candidate.head == "hood":
			candidate.head = "short"
			candidate.headwear = "hood"
		elif candidate.head == "beard":
			candidate.head = "short"
			candidate.beard = "full"
	for key in Wardrobe.COLOR_FIELDS:
		var value = candidate[key]
		if not Wardrobe.number(value) or value != int(value) or value < 0 or value >= Wardrobe.data[Wardrobe.COLOR_FIELDS[key]].size():
			return false
		candidate[key] = int(value)
	for key in CHOICE_FIELDS:
		var source: Dictionary = Wardrobe.data.body_types if key == "body_type" else Wardrobe.data.collections[key]
		if not candidate[key] is String or not source.has(candidate[key]):
			return false
	if not Wardrobe.number(candidate.eye_shape) or candidate.eye_shape != int(candidate.eye_shape) or candidate.eye_shape < 0 or candidate.eye_shape > 2:
		return false
	var clothing = candidate.costume
	if not clothing is String or not CLOTHING.values().any(func(choices): return choices.has(clothing)) or (not class_id.is_empty() and not CLOTHING.get(class_id, {}).has(clothing)):
		return false
	display_name = name
	ancestry = candidate.ancestry
	head = candidate.head
	costume = clothing
	model = candidate.model
	eye_shape = int(candidate.eye_shape)
	for key in CHOICE_FIELDS + Wardrobe.COLOR_FIELDS.keys():
		set(key, candidate[key])
	appearance_version = 2
	migration_notice = notice
	return true
