extends SceneTree

const Models = preload("res://scripts/creature_models.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const EnemyModels = preload("res://scripts/enemy_models.gd")
const LifeCatalog = preload("res://scripts/world_life_catalog.gd")
const LifeView = preload("res://scripts/world_life_view.gd")
const Registry = preload("res://scripts/asset_registry.gd")
var models := Models.new()

class MissingRegistry extends Registry:
	func instantiate(_id: String) -> Node3D:
		error = "Unavailable creature resource"
		return null

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(models.styles.error.is_empty(), models.styles.error)
	var sources := {}
	var direct := 0
	var derivatives := 0
	for kind in range(Enemies.TYPES.size()):
		var definition: Dictionary = Enemies.TYPES[kind]
		var ids: Array = [definition.source_asset] if definition.has("source_asset") else Enemies.content.models(definition.visual).map(func(asset): return asset.id)
		assert(not ids.is_empty())
		for id in ids:
			sources[id] = true
		for biome in range(4):
			var chosen := models.choose(ids, 47, "", biome)
			if ids.any(func(id): return models.styles.allows(id, biome)):
				assert(models.styles.allows(chosen, biome), "New model selection must prefer an actual matching source")
			assert(chosen == models.choose(ids, 47, "", biome))
			var body := EnemyModels.create(kind, 47, ids[0], biome)
			assert(body.get_meta("asset_id") == ids[0], "Saved species/source identity must not be replaced by a derivative identity")
			assert(body.get_meta("biome") == biome and body.get_meta("visual_family") == models.styles.family_for(biome))
			if body.get_meta("representation") == "native_fallback":
				printerr("FAIL: adopted creature %s / %s / biome %s: %s" % [definition.id, ids[0], biome, EnemyModels.creatures.error])
				body.free()
				quit(1)
				return
			assert(EnemyModels.bounds(body).size.y > 0)
			assert(body.find_children("*", "AnimatedSprite3D", true, false).is_empty(), "The adopted pixel skeleton needs explicit matching 3D presentation")
			if body.get_meta("representation") == "direct":
				direct += 1
			else:
				derivatives += 1
			body.free()
	var catalog := LifeCatalog.new()
	var view := LifeView.new()
	for definition in catalog.data.species:
		for source in catalog.model_choices[definition.id]:
			sources[source.id] = true
			for biome in [0, 2]:
				var actor := {"kind": "animal", "asset_id": source.id, "biome": biome, "height": definition.height}
				var body := view._create(actor)
				assert(body.has_meta("source_asset") and body.get_meta("source_asset") == source.id)
				assert(body.get_meta("visual_family") == models.styles.family_for(biome))
				assert(EnemyModels.bounds(body).size.y > 0)
				body.free()
	for source_id in sources:
		assert(not models.styles.family_of(source_id).is_empty() or models.data.sprite_presentations.has(source_id), "Every adopted creature source needs explicit source classification: " + source_id)
	assert(models.instantiate("unknown_source", 0) == null)
	assert(models.styles.family_of("native_creature:block_voxel:unknown_source").is_empty())
	assert(models.instantiate(sources.keys()[0], -1) == null)
	var original_registry = EnemyModels.creatures.registry
	EnemyModels.creatures.registry = MissingRegistry.new()
	var fallback_id: String = Enemies.content.models(Enemies.TYPES[0].visual)[0].id
	for biome in [0, 2]:
		var body := EnemyModels.create(0, 1, fallback_id, biome)
		assert(body.get_meta("asset_id") == fallback_id)
		assert(body.get_meta("representation") == "native_fallback" and models.styles.allows(body.get_meta("render_asset"), biome), str([biome, body.get_meta("representation"), body.get_meta("render_asset"), models.styles.family_of(body.get_meta("render_asset"))]))
		assert(EnemyModels.bounds(body).size.y > 0)
		body.free()
	EnemyModels.creatures.registry = original_registry
	view.free()
	print("PASS: %s creature sources; all %s enemy identities in four climates (%s direct / %s derivatives), all animal bodies in both styles, deterministic source preferences, preserved legacy identities and explicit 3D sprite policy" % [sources.size(), Enemies.TYPES.size(), direct, derivatives])
	quit()
