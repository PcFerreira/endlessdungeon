extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
static var registry := Registry.new()
const CLOTHING := {
	"mage": {"class_default": "Apprentice robes", "mage_scholar": "Scholar vestments", "mage_battlemage": "Battlemage mantle"},
	"sword": {"class_default": "Vanguard armor", "sword_duelist": "Duelist coat", "sword_sentinel": "Sentinel plate"},
	"spellsword": {"class_default": "Runewarden coat", "spellsword_spellblade": "Spellblade armor", "spellsword_cloak": "Arcane cloak"}
}

const ANCESTRIES := {"human": "Human", "elf": "Elf", "dwarf": "Dwarf"}
const SKINS := [Color("d3b697"), Color("f0d1b4"), Color("bb8b65"), Color("8c5b43"), Color("593d35"), Color("aeabbc")]
const HAIR := [Color("3b2b27"), Color("b78244"), Color("d6c9b2"), Color("672e36"), Color("292633"), Color("888195")]
const OUTFITS := [Color("427aac"), Color("9c4654"), Color("4f856f"), Color("756198"), Color("b18a46"), Color("59616f")]
const HEADS := {"hood": "Hood", "short": "Short hair", "long": "Long hair", "bald": "Shaved", "beard": "Beard"}
var display_name := "Wanderer"
var ancestry := "human"
var skin := 0
var hair := 0
var outfit := 0
var head := "hood"
var costume := "class_default"
var model := "custom"

static func premades() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for entry in registry.find("model"):
		if "player" in entry.tags or ("npc" in entry.tags and "/Characters/" in entry.path):
			choices.append(entry)
	return choices

static func valid_model(id: String) -> bool:
	if id == "custom":
		return true
	for entry in premades():
		if entry.id == id:
			return true
	return false

func clothing_for(class_id: String) -> String:
	return costume if CLOTHING[class_id].has(costume) else "class_default"

func snapshot() -> Dictionary:
	return {"name": display_name, "ancestry": ancestry, "skin": skin, "hair": hair, "outfit": outfit, "head": head, "costume": costume, "model": model}

func restore(data, class_id: String = "") -> bool:
	if not data is Dictionary or not data.get("name") is String or not ANCESTRIES.has(data.get("ancestry")) or not HEADS.has(data.get("head")):
		return false
	var name: String = data.name.strip_edges()
	if name.is_empty() or name.length() > 24:
		return false
	for index in range(name.length()):
		if name.unicode_at(index) < 32 or name.unicode_at(index) == 127:
			return false
	for key in ["skin", "hair", "outfit"]:
		var value = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(value) or value < 0 or value >= 6:
			return false
	var clothing = data.get("costume", "class_default")
	var model_id = data.get("model", "custom")
	if not clothing is String or not model_id is String or not valid_model(model_id):
		return false
	var known := false
	for id in CLOTHING:
		if CLOTHING[id].has(clothing) and (class_id.is_empty() or id == class_id):
			known = true
	if not known:
		return false
	display_name = name
	ancestry = data.ancestry
	skin = int(data.skin)
	hair = int(data.hair)
	outfit = int(data.outfit)
	head = data.head
	costume = clothing
	model = model_id
	return true
