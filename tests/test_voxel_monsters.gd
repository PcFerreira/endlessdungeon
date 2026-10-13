extends SceneTree

const Enemies = preload("res://scripts/enemy_catalog.gd")
const Models = preload("res://scripts/enemy_models.gd")
const Generator = preload("res://scripts/voxel_monster_generator.gd")
const Catalog = preload("res://scripts/voxel_monster_catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(Generator.catalog.error.is_empty())
	var invalid: Dictionary = Generator.catalog.data.duplicate(true)
	invalid.selectors[0].template = "unknown"
	assert(not Catalog.valid(invalid), "Unknown monster body references must fail validation")
	invalid = Generator.catalog.data.duplicate(true)
	invalid.templates.skeleton.parts.Head.pieces[0].size[0] = -1
	assert(not Catalog.valid(invalid), "Negative monster geometry must fail validation")
	invalid = Generator.catalog.data.duplicate(true)
	invalid.templates.skeleton.parts.Head.phase = .5
	assert(not Catalog.valid(invalid), "Motion phases must be valid signs despite JSON number normalization")
	var silhouettes := {}
	var variants := {}
	for kind in range(Enemies.TYPES.size()):
		var profile := Generator.catalog.profile(Enemies.TYPES[kind])
		assert(profile.has("ids") or profile.has("names"), "Every current enemy needs explicit semantic classification")
		for biome in range(4):
			var body := Models.create(kind,kind * 47,"",biome,true)
			root.add_child(body)
			assert(body.get_meta("representation") == "generated_voxel")
			assert(body.get_meta("visual_family") == "block_voxel")
			var style: Dictionary = body.get_meta("monster_style")
			silhouettes[style.template] = true
			variants[body.get_meta("asset_id")] = true
			var box := Models.bounds(body)
			assert(box.position.y >= -.001 and box.size.y > .1)
			assert(box.size.y <= Enemies.TYPES[kind].height + .001 and maxf(box.size.x,box.size.z) <= 1.301)
			assert(body.find_children("*","Skeleton3D",true,false).is_empty())
			assert(body.find_children("*","SpriteBase3D",true,false).is_empty())
			var player: AnimationPlayer = body.find_children("*","AnimationPlayer",true,false)[0]
			for mode in ["idle","walk","attack"]:
				Models.animate(body,mode)
				assert(player.current_animation == mode)
				player.advance(.15)
				for track in player.get_animation(mode).get_track_count():
					var path := str(player.get_animation(mode).track_get_path(track)).split(":")[0]
					assert(player.get_parent().has_node(path))
				assert(Models.bounds(body).position.is_finite() and Models.bounds(body).size.is_finite())
			var restored := Models.create(kind,999,body.get_meta("asset_id"),biome,true)
			assert(restored.get_meta("monster_style") == style, "Saved generated descriptors must restore their actual selected appearance")
			restored.free()
			body.free()
	assert(silhouettes.size() >= 16, "The full species catalogue must retain varied monster silhouettes")
	assert(variants.size() >= Enemies.TYPES.size() * 3)
	assert(Generator.mesh_cache.size() <= Generator.CACHE_LIMIT)
	assert(Generator.decode("voxel-monster:1:skeleton:bone:0:0:regular:plain:99","skeleton",["bone"]).is_empty())
	var future: Dictionary = Enemies.TYPES[0].duplicate(true)
	future.id = "future-dungeon-creature"
	future.name = "Future monster"
	var style := Generator.appearance(future,73,"",2)
	var body := Generator.create(style)
	assert(Models.bounds(body).size.y > 0, "Future catalogue entries need a generated fallback without imported assets")
	body.free()
	print("PASS: %s dungeon profiles, %s body templates and %s appearances; validated recipes, grounded bounded bodies, actual combat animation, saved descriptors and bounded meshes" % [Enemies.TYPES.size(),silhouettes.size(),variants.size()])
	quit()
