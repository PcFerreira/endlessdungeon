extends Node3D

const Decor = preload("res://scripts/decor_geometry.gd")
const Styles = preload("res://scripts/environment_styles.gd")
static var styles := Styles.new()
const STYLES := ["timber_lattice","bracket_eaves","quiet_tiles","pumpkin_lights","evergreen_lights","arcane_circuit","rune_lattice","petal_trim"]

static func plan(house: Dictionary, profile: Dictionary, actual_bounds: AABB = AABB()) -> Dictionary:
	var width: float = house.footprint.size.x - .07
	var length: float = house.footprint.size.y - .07
	if house.facing.x != 0:
		var previous := width
		width = length
		length = previous
	var height: float = house.height
	if actual_bounds.size != Vector3.ZERO:
		width = minf(width, actual_bounds.size.x)
		length = minf(length, actual_bounds.size.z)
		height = maxf(.01, actual_bounds.end.y - 1.0)
	var front := length * .5 + .012
	var color := Color(profile.color)
	var accent := Color(profile.accent)
	var wood := Color("654c39")
	var solid := []
	var glow := []
	match profile.style:
		"timber_lattice":
			solid.append([Vector3(0,height + .98,0),Vector3(.12,.10,length * .80),wood])
			for side in [-1,1]:
				for offset in [-.12,0,.12]:
					solid.append([Vector3(side * width * .23 + offset,height * .65 + .20,front),Vector3(.025,.36,.035),wood])
				solid.append([Vector3(side * width * .23,height * .65 + .20,front),Vector3(.38,.025,.035),wood])
		"bracket_eaves":
			for side in [-1,1]:
				for edge in [-1,1]:
					for step in range(3):
						solid.append([Vector3(side * (width * .5 - .28),height + .08 + step * .075,edge * (length * .5 - .1)),Vector3(.18 + step * .12,.06,.16),wood if step == 0 else color])
			solid.append([Vector3(0,height + .98,0),Vector3(.14,.08,length * .72),accent])
		"quiet_tiles":
			solid.append([Vector3(0,height + .98,0),Vector3(.18,.08,length * .80),Color("a5a9aa")])
			for side in [-1,1]:
				for offset in [-.10,.10]:
					solid.append([Vector3(side * width * .23 + offset,height * .65 + .20,front),Vector3(.025,.36,.035),wood])
				for offset in [-.10,.10]:
					solid.append([Vector3(side * width * .23,height * .65 + .20 + offset,front),Vector3(.36,.025,.035),wood])
		"pumpkin_lights":
			for side in [-1,1]:
				var point := Vector3(side * width * .23,height * .65 + .20,front - .06)
				glow.append([point,Vector3(.22,.18,.12),color])
				solid.append([point + Vector3(0,.12,0),Vector3(.025,.06,.025),wood])
				for eye in [-1,1]:
					solid.append([point + Vector3(eye * .055,.025,.068),Vector3(.025,.025,.01),Color("352438")])
		"evergreen_lights":
			for side in [-1,1]:
				solid.append([Vector3(side * .12,height + .06,front),Vector3(.10,.24,.035),Color("467b55")])
				solid.append([Vector3(0,height + .06 + side * .12,front),Vector3(.24,.10,.035),Color("467b55")])
			for index in range(5):
				glow.append([Vector3((index - 2) * width * .16,height + .36,length * .43),Vector3(.065,.065,.065),accent if index % 2 == 0 else Color("e28d87")])
		"arcane_circuit":
			glow.append([Vector3(0,height + .14,front),Vector3(width * .78,.05,.035),color])
			for side in [-1,1]:
				glow.append([Vector3(side * (width * .5 - .20),height * .65 + .20,front),Vector3(.055,.58,.035),accent])
			solid.append([Vector3(-width * .22,height + .92,0),Vector3(.32,.16,.28),Color("38445d")])
			glow.append([Vector3(-width * .22,height + .99,0),Vector3(.24,.06,.20),color])
		"rune_lattice":
			glow.append([Vector3(0,height + .98,0),Vector3(.46,.05,.08),color])
			glow.append([Vector3(0,height + .98,0),Vector3(.08,.05,.46),accent])
			for side in [-1,1]:
				glow.append([Vector3(side * width * .23,height * .65 + .20,front),Vector3(.28,.035,.035),color])
				glow.append([Vector3(side * width * .23,height * .65 + .20,front),Vector3(.035,.28,.035),accent])
		"petal_trim":
			for side in [-1,1]:
				var point := Vector3(side * (width * .5 - .25),height + .40,length * .40)
				solid.append([point,Vector3(.30,.06,.12),color])
				solid.append([point,Vector3(.12,.06,.30),accent])
				for step in range(3):
					solid.append([Vector3(side * (width * .5 - .15),height * .5 + step * .18,front),Vector3(.12,.10,.035),accent])
	return {"solid":solid,"glow":glow}

func build(city: Dictionary, opaque_material: Material = null, house_models: Dictionary = {}) -> void:
	if not city.has("exterior_profile"):
		return
	var profile: Dictionary = city.exterior_profile
	var family := styles.family_for(city.biome)
	set_meta("visual_family", family)
	var luminous := StandardMaterial3D.new()
	luminous.vertex_color_use_as_albedo = true
	luminous.emission_enabled = true
	luminous.emission = Color(profile.color)
	luminous.emission_energy_multiplier = .3
	for house in city.houses:
		if house_models.has(house.id) and house_models[house.id].has_meta("town_voxel_id"):
			continue
		var actual := Decor.bounds(house_models[house.id]) if house_models.has(house.id) else AABB()
		var geometry := plan(house,profile,actual)
		var center := Vector2(house.footprint.position) + (Vector2(house.footprint.size) - Vector2.ONE) * .5
		for kind in ["solid","glow"]:
			if geometry[kind].is_empty():
				continue
			var model := Decor.node(geometry[kind], family, "house_trim")
			model.position = Vector3(center.x - city.cell.x,0,center.y - city.cell.y)
			model.rotation.y = atan2(house.facing.x,house.facing.y)
			model.set_meta("house_id",house.id)
			model.set_meta("support_bounds", actual)
			if kind == "glow":
				model.material_override = luminous
			elif opaque_material != null:
				model.material_override = opaque_material
			add_child(model)
