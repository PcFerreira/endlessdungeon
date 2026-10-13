extends SceneTree

const Build = preload("res://scripts/character_build.gd")
const Store = preload("res://scripts/save_store.gd")
const ADDED := {
	"mage": ["ice_lance", "chain_lightning", "lantern_familiar"],
	"sword": ["quake_strike", "aegis", "ancestral_warden"],
	"spellsword": ["cinder_brand", "siphon_touch", "runic_blade"]
}
const LEGACY := ["bolt", "fire", "nova", "blink", "strike", "cleave", "guard", "dash", "storm", "meteor", "mend", "whirlwind", "second_wind", "execute", "runeblade"]

func _initialize() -> void:
	call_deferred("run_checks")

func envelope(build: Dictionary) -> Dictionary:
	var cooldowns := {}
	for spell in LEGACY:
		cooldowns[spell] = .4
	return {
		"generator_version": 4, "saved_at": 1, "seed": "91", "rng_state": "1", "build": build,
		"location": {"layer": "overworld", "name": "Journey", "point": [0, 0], "surface_return": [0, 0], "sanctuary": [0, 0], "site_cell": [0, 0], "aim": [0, 1], "heading": [0, 1], "site_id": "", "selected": "", "grounded": true, "player_y": 0, "velocity": 0, "depth": 1},
		"stats": {"hp": 100, "mana": 100, "kills": 0, "elapsed": 0, "guard": 0, "invulnerable": 0, "best_depth": 1, "cooldowns": cooldowns},
		"view": {"yaw": 0, "target_yaw": 0, "surface_zoom": 20, "dungeon_zoom": 20},
		"progress": {"lore": {"books": [], "speakers": [], "heard": {}, "returns": {}}, "encounters": {}, "floors": {}, "discovery": {}, "claimed": [], "cities": [], "waypoint": "", "waypoint_cell": [0, 0]},
		"pickups": [], "projectiles": []
	}

func run_checks() -> void:
	for class_id in ADDED:
		var build := Build.new()
		build.reset(class_id)
		var old: Dictionary = build.snapshot()
		old.ranks = {"power": 1, "reserve": 1, "vitality": 0, "specialty": 1, "utility": 0, "advanced": 0}
		assert(build.restore(old), "Every pre-expansion rank/action save remains playable")
		var data := envelope(old)
		var store := Store.new()
		assert(store.validate(data), "A legacy envelope with precisely fifteen cooldowns remains valid")
		for id in ADDED[class_id]:
			assert(Build.ABILITIES.has(id), "Each class needs three additional learnable abilities")
			var node := {}
			for candidate in build.tree():
				if candidate.ability == id:
					node = candidate
			assert(not node.is_empty() and node.max == 1 and node.parent in ["power", "reserve", "specialty"])
			build.skill_points = 1
			assert(build.learn(node.id) and build.skill_points == 0 and build.equip(id, 9))
			var restored := Build.new()
			assert(restored.restore(build.snapshot()) and restored.action_bar[9] == id and restored.unlocked.has(id))
			assert(not build.learn(node.id), "An acquired expansion spell consumes only one skill point")
			assert(FileAccess.file_exists("res://assets/spells/%s.svg" % id))
			var image := Image.new()
			assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/spells/%s.svg" % id)) == OK and image.get_width() == 48 and not image.is_invisible(), "Spell icons decode without an editor import")
			var texture: Texture2D = load("res://assets/spells/%s.svg" % id)
			assert(texture != null and texture.get_width() == 48 and not texture.get_image().is_invisible(), "The action bar loads a decoded spell texture")
			data.stats.cooldowns[id] = 2.5
			assert(store.validate(data))
			for invalid in [-1, INF, NAN, "2", true]:
				data.stats.cooldowns[id] = invalid
				assert(not store.validate(data), "New cooldowns must remain finite nonnegative numbers")
			data.stats.cooldowns.erase(id)
			var bad: Dictionary = build.snapshot()
			bad.ranks = {node.id: 1}
			bad.action_bar = ["", "", "", "", "", "", "", "", "", ""]
			assert(not restored.restore(bad), "Expansion ranks still require their original skill parent")
		for id in LEGACY:
			data.stats.cooldowns.erase(id)
			assert(not store.validate(data), "Original cooldown omissions remain malformed saves")
			data.stats.cooldowns[id] = .4
		data.stats.cooldowns.unknown = 0
		assert(not store.validate(data), "Unknown cooldown keys are rejected")
	print("PASS: additive class unlocks, original skill/action saves, prerequisites, authored SVGs and strict legacy cooldown validation")
	quit()
