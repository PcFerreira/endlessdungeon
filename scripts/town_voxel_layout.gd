extends RefCounted

const THEMES := ["japanese","chinese","korean","halloween","christmas","cyberpunk","mage","fairy"]

static func gateway(city: Dictionary, roads: Dictionary) -> Dictionary:
	if city.get("theme_id", "") not in THEMES:
		return {}
	var center: Vector2i = city.cell + Vector2i(-12,0)
	var posts := [center + Vector2i(0,-3),center + Vector2i(0,3)]
	for cell in posts:
		if roads.has(cell) or city.streets.has(cell):
			return {}
		for house in city.houses:
			if house.footprint.has_point(cell) or cell in [house.door,house.approach]:
				return {}
		for lot in city.outdoor_lots:
			if lot.footprint.has_point(cell) or cell in [lot.door,lot.approach]:
				return {}
		if city.decorations.any(func(value): return value.cell == cell) or (city.residents + city.books).any(func(value): return Vector2(cell).distance_to(value.point) < 1.0 or Vector2(cell).distance_to(value.approach) < 1.0):
			return {}
	return {"id":city.id + ":gateway","cell":center,"facing":Vector2i.LEFT,"solid_cells":posts}
