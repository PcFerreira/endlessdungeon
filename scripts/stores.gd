extends CanvasLayer

const Catalog = preload("res://scripts/store_catalog.gd")
const Items = preload("res://scripts/item_catalog.gd")
static var catalog := Catalog.new()
var game
var records: Dictionary = {}
var current: Dictionary = {}
var feedback := ""
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
			if not Items.definitions.has(item) or not catalog.accepts(record.profile,item) or not Catalog.integer(record.stock[item],0,int(catalog.data.stock_limit)):
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
	var shade := ColorRect.new()
	shade.color = Color(.025,.04,.065,.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = game.interface._panel(center,Vector2(760,0),Color("766950"))
	var box = game.interface._vbox(panel,10)
	game.interface._label(box,current.name,27,Color("e5e0d5"),true)
	var currency: String = catalog.data.currency
	game.interface._label(box,"%s / Your coins: %s / Trader coins: %s" % [catalog.data.profiles[current.profile].name,game.inventory.count(currency) - game.inventory.stolen_count(currency),records[current.id].purse],14,Color("c3a576"))
	game.interface._label(box,"Stock stays with this trader. Clean, unequipped goods can be sold here.",14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,340)
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var list := offers(current)
	for item in game.inventory.items:
		if catalog.accepts(current.profile,item) and not list.has(item):
			list[item] = {"count":0,"buy":catalog.price(item),"sell":maxi(1,floori(catalog.price(item) * catalog.data.buyback_fraction))}
	for item in list:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label = game.interface._label(row,"%s  /  Stock %s" % [Items.definitions[item].name,list[item].count],15)
		label.custom_minimum_size.x = 385
		label.clip_text = true
		label.tooltip_text = Items.definitions[item].get("description", "")
		var purchase: Button = game.interface._button(row,"Buy %s" % list[item].buy,_button_trade.bind(item,true),Vector2(100,32))
		purchase.disabled = list[item].count <= 0 or game.inventory.count(currency) - game.inventory.stolen_count(currency) < list[item].buy
		var sale: Button = game.interface._button(row,"Sell %s" % list[item].sell,_button_trade.bind(item,false),Vector2(100,32))
		sale.disabled = game.inventory.count(item) - game.inventory.stolen_count(item) <= (1 if game.inventory.equipment.values().has(item) else 0) or records[current.id].purse < list[item].sell or list[item].count >= catalog.data.stock_limit
	var receipt: Label = game.interface._label(box,feedback,14,Color("e9cb85"))
	receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.interface._button(box,"Return  [Esc]",close,Vector2(0,36))

func _button_trade(item: String, buying: bool) -> void:
	_transaction(item,buying)
	_show()
