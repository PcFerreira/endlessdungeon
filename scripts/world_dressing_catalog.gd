extends RefCounted

const Registry = preload("res://scripts/asset_registry.gd")
const Styles = preload("res://scripts/environment_styles.gd")
var registry := Registry.new()
var styles := Styles.new(registry)
var data: Dictionary = {}
var pools: Dictionary = {}
var error := ""

func _init(path: String = "res://config/world_dressing.json", bundle: String = "res://assets/world_construction/catalog.json") -> void:
	if not styles.error.is_empty():
		error = styles.error
		return
	var document = JSON.parse_string(FileAccess.get_file_as_string(path))
	var assets = JSON.parse_string(FileAccess.get_file_as_string(bundle))
	if not valid(document) or not assets is Dictionary or not assets.get("roles") is Dictionary:
		error = "Invalid contextual world construction catalogue"
		return
	data = document
	pools = assets.roles
	for recipe in data.recipes:
		for part in recipe.parts:
			if part.has("pool") and (not pools.has(part.pool) or pools[part.pool].is_empty()):
				error = "Empty world construction pool: " + part.pool
				return

static func _number(value) -> bool:
	return (value is float or value is int) and is_finite(value)

static func _pair(value) -> bool:
	return value is Array and value.size() == 2 and value.all(_number)

static func _rect(part: Dictionary) -> Rect2:
	return Rect2(Vector2(part.point[0],part.point[1]) - Vector2(part.footprint[0],part.footprint[1]) * .5, Vector2(part.footprint[0],part.footprint[1]))

static func valid(document) -> bool:
	if not document is Dictionary or document.get("version") != 1 or not document.get("recipes") is Array or document.recipes.is_empty():
		return false
	for key in ["palette_variants", "template_cap"]:
		if not _number(document.get(key)) or document[key] != int(document[key]) or document[key] < 1 or document[key] > 128:
			return false
	var ids := {}
	for recipe in document.recipes:
		if not recipe is Dictionary or not recipe.get("id") is String or ids.has(recipe.id) or not recipe.get("anchors") is Array or recipe.anchors.is_empty() or not recipe.anchors.all(func(value): return value is String):
			return false
		ids[recipe.id] = true
		if not _pair(recipe.get("footprint")) or recipe.footprint.any(func(value): return value <= 0 or value > 3) or not recipe.get("parts") is Array or recipe.parts.is_empty() or recipe.parts.size() > 24 or not _number(recipe.get("priority")):
			return false
		var allowed := Rect2(-Vector2(recipe.footprint[0],recipe.footprint[1]) * .5, Vector2(recipe.footprint[0],recipe.footprint[1]))
		var parts := {}
		var resolved := {}
		for part in recipe.parts:
			if not part is Dictionary or not part.get("id") is String or parts.has(part.id) or not _pair(part.get("point")) or not _pair(part.get("footprint")) or part.footprint.any(func(value): return value <= 0) or not _number(part.get("height")) or part.height <= 0 or part.height > 3 or not part.get("support") is String:
				return false
			if not (part.get("pool") is String or part.get("primitive") in ["wood", "stone"]):
				return false
			var box := _rect(part)
			var base := 0.0
			if part.support != "ground":
				if not parts.has(part.support):
					return false
				var support: Dictionary = parts[part.support]
				var support_box: AABB = resolved[part.support]
				base = support_box.end.y
				if part.has("span"):
					if not part.span is Array or part.span.size() < 2 or not part.span.all(func(id): return id is String and parts.has(id)) or part.support not in part.span:
						return false
					var span_ids := {}
					for id in part.span:
						var post: AABB = resolved[id]
						if span_ids.has(id) or not box.has_point(Vector2(post.get_center().x,post.get_center().z)) or not is_equal_approx(post.end.y, base):
							return false
						span_ids[id] = true
				else:
					if not support.get("surface", false) or not Rect2(-Vector2(support.footprint[0],support.footprint[1]) * .5, Vector2(support.footprint[0],support.footprint[1])).encloses(box):
						return false
					box.position += Vector2(support_box.get_center().x,support_box.get_center().z)
			elif part.has("span"):
				return false
			if not allowed.encloses(box):
				return false
			parts[part.id] = part
			resolved[part.id] = AABB(Vector3(box.position.x,base,box.position.y),Vector3(box.size.x,part.height,box.size.y))
	return true

func recipe_for(anchor: String, context: Dictionary) -> Dictionary:
	var choices: Array[Dictionary] = []
	var priority := -INF
	for recipe in data.get("recipes", []):
		if anchor not in recipe.anchors or (recipe.has("biomes") and not recipe.biomes.any(func(value): return int(value) == int(context.get("biome", 0)))) or (recipe.has("city_types") and context.get("city_type", "") not in recipe.city_types):
			continue
		if recipe.has("families") and context.get("family", "") not in recipe.families:
			continue
		if recipe.priority > priority:
			choices.clear()
			priority = recipe.priority
		if recipe.priority == priority:
			choices.append(recipe)
	return {} if choices.is_empty() else choices[_salt(str(context.get("region_id", "")) + anchor) % choices.size()]

static func _salt(text: String) -> int:
	return hash("construction:" + text) & 0x7fffffff

func plan(recipe: Dictionary, context: Dictionary, seed_value: int) -> Dictionary:
	var biome := int(context.get("biome", 0))
	var family := styles.family_for(biome)
	if family.is_empty():
		return {}
	var result := {"recipe_id": recipe.id, "footprint": recipe.footprint, "parts": [], "visual_family": family}
	for part in recipe.parts:
		var entry: Dictionary = part.duplicate(true)
		entry.visual_family = family
		var role: String = part.get("pool", "wood" if part.get("primitive") == "wood" else "stone_block")
		if not styles.supports(role):
			return {}
		entry.environment_role = role
		if part.has("primitive"):
			entry.asset = styles.native_id(family, role)
			entry.native_role = role
		if part.has("pool"):
			var candidates: Array = pools[part.pool].filter(func(id): return part.get("patterns", ["*"]).any(func(pattern): return id.matchn(pattern)))
			candidates = candidates.filter(func(id): return styles.allows(id, biome))
			if candidates.is_empty():
				entry.asset = styles.native_id(family, part.pool)
				entry.native_role = part.pool
				result.parts.append(entry)
				continue
			var palette_seed := _salt("%s:%s" % [context.get("region_id", ""), part.pool])
			var palette: Array = []
			for index in range(mini(data.palette_variants,candidates.size())):
				palette.append(candidates[(palette_seed + index) % candidates.size()])
			entry.asset = palette[_salt("%s:%s" % [seed_value,part.id]) % palette.size()]
		result.parts.append(entry)
	return result
