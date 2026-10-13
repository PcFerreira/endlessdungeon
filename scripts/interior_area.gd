extends "res://scripts/grid_area.gd"

const Content = preload("res://scripts/world_content.gd")
const Placement = preload("res://scripts/contextual_placement.gd")
const Styles = preload("res://scripts/environment_styles.gd")
const Dressing = preload("res://scripts/interior_dressing.gd")
static var content := Content.new()
static var styles := Styles.new(content.registry)
var biome := 0
var size := 18
var start := Vector2i.ZERO
var exit := Vector2i.ZERO
var place: Dictionary = {}
var props: Array[Dictionary] = []
var readables: Array[Dictionary] = []
var rest_point := Vector2.ZERO

func generate(destination: Dictionary) -> void:
	place = destination
	biome = int(place.get("biome", 0))
	assert(not styles.family_for(biome).is_empty(), "Indoor climate must come from its real owning town")
	tiles.clear()
	obstacles.clear()
	props.clear()
	readables.clear()
	var definition: Dictionary = content.get_entry("interiors", place.type)
	var dimensions := Vector2i(definition.size[0], definition.size[1])
	size = maxi(dimensions.x, dimensions.y)
	bounds = Rect2i(Vector2i.ZERO, dimensions)
	start = Vector2i(dimensions.x / 2, dimensions.y - 4)
	exit = Vector2i(start.x, dimensions.y - 2)
	for x in range(1, dimensions.x - 1):
		for y in range(1, dimensions.y - 1):
			tiles[Vector2i(x, y)] = true
	var layouts: Array = definition.layouts
	var recipe: Dictionary = layouts[posmod(hash(place.id), layouts.size())]
	for layout in layouts:
		if layout.id == place.get("layout_id", ""):
			recipe = layout
	place.layout_id = recipe.id
	var variants: Dictionary = place.get("variants", {}).duplicate()
	var defaults: Dictionary = content.data.interior_defaults
	for index in range(defaults.props.size()):
		_add_prop(defaults.props[index], index, variants)
	var readable: Dictionary = defaults.readable
	readables.append({"kind": "book", "id": place.id + ":book", "book_id": definition.book, "point": Vector2(readable.point[0], readable.point[1]), "approach": Vector2(readable.approach[0], readable.approach[1])})
	rest_point = Vector2(definition.rest[0], definition.rest[1]) if definition.get("rest") is Array else Vector2.ZERO
	for index in range(recipe.props.size()):
		_add_prop(recipe.props[index], index + defaults.props.size(), variants)
	Dressing.new().decorate(self, variants)
	place.variants = variants

func _add_prop(spec: Dictionary, index: int, variants: Dictionary) -> void:
	var key: String = spec.get("source_key", str(index))
	var saved: String = variants.get(key, "")
	var family := styles.family_for(biome)
	var role: String = styles.data.anchors.get(spec.fallback, spec.fallback)
	assert(styles.supports(role), "Interior fixtures need a purposeful native fallback role")
	var candidates: Array = content.models(spec.query).filter(func(asset): return styles.allows(asset.id, biome)) if spec.has("query") else []
	var asset_id: String = styles.native_id(family, role)
	if styles.allows(saved, biome) and (saved == asset_id or candidates.any(func(asset): return asset.id == saved)):
		asset_id = saved
	elif not candidates.is_empty():
		asset_id = candidates[posmod(hash("%s:%s" % [place.id, key]), candidates.size())].id
	if not asset_id.begins_with("native_environment:") and content.registry.resource(asset_id) == null:
		asset_id = styles.native_id(family, role)
	variants[key] = asset_id
	var point := Vector2(spec.point[0], spec.point[1])
	var footprint := Vector2(spec.footprint[0], spec.footprint[1])
	props.append({"kind": asset_id, "fallback": spec.fallback, "visual_family": family, "point": point, "width": footprint.x, "footprint": footprint, "height": spec.height, "yaw": Placement.yaw(spec), "elevation": spec.get("elevation", 0.0), "solid": spec.get("solid", true), "source_key": key, "parent": spec.get("parent", ""), "purpose": spec.get("purpose", "Fixtures for " + place.type)})
	if spec.get("solid", true):
		obstacles.append(Rect2(point - footprint * .5, footprint))

