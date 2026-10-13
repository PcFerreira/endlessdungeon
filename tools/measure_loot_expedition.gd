extends SceneTree

const Game = preload("res://scripts/game.gd")
const Items = preload("res://scripts/item_catalog.gd")
var game
var path: PackedVector2Array = []
var path_timer := 0.0

func _initialize() -> void:
	call_deferred("measure")

func measure() -> void:
	var reports := []
	for class_id in ["mage", "sword", "spellsword"]:
		game = Game.new()
		game.records_enabled = false
		game.save_directory = "user://loot-measure-%s-%s" % [class_id,Time.get_ticks_usec()]
		game.settings_path = game.save_directory.path_join("settings.cfg")
		root.add_child(game)
		game.set_physics_process(false)
		game.start_run(12345)
		game.state = "title"
		game.choose_class(class_id)
		assert(game.build.class_id == class_id)
		game.begin_journey()
		var site: Dictionary = game.world.nearest_site(game.player_point,"dungeon")
		game.enter_dungeon(site)
		var stats := {"class":class_id,"seed":12345,"family":site.family,"outcome":"time_limit","active_seconds":0.0,"kills":0,"coins":0,"shards":0,"bag_items":0,"consumables":0,"equipment":0,"materials":0,"furnishings":0,"equipment_upgrades":0,"consumed_items":0,"blocked_pickups":0,"maximum_slots":game.inventory.slots_used()}
		var blocked := {}
		path = []
		path_timer = 0
		for frame in range(54000):
			if game.state == "dead":
				stats.outcome = "defeated"
				break
			if game.state == "reader":
				game.expansion.close_lore()
			if game.state != "playing":
				stats.outcome = "modal:"+game.state
				break
			var before: Dictionary = game.inventory.items.duplicate()
			_tick(1.0/60)
			for id in game.inventory.items:
				var quantity: int = game.inventory.count(id)-int(before.get(id,0))
				if quantity <= 0 or id in ["gold_coin","ember_shard"]:
					continue
				var item: Dictionary = Items.definitions[id]
				stats.bag_items += quantity
				stats["equipment" if item.kind == "equipment" else item.kind+"s"] += quantity
				if item.kind == "equipment" and _upgrade(item):
					game.equip_item(id)
					stats.equipment_upgrades += 1
			for id in game.inventory.items.keys():
				var item: Dictionary = Items.definitions[id]
				if item.kind == "consumable" and ((item.get("restore_health",0)>0 and game.max_hp-game.hp >= item.get("restore_health",0)) or (item.get("restore_mana",0)>0 and game.max_mana-game.mana >= item.get("restore_mana",0))):
					if game.use_item(id):
						stats.consumed_items += 1
			for pickup in game.pickups:
				if pickup.get("notified",false):
					blocked[pickup.node.get_instance_id()] = true
			stats.maximum_slots = maxi(stats.maximum_slots,game.inventory.slots_used())
			if game.claimed_chests.has(site.id) and not game.pickups.any(func(pickup): return not pickup.get("notified",false)):
				stats.outcome = "completed"
				break
			if frame % 60 == 0:
				await process_frame
		stats.active_seconds = snappedf(game.elapsed,.01)
		stats.kills = game.kills
		stats.coins = game.inventory.count("gold_coin")
		stats.shards = game.inventory.count("ember_shard")
		stats.final_depth = game.depth
		stats.chest_claimed = game.claimed_chests.has(site.id)
		stats.blocked_pickups = blocked.size()
		stats.potion_purchases_affordable = floori(float(stats.coins)/4)
		stats.lantern_purchases_affordable = floori(float(stats.coins)/12)
		reports.append(stats)
		game.queue_free()
		await process_frame
	var report := {"method":"Automated dungeon expedition, actual default abilities, HP, collision, projectiles, loot and collection; started at the real entrance, no instant kills or resource refills. Stops on completion/death or 900 active seconds. Human exploration/balance acceptance remains separate.","reports":reports}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/loot-expeditions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PASS: measured actual controlled expeditions: ",JSON.stringify(reports))
	quit()

func _upgrade(item: Dictionary) -> bool:
	if game.build.class_id not in item.classes:
		return false
	var id: String = game.inventory.equipment[item.slot]
	var old: Dictionary = Items.definitions[id] if not id.is_empty() else {}
	return float(item.get("power",0))+float(item.get("hp",0))+float(item.get("mana",0)) > float(old.get("power",0))+float(old.get("hp",0))+float(old.get("mana",0))

func _tick(delta: float) -> void:
	var target: Dictionary = {}
	var distance := INF
	for enemy in game.enemies:
		var next: float = enemy.point.distance_squared_to(game.player_point)
		if next < distance:
			distance = next
			target = enemy
	var goal: Vector2 = Vector2(game.dungeon.exit)+Vector2.DOWN
	if not target.is_empty():
		goal = target.point
		if game.enemy_render_visible(target.point) and game.dungeon.line_clear(game.player_point,target.point):
			game.select_target(target)
			game.aim = (target.point-game.player_point).normalized()
			game.cast_slot(0)
			game.cast_slot(1)
	for pickup in game.pickups:
		if not pickup.get("notified",false) and (target.is_empty() or pickup.point.distance_to(game.player_point)<3):
			goal = pickup.point
			break
	path_timer -= delta
	if path_timer <= 0:
		path_timer = .2
		var from := Vector2i(game.player_point.round())
		var to := Vector2i(goal.round())
		path = game.astar.get_point_path(game.navigation_ids[from],game.navigation_ids[to]) if game.navigation_ids.has(from) and game.navigation_ids.has(to) else PackedVector2Array()
		if path.size()>1:
			path.remove_at(0)
	var range_limit := 1.1 if game.build.class_id=="sword" else 4.0
	var collecting: bool = goal!=target.get("point",Vector2.INF)
	if not path.is_empty() and (collecting or game.player_point.distance_to(goal)>range_limit or not game.dungeon.line_clear(game.player_point,goal)):
		var movement: Vector2 = (path[0]-game.player_point).normalized()*3.8*delta
		game.player_point = game.dungeon.move_actor(game.player_point,movement,game.player_y,false)
		if game.player_point.distance_to(path[0])<.08:
			path.remove_at(0)
	game.simulate(delta)
	if game.enemies.is_empty() and game.player_point.distance_to(game.dungeon.exit)<1.6 and not game.claimed_chests.has(game.active_dungeon.id):
		game.interact()
		path = []
