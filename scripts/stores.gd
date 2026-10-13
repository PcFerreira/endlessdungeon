extends CanvasLayer

const Catalog = preload("res://scripts/store_catalog.gd")
const Items = preload("res://scripts/item_catalog.gd")
const Wonder = preload("res://scripts/wonder_catalog.gd")
const Roamers = preload("res://scripts/wilderness_roamers.gd")
static var catalog := Catalog.new()
var game
var records: Dictionary = {}
var current: Dictionary = {}
var feedback := ""
var selected_item := ""
var selling := false
var grid_page := 0
var overlay := Control.new()
var marker := Label3D.new()

func _ready() -> void:
	layer = 7
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.hide()
	marker.text = "Trade  [E]"
	marker.font_size = 30
	marker.pixel_size = .009
	marker.modulate = Color("e9cb85")
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(marker)
	marker.hide()

func reset() -> void:
	records.clear()
	current.clear()
	marker.hide()
	_clear()

func snapshot() -> Dictionary:
	return records.duplicate(true)

static func valid(data) -> bool:
	if not data is Dictionary or data.size() > 4096:
		return false
	for id in data:
		var record = data[id]
		if not id is String or not id.begins_with("city:") or id.length() > 240 or not record is Dictionary or not catalog.data.profiles.has(record.get("profile", "")) or not record.get("stock") is Dictionary or record.stock.size() > 128 or not Catalog.integer(record.get("purse"),0,999999):
			return false
		for item in record.stock:
			if not Items.definitions.has(item) or not catalog.accepts(record.profile,item,true) or not Catalog.integer(record.stock[item],0,int(catalog.data.stock_limit)):
				return false
	return true

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	reset()
	records = data.duplicate(true)
	for record in records.values():
		record.purse = int(record.purse)
		for item in record.stock:
			record.stock[item] = int(record.stock[item])
	return true

func sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game.state == "store" and current.has("wonder_actor"):
		var source := _wonder_source(game.life.actors.get(current.wonder_actor, {}))
		if not source.is_empty():
			result.append(source)
	if game.layer == "interior":
		var place: Dictionary = game.interiors.current
		var definition: Dictionary = catalog.data.interiors.get(place.get("type", ""), {})
		if definition.is_empty():
			return result
		var point := Vector2(definition.point[0],definition.point[1])
		point = game.dungeon.safe_position(point)
		result.append({"id":place.id,"name":place.name,"city_id":place.city_id,"point":point,"profile":catalog.data.uses.get(place.get("use_id",""),definition.profile)})
	elif game.layer == "overworld":
		var city: Dictionary = game.world.region_at(Vector2i(game.player_point.round())).city
		for lot in city.get("outdoor_lots", []):
			var profile: String = catalog.data.lots.get(lot.kind, "")
			if profile.is_empty():
				continue
			var center := Vector2(lot.footprint.get_center())
			for offset in [Vector2(0,1),Vector2(1,0),Vector2(0,-1),Vector2(-1,0),Vector2(0,2),Vector2(2,0)]:
				var point: Vector2 = center + offset
				if game.world.walkable(point):
					result.append({"id":lot.id,"name":lot.name,"city_id":city.id,"point":point,"profile":profile})
					break
	for source in result:
		if records.has(source.id):
			source.profile = records[source.id].profile
	return result

func _wonder_source(speaker: Dictionary) -> Dictionary:
	if game.layer != "overworld" or not game.offline_actions_allowed() or not Roamers.supports(game.world, game.player_point) or speaker.is_empty():
		return {}
	var id: String = speaker.get("id", "")
	var actor: Dictionary = game.life.actors.get(id, {})
	var definition: Dictionary = Wonder.DATA.npcs.get(actor.get("wonder_id", ""), {})
	if actor.get("kind") != "npc" or not actor.get("roaming", false) or definition.get("trade_profile", "").is_empty() or not Roamers.supports(game.world, actor.point):
		return {}
	return {"id": "city:wonder:" + id, "name": definition.name + "'s Pack", "city_id": "", "point": actor.point, "profile": definition.trade_profile, "wonder_actor": id}

func open_wonder(speaker: Dictionary) -> bool:
	if game.state not in ["playing", "dialogue"]:
		return false
	var source := _wonder_source(speaker)
	if source.is_empty() or game.player_point.distance_to(source.point) >= 1.4 or not game.dungeon.line_clear(game.player_point, source.point) or not game.grounded:
		game.notify("Come closer on safe ground to trade.")
		return false
	var problem: String = game.sanctum_problem(true)
	if not problem.is_empty():
		game.notify("Find safe ground before trading.")
		return false
	if not records.has(source.id) and records.size() >= 4096:
		game.notify("The trade ledger is full. Existing traders still keep their stock.")
		return false
	if records.has(source.id):
		source.profile = records[source.id].profile
	current = source
	feedback = ""
	selected_item = ""
	selling = false
	grid_page = 0
	offers(source)
	game.rotating_camera = false
	game.state = "store"
	_show()
	return true

func target() -> Dictionary:
	var result := {}
	var distance := 1.4
	for source in sources():
		var delta: float = game.player_point.distance_to(source.point)
		if delta < distance and game.dungeon.line_clear(game.player_point,source.point):
			result = source
			distance = delta
	return result

func hint() -> String:
	var source := target()
	return "" if source.is_empty() else "E: Trade at " + source.name

func interact() -> bool:
	if not game.offline_actions_allowed():
		return false
	var source := target()
	if source.is_empty() or game.state != "playing":
		return false
	var problem: String = game.sanctum_problem()
	if not problem.is_empty():
		game.notify("Find safe ground before trading.")
		return true
	current = source
	feedback = ""
	selected_item = ""
	selling = false
	grid_page = 0
	if not records.has(source.id) and records.size() >= 4096:
		game.notify("The trade ledger is full. Existing traders still keep their stock.")
		return true
	offers(source)
	game.rotating_camera = false
	game.state = "store"
	_show()
	return true

func offers(source: Dictionary) -> Dictionary:
	if not records.has(source.id):
		records[source.id] = catalog.initial(source,game.run_seed)
	var result := {}
	for item in records[source.id].stock:
		if not catalog.accepts(source.profile,item):
			continue
		var price := catalog.price(item)
		result[item] = {"count": int(records[source.id].stock[item]), "buy": price, "sell": maxi(1,floori(price * catalog.data.buyback_fraction))}
	return result

func _transaction(item: String, buying: bool) -> bool:
	if not game.offline_actions_allowed():
		return false
	if game.state != "store" or current.is_empty() or target().get("id", "") != current.id or not catalog.accepts(current.profile,item):
		return false
	var record: Dictionary = records[current.id]
	var price := catalog.price(item) if buying else maxi(1,floori(catalog.price(item) * catalog.data.buyback_fraction))
	var currency: String = catalog.data.currency
	if buying and (record.stock.get(item,0) <= 0 or game.inventory.count(currency) - game.inventory.stolen_count(currency) < price or record.purse > 999999 - price):
		feedback = "That stock is sold out or you need more coins of your own."
		return false
	if not buying and (record.stock.get(item,0) >= catalog.data.stock_limit or record.stock.size() >= 128 and not record.stock.has(item) or record.purse < price):
		feedback = "This trader cannot take more of that item."
		return false
	var before: Dictionary = game.inventory.snapshot()
	var removed: bool = game.inventory.remove(currency,price) if buying else game.inventory.remove(item)
	var added: bool = false
	if removed:
		added = game.inventory.add(item) if buying else game.inventory.add(currency,price)
	if not removed or not added:
		game.inventory.restore(before,game.build.class_id)
		feedback = "Make room in your backpack and trade only unequipped items you own."
		return false
	record.stock[item] = int(record.stock.get(item,0)) + (-1 if buying else 1)
	record.purse += price if buying else -price
	feedback = "%s %s for %s coins." % ["Bought" if buying else "Sold",Items.definitions[item].name,price]
	game._auto_save()
	return true

func buy(item: String) -> bool:
	return _transaction(item,true)

func sell(item: String) -> bool:
	return _transaction(item,false)

func close() -> void:
	if game.state == "store":
		game.state = "playing"
	current.clear()
	_clear()
	game._auto_save()

func _input(event: InputEvent) -> void:
	if game.state == "store" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if game == null:
		return
	var source := target() if game.state == "playing" else current
	marker.visible = not source.is_empty() and game.state in ["playing", "store"]
	if marker.visible:
		marker.position = game.to_world(source.point) + Vector3(0,1.8,0)

func _clear() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.hide()

func _show() -> void:
	_clear()
	overlay.show()
	var ui = game.interface
	var shade := ColorRect.new()
	shade.color = Color(.025,.04,.065,.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = ui._panel(center,Vector2(960,0),Color("766950"))
	var box = ui._vbox(panel,12)
	ui._label(box,current.name,27,ui.INK,true)
	var currency: String = catalog.data.currency
	ui._label(box,"%s / Your coins: %s / Trader coins: %s" % [catalog.data.profiles[current.profile].name,game.inventory.count(currency) - game.inventory.stolen_count(currency),records[current.id].purse],14,ui.GOLD)
	var modes := HBoxContainer.new()
	box.add_child(modes)
	for buying in [true,false]:
		var tab: Button = ui._button(modes,"Trader stock" if buying else "Your goods",_change_mode.bind(not buying),Vector2(160,34))
		tab.toggle_mode = true
		tab.button_pressed = selling != buying
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	box.add_child(row)
	var left: VBoxContainer = ui._vbox(row,10)
	var entries: Dictionary = offers(current)
	var ids: Array = entries.keys() if not selling else game.inventory.items.keys().filter(func(id): return game.inventory.count(id) > 0 and catalog.accepts(current.profile,id))
	ids.sort_custom(func(a,b): return Items.definitions[a].name.naturalnocasecmp_to(Items.definitions[b].name) < 0)
	grid_page = clampi(grid_page,0,maxi(0,ceili(ids.size() / 24.0) - 1))
	if selected_item not in ids:
		selected_item = ids[0] if not ids.is_empty() else ""
	var grid: GridContainer = ui.IconGrid.grid(left,6)
	for id in ui.IconGrid.page(ids,grid_page):
		ui.IconGrid.item(ui,grid,id,_select.bind(id),game.inventory.count(id) if selling else entries[id].count,id == selected_item)
	if ids.is_empty():
		ui._label(left,"No eligible goods to sell." if selling else "This trader has no stock.",14,ui.MUTED)
	if ids.size() > 24:
		var paging := HBoxContainer.new()
		left.add_child(paging)
		var previous: Button = ui._button(paging,"Previous",_page.bind(-1),Vector2(120,30))
		previous.disabled = grid_page <= 0
		ui._label(paging,"%s / %s" % [grid_page + 1,ceili(ids.size() / 24.0)],14,ui.GOLD)
		var next: Button = ui._button(paging,"Next",_page.bind(1),Vector2(120,30))
		next.disabled = (grid_page + 1) * 24 >= ids.size()
	var details = ui._vbox(ui._panel(row,Vector2(340,0)),10)
	if not selected_item.is_empty():
		var item: Dictionary = Items.definitions[selected_item]
		var price: int = catalog.price(selected_item)
		var sale: int = maxi(1,floori(price * catalog.data.buyback_fraction))
		ui._label(details,item.name,21,ui.INK,true)
		var owned: int = game.inventory.count(selected_item) - game.inventory.stolen_count(selected_item)
		var stock: int = records[current.id].stock.get(selected_item,0)
		ui._label(details,"Stock %s / Owned %s" % [stock,owned],13,ui.GOLD)
		var description: Label = ui._label(details,item.description,14,ui.MUTED)
		description.custom_minimum_size.x = 295
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var purchase: Button = ui._button(details,"Buy / %s coins" % price,_button_trade.bind(selected_item,true),Vector2(0,38))
		purchase.set_meta("trade_action","buy")
		purchase.disabled = stock <= 0 or game.inventory.count(currency) - game.inventory.stolen_count(currency) < price
		var sell_button: Button = ui._button(details,"Sell / %s coins" % sale,_button_trade.bind(selected_item,false),Vector2(0,38))
		sell_button.set_meta("trade_action","sell")
		sell_button.disabled = owned <= (1 if game.inventory.equipment.values().has(selected_item) else 0) or records[current.id].purse < sale or stock >= catalog.data.stock_limit
		ui._label(details,"Trade only unequipped goods and coins you own.",13,ui.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var receipt: Label = ui._label(box,feedback,14,Color("e9cb85"))
	receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._button(box,"Return",close,Vector2(0,36))

func _select(id: String) -> void:
	selected_item = id
	_show()

func _change_mode(value: bool) -> void:
	selling = value
	grid_page = 0
	selected_item = ""
	_show()

func _page(offset: int) -> void:
	grid_page = maxi(0,grid_page + offset)
	_show()

func _button_trade(item: String, buying: bool) -> void:
	_transaction(item,buying)
	_show()
