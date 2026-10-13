extends Node3D

const Models = preload("res://scripts/item_models.gd")
var models := Models.new()
var markers: Dictionary = {}

func clear() -> void:
	for node in markers.values():
		remove_child(node)
		node.queue_free()
	markers.clear()

func create(entry: Dictionary) -> Node3D:
	var family: String = models.styles.family_for(entry.biome)
	var body := models.source_model(entry.model_id, family)
	if body == null:
		return null
	var bounds := Models.Bounds.bounds(body)
	var width: float = maxf(bounds.size.x, bounds.size.z)
	var footprint: Vector2 = Vector2(bounds.size.x, bounds.size.z) * (entry.marker_width / width)
	return models.fitted(body, footprint, entry.marker_height)

func sync(game, sites: Dictionary) -> void:
	visible = game.layer == "overworld" and game.has_journey
	for id in markers.keys():
		if not sites.has(id):
			var node: Node3D = markers[id]
			remove_child(node)
			node.queue_free()
			markers.erase(id)
	for id in sites:
		var entry: Dictionary = sites[id]
		if not markers.has(id):
			var model := create(entry)
			if model == null:
				continue
			model.position = Vector3(entry.point[0], entry.ground_height, entry.point[1])
			var label := Label3D.new()
			label.name = "DiscoveryLabel"
			label.text = entry.marker_label
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 28
			label.pixel_size = .012
			label.modulate = Color("ddc997")
			label.position.y = entry.marker_height + .25
			model.add_child(label)
			add_child(model)
			markers[id] = model
		var point := Vector2(entry.point[0], entry.point[1])
		markers[id].get_node("DiscoveryLabel").visible = point.distance_to(game.player_point) < 9
