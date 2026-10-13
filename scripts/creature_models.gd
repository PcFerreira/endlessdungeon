extends RefCounted

const Styles = preload("res://scripts/environment_styles.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const AnimatedStyle = preload("res://scripts/animated_model_style.gd")
var registry := Registry.new()
var styles := Styles.new(registry)
var renderer := AnimatedStyle.new()
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/creature_styles.json"))
var error := ""

func choose(ids: Array, salt: int, saved_id: String, biome: int) -> String:
	if saved_id in ids:
		return saved_id
	var compatible := ids.filter(func(id): return styles.allows(id, biome))
	var choices: Array = ids if compatible.is_empty() else compatible
	return "" if choices.is_empty() else choices[posmod(salt, choices.size())]

func instantiate(source_id: String, biome: int) -> Node3D:
	error = ""
	var family := styles.family_for(biome)
	var actual_id: String = data.sprite_presentations.get(source_id, {}).get(family, source_id)
	if family.is_empty() or not styles.creature_sources.has(actual_id):
		error = "Unclassified creature source: " + actual_id
		return null
	var source := registry.instantiate(actual_id)
	if source == null:
		error = registry.error
		return null
	var direct := styles.allows(actual_id, biome)
	if not direct and not renderer.convert(source, family, 18):
		error = renderer.error
		source.free()
		return null
	source.set_meta("source_asset", source_id)
	source.set_meta("render_source", actual_id)
	source.set_meta("visual_family", family)
	source.set_meta("representation", "direct" if direct else source.get_meta("representation"))
	source.set_meta("render_asset", actual_id if direct else "native_creature:%s:%s" % [family, actual_id])
	return source
