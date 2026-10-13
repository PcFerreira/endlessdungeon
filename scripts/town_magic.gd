extends Node3D

const Decor = preload("res://scripts/decor_geometry.gd")
const Styles = preload("res://scripts/environment_styles.gd")
static var styles := Styles.new()
var floating: Array[Node3D] = []
var origins: Array[Vector3] = []
var ring: Node3D
var clock := 0.0
var phase := 0.0

static func plan(city: Dictionary, profile_id: String, profile: Dictionary, seed_value: int) -> Dictionary:
	var rune_cells: Array[Vector2i] = []
	for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		for distance in profile.rune_distances:
			var cell: Vector2i = city.cell + direction * int(distance)
			if city.streets.has(cell):
				rune_cells.append(cell)
	var houses: Array = city.houses.duplicate()
	houses.sort_custom(func(a,b): return (hash("%s:%s" % [seed_value,a.id]) & 0x7fffffff) < (hash("%s:%s" % [seed_value,b.id]) & 0x7fffffff))
	var charms: Array[Dictionary] = []
	for house in houses.slice(0,int(profile.roof_charm_cap)):
		var center := Vector2(house.footprint.position) + (Vector2(house.footprint.size) - Vector2.ONE) * .5
		charms.append({"house_id": house.id,"point": Vector3(center.x,city.height + house.height + 1.28,center.y)})
	return {"id": city.id + ":charm","profile_id": profile_id,"profile": profile,"seed": seed_value,"rune_cells": rune_cells,"roof_charms": charms,"support": city.cell}

func build(city: Dictionary, house_models: Dictionary = {}, fountain: Node3D = null) -> void:
	var magic: Dictionary = city.magic
	var profile: Dictionary = magic.profile
	var color := Color(profile.color)
	var accent := Color(profile.accent)
	var family := styles.family_for(city.biome)
	set_meta("visual_family", family)
	phase = fmod(float(magic.seed),1000) * .01
	var core_boxes := []
	for piece in profile.pieces:
		core_boxes.append([Vector3(piece.point[0],piece.point[1],piece.point[2]),Vector3(piece.size[0],piece.size[1],piece.size[2]),color if piece.color == "color" else accent])
	var core := Decor.node(core_boxes, family, "civic_core")
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = .35
	core.material_override = material
	var support_height: float = .6 if fountain == null else Decor.bounds(fountain).end.y
	core.position = Vector3(0,maxf(2.0, support_height + .30 - core.mesh.get_aabb().position.y + .07),0)
	core.set_meta("support_height", support_height)
	add_child(core)
	floating.append(core)
	origins.append(core.position)
	ring = Node3D.new()
	ring.position.y = .60
	add_child(ring)
	for index in range(12):
		var angle := index * TAU / 12
		var rune := Decor.node([[Vector3.ZERO, Vector3(.13,.045,.075), accent]], family, "street_rune", true)
		rune.position = Vector3(cos(angle) * .61,0,sin(angle) * .61)
		rune.rotation.y = -angle
		ring.add_child(rune)
	for charm in magic.roof_charms:
		var light := Decor.node([[Vector3.ZERO, Vector3(.15,.24,.15), color]], family, "roof_charm", true)
		light.position = charm.point - Vector3(city.cell.x,city.height,city.cell.y)
		var support: float = light.position.y - 1.28 + 1.0
		if house_models.has(charm.house_id):
			support = Decor.bounds(house_models[charm.house_id]).end.y
		light.position.y = support + .28
		light.set_meta("house_id", charm.house_id)
		light.set_meta("support_height", support)
		add_child(light)
		floating.append(light)
		origins.append(light.position)
	for cell in magic.rune_cells:
		var mark := Node3D.new()
		mark.position = Vector3(cell.x - city.cell.x,.025,cell.y - city.cell.y)
		add_child(mark)
		for offset in [Vector3(-.14,0,-.14),Vector3(.14,0,-.14),Vector3(.14,0,.14),Vector3(-.14,0,.14)]:
			var stroke := Decor.node([[Vector3.ZERO, Vector3(.39,.02,.055), accent]], family, "street_rune", true)
			stroke.position = offset
			stroke.rotation.y = PI * .25 * (1 if offset.x * offset.z > 0 else -1)
			mark.add_child(stroke)
	var label := Label3D.new()
	label.text = profile.name
	label.position = Vector3(0,core.position.y + core.mesh.get_aabb().end.y + .25,0)
	label.font_size = 34
	label.pixel_size = .004
	label.modulate = accent
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 5
	add_child(label)

func _process(delta: float) -> void:
	clock += delta
	for index in range(floating.size()):
		var angle := clock * .65 + phase + index * 1.7
		floating[index].position = origins[index] + Vector3(0,sin(angle) * .07,0)
		floating[index].rotation.y = angle * .35
	if ring != null:
		ring.rotation.y = clock * .12 + phase
