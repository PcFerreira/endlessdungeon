extends RefCounted

const Visual = preload("res://scripts/item_visual.gd")

static func build(ui, box: VBoxContainer) -> void:
	var game = ui.game
	var bag = game.inventory
	ui._center_label(box, game.profile.display_name + "'s backpack", 28, ui.INK, true)
	ui._center_label(box, "%s / %s slots / Items, equipment, and finds from your journey" % [bag.slots_used(), bag.CAPACITY], 14, ui.GOLD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var left: VBoxContainer = ui._vbox(row, 12)
	var filters := OptionButton.new()
	for caption in ["All items", "Consumables", "Equipment", "Furnishings", "Materials"]:
		filters.add_item(caption)
	filters.selected = ui.inventory_filter
	filters.item_selected.connect(func(index: int): ui.inventory_filter = index; ui.previous_state = "")
	left.add_child(filters)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	var slots := 0
	var kinds := ["", "consumable", "equipment", "furnishing", "material"]
	for id in bag.items:
		if bag.count(id) <= 0 or (ui.inventory_filter > 0 and bag.ITEMS[id].kind != kinds[ui.inventory_filter]):
			continue
		var remaining: int = bag.count(id)
		while remaining > 0:
			var amount: int = mini(remaining, bag.ITEMS[id].stack)
			remaining -= amount
			ui.IconGrid.item(ui,grid,id,func(): ui.inventory_selected = id; ui.previous_state = "",amount,id == ui.inventory_selected)
			slots += 1
	for index in range(slots, bag.CAPACITY):
		ui._button(grid, "", Callable(), Vector2(80, 88)).disabled = true
	var right: PanelContainer = ui._panel(row, Vector2(350, 0))
	var details: VBoxContainer = ui._vbox(right, 10)
	ui._label(details, "Equipment", 20, ui.GOLD, true)
	var equipment_grid: GridContainer = ui.IconGrid.grid(details,3)
	for slot in bag.equipment:
		var equipped: String = bag.equipment[slot]
		var tile: Button
		if equipped.is_empty():
			tile = ui.IconGrid.tile(ui,equipment_grid,slot.capitalize(),ui.IconGrid.symbol("slot"),Callable(),Vector2(90,88))
			tile.disabled = true
		else:
			tile = ui.IconGrid.item(ui,equipment_grid,equipped,func(): ui.inventory_selected = equipped; ui.previous_state = "")
			tile.tooltip_text = "%s: %s" % [slot.capitalize(),bag.ITEMS[equipped].name]
		tile.set_meta("equipment_slot",slot)
	ui._separator(details)
	var id: String = ui.inventory_selected
	if bag.count(id) > 0:
		var item: Dictionary = bag.ITEMS[id]
		ui._label(details, item.name, 18, ui.INK, true)
		ui._label(details, "%s / Carried: %s" % [item.kind.capitalize(), bag.count(id)], 12, ui.GOLD)
		var stolen: int = bag.stolen_count(id) if bag.has_method("stolen_count") else 0
		if stolen > 0:
			ui._label(details, "Stolen: %s" % stolen, 13, ui.GOLD)
		var description: Label = ui._label(details, item.description, 14, ui.MUTED)
		description.custom_minimum_size.x = 310
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if item.kind in ["consumable", "bound"]:
			var use: Button = ui._button(details, "Use item", game.use_item.bind(id), Vector2(0, 34))
			use.disabled = item.kind == "consumable" and (bag.count(id) <= stolen or not bag.Catalog.can_use(item, game.hp, game.max_hp, game.mana, game.max_mana))
			if item.kind == "consumable" and bag.count(id) <= stolen:
				use.tooltip_text = "Return stolen property to its city."
		elif item.kind == "equipment":
			var equip: Button = ui._button(details, "Equip", game.equip_item.bind(id), Vector2(0, 34))
			equip.disabled = not item.classes.has(game.build.class_id) or bag.equipment.values().has(id)
			if bag.equipment.values().has(id):
				var slot: String = bag.equipment.find_key(id)
				var unequip: Button = ui._button(details,"Unequip",game.unequip_item.bind(slot),Vector2(0,34))
				unequip.set_meta("unequip_slot",slot)
		elif item.kind == "furnishing":
			var place: Button = ui._button(details, "Place in Sanctum [B]", game.furnishing_editor.open.bind(id), Vector2(0, 34))
			place.disabled = game.layer != "sanctum" or bag.count(id) <= stolen
			ui._label(details, "Visit your Sanctum to arrange this furnishing." if game.layer != "sanctum" else "Place, rotate or pick up furniture in your alcoves.", 13, ui.GOLD)
		if item.kind != "bound":
			var portable = game.get("world_items")
			var place_world: Button = ui._button(details, "Place in world", func():
				if portable != null: portable.open_placement(id), Vector2(0, 34))
			place_world.disabled = portable == null
		var discard: Button = ui._button(details, "Discard one", game.discard_item.bind(id), Vector2(0, 30))
		discard.disabled = item.kind == "bound" or bag.count(id) <= stolen or (bag.equipment.values().has(id) and bag.count(id) == 1)
		if bag.count(id) <= stolen:
			discard.tooltip_text = "Place stolen property in the world or return it to its city."
	else:
		ui._label(details, "Select an item to inspect it.", 14, ui.MUTED)
	ui._label(details, "Vitality %s / %s\n%s %s / %s\nAbility damage +%s%%" % [ceili(game.hp), int(game.max_hp), game.CharacterBuild.CLASSES[game.build.class_id].resource, int(game.mana), int(game.max_mana), roundi((game.damage_multiplier - 1) * 100)], 13, ui.MUTED)
	ui._button(box, "Return  [I / Esc]", game.toggle_inventory)
