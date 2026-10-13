extends RefCounted

const PATH := "res://config/combat_audio.json"
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("clips") is Dictionary or not document.get("effects") is Dictionary or not document.get("hits") is Dictionary:
		return false
	for path in document.clips.values():
		if not path is String or ".." in path.split("/") or not (path.begins_with("res://assets/combat_audio/") or path.begins_with("res://assets/imported/packs/")) or path.get_extension() not in ["wav", "ogg"]:
			return false
	for id in document.effects:
		var profile = document.effects[id]
		if not id is String or not profile is Dictionary or not profile.get("files") is Array or profile.files.is_empty() or profile.files.size() > 8:
			return false
		if not profile.files.all(func(clip): return clip is String and document.clips.has(clip)):
			return false
		if not number(profile.get("volume_db")) or profile.volume_db < -30 or profile.volume_db > 0 or not number(profile.get("pitch")) or profile.pitch < .6 or profile.pitch > 1.6 or not number(profile.get("cooldown_ms")) or profile.cooldown_ms < 0 or profile.cooldown_ms > 1000:
			return false
	return document.effects.has("impact") and document.hits.values().all(func(id): return id is String and document.effects.has(id))

static func hit_for(spell: String) -> String:
	return data.hits.get(spell, "impact")
