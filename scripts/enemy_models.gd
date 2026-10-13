extends RefCounted

const Voxels = preload("res://scripts/voxel_kit.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const CreatureModels = preload("res://scripts/creature_models.gd")
const MonsterGenerator = preload("res://scripts/voxel_monster_generator.gd")
const WonderModels = preload("res://scripts/wonder_models.gd")
static var creatures := CreatureModels.new()
static var meshes: Dictionary = {}

static func prepared(kind: int, seed_value: int, saved_id: String, biome: int) -> bool:
	var definition: Dictionary = Enemies.TYPES[kind]
	if definition.get("visual_mode", "automatic") == "generated":
		return true
	var ids: Array = [definition.source_asset] if definition.has("source_asset") else Enemies.content.models(definition.visual).map(func(asset): return asset.id)
	return creatures.prepared(creatures.choose(ids, seed_value, saved_id, biome), biome)

static func create(kind: int, seed_value: int, saved_id: String = "", biome: int = 0, dungeon_monster: bool = false) -> Node3D:
	var definition: Dictionary = Enemies.TYPES[kind]
	if definition.has("wonder_id") and definition.get("visual_mode", "") == "generated":
		return _wonder(definition, seed_value, saved_id, biome)
	if definition.get("visual_mode", "automatic") == "generated" or (dungeon_monster and definition.get("visual_mode", "automatic") != "imported"):
		return _generated(definition,seed_value,saved_id,biome)
	var ids: Array = [definition.source_asset] if definition.has("source_asset") else Enemies.content.models(definition.visual).map(func(asset): return asset.id)
	var id := creatures.choose(ids, seed_value, saved_id, biome)
	var root := Node3D.new()
	var body := creatures.instantiate(id, biome) if not id.is_empty() else null
	if body == null:
		body = Voxels.instance(mesh(int(definition.get("voxel_shape", 0))))
		var family := creatures.styles.family_for(biome)
		if family == "flat_lowpoly":
			var converted: bool = creatures.renderer.convert(body, family, 18)
			assert(converted)
		body.set_meta("visual_family", family)
		body.set_meta("render_asset", "native_creature:%s:fallback_%s" % [family, int(definition.get("voxel_shape", 0))])
		body.set_meta("representation", "native_fallback")
	root.add_child(body)
	body.rotation_degrees.y += float(definition.get("facing_degrees", 0))
	var box := bounds(body)
	var scale_factor: float = minf(definition.height / maxf(.01, box.size.y), 1.3 / maxf(.01, maxf(box.size.x, box.size.z)))
	body.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	root.scale = Vector3.ONE * scale_factor
	root.set_meta("asset_id", id)
	for key in ["visual_family", "render_asset", "representation"]:
		root.set_meta(key, body.get_meta(key))
	root.set_meta("biome", biome)
	root.set_meta("animation", "")
	root.set_meta("animation_overrides", definition.get("animations", {}))
	animate(root, "idle")
	return root

static func _wonder(definition: Dictionary, seed_value: int, saved_id: String, biome: int) -> Node3D:
	var family: String = creatures.styles.family_for(biome)
	var fields := saved_id.split(":")
	if fields.size() == 4 and fields[0] == "wonder" and fields[1] == definition.wonder_id and fields[2].length() <= 18 and fields[2].is_valid_int() and fields[3] in ["block_voxel", "flat_lowpoly"]:
		seed_value = fields[2].to_int()
		family = fields[3]
	var root := Node3D.new()
	var body := WonderModels.create(definition.wonder_id, family, seed_value)
	root.add_child(body)
	body.rotation_degrees.y += float(definition.get("facing_degrees", 0))
	var box := bounds(body)
	body.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	root.scale = Vector3.ONE * minf(definition.height / box.size.y, 1.3 / maxf(box.size.x, box.size.z))
	var descriptor := "wonder:%s:%s:%s" % [definition.wonder_id, seed_value, family]
	root.set_meta("asset_id", descriptor)
	root.set_meta("render_asset", descriptor)
	root.set_meta("wonder_id", definition.wonder_id)
	root.set_meta("representation", "original_wonder_voxel")
	root.set_meta("visual_family", family)
	root.set_meta("appearance_variant", body.get_meta("appearance_variant"))
	root.set_meta("biome", biome)
	root.set_meta("animation", "")
	root.set_meta("animation_overrides", definition.get("animations", {}))
	animate(root, "idle")
	return root

static func _generated(definition: Dictionary, seed_value: int, saved_id: String, biome: int) -> Node3D:
	var style := MonsterGenerator.appearance(definition,seed_value,saved_id,biome)
	var root := Node3D.new()
	var body := MonsterGenerator.create(style)
	root.add_child(body)
	body.rotation_degrees.y += float(definition.get("facing_degrees", 0))
	var box := bounds(body)
	body.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)
	root.scale = Vector3.ONE * minf(definition.height / box.size.y,1.3 / maxf(box.size.x,box.size.z))
	root.set_meta("asset_id",style.asset)
	root.set_meta("render_asset",style.asset)
	root.set_meta("representation","generated_voxel")
	root.set_meta("visual_family","block_voxel")
	root.set_meta("monster_style",style)
	root.set_meta("biome",biome)
	root.set_meta("animation","")
	root.set_meta("animation_overrides", definition.get("animations", {}))
	animate(root,"idle")
	return root

static func _sprite(definition: Dictionary) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	var texture: Texture2D = Enemies.content.registry.resource(definition.asset_id)
	var size := Vector2(texture.get_width() / int(definition.columns), texture.get_height() / int(definition.rows))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for mode in ["idle", "walk", "attack"]:
		frames.add_animation(mode)
		frames.set_animation_speed(mode, 8)
		for frame in definition[mode]:
			var region := AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(Vector2(float(frame) * size.x, 3 * size.y), size)
			frames.add_frame(mode, region)
	sprite.sprite_frames = frames
	sprite.pixel_size = 1.0 / size.y
	sprite.position.y = .5
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.play("idle")
	return sprite

static func bounds(node: Node3D, parent: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent * node.transform
	var result: AABB = transform * node.mesh.get_aabb() if node is MeshInstance3D else AABB()
	if node is SpriteBase3D:
		result = transform * AABB(Vector3(-.5, -.5, -.01), Vector3(1, 1, .02))
	for child in node.get_children():
		if child is Node3D:
			var box := bounds(child, transform)
			if box.size != Vector3.ZERO:
				result = box if result.size == Vector3.ZERO else result.merge(box)
	return result

static func animate(model: Node3D, mode: String) -> void:
	if model.get_meta("animation", "") == mode:
		return
	model.set_meta("animation", mode)
	for sprite in model.find_children("*", "AnimatedSprite3D", true, false):
		if sprite.sprite_frames.has_animation(mode):
			sprite.play(mode)
	for player in model.find_children("*", "AnimationPlayer", true, false):
		var preferred := mode
		var animation: String = model.get_meta("animation_overrides", {}).get(mode, "")
		if not animation.is_empty() and not player.has_animation(animation):
			animation = ""
		for candidate in player.get_animation_list():
			if not animation.is_empty():
				break
			if candidate.to_lower().contains(preferred) or (mode == "walk" and candidate.to_lower().contains("run")):
				animation = candidate
				break
		if animation.is_empty():
			for candidate in player.get_animation_list():
				if candidate.to_lower().contains("idle"):
					animation = candidate
		if not animation.is_empty():
			player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
			player.play(animation)

static func mesh(kind: int) -> ArrayMesh:
	if not meshes.has(kind):
		meshes[kind] = Voxels.enemy(kind) if kind < 3 else Voxels.mesh(_boxes(kind))
	return meshes[kind]

static func _boxes(kind: int) -> Array:
	var boxes: Array = []
	if kind in [3, 5]:
		var fur := Color("697367") if kind == 3 else Color("805944")
		boxes = [
			[Vector3(0, .43, 0), Vector3(.42, .40, .73), fur],
			[Vector3(0, .55, .39), Vector3(.35, .32, .35), fur.lightened(.12)],
			[Vector3(0, .48, .61), Vector3(.23, .15, .22), fur.darkened(.2)],
			[Vector3(0, .53, -.46), Vector3(.13, .13, .30), fur]
		]
		for x in [-.15, .15]:
			for z in [-.24, .24]:
				boxes.append([Vector3(x, .14, z), Vector3(.12, .28, .13), fur.darkened(.2)])
			boxes.append([Vector3(x, .77, .37), Vector3(.09, .16, .12), fur])
			boxes.append([Vector3(x, .58, .56), Vector3(.055, .055, .05), Color("f2c88b")])
			if kind == 5:
				boxes.append([Vector3(x, .42, .66), Vector3(.065, .17, .07), Color("ead6af")])
	elif kind == 4:
		boxes = [
			[Vector3(0, .44, 0), Vector3(.4, .48, .30), Color("73505b")],
			[Vector3(0, .79, 0), Vector3(.32, .30, .30), Color("554550")],
			[Vector3(0, .78, .17), Vector3(.23, .13, .035), Color("caab85")],
			[Vector3(0, .73, .19), Vector3(.25, .065, .04), Color("2f333e")],
			[Vector3(-.27, .51, .17), Vector3(.13, .35, .14), Color("73505b")],
			[Vector3(.27, .51, .17), Vector3(.13, .35, .14), Color("73505b")],
			[Vector3(.32, .58, .31), Vector3(.08, .62, .08), Color("b79762")],
			[Vector3(-.11, .13, 0), Vector3(.16, .26, .2), Color("373644")],
			[Vector3(.11, .13, 0), Vector3(.16, .26, .2), Color("373644")]
		]
	elif kind == 6:
		boxes = [
			[Vector3(0, .64, 0), Vector3(.66, .70, .48), Color("91b7c4")],
			[Vector3(0, 1.12, 0), Vector3(.42, .32, .36), Color("badce0")],
			[Vector3(-.48, .73, 0), Vector3(.25, .62, .34), Color("799daa")],
			[Vector3(.48, .73, 0), Vector3(.25, .62, .34), Color("799daa")],
			[Vector3(-.21, .17, 0), Vector3(.25, .34, .32), Color("607e91")],
			[Vector3(.21, .17, 0), Vector3(.25, .34, .32), Color("607e91")],
			[Vector3(0, 1.15, .20), Vector3(.29, .075, .045), Color("b1f6f0")]
		]
	elif kind == 7:
		boxes = [
			[Vector3(0, .64, 0), Vector3(.40, .48, .40), Color("d76b43")],
			[Vector3(0, .91, 0), Vector3(.24, .27, .24), Color("ffb86b")],
			[Vector3(0, .33, 0), Vector3(.19, .18, .19), Color("a84038")],
			[Vector3(-.31, .69, 0), Vector3(.14, .22, .14), Color("ffc785")],
			[Vector3(.31, .69, 0), Vector3(.14, .22, .14), Color("ffc785")],
			[Vector3(0, .71, .22), Vector3(.26, .075, .05), Color("fff1b0")]
		]
	else:
		var shell := Color("9079a9") if kind == 8 else Color("ba9860")
		boxes = [[Vector3(0, .33, 0), Vector3(.57, .40, .62), shell], [Vector3(0, .28, .42), Vector3(.32, .23, .29), shell.darkened(.2)]]
		for x in [-.37, .37]:
			for z in [-.23, 0, .23]:
				boxes.append([Vector3(x, .12, z), Vector3(.22, .16, .08), shell.darkened(.3)])
		if kind == 8:
			for x in [-.16, .16]:
				boxes.append([Vector3(x, .62, -.12), Vector3(.14, .26, .14), Color("cfb88f")])
		else:
			boxes.append([Vector3(0, .59, .31), Vector3(.11, .26, .1), Color("e4cf91")])
	return boxes
