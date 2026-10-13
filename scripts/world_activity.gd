extends RefCounted

const PATH := "res://config/world_activity.json"
var data: Dictionary = {}

func _init() -> void:
	var value = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if valid(value):
		data = value

static func valid(value) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("travelers") is Array or value.travelers.size() < 2 or value.travelers.size() > 16 or not value.get("guards") is Dictionary:
		return false
	var ids := {}
	for entry in value.travelers + [value.guards]:
		if not entry is Dictionary or not entry.get("name") is String or not entry.get("greetings") is Array or entry.greetings.is_empty():
			return false
		for text in entry.greetings:
			if not text is String or text.is_empty() or text.length() > 2000:
				return false
		for key in ["speed", "pause_seconds"]:
			if not _number(entry.get(key)) or entry[key] < .5 or entry[key] > 30:
				return false
		if entry == value.guards:
			continue
		if not entry.get("id") is String or not entry.id.is_valid_identifier() or entry.id.length() > 64 or entry.id == "guard" or ids.has(entry.id):
			return false
		ids[entry.id] = true
		var offers = entry.get("offers", [])
		if not offers is Array or offers.size() > 8 or (entry.id == "merchant" and offers.is_empty()):
			return false
		for offer in offers:
			if not offer is Dictionary or not offer.get("item") is String or not _number(offer.get("cost")) or offer.cost < 1 or offer.cost > 99 or offer.cost != floorf(offer.cost):
				return false
			if offer.has("coin_cost") and (not _number(offer.coin_cost) or offer.coin_cost < 1 or offer.coin_cost > 99 or offer.coin_cost != floorf(offer.coin_cost)):
				return false
	if not ids.has("merchant") or not value.get("episodes") is Array or value.episodes.size() > 8:
		return false
	var end := 0.0
	for episode in value.episodes:
		if not episode is Dictionary or not episode.get("choices") is Array or episode.choices.is_empty():
			return false
		for key in ["start_seconds", "finish_seconds", "end_seconds"]:
			if not _number(episode.get(key)):
				return false
		if episode.start_seconds < end or episode.finish_seconds <= episode.start_seconds or episode.end_seconds <= episode.finish_seconds or episode.end_seconds > 240:
			return false
		end = episode.end_seconds
		for choice in episode.choices:
			if not choice is Dictionary or not choice.get("id") is String or not choice.get("label") is String or not choice.get("aftermath") is String or choice.get("visual") not in ["meal", "crates", "banner", "market", "books"]:
				return false
	var areas = value.get("monster_areas")
	if not areas is Dictionary or not areas.get("labels") is Array or areas.labels.size() != 3:
		return false
	for label in areas.labels:
		if not label is String or label.is_empty():
			return false
	if not areas.get("biome_labels", {}) is Dictionary:
		return false
	for biome in areas.get("biome_labels", {}):
		var labels = areas.biome_labels[biome]
		if biome not in ["0","1","2","3"] or not labels is Array or labels.size() != 3 or not labels.all(func(label): return label is String and not label.is_empty()):
			return false
	for key in ["radius", "members", "clearance"]:
		if not _number(areas.get(key)) or areas[key] != floorf(areas[key]):
			return false
	return areas.radius >= 3 and areas.radius <= 9 and areas.members >= 2 and areas.members <= 8 and areas.clearance >= 16 and areas.clearance <= 24

static func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func role(id: String) -> Dictionary:
	if id == "guard":
		return data.guards
	for entry in data.travelers:
		if entry.id == id:
			return entry
	return {}

func event(city_id: String, tick: int, salt: int) -> Dictionary:
	var offset := 0 if city_id == "city:0:0" else salt % 60
	var local := tick + offset
	var cycle := floori(float(local) / 480)
	var phase := local % 480
	for window in data.episodes:
		if phase >= window.start_seconds * 2 and phase < window.end_seconds * 2:
			var choice: Dictionary = window.choices[posmod(salt + cycle, window.choices.size())]
			return {"kind": choice.id, "phase": "active" if phase < window.finish_seconds * 2 else "aftermath", "instance_id": "%s:%s:%s" % [city_id, choice.id, cycle], "home_city_id": city_id, "start_tick": cycle * 480 + int(window.start_seconds * 2) - offset, "finish_tick": cycle * 480 + int(window.finish_seconds * 2) - offset, "label": choice.label, "visual": choice.visual, "aftermath": choice.aftermath}
	return {}

func dialogue(actor: Dictionary, event: String, salt: int) -> String:
	var definition := role(actor.role)
	if event == "farewell":
		return "Safe travels. We will meet again along the road."
	var text: String = definition.greetings[posmod(salt, definition.greetings.size())]
	if event == "topic_route":
		text = "I travel between {city_name} and {destination}. I stop at the town approaches before taking the road back."
	elif event == "topic_local_life":
		text = "I am %s. The town's watch and travelers keep their own hours." % actor.activity.replace("_", " ")
	return text.replace("{city_name}", actor.city_name).replace("{destination}", actor.get("destination", actor.city_name))

func trade(inventory, actor: Dictionary, item: String, class_id: String, currency: String = "ember_shard") -> String:
	if actor.get("role") != "merchant":
		return "This traveler is not trading."
	if currency not in ["ember_shard","gold_coin"]:
		return "That currency is not accepted here."
	for offer in role("merchant").offers:
		if offer.item != item:
			continue
		if currency == "gold_coin" and not offer.has("coin_cost"):
			return "That item is only offered for shards."
		var cost: int = int(offer.coin_cost if currency == "gold_coin" else offer.cost)
		var label := "coins" if currency == "gold_coin" else "ember shards"
		if inventory.count(currency) - inventory.stolen_count(currency) < cost:
			return "You need %s %s of your own." % [cost,label]
		var before: Dictionary = inventory.snapshot()
		if not inventory.remove(currency, cost) or not inventory.add(item):
			inventory.restore(before, class_id)
			return "Make room in your backpack before trading."
		return "Traded %s %s for supplies." % [cost,label]
	return "That item is not offered here."
