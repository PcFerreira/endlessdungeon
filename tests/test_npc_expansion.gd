extends SceneTree

const Actors = preload("res://scripts/actor_models.gd")
const Generator = preload("res://scripts/voxel_character_generator.gd")

func _initialize() -> void:
	var reached := {}
	for kind in ["build", "skin", "hair_color", "hair", "beard", "outfit", "hat", "accessory"]:
		reached[kind] = {}
	var variants := {}
	for index in range(4096):
		var context := {"id":"npc-expansion:%s" % index, "role":Generator.catalog.data.roles.keys()[index % Generator.catalog.data.roles.size()], "traveling":true, "biome":index % 4}
		var style := Actors.style_for(index, context)
		assert(style.asset.begins_with("procedural:voxel-npc:v1:"))
		variants[style.asset] = true
		for kind in reached:
			reached[kind][style[kind]] = true
	for kind in ["build", "hair", "beard", "outfit", "hat", "accessory"]:
		var plural: String = {"build":"builds", "beard":"beards", "outfit":"outfits", "hat":"hats", "accessory":"accessories"}.get(kind, kind)
		assert(reached[kind].size() == Generator.catalog.data[plural].size(), "Every authored appearance recipe must be reachable: " + kind)
	assert(reached.skin.size() == Generator.catalog.data.skins.size())
	assert(reached.hair_color.size() == Generator.catalog.data.hair_colors.size())
	assert(variants.size() > 3500)
	print("PASS: %s generated NPC appearances; every body, skin, hair, outfit, hat and role accessory is reachable without imported models" % variants.size())
	quit()
