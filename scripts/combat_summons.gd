extends Node3D

const Models = preload("res://scripts/combat_summon_models.gd")
const Voxels = preload("res://scripts/voxel_kit.gd")
const DEFINITIONS := {
	"lantern_familiar": {"duration": 24.0, "hp": 35.0, "damage": 12.0, "period": 1.4, "range": 5.0, "speed": 3.0, "radius": .22, "height": .86},
	"ancestral_warden": {"duration": 22.0, "hp": 80.0, "damage": 16.0, "period": 1.6, "range": 1.65, "speed": 2.7, "radius": .32, "height": .72},
	"runic_blade": {"duration": 22.0, "hp": 40.0, "damage": 10.0, "period": 1.1, "range": 1.7, "speed": 3.4, "radius": .22, "height": .8}
}
var game
var allies: Array[Dictionary] = []
var next_id := 0
var clock := 0.0
var area

func summon(spell: String) -> bool:
	if not DEFINITIONS.has(spell) or game.state != "playing" or not game.offline_actions_allowed():
		return false
	if area != game.dungeon:
		clear()
	var point := _spawn_point(spell)
	if not point.is_finite():
		return false
	for ally in allies.duplicate():
		if ally.spell == spell:
			_remove(ally)
	if allies.size() == 2:
		_remove(allies[0])
	area = game.dungeon
	next_id += 1
	var definition: Dictionary = DEFINITIONS[spell]
	var node := Node3D.new()
	node.name = "Companion_%s_%s" % [spell, next_id]
	node.position = game.to_world(point)
	add_child(node)
	var model := Models.create(spell)
	node.add_child(model)
	var bar := Voxels.cube(Vector3(.56, .045, .045), Models.COLORS[spell], true)
	bar.position.y = 1.5
	bar.visible = false
	node.add_child(bar)
	var label := Label3D.new()
	label.name = "CompanionName"
	label.text = game.ABILITIES[spell].name
	label.position.y = 1.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = .007
	label.font_size = 18
	label.outline_size = 3
	label.modulate = Models.COLORS[spell]
	node.add_child(label)
	allies.append({"id": next_id, "spell": spell, "point": point, "node": node, "model": model, "bar": bar, "hp": definition.hp, "max_hp": definition.hp, "height": definition.height, "life": definition.duration, "attack": 0.0, "path_time": 0.0, "path": PackedVector2Array(), "path_index": 1, "flash": 0.0})
	Models.animate(model, spell, clock, false, false)
	game._ring(point, Models.COLORS[spell], .65)
	return true

func _spawn_point(spell: String) -> Vector2:
	var radius: float = DEFINITIONS[spell].radius
	for offset in [Vector2(.95, 0), Vector2(-.95, 0), Vector2(0, .95), Vector2(0, -.95), Vector2(.95, .95), Vector2(-.95, .95), Vector2(.95, -.95), Vector2(-.95, -.95), Vector2(1.8, 0), Vector2(-1.8, 0), Vector2(0, 1.8), Vector2(0, -1.8)]:
		var point: Vector2 = game.player_point + offset
		if not _supported(point, radius) or not _direct_route(game.player_point, point, radius):
			continue
		var occupied := false
		for ally in allies:
			if ally.spell != spell and point.distance_to(ally.point) < .75:
				occupied = true
		if not occupied:
			return point
	return Vector2.INF

func _supported(point: Vector2, radius: float) -> bool:
	return game.dungeon.walkable(point, radius) and game.dungeon.clearance_height(point) <= game.dungeon.ground_height(point) + .51

func _line_clear(from: Vector2, to: Vector2) -> bool:
	if not game.dungeon.line_clear(from, to):
		return false
	var samples := maxi(1, ceili(from.distance_to(to) / .12))
	for index in range(samples + 1):
		if not game.dungeon.walkable(from.lerp(to, float(index) / samples), .04):
			return false
	return true

func _direct_route(from: Vector2, to: Vector2, radius: float) -> bool:
	var samples := maxi(1, ceili(from.distance_to(to) / .12))
	var previous := from
	for index in range(1, samples + 1):
		var point := from.lerp(to, float(index) / samples)
		if not _supported(point, radius) or not game.dungeon.can_step(previous, point):
			return false
		previous = point
	return true

func _safe(point: Vector2) -> bool:
	return game.layer == "sanctum" or (game.layer == "overworld" and not game.world.city_at(point).is_empty())

func _target(ally: Dictionary) -> Dictionary:
	if _safe(game.player_point):
		return {}
	var nearest := {}
	var distance := INF
	for enemy in game.enemies:
		if enemy.hp <= 0 or enemy.point.distance_to(game.player_point) > 7.5 or _safe(enemy.point):
			continue
		if enemy == game.selected_target:
			return enemy
		if not game.EnemyCatalog.should_engage(game.EnemyCatalog.TYPES[enemy.kind], enemy.active, true):
			continue
		var candidate: float = enemy.point.distance_squared_to(ally.point)
		if candidate < distance:
			distance = candidate
			nearest = enemy
	return nearest

func step(delta: float) -> void:
	if game.state == "dead" or area != game.dungeon:
		clear()
		return
	if game.state != "playing" or not game.offline_actions_allowed():
		return
	clock += delta
	for ally in allies.duplicate():
		ally.life -= delta
		if ally.life <= 0 or not is_instance_valid(ally.node):
			_remove(ally)
			continue
		var definition: Dictionary = DEFINITIONS[ally.spell]
		ally.attack = maxf(0, ally.attack - delta)
		ally.path_time -= delta
		ally.flash = maxf(0, ally.flash - delta)
		var enemy := _target(ally)
		var goal: Vector2 = game.player_point if enemy.is_empty() else enemy.point
		var reach: float = 1.15 if enemy.is_empty() else definition.range
		var distance: float = ally.point.distance_to(goal)
		var clear_line := _line_clear(ally.point, goal)
		var previous: Vector2 = ally.point
		if distance > reach * .85 or not clear_line:
			_move(ally, goal, definition, minf(delta, .2))
		_separate(ally, minf(delta, .2))
		if not enemy.is_empty() and ally.attack <= 0 and ally.point.distance_to(enemy.point) <= definition.range and _line_clear(ally.point, enemy.point):
			ally.attack = definition.period
			_strike(ally, enemy, definition.damage)
		ally.node.position = game.to_world(ally.point)
		var facing: Vector2 = goal - ally.point
		if not facing.is_zero_approx():
			ally.node.rotation.y = atan2(facing.x, facing.y)
		ally.model.scale = Vector3.ONE * (1.08 if ally.flash > 0 else 1.0)
		ally.bar.visible = ally.hp < ally.max_hp
		ally.bar.scale.x = maxf(.01, ally.hp / ally.max_hp)
		Models.animate(ally.model, ally.spell, clock, previous != ally.point, ally.attack > definition.period - .2)

func _move(ally: Dictionary, goal: Vector2, definition: Dictionary, delta: float) -> void:
	if ally.path_time <= 0:
		ally.path_time = .45
		var from := Vector2i(ally.point.round())
		var to := Vector2i(goal.round())
		ally.path = game.astar.get_point_path(game.navigation_ids[from], game.navigation_ids[to]) if game.navigation_ids.has(from) and game.navigation_ids.has(to) else PackedVector2Array()
		ally.path_index = 1
		if ally.path.size() > 1 and not _direct_route(ally.point, ally.path[1], definition.radius):
			ally.path_index = 0
	var target := goal
	if not _direct_route(ally.point, goal, definition.radius):
		while ally.path_index < ally.path.size() and ally.point.distance_to(ally.path[ally.path_index]) < .16:
			ally.path_index += 1
		if ally.path_index >= ally.path.size():
			return
		target = ally.path[ally.path_index]
	var movement: Vector2 = (target - ally.point).limit_length(definition.speed * delta)
	var parts := maxi(1, ceili(movement.length() / .12))
	for index in range(parts):
		var next: Vector2 = game.dungeon.move_actor(ally.point, movement / parts)
		if not _supported(next, definition.radius):
			break
		ally.point = next

func _separate(ally: Dictionary, delta: float) -> void:
	for other in allies:
		if other == ally:
			continue
		var offset: Vector2 = ally.point - other.point
		if offset.length() >= .6:
			continue
		if offset.is_zero_approx():
			offset = Vector2.LEFT if ally.id < other.id else Vector2.RIGHT
		var point: Vector2 = game.dungeon.move_actor(ally.point, offset.normalized() * delta * .8)
		if _supported(point, DEFINITIONS[ally.spell].radius):
			ally.point = point

func _strike(ally: Dictionary, enemy: Dictionary, damage: float) -> void:
	var color: Color = Models.COLORS[ally.spell]
	if ally.spell == "lantern_familiar":
		var from: Vector3 = game.to_world(ally.point, ally.height)
		var to: Vector3 = game.to_world(enemy.point, .55)
		for index in range(8):
			game._particle(from.lerp(to, float(index) / 7), color, Vector3.ZERO, .16, .075)
	else:
		game._ring(enemy.point, color, .25)
	game._hit_enemy(enemy, damage * game.damage_multiplier, ally.spell)

func enemy_target(enemy: Dictionary) -> Dictionary:
	if game.state != "playing" or not game.offline_actions_allowed() or not game.enemies.has(enemy) or enemy.point.distance_to(game.player_point) > 7.5 or _safe(game.player_point) or _safe(enemy.point):
		return {}
	var distance: float = enemy.point.distance_to(game.player_point)
	var target := {}
	for ally in allies:
		var candidate: float = enemy.point.distance_to(ally.point)
		if ally.hp > 0 and candidate < distance and candidate <= 7.5 and _line_clear(enemy.point, ally.point):
			distance = candidate
			target = ally
	return target

func hurt(ally: Dictionary, damage: float) -> bool:
	if game.state != "playing" or not game.offline_actions_allowed() or not allies.has(ally) or damage <= 0 or _safe(game.player_point) or _safe(ally.point):
		return false
	ally.hp = maxf(0, ally.hp - damage)
	ally.flash = .15
	game._ring(ally.point, Models.COLORS[ally.spell], .22)
	game.sound.play_effect("impact")
	if ally.hp <= 0:
		_remove(ally)
	return true

func projectile_hit(point: Vector2, height: float, damage: float) -> bool:
	for ally in allies.duplicate():
		if point.distance_to(ally.point) < .4 and absf(height - game.dungeon.ground_height(ally.point) - ally.height) < .45:
			if hurt(ally, damage):
				return true
	return false

func _remove(ally: Dictionary) -> void:
	if is_instance_valid(ally.node):
		ally.node.queue_free()
	allies.erase(ally)

func clear() -> void:
	for ally in allies.duplicate():
		_remove(ally)
	area = null
