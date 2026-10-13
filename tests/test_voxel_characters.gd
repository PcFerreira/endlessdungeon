extends SceneTree

const Actors = preload("res://scripts/actor_models.gd")
const Generator = preload("res://scripts/voxel_character_generator.gd")
const Catalog = preload("res://scripts/voxel_character_catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(Generator.catalog.error.is_empty())
	var invalid: Dictionary = Generator.catalog.data.duplicate(true)
	invalid.roles.milewarden.outfits = ["missing"]
	assert(not Catalog.valid(invalid), "Dangling outfit references must fail authoring validation")
	invalid = Generator.catalog.data.duplicate(true)
	invalid.hair.short[0].size[0] = -1
	assert(not Catalog.valid(invalid), "Invalid geometry must fail authoring validation")
	var variants := {}
	for biome in range(4):
		for index in range(48):
			var context := {"id": "city:test:%s:npc:%s" % [biome,index], "city_id": "city:test:%s" % biome, "biome": biome, "role": Generator.catalog.data.roles.keys()[index % Generator.catalog.data.roles.size()]}
			var style := Actors.style_for(index, context)
			assert(style == Actors.style_for(index, context))
			assert(style.generator_version == 1 and style.geometry == "voxel")
			assert(style.palette_id in Generator.catalog.data.biomes[str(biome)])
			variants[style.asset] = true
			var actor := Actors.create(index, context)
			root.add_child(actor)
			var body: Node3D = actor.get_child(0)
			var bounds := Actors._bounds(body, Transform3D.IDENTITY)
			assert(is_equal_approx(bounds.size.y, 1.15) and absf(bounds.position.y) < .001)
			assert(bounds.size.x < 1 and bounds.size.z < 1)
			assert(actor.find_children("*", "Skeleton3D", true, false).is_empty(), "NPC replacement must not load imported rigs")
			assert(actor.find_children("*", "CollisionObject3D", true, false).is_empty())
			var player: AnimationPlayer = body.get_node("AnimationPlayer")
			for action in ["Idle", "Walk", "Wave", "Attack"]:
				assert(Actors.animation_key(player, action) == action)
				var animation := player.get_animation(action)
				for track in animation.get_track_count():
					var path := str(animation.track_get_path(track)).split(":")[0]
					assert(body.has_node(path), "Animation tracks must address actual generated limbs")
			player.play("Walk")
			player.advance(.15)
			assert(absf(body.get_node("LeftLeg").rotation.x) > .1)
			assert(Actors._bounds(body,Transform3D.IDENTITY).position.y >= -.005, "Walking feet should clear the ground")
			Actors.greet(actor)
			player.advance(0)
			assert(player.current_animation == "Wave")
			player.advance(player.get_animation("Wave").length + .05)
			assert(player.current_animation == "Idle")
			actor.free()
	assert(variants.size() >= 160, "Identity should produce meaningful visible variation")
	assert(Generator.mesh_cache.size() <= Generator.CACHE_LIMIT, "Streaming must retain bounded mesh memory")
	var context := {"id":"same-resident", "role":"relic_mender"}
	var first := Actors.create(4, context)
	var second := Actors.create(4, context)
	assert(first.get_child(0).get_node("Torso/Geometry").mesh == second.get_child(0).get_node("Torso/Geometry").mesh)
	first.free()
	second.free()
	print("PASS: deterministic voxel NPC variety, validated recipes, actual limb animation/greetings, grounded bounds, shared bounded meshes and independent randomness")
	quit()
