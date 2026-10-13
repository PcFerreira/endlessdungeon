extends Node3D

const Voxels = preload("res://scripts/voxel_kit.gd")
const EFFECT_CAP := 40
var game
var conditions: Dictionary = {}
var visuals: Array[Dictionary] = []
var barrier := 0.0
var barrier_time := 0.0
var barrier_node: Node3D

func clear() -> void:
	conditions.clear()
	visuals.clear()
	barrier = 0
	barrier_time = 0
	barrier_node = null
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _line_clear(from: Vector2, to: Vector2) -> bool:
	if not game.dungeon.line_clear(from, to):
		return false
	var samples := maxi(1, ceili(from.distance_to(to) / .15))
	for index in range(samples + 1):
		if not game.dungeon.walkable(from.lerp(to, float(index) / samples), .03):
			return false
	return true

func _key(enemy: Dictionary) -> int:
	return enemy.node.get_instance_id()

func immobilized(enemy: Dictionary) -> bool:
	var record: Dictionary = conditions.get(_key(enemy), {})
	return record.get("freeze", 0) > 0 or record.get("stun", 0) > 0

func _condition(enemy: Dictionary, color: Color) -> Dictionary:
	var key := _key(enemy)
	if not conditions.has(key):
		var node := Node3D.new()
		node.position = game.to_world(enemy.point)
		add_child(node)
		for index in range(6):
			var angle := index * TAU / 6
			var rune := Voxels.cube(Vector3(.10, .2, .10), color, true)
			rune.position = Vector3(cos(angle) * .33, 1.2, sin(angle) * .33)
			node.add_child(rune)
		conditions[key] = {"enemy": enemy, "freeze": 0.0, "stun": 0.0, "burn": 0.0, "tick": 0.0, "damage": 0.0, "node": node}
	else:
		for rune in conditions[key].node.get_children():
			rune.material_override = Voxels.glow(color)
	return conditions[key]

func cast(spell: String) -> bool:
	if not game.offline_actions_allowed() or game.state != "playing":
		return false
	var ability: Dictionary = game.ABILITIES[spell]
	var target: Dictionary = game.selected_target
	if ability.range > 0 and (not game.valid_enemy(target) or not _line_clear(game.player_point, target.point)):
		game.notify("The target is hidden behind solid ground or furnishings.")
		return false
	var damage: float = ability.damage * game.damage_multiplier
	match spell:
		"ice_lance":
			beam(game.player_point, target.point, ability.color)
			game._hit_enemy(target, damage, spell)
			if game.valid_enemy(target):
				_condition(target, ability.color).freeze = ability.freeze
				target.windup = 0
		"chain_lightning":
			var struck := []
			var source: Vector2 = game.player_point
			for index in range(int(ability.chains)):
				var point: Vector2 = target.point
				beam(source, point, ability.color, true)
				game._hit_enemy(target, damage * pow(.8, index), spell)
				struck.append(target)
				source = point
				var nearest := {}
				var distance: float = ability.radius
				for enemy in game.enemies:
					var gap: float = enemy.point.distance_to(source)
					if not struck.has(enemy) and gap <= distance and game.valid_enemy(enemy) and _line_clear(source, enemy.point):
						nearest = enemy
						distance = gap
				if nearest.is_empty():
					break
				target = nearest
		"quake_strike":
			if not game.grounded:
				game.notify("Stand on solid ground to strike the earth.")
				return false
			wave(game.player_point, ability.color, ability.radius)
			game.shake = .4
			for enemy in game.enemies.duplicate():
				if enemy.point.distance_to(game.player_point) <= ability.radius and _line_clear(game.player_point, enemy.point):
					game._hit_enemy(enemy, damage, spell)
					if game.valid_enemy(enemy):
						_condition(enemy, ability.color).stun = ability.stun
						enemy.windup = 0
		"aegis":
			barrier = ability.barrier
			barrier_time = ability.duration
			if is_instance_valid(barrier_node):
				remove_child(barrier_node)
				barrier_node.queue_free()
			barrier_node = _ring(ability.color, .65)
			add_child(barrier_node)
			for index in range(8):
				var angle := index * TAU / 8
				var pillar := Voxels.cube(Vector3(.025, 1.25, .025), ability.color, true)
				pillar.position = Vector3(cos(angle) * .65, 0, sin(angle) * .65)
				barrier_node.add_child(pillar)
			barrier_node.position = Vector3(game.player_point.x, game.player_y + .8, game.player_point.y)
		"cinder_brand":
			beam(game.player_point, target.point, ability.color)
			game._hit_enemy(target, damage, spell)
			if game.valid_enemy(target):
				var record := _condition(target, ability.color)
				record.burn = ability.duration
				record.tick = 0
				record.damage = ability.burn * game.damage_multiplier
		"siphon_touch":
			var dealt: float = minf(target.hp, damage)
			beam(target.point, game.player_point, ability.color)
			game._hit_enemy(target, damage, spell)
			game.hp = minf(game.max_hp, game.hp + dealt * ability.heal_ratio)
			wave(game.player_point, ability.color, .8)
		_:
			return false
	return true

func absorb(damage: float) -> float:
	var consumed := minf(barrier, maxf(0, damage))
	barrier -= consumed
	if consumed > 0:
		wave(game.player_point, Color("a1ddeb"), .7)
	return damage - consumed

func _ring(color: Color, radius: float) -> Node3D:
	var node := Node3D.new()
	for index in range(24):
		var angle := index * TAU / 24
		var segment := Voxels.cube(Vector3(.14, .035, .05), color, true)
		segment.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		segment.rotation.y = -angle
		node.add_child(segment)
	return node

func _visual(node: Node3D, duration: float) -> void:
	if visuals.size() >= EFFECT_CAP:
		var oldest: Dictionary = visuals.pop_front()
		remove_child(oldest.node)
		oldest.node.queue_free()
	add_child(node)
	visuals.append({"node": node, "life": duration, "duration": duration})

func wave(point: Vector2, color: Color, radius: float) -> void:
	var node := _ring(color, radius)
	node.position = game.to_world(point, .08)
	_visual(node, .6)

func beam(from: Vector2, to: Vector2, color: Color, lightning: bool = false) -> void:
	var start: Vector3 = game.to_world(from, .8)
	var end: Vector3 = game.to_world(to, .8)
	if start.distance_to(end) < .01:
		return
	var root := Node3D.new()
	root.position = start
	var count := 6 if lightning else 1
	var last := start
	var sideways := (end - start).cross(Vector3.UP).normalized()
	for index in range(1, count + 1):
		var next := start.lerp(end, float(index) / count)
		if index < count:
			next += sideways * (.18 if index % 2 == 0 else -.18)
		var piece := Voxels.cube(Vector3(.05, .05, last.distance_to(next)), color, true)
		piece.position = (last + next) * .5 - start
		root.add_child(piece)
		piece.basis = Basis.looking_at(next - last, Vector3.UP)
		last = next
	_visual(root, .45)

func step(delta: float) -> void:
	if game.state == "dead":
		clear()
		return
	if game.state != "playing" or not game.offline_actions_allowed():
		return
	barrier_time = maxf(0, barrier_time - delta)
	if barrier_time == 0:
		barrier = 0
	if is_instance_valid(barrier_node):
		if barrier <= 0:
			remove_child(barrier_node)
			barrier_node.queue_free()
			barrier_node = null
		else:
			barrier_node.position = Vector3(game.player_point.x, game.player_y + .8, game.player_point.y)
			barrier_node.rotation.y += delta * .6
	for key in conditions.keys():
		var record: Dictionary = conditions[key]
		if game.valid_enemy(record.enemy):
			record.freeze = maxf(0, record.freeze - delta)
			record.stun = maxf(0, record.stun - delta)
			record.tick += minf(record.burn, delta)
			record.burn = maxf(0, record.burn - delta)
			while record.tick >= 1 and game.valid_enemy(record.enemy):
				record.tick -= 1
				game._hit_enemy(record.enemy, record.damage, "cinder_brand")
			record.node.position = game.to_world(record.enemy.point)
			record.node.rotation.y += delta * 2
		if not game.valid_enemy(record.enemy) or record.freeze == 0 and record.stun == 0 and record.burn == 0:
			remove_child(record.node)
			record.node.queue_free()
			conditions.erase(key)
	for record in visuals.duplicate():
		record.life -= delta
		if record.life <= 0:
			remove_child(record.node)
			record.node.queue_free()
			visuals.erase(record)
		else:
			record.node.scale = Vector3.ONE * (1 + (1 - record.life / record.duration) * .12)
