extends Node3D

const Actors = preload("res://scripts/actor_models.gd")
const Registry = preload("res://scripts/asset_registry.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const AnimalHabitat = preload("res://scripts/animal_habitat.gd")
const CreatureModels = preload("res://scripts/creature_models.gd")
const Decor = preload("res://scripts/decor_geometry.gd")
var creatures := CreatureModels.new()
var registry := Registry.new()
var scenery := Scenery.new()
var models: Dictionary = {}
var animations: Dictionary = {}
var motions: Dictionary = {}
var episode_root: Node3D
var episode_id := ""
var episode_phase := ""
var npc_models: Dictionary = {}

func reset() -> void:
	for id in models:
		npc_models.erase(id)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	models.clear()
	animations.clear()
	motions.clear()
	episode_root = null
	episode_id = ""
	episode_phase = ""

func sync(game) -> void:
	visible = game.layer == "overworld"
	if not visible:
		return
	npc_models = game.world_view.npc_models
	for id in models.keys():
		if not game.life.actors.has(id):
			remove_child(models[id])
			models[id].queue_free()
			models.erase(id)
			animations.erase(id)
			motions.erase(id)
			npc_models.erase(id)
	for actor in game.life.actors.values():
		if not models.has(actor.id):
			var model := _create(actor)
			add_child(model)
			models[actor.id] = model
			var players: Array[AnimationPlayer] = []
			for player in model.find_children("*", "AnimationPlayer", true, false):
				players.append(player)
			animations[actor.id] = players
			if actor.kind == "npc":
				npc_models[actor.id] = model
				if actor.get("traveling", false):
					var label := Label3D.new()
					label.name = "WatchLabel"
					label.text = game.life.activity.role(actor.role).name
					label.font_size = 24
					label.pixel_size = .008
					label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					label.modulate = Color("dfd0ab")
					label.position.y = 1.6
					model.add_child(label)
		var model: Node3D = models[actor.id]
		if actor.kind == "npc" and actor.role == "guard":
			var label: Label3D = model.get_node_or_null("WatchLabel")
			if label != null:
				label.text = "Return the city's property" if actor.get("law_mode", "patrol") == "guard_demand" else ("Town watch / pursuing" if actor.get("law_mode", "patrol") == "guard_pursuit" else "Town guard")
				label.modulate = Color("e9a47c") if actor.get("law_mode", "patrol") == "guard_pursuit" else Color("dfd0ab")
		model.position = Vector3(actor.point.x, AnimalHabitat.height(game.world, actor.point, actor.get("medium", "land")), actor.point.y)
		model.rotation.y = atan2(actor.heading.x, actor.heading.y)
		_animate(actor)
	_update_episode(game)

func _create(actor: Dictionary) -> Node3D:
	if actor.kind == "npc":
		return Actors.create(actor.appearance, actor)
	var source := creatures.instantiate(actor.asset_id, int(actor.get("biome", 0)))
	var model := Node3D.new()
	if source == null:
		push_error(creatures.error)
		return model
	model.add_child(source)
	for key in ["source_asset", "render_asset", "visual_family", "representation"]:
		model.set_meta(key, source.get_meta(key))
	var bounds := Actors._bounds(source, Transform3D.IDENTITY)
	var scale_factor: float = minf(actor.height / maxf(.01, bounds.size.y), 1.4 / maxf(.01, maxf(bounds.size.x, bounds.size.z)))
	source.scale = Vector3.ONE * scale_factor
	source.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_factor
	return model

func _animate(actor: Dictionary) -> void:
	var desired := "Walk" if actor.moving else "Idle"
	if actor.kind == "npc" and actor.role == "guard" and actor.get("law_windup_tick",0) > 0:
		desired = "Attack"
	if actor.kind == "animal":
		desired = actor.walk if actor.moving else actor.idle
	if motions.get(actor.id, "") == desired:
		return
	motions[actor.id] = desired
	for player in animations[actor.id]:
		var key: String = Actors.animation_key(player, desired) if actor.kind == "npc" else desired
		if not key.is_empty() and player.has_animation(key):
			player.get_animation(key).loop_mode = Animation.LOOP_LINEAR
			player.play(key, .15)
		elif player.has_animation("Idle"):
			player.play("Idle", .15)

func _update_episode(game) -> void:
	var city := {}
	var distance := 24.0
	for candidate in game.life.cities.values():
		var next: float = Vector2(candidate.cell).distance_to(game.player_point)
		if next < distance:
			city = candidate
			distance = next
	var episode: Dictionary = game.life.event_at(city.id) if not city.is_empty() else {}
	var id: String = episode.get("instance_id", "")
	var phase: String = episode.get("phase", "")
	if id == episode_id and phase == episode_phase:
		return
	var busy: bool = game.enemies.any(func(enemy): return enemy.active)
	if not id.is_empty() and id != episode_id and busy:
		if is_instance_valid(episode_root):
			remove_child(episode_root)
			episode_root.queue_free()
		episode_root = null
		episode_id = ""
		episode_phase = ""
		return
	if is_instance_valid(episode_root):
		remove_child(episode_root)
		episode_root.queue_free()
	episode_root = null
	episode_id = id
	episode_phase = phase
	if id.is_empty():
		return
	var point: Vector2 = game.world.safe_position(Vector2(city.cell) + Vector2(0,3), 1)
	episode_root = Node3D.new()
	var family: String = creatures.styles.family_for(city.biome)
	episode_root.set_meta("visual_family", family)
	episode_root.set_meta("episode_id", id)
	episode_root.position = Vector3(point.x + .4, game.world.ground_height(point), point.y + .25)
	add_child(episode_root)
	if episode.visual == "crates":
		var crates := _episode_model("crates", .6, .55, family)
		episode_root.add_child(crates)
	elif episode.visual == "meal":
		var blanket := Decor.node([[Vector3.ZERO, Vector3(.9,.035,.65), Color("ba8e68")]], family, "episode_rug")
		blanket.position.y = .0175
		episode_root.add_child(blanket)
		var pot := _episode_model("pot", .25, .28, family)
		pot.position = Vector3(0,.035,0)
		episode_root.add_child(pot)
		for side in [-1,1]:
			var cup := _episode_model("tea", .10, .12, family)
			cup.position = Vector3(side * .3,.035,.08)
			episode_root.add_child(cup)
	elif episode.visual == "banner":
		episode_root.add_child(_episode_model("banner", .45, 1.2, family))
	else:
		var table := _episode_model("table", .8, .5, family)
		episode_root.add_child(table)
		for index in range(3):
			var goods := _episode_model("book" if episode.visual == "books" else "bread", .16, .07, family)
			goods.position = Vector3((index - 1) * .21,.5,0)
			episode_root.add_child(goods)
	var label := Label3D.new()
	label.text = episode.get("aftermath", "Delivery received" if episode.visual == "crates" else "Cups left to dry") if phase == "aftermath" else episode.label
	label.font_size = 24
	label.pixel_size = .009
	label.modulate = Color("dfd0ab")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = .85
	episode_root.add_child(label)

func _episode_model(role: String, width: float, height: float, family: String) -> Node3D:
	var id: String = creatures.styles.native_id(family, role)
	var model := scenery.model(id, width, height)
	model.set_meta("asset_id", id)
	for part in model.find_children("*", "MeshInstance3D", true, false):
		part.set_meta("asset_id", id)
		part.set_meta("visual_family", family)
	return model
