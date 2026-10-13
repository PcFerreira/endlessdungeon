extends SceneTree

const Profile = preload("res://scripts/character_profile.gd")
const Visual = preload("res://scripts/character_visual.gd")

func geometry_signature(body: Node3D) -> String:
	var checksum := HashingContext.new()
	checksum.start(HashingContext.HASH_SHA256)
	for bone in ["Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		var mesh: ArrayMesh = body.get_node(bone + "/Geometry").mesh
		checksum.update(var_to_bytes(mesh.surface_get_arrays(0)))
	return checksum.finish().hex_encode()

func _initialize() -> void:
	call_deferred("checks")

func checks() -> void:
	var profile := Profile.new()
	assert(Profile.options("head", "mage").size() >= 10)
	assert(Profile.options("costume", "mage").size() >= 15)
	assert(Profile.premades().size() >= 12 and Profile.premades().all(func(entry): return entry.geometry == "voxel"))
	var full: Dictionary = profile.snapshot()
	full.merge({"name": "Iona", "ancestry": "elf", "body_type": "slender", "head": "braid", "beard": "none", "headwear": "circlet", "costume": "guild_coat", "outerwear": "long_cloak", "gloves": "leather", "boots": "riding", "belt": "pouches", "accessory": "satchel", "skin": 8, "hair": 9, "outfit": 10, "trim": 2, "trousers": 5, "boots_color": 4, "outer_color": 7, "headwear_color": 1, "eye_color": 3, "eye_shape": 2}, true)
	assert(profile.restore(full, "mage") and profile.snapshot() == full)
	var broken := full.duplicate(true)
	broken.headwear = "res://project.godot"
	assert(not profile.restore(broken, "mage") and profile.snapshot() == full)
	broken = full.duplicate(true)
	broken.trim = NAN
	assert(not profile.restore(broken, "mage"))
	var legacy := {"name": "Old hero", "ancestry": "human", "skin": 0, "hair": 0, "outfit": 0, "head": "hood", "costume": "mage_scholar", "model": "custom"}
	assert(profile.restore(legacy, "mage") and profile.headwear == "hood" and profile.appearance_version == 2)
	legacy.model = "kaykit_adventures/content/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb"
	assert(profile.restore(legacy, "mage") and profile.model == "custom" and profile.display_name == "Old hero")
	broken = profile.snapshot()
	broken.model = legacy.model
	assert(not profile.restore(broken, "mage"), "Removed imported bodies cannot be selected by a new profile")
	var signatures := {}
	for key in ["head", "beard", "headwear", "costume", "outerwear", "gloves", "boots", "belt", "accessory", "body_type"]:
		var distinct := {}
		for option in Profile.options(key, "mage"):
			var data := Profile.new().snapshot()
			data[key] = option.id
			var candidate := Profile.new()
			assert(candidate.restore(data, "mage"))
			var visual := Visual.new()
			root.add_child(visual)
			visual.configure("mage", candidate)
			assert(not visual.imported and visual.body.get_meta("geometry") == "voxel")
			assert(visual.find_children("*", "Skeleton3D", true, false).is_empty())
			var bounds: AABB = visual.visual_bounds()
			assert(absf(bounds.position.y) < .001 and bounds.size.y > .75 and bounds.size.y < 1.7)
			assert(visual.animations.size() == 1)
			var rig: AnimationPlayer = visual.animations[0]
			visual.animate(true, true)
			rig.advance(0)
			rig.advance(.15)
			rig.advance(.1)
			assert(visual.motion == "Walk" and absf(visual.body.get_node("LeftLeg").rotation.x) > .1)
			visual.animate(false, false)
			assert(visual.motion == "Jump_Idle" and rig.has_animation("Jump_Idle"))
			distinct[geometry_signature(visual.body)] = true
			visual.free()
		assert(distinct.size() == Profile.options(key, "mage").size(), "Every selected option must create a distinct visible voxel recipe")
		signatures[key] = distinct.size()
	for boots in Profile.options("boots", "mage"):
		var candidate := Profile.new()
		candidate.boots = boots.id
		var visual := Visual.new()
		root.add_child(visual)
		visual.configure("mage", candidate)
		var rig: AnimationPlayer = visual.animations[0]
		rig.play("Walk", 0)
		for step in range(65):
			rig.seek(step * .7 / 64, true)
			assert(visual.visual_bounds().position.y >= -.001, "Walking boots must stay above the floor: " + boots.id)
		visual.free()
	print("PASS: voxel-only editable presets, layered wardrobe choices, visible recipes, animated limbs/jump, grounded proportions and walking feet, validated atomic saves and legacy imported migration ", signatures)
	quit()
