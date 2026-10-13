extends RefCounted

const CLASSES := {
	"mage": {"name": "Mage", "description": "Ranged magic, frost control, and teleportation.", "hp": 100.0, "mana": 100.0, "regen": 9.0, "resource": "Aether", "starter": ["bolt", "fire", "nova", "blink"], "specialty": "storm", "utility": "mend", "advanced": "meteor"},
	"sword": {"name": "Sword", "description": "Close combat, sweeping attacks, and defensive stance.", "hp": 140.0, "mana": 100.0, "regen": 14.0, "resource": "Stamina", "starter": ["strike", "cleave", "guard", "dash"], "specialty": "whirlwind", "utility": "second_wind", "advanced": "execute"},
	"spellsword": {"name": "Spellsword", "description": "A sword in one hand and arcane power in the other.", "hp": 120.0, "mana": 100.0, "regen": 10.0, "resource": "Aether", "starter": ["strike", "bolt", "fire", "blink"], "specialty": "runeblade", "utility": "nova", "advanced": "mend"}
}
const ABILITIES := {
	"bolt": {"name": "Arcane Bolt", "short": "Bolt", "description": "A free projectile that follows your selected enemy.", "kind": "projectile", "cost": 0.0, "recharge": .30, "range": 7.5, "damage": 20.0, "radius": 0.0, "color": Color("82eadd")},
	"fire": {"name": "Ember Orb", "short": "Ember", "description": "An orb that bursts around your selected enemy.", "kind": "projectile", "cost": 24.0, "recharge": 1.25, "range": 7.5, "damage": 58.0, "radius": 2.0, "color": Color("ffa16b")},
	"nova": {"name": "Frost Nova", "short": "Frost", "description": "Freeze the ground, damaging and slowing nearby enemies.", "kind": "area", "cost": 28.0, "recharge": 5.0, "range": 0.0, "damage": 22.0, "radius": 3.0, "color": Color("8ecffa")},
	"blink": {"name": "Blink", "short": "Blink", "description": "Teleport along your last movement direction. Solid obstacles stop you.", "kind": "move", "cost": 15.0, "recharge": 2.5, "range": 0.0, "damage": 0.0, "radius": 0.0, "color": Color("bc9af4")},
	"strike": {"name": "Sword Strike", "short": "Strike", "description": "Cut your selected enemy within sword reach.", "kind": "melee", "cost": 0.0, "recharge": .55, "range": 1.65, "damage": 30.0, "radius": 0.0, "color": Color("e1d0ab")},
	"cleave": {"name": "Cleave", "short": "Cleave", "description": "Sweep through enemies in a wide arc ahead of you.", "kind": "cleave", "cost": 16.0, "recharge": 2.0, "range": 0.0, "damage": 36.0, "radius": 2.0, "color": Color("ffba82")},
	"guard": {"name": "Iron Guard", "short": "Guard", "description": "Reduce incoming damage by 65% for three seconds.", "kind": "guard", "cost": 18.0, "recharge": 7.0, "range": 0.0, "damage": 0.0, "radius": 0.0, "color": Color("a1cbd7")},
	"dash": {"name": "Battle Step", "short": "Step", "description": "Lunge along your movement direction with a brief dodge.", "kind": "move", "cost": 12.0, "recharge": 2.0, "range": 0.0, "damage": 0.0, "radius": 0.0, "color": Color("e6c99a")},
	"storm": {"name": "Storm Lance", "short": "Storm", "description": "Strike your selected enemy with lightning and slow it.", "kind": "target", "cost": 28.0, "recharge": 3.0, "range": 7.5, "damage": 48.0, "radius": 0.0, "color": Color("b2cfff")},
	"meteor": {"name": "Meteor", "short": "Meteor", "description": "Call down fire on your target and nearby enemies.", "kind": "target", "cost": 42.0, "recharge": 8.0, "range": 7.5, "damage": 85.0, "radius": 2.5, "color": Color("ff855c")},
	"mend": {"name": "Mending Light", "short": "Mend", "description": "Restore 40 vitality.", "kind": "heal", "cost": 30.0, "recharge": 10.0, "range": 0.0, "damage": 40.0, "radius": 0.0, "color": Color("9ae3ba")},
	"whirlwind": {"name": "Whirlwind", "short": "Whirl", "description": "Spin your blade through every nearby enemy.", "kind": "area", "cost": 30.0, "recharge": 5.0, "range": 0.0, "damage": 46.0, "radius": 3.0, "color": Color("ead5ad")},
	"second_wind": {"name": "Second Wind", "short": "Wind", "description": "Catch your breath and restore 48 vitality.", "kind": "heal", "cost": 25.0, "recharge": 10.0, "range": 0.0, "damage": 48.0, "radius": 0.0, "color": Color("99d3ae")},
	"execute": {"name": "Execution", "short": "Finish", "description": "A heavy sword blow. Double damage below half vitality.", "kind": "melee", "cost": 25.0, "recharge": 3.0, "range": 1.8, "damage": 48.0, "radius": 0.0, "color": Color("f3a1a1")},
	"runeblade": {"name": "Runeblade", "short": "Rune", "description": "An enchanted sword blow that slows your target.", "kind": "melee", "cost": 22.0, "recharge": 2.5, "range": 1.8, "damage": 52.0, "radius": 0.0, "color": Color("b49ded")},
	"ice_lance": {"name": "Ice Lance", "short": "Ice", "description": "Pierce your selected enemy with ice and freeze it for 2.2 seconds.", "kind": "expanded", "cost": 18.0, "recharge": 3.0, "range": 7.5, "damage": 34.0, "radius": 0.0, "color": Color("83ddff"), "freeze": 2.2},
	"chain_lightning": {"name": "Chain Lightning", "short": "Chain", "description": "Lightning jumps from your selected enemy to up to two nearby foes.", "kind": "expanded", "cost": 32.0, "recharge": 5.0, "range": 7.5, "damage": 34.0, "radius": 3.0, "color": Color("ced5ff"), "chains": 3},
	"lantern_familiar": {"name": "Lantern Familiar", "short": "Lantern", "description": "Summon a flying lantern that follows you and fires at enemies for 24 seconds.", "kind": "summon", "cost": 35.0, "recharge": 26.0, "range": 0.0, "damage": 12.0, "radius": 0.0, "color": Color("ffc979"), "duration": 24.0},
	"quake_strike": {"name": "Quake Strike", "short": "Quake", "description": "Strike the earth, damaging nearby enemies and stunning them for one second.", "kind": "expanded", "cost": 26.0, "recharge": 6.0, "range": 0.0, "damage": 38.0, "radius": 2.6, "color": Color("dfac78"), "stun": 1.0},
	"aegis": {"name": "Aegis", "short": "Aegis", "description": "Raise a barrier that absorbs 45 damage and lasts up to eight seconds.", "kind": "expanded", "cost": 28.0, "recharge": 12.0, "range": 0.0, "damage": 0.0, "radius": 0.0, "color": Color("9bd5ef"), "barrier": 45.0, "duration": 8.0},
	"ancestral_warden": {"name": "Ancestral Warden", "short": "Warden", "description": "Summon an ancestral shield bearer to fight beside you for 22 seconds.", "kind": "summon", "cost": 40.0, "recharge": 28.0, "range": 0.0, "damage": 16.0, "radius": 0.0, "color": Color("b2e6dd"), "duration": 22.0},
	"cinder_brand": {"name": "Cinder Brand", "short": "Cinder", "description": "Brand your selected enemy with fire, then burn it for six damage per second for five seconds.", "kind": "expanded", "cost": 24.0, "recharge": 4.0, "range": 7.5, "damage": 24.0, "radius": 0.0, "color": Color("ff9861"), "burn": 6.0, "duration": 5.0},
	"siphon_touch": {"name": "Siphon Touch", "short": "Siphon", "description": "Drain a nearby enemy and restore vitality equal to 45% of the damage dealt.", "kind": "expanded", "cost": 24.0, "recharge": 5.0, "range": 3.0, "damage": 28.0, "radius": 0.0, "color": Color("e3a2eb"), "heal_ratio": .45},
	"runic_blade": {"name": "Runic Blade", "short": "Blade", "description": "Summon an enchanted blade that follows you and attacks enemies for 22 seconds.", "kind": "summon", "cost": 32.0, "recharge": 24.0, "range": 0.0, "damage": 10.0, "radius": 0.0, "color": Color("bea1ff"), "duration": 22.0}
}
const NEW_ABILITIES := ["ice_lance", "chain_lightning", "lantern_familiar", "quake_strike", "aegis", "ancestral_warden", "cinder_brand", "siphon_touch", "runic_blade"]
const CLASS_ADDITIONS := {
	"mage": ["ice_lance", "chain_lightning", "lantern_familiar"],
	"sword": ["quake_strike", "aegis", "ancestral_warden"],
	"spellsword": ["cinder_brand", "siphon_touch", "runic_blade"]
}
var class_id := "mage"
var skill_points := 0
var ranks: Dictionary = {}
var unlocked: Array[String] = []
var action_bar: Array[String] = []

func reset(id: String) -> void:
	class_id = id
	skill_points = 0
	ranks.clear()
	unlocked.assign(CLASSES[id].starter)
	action_bar.assign(CLASSES[id].starter)
	action_bar.resize(10)
	for index in range(4, 10):
		action_bar[index] = ""

func tree() -> Array[Dictionary]:
	var data: Dictionary = CLASSES[class_id]
	var nodes: Array[Dictionary] = [
		{"id": "power", "name": "Battle Mastery" if class_id == "sword" else "Runic Power", "description": "+15% ability damage per rank", "max": 3, "parent": "", "ability": ""},
		{"id": "reserve", "name": "Deep Reserves", "description": "+20 resource and +2 regeneration per rank", "max": 2, "parent": "", "ability": ""},
		{"id": "vitality", "name": "Enduring Soul", "description": "+20 maximum vitality per rank", "max": 2, "parent": "", "ability": ""},
		{"id": "specialty", "name": ABILITIES[data.specialty].name, "description": ABILITIES[data.specialty].description, "max": 1, "parent": "power", "ability": data.specialty},
		{"id": "utility", "name": ABILITIES[data.utility].name, "description": ABILITIES[data.utility].description, "max": 1, "parent": "reserve", "ability": data.utility},
		{"id": "advanced", "name": ABILITIES[data.advanced].name, "description": ABILITIES[data.advanced].description, "max": 1, "parent": "specialty", "ability": data.advanced}
	]
	for index in range(3):
		var spell: String = CLASS_ADDITIONS[class_id][index]
		nodes.append({"id": spell, "name": ABILITIES[spell].name, "description": ABILITIES[spell].description, "max": 1, "parent": ["power", "reserve", "specialty"][index], "ability": spell})
	return nodes

func can_learn(id: String) -> bool:
	for node in tree():
		if node.id == id:
			return skill_points > 0 and ranks.get(id, 0) < node.max and (node.parent.is_empty() or ranks.get(node.parent, 0) > 0)
	return false

func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	skill_points -= 1
	ranks[id] = ranks.get(id, 0) + 1
	for node in tree():
		if node.id == id and not node.ability.is_empty() and not unlocked.has(node.ability):
			unlocked.append(node.ability)
	return true

func equip(spell: String, slot: int) -> bool:
	if slot < 0 or slot >= 10 or (not spell.is_empty() and not unlocked.has(spell)):
		return false
	for index in range(10):
		if action_bar[index] == spell:
			action_bar[index] = ""
	action_bar[slot] = spell
	return true

func snapshot() -> Dictionary:
	return {"class_id": class_id, "skill_points": skill_points, "ranks": ranks.duplicate(), "action_bar": action_bar.duplicate()}

func restore(data: Dictionary) -> bool:
	if not CLASSES.has(data.get("class_id", "")) or not data.get("ranks") is Dictionary or not data.get("action_bar") is Array:
		return false
	var points = data.get("skill_points")
	if not (points is int or points is float) or not is_finite(float(points)) or points < 0 or points != floorf(points):
		return false
	reset(data.class_id)
	var nodes := tree()
	var known := {}
	for node in nodes:
		known[node.id] = true
		var rank = data.ranks.get(node.id, 0)
		if not (rank is int or rank is float) or not is_finite(float(rank)) or rank != floorf(rank) or rank < 0 or rank > node.max:
			return false
		ranks[node.id] = int(rank)
	for id in data.ranks:
		if not known.has(id):
			return false
	for node in nodes:
		if ranks[node.id] > 0:
			if not node.parent.is_empty() and ranks[node.parent] == 0:
				return false
			if not node.ability.is_empty() and not unlocked.has(node.ability):
				unlocked.append(node.ability)
	if data.action_bar.size() != 10:
		return false
	var equipped := {}
	for spell in data.action_bar:
		if not spell is String or (not spell.is_empty() and (not unlocked.has(spell) or equipped.has(spell))):
			return false
		if not spell.is_empty():
			equipped[spell] = true
	skill_points = int(points)
	action_bar.assign(data.action_bar)
	return true
