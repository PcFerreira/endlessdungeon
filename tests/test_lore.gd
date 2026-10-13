extends SceneTree

const Lore = preload("res://scripts/lore_catalog.gd")

func _init() -> void:
	var original: Array = Lore.LINES
	Lore.LINES = [
		{"id": "memory", "speaker": "review", "event": "topic_memory", "condition": "Once per speaker", "variant_group": "memory", "text": "I miss my companions."},
		{"id": "memory_v02", "speaker": "review", "event": "topic_memory", "condition": "Once per speaker", "variant_group": "memory", "text": "I remember their voices."},
		{"id": "memory_v03", "speaker": "review", "event": "topic_memory", "condition": "Once per speaker", "variant_group": "memory", "text": "We used to travel together."}
	]
	var first := Lore.line("review", "topic_memory", {}, [], 1)
	assert(not first.id.is_empty())
	assert(Lore.line("review", "topic_memory", {}, [first.id], 2).id.is_empty(), "A wording variant must not repeat a once-only personal memory")
	assert(Lore.line("review", "topic_memory", {}, ["memory"], 2).id.is_empty(), "Legacy heard IDs must suppress the whole variant group")
	Lore.LINES = original
	var english = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lore/locales/en.json"))
	assert(english is Dictionary and english.get("locale") == "en")
	var groups := {}
	for entry in Lore.LINES:
		assert(entry.has("text_key") and english.messages.get(entry.text_key) == entry.text)
		var group: String = entry.variant_group
		groups[group] = groups.get(group, 0) + 1
		var context := {"met": false, "returned": false, "city_name": "Amberhaven", "dungeon_name": "Whispering Crypt", "biome_label": "Greenwood", "player_class": "mage"}
		var unsupported: bool = entry.condition.contains("Future")
		if unsupported:
			assert(Lore.line(entry.speaker, entry.event, context, [], 0).id.is_empty())
	for size in groups.values():
		assert(size >= 6, "Every migrated dialogue line needs a large authored variant bank")
	var unknown := Lore.line("unwritten_role", "topic_unknown", {}, [], 0)
	assert(unknown.id.is_empty() and unknown.has("text_key") and english.messages.get(unknown.text_key) == unknown.text)
	for role in Lore.ROLE_NAMES:
		for event in ["topic_world", "topic_guild", "topic_neighbors"]:
			var line := Lore.line(role, event, {}, [], 0)
			assert(not line.id.is_empty() and not line.text.contains("{"))
	print("PASS: grouped personal-memory continuity, legacy heard IDs, all dialogue/English keys, six-variant banks and future-condition gating")
	quit()
