extends SceneTree

const Content = preload("res://scripts/world_content.gd")
const Enemies = preload("res://scripts/enemy_catalog.gd")
const Models = preload("res://scripts/enemy_models.gd")
const Rooms = preload("res://scripts/interior_area.gd")

func _initialize() -> void:
	var catalog := Content.new()
	assert(catalog.error.is_empty())
	var future := catalog.data.duplicate(true)
	var enemy: Dictionary = future.enemies[3].duplicate(true)
	enemy.id = "future_woodland_creature"
	enemy.name = "Future woodland creature"
	enemy.visual = {"tags": ["enemy"], "patterns": ["*Skeleton*.gltf"]}
	future.enemies.push_front(enemy)
	var room: Dictionary = future.interiors[0].duplicate(true)
	room.id = "future_archive"
	room.name = "Future archive"
	future.interiors.append(room)
	var path := "user://test-world-content-%s.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(future))
	file.close()
	assert(catalog.reload(path))
	assert(catalog.get_entry("interiors", "future_archive").name == "Future archive")
	assert(Enemies.refresh(path))
	assert(Enemies.TYPES[0].id == "crypt_skeleton", "Legacy kind numbers must survive catalogue insertion")
	assert(Enemies.index_of(enemy.id) in Enemies.surface_pool(0))
	var added_model := Models.create(Enemies.index_of(enemy.id), 1)
	assert(not added_model.get_meta("asset_id").is_empty())
	added_model.free()
	assert(Rooms.content.reload(path))
	var added_room := Rooms.new()
	added_room.generate({"id": "test-future-building", "type": "future_archive"})
	assert(added_room.tiles.size() > 0 and added_room.walkable(Vector2(added_room.start)))
	assert(added_room.props.size() > 0 and added_room.readables[0].book_id == room.book)
	assert(added_room.props.any(func(prop): return prop.get("purpose", "").contains("reference books")), "Unknown data-defined interiors need purposeful reader-bound dressing")
	assert(added_room.props.filter(func(prop): return prop.get("solid", true)).size() >= mini(24, ceili(added_room.tiles.size() / 10.0)))
	assert(Rooms.content.reload())
	assert(Enemies.refresh())
	var variations := {}
	for index in range(Enemies.TYPES.size()):
		var definition: Dictionary = Enemies.TYPES[index]
		var available := catalog.models(definition.visual)
		if definition.has("sprite"):
			var sprite := catalog.registry.get_asset(definition.sprite.asset_id)
			assert(sprite.get("kind") == "texture" and catalog.registry.resource(sprite.id) is Texture2D)
			available.append(sprite)
		assert(not available.is_empty(), "Every enemy definition should use staged imported art")
		for asset in available:
			variations[asset.id] = true
			var model := Models.create(index, 123, asset.id)
			assert(model.get_meta("asset_id") == asset.id)
			var bounds := Models.bounds(model)
			assert(bounds.size.y > 0 and bounds.size.y <= definition.height + .01)
			assert(absf(bounds.position.y) < .01)
			model.free()
	assert(variations.size() >= 25)
	var records := catalog.models({"tags": ["animal"], "patterns": ["*/Wolf.gltf"]})
	assert(records.size() == 1)
	var chosen := catalog.choose_model({"tags": ["animal"]}, 1)
	assert(catalog.choose_model({"tags": ["animal"]}, 999, chosen) == chosen)
	var invalid := future.duplicate(true)
	invalid.enemies[0].visual.tags = "not an array"
	assert(not Content.valid(invalid))
	invalid = future.duplicate(true)
	invalid.enemies[0].hp = 0
	assert(not Content.valid(invalid))
	invalid = future.duplicate(true)
	invalid.interiors[0].layouts[0].props[0].footprint = [-1, 2]
	assert(not Content.valid(invalid))
	var bad_dressing: Dictionary = future.duplicate(true)
	bad_dressing.interiors[-1].dressing_type = "unknown_recipe"
	assert(not Content.valid(bad_dressing))
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	assert(not catalog.reload(path))
	assert(not catalog.get_entry("interiors", "future_archive").is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: data-only future enemy/room insertion, stable legacy IDs and asset choices, tag/pattern queries, invalid definition rejection and last-valid catalogue retention")
	quit()
