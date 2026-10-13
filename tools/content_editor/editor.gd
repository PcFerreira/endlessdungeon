extends SceneTree

const Store = preload("res://tools/content_editor/store.gd")
const Assets = preload("res://tools/content_editor/assets.gd")
const Preview = preload("res://tools/content_editor/preview.gd")
const Edits = preload("res://scripts/content_edits.gd")
const Models = preload("res://scripts/enemy_models.gd")
const Areas = preload("res://scripts/area_catalog.gd")
var store := Store.new()
var assets := Assets.new()
var screen := Control.new()
var section := "enemies"
var selected := {}
var editing_target := {}
var records: Array = []
var filtered: Array = []
var page := 0
var page_size := 60
var search := LineEdit.new()
var section_choice := OptionButton.new()
var usage := OptionButton.new()
var kind_filter := OptionButton.new()
var pack_filter := OptionButton.new()
var show_removed := CheckBox.new()
var list := ItemList.new()
var page_label := Label.new()
var form := VBoxContainer.new()
var preview := Preview.new()
var status := Label.new()
var preview_label := Label.new()
var title := Label.new()
var counts := Label.new()
var save_button: Button
var biome := OptionButton.new()
var body_context := OptionButton.new()
var depth := SpinBox.new()
var controls := {}
var preview_timer := Timer.new()
var worker: Thread
var worker_result := {}
var rebuilding := false
var booted := false
var reward_class := "mage"
var reward_family := "dungeon_ashen_crypt"

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	root.title = "Endless World | Content Workbench"
	root.min_size = Vector2i(1180, 720)
	root.size = Vector2i(1440, 900)
	auto_accept_quit = false
	root.close_requested.connect(_close)
	store.load_catalogues()
	_build_ui()
	_status("Indexing import_assets and game references...")
	await process_frame
	assets.build(store)
	_fill_packs()
	_refresh_records()
	booted = true
	_status("Ready. Edits apply to local games after restart. Right-drag the preview to orbit; scroll to zoom.")
	if "--smoke-test" in OS.get_cmdline_user_args():
		await _smoke_test()
		quit()
		return
	if "--capture" in OS.get_cmdline_user_args():
		assert(list.item_count > 0 and preview.body != null, "Workbench must open with selectable real monsters")
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
		root.get_texture().get_image().save_png("res://artifacts/content-editor-monsters.png")
		_switch("items")
		_select_id("iron_sword")
		await create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/content-editor-items.png")
		_switch("assets")
		var sample: Dictionary = assets.rows.filter(func(asset): return asset.staged and asset.kind == "model")[0]
		_select_id(sample.id)
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/content-editor-assets.png")
		print("PASS: native workbench previews and browser captured")
		quit()

func _build_ui() -> void:
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = _theme()
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	screen.add_child(margin)
	var layout := _column(margin)
	var header := _row(layout)
	var heading := _column(header)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(heading, "CONTENT WORKBENCH", 24, Color("e9f0fa"))
	_label(heading, "Items, monsters and source assets", 14, Color("a1afc4"))
	_button(header, "Reload", _reload)
	_button(header, "Discard unsaved", _discard)
	_button(header, "Export usage report", _export_report)
	save_button = _button(header, "Save changes", _save)
	var main := HSplitContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(main)
	var browser := _column(_panel(main))
	browser.custom_minimum_size.x = 280
	for text in ["Monsters", "Items", "Assets"]:
		section_choice.add_item(text)
	browser.add_child(section_choice)
	section_choice.item_selected.connect(func(index): _switch(["enemies", "items", "assets"][index]))
	search.placeholder_text = "Search name, ID or pack"
	browser.add_child(search)
	search.text_changed.connect(func(_text): page = 0; _filter())
	for text in ["All usage", "Game references", "Portable only", "Not referenced", "Source only"]:
		usage.add_item(text)
	browser.add_child(usage)
	usage.item_selected.connect(func(_index): page = 0; _filter())
	for text in ["All kinds", "model", "texture", "audio"]:
		kind_filter.add_item(text)
	browser.add_child(kind_filter)
	kind_filter.item_selected.connect(func(_index): page = 0; _filter())
	browser.add_child(pack_filter)
	pack_filter.item_selected.connect(func(_index): page = 0; _filter())
	show_removed.text = "Show removed items"
	browser.add_child(show_removed)
	show_removed.toggled.connect(func(_value): page = 0; _filter())
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(28, 28)
	list.add_theme_constant_override("v_separation", 8)
	browser.add_child(list)
	list.item_selected.connect(_select)
	var pagination := _row(browser)
	_button(pagination, "<", func(): page = maxi(0, page - 1); _show_page())
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pagination.add_child(page_label)
	_button(pagination, ">", func(): page = mini(maxi(0, ceili(filtered.size() / float(page_size)) - 1), page + 1); _show_page())
	counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	browser.add_child(counts)
	var detail_split := HSplitContainer.new()
	main.add_child(detail_split)
	var inspector := _column(_panel(detail_split))
	inspector.custom_minimum_size.x = 320
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	inspector.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector.add_child(scroll)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var stage := _column(_panel(detail_split))
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(stage, "MODEL & MOVEMENT", 16, Color("71dcca"))
	var options := _row(stage)
	for text in ["Greenwood", "Meadows", "Wastes", "Frostlands"]:
		biome.add_item(text)
	options.add_child(biome)
	biome.item_selected.connect(func(_index): _update_preview())
	for text in ["Dungeon body", "Surface body"]:
		body_context.add_item(text)
	options.add_child(body_context)
	body_context.item_selected.connect(func(_index): _update_preview())
	_label(options, "Depth", 13)
	depth.min_value = 1
	depth.max_value = 1000
	depth.value = 1
	options.add_child(depth)
	depth.value_changed.connect(func(value): preview.depth = int(value); _stats_label())
	stage.add_child(preview)
	preview.changed.connect(func(text): preview_label.text = text)
	var motion := _row(stage)
	var mode := OptionButton.new()
	for text in ["Idle", "Walk loop", "Pursuit", "Attack"]:
		mode.add_item(text)
	motion.add_child(mode)
	mode.item_selected.connect(func(index): preview.mode = mode.get_item_text(index); preview.actor.position = Vector3.ZERO; preview.distance = 8 if index in [1, 2] else 4; preview._update_camera())
	var play := CheckButton.new()
	play.text = "Simulate"
	play.button_pressed = true
	motion.add_child(play)
	play.toggled.connect(func(value): preview.running = value)
	_button(motion, "Reset", func(): preview.time = 0; preview.actor.position = Vector3.ZERO; preview.provoked = false)
	_button(motion, "Provoke", func(): preview.provoked = store.Enemies.after_hit(selected, preview.provoked); preview.mode = "Pursuit"; preview.distance = 8; preview._update_camera(); mode.select(2))
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.custom_minimum_size.y = 44
	preview_label.add_theme_color_override("font_color", Color("a1afc4"))
	stage.add_child(preview_label)
	_label(stage, "Green arrow = movement front (+Z). Correct the body with Facing or Flip 180°.", 12, Color("a1afc4")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 38
	layout.add_child(status)
	preview_timer.one_shot = true
	preview_timer.wait_time = .3
	screen.add_child(preview_timer)
	preview_timer.timeout.connect(_update_preview)

func _switch(value: String) -> void:
	section = value
	section_choice.select(["enemies", "items", "assets"].find(value))
	search.text = ""
	page = 0
	_refresh_records()

func _refresh_records() -> void:
	records = assets.rows if section == "assets" else store.entries(section)
	records.sort_custom(func(a, b): return str(a.get("name", a.get("title", ""))).naturalnocasecmp_to(str(b.get("name", b.get("title", "")))) < 0)
	for control in [usage, kind_filter, pack_filter]:
		control.visible = section == "assets"
	show_removed.visible = section == "items"
	_filter()
	if not filtered.is_empty():
		list.select(0)
		_select(0)
	else:
		selected.clear()
		controls.clear()
		preview_timer.stop()
		preview.clear()
		title.text = "No matching records"
		for child in form.get_children():
			form.remove_child(child)
			child.queue_free()
	counts.text = "%s records • %s shown" % [records.size(), filtered.size()]

func _fill_packs() -> void:
	pack_filter.clear()
	pack_filter.add_item("All packs")
	var packs := {}
	for asset in assets.rows:
		packs[asset.pack] = true
	var names: Array = packs.keys()
	names.sort()
	for name in names:
		pack_filter.add_item(name)

func _filter() -> void:
	filtered = records.filter(func(entry):
		var text: String = entry.get("search", str(entry.get("name", "")) + " " + entry.id + " " + str(entry.get("source_pack", ""))).to_lower()
		if not search.text.is_empty() and not search.text.to_lower() in text:
			return false
		if section != "assets":
			return section != "items" or show_removed.button_pressed or not entry.get("removed", false)
		return (usage.selected == 0 or entry.usage == ["", "referenced", "portable", "unused", "source"][usage.selected]) and (kind_filter.selected == 0 or entry.kind == kind_filter.get_item_text(kind_filter.selected)) and (pack_filter.selected == 0 or entry.pack == pack_filter.get_item_text(pack_filter.selected))
	)
	counts.text = "%s records • %s shown" % [records.size(), filtered.size()]
	_show_page()

func _show_page() -> void:
	list.clear()
	page = mini(page, maxi(0, ceili(filtered.size() / float(page_size)) - 1))
	for entry in filtered.slice(page * page_size, (page + 1) * page_size):
		var name: String = entry.get("name", entry.get("title", entry.id))
		var suffix: String = entry.get("usage", entry.get("kind", ""))
		if entry.get("removed", false):
			suffix = "Removed · " + suffix
		list.add_item(name + "\n" + suffix + " · " + entry.id.left(45))
		list.set_item_tooltip(list.item_count - 1, entry.id)
		if entry.get("enabled", true) == false or entry.get("removed", false):
			list.set_item_custom_fg_color(list.item_count - 1, Color("a17f80"))
	page_label.text = "%s / %s" % [page + 1, maxi(1, ceili(filtered.size() / float(page_size)))]

func _select(index: int) -> void:
	if page * page_size + index >= filtered.size():
		return
	selected = filtered[page * page_size + index].duplicate(true)
	if section != "assets":
		var effective := store.entries(section).filter(func(entry): return entry.id == selected.id)
		if not effective.is_empty():
			selected = effective[0].duplicate(true)
	controls.clear()
	for child in form.get_children():
		form.remove_child(child)
		child.queue_free()
	title.text = selected.get("name", selected.get("title", "Asset"))
	_label(form, selected.id, 11, Color("96a5bc")).autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	if section == "assets":
		_asset_form()
	else:
		editing_target = {"section": section, "id": selected.id}
		_common_form()
		if section == "enemies":
			_monster_form()
		else:
			_item_form()
	_update_preview()

func _common_form() -> void:
	_text_field("name", "Name", selected.get("name", ""))
	_bool_field("enabled", "Enabled in future loot / spawns", selected.get("enabled", true))
	_button(form, "Revert this record to catalogue", func(): store.reset_entry(section, selected.id); _refresh_records(); _dirty())

func _monster_form() -> void:
	_heading("Combat")
	for spec in [["hp", "Base health", .01, 100000, .5], ["damage", "Base attack", .01, 100000, .5], ["speed", "Move speed", .01, 20, .05], ["reach", "Attack range", .01, 50, .05], ["windup", "Windup seconds", .01, 20, .05], ["period", "Recovery seconds", .01, 60, .05], ["height", "Body height", .01, 20, .05], ["weight", "Spawn weight", 1, 100, 1], ["level", "Base level", 1, 10000, 1]]:
		_number_field(spec[0], spec[1], selected.get(spec[0], 1), spec[2], spec[3], spec[4])
	_choice_field("level_mode", "Level scaling", ["depth", "fixed"], selected.get("level_mode", "depth"))
	_number_field("hp_growth", "Health / level %", selected.get("hp_growth", .13) * 100, 0, 1000, 1, 100)
	_number_field("damage_growth", "Attack / level %", selected.get("damage_growth", .07) * 100, 0, 1000, 1, 100)
	_bool_field("ranged", "Ranged attack", selected.ranged)
	_bool_field("aggressive", "Aggressive on sight", selected.get("aggressive", true))
	_bool_field("retaliates", "Retaliates when hit", selected.get("retaliates", true))
	_heading("Appearance & facing")
	_choice_field("visual_mode", "Body mode", ["automatic", "imported", "generated"], selected.get("visual_mode", "automatic"))
	_number_field("facing_degrees", "Facing correction °", selected.get("facing_degrees", 0), -360, 360, 5)
	_button(form, "Flip 180°", func(): controls.facing_degrees.value = wrapf(controls.facing_degrees.value + 180, -360, 360))
	_button(form, "Choose source model", func(): _picker("model", _bind_model))
	_button(form, "Animation clip mapping", func(): _json_editor("animations", selected.get("animations", {})))
	_button(form, "Spawn biomes / dungeon families", func(): _json_editor("habitat", selected.habitat))
	_heading("Drops")
	var drops: Dictionary = selected.get("drops", {})
	_drop_number("coins", "Coins per kill", drops.get("coins", 1), 0, 10, 1)
	_drop_number("item_chance", "Item chance %", drops.get("item_chance", store.Items.policy.enemy_item_chance) * 100, 0, 100, 1, 100)
	_drop_number("shard_chance", "Shard chance %", drops.get("shard_chance", store.Items.policy.enemy_shard_chance) * 100, 0, 100, 1, 100)
	_drop_number("orb_chance", "Recovery orb chance %", drops.get("orb_chance", 1) * 100, 0, 100, 1, 100)
	var orb := OptionButton.new()
	for text in ["legacy", "none", "health", "mana"]:
		orb.add_item(text)
	orb.select(["legacy", "none", "health", "mana"].find(drops.get("orb_mode", "legacy")))
	form.add_child(orb)
	orb.item_selected.connect(func(index): _set_drop("orb_mode", orb.get_item_text(index)))
	_label(form, "Empty custom table uses normal contextual loot. Weights choose one eligible item when the item roll succeeds.", 12, Color("a1afc4")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var table := ItemList.new()
	table.custom_minimum_size.y = 110
	form.add_child(table)
	var entries: Array = drops.get("entries", [])
	for entry in entries:
		table.add_item("%s × weight %s" % [entry.item, entry.weight])
	var actions := _row(form)
	_button(actions, "Add item", func(): _drop_picker())
	_button(actions, "Remove", func():
		if table.get_selected_items().is_empty():
			return
		var updated: Array = selected.get("drops", {}).get("entries", []).duplicate(true)
		updated.remove_at(table.get_selected_items()[0])
		_set_drop("entries", updated)
		_select(list.get_selected_items()[0])
	)
	_button(form, "Edit full weighted table", func(): _json_editor("drops", selected.get("drops", {})))
	var context := _row(form)
	var class_choice := OptionButton.new()
	for name in ["mage", "sword", "spellsword"]:
		class_choice.add_item(name)
	class_choice.select(["mage", "sword", "spellsword"].find(reward_class))
	context.add_child(class_choice)
	class_choice.item_selected.connect(func(index): reward_class = class_choice.get_item_text(index))
	var family_choice := OptionButton.new()
	for id in Areas.DUNGEONS:
		family_choice.add_item(Areas.DUNGEONS[id].name)
		family_choice.set_item_metadata(family_choice.item_count - 1, id)
		if id == reward_family:
			family_choice.select(family_choice.item_count - 1)
	form.add_child(family_choice)
	family_choice.item_selected.connect(func(index): reward_family = family_choice.get_item_metadata(index))
	_button(form, "Simulate 1,000 reward rolls", _simulate_drops)

func _item_form() -> void:
	if selected.get("removed", false):
		_label(form, "Removed from future loot and shops. Saved items keep their identity.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls.removal = _button(form, "Restore item", func(): _set_item_removed(false))
	else:
		controls.removal = _button(form, "Remove item", func(): _set_item_removed(true))
	_text_field("description", "Description", selected.get("description", ""))
	_choice_field("kind", "Kind", ["bound", "material", "consumable", "equipment", "furnishing"], selected.kind)
	_number_field("stack", "Stack size", selected.get("stack", 1), 1, 99, 1)
	_number_field("level", "Minimum enemy drop level", selected.get("level", 1), 1, 10000, 1)
	for spec in [["restore_health", "Restores health"], ["restore_mana", "Restores resource"], ["hp", "Health bonus"], ["mana", "Resource bonus"]]:
		_number_field(spec[0], spec[1], selected.get(spec[0], 0), 0, 100000, 1)
	_number_field("power", "Attack bonus %", selected.get("power", 0) * 100, 0, 10000, 1, 100)
	_choice_field("slot", "Equipment slot", ["weapon", "armor", "charm"], selected.get("slot", "weapon"))
	_button(form, "Class compatibility", func(): _json_editor("classes", selected.get("classes", ["mage", "sword", "spellsword"])))
	_button(form, "Loot sources", func(): _json_editor("loot_sources", selected.get("loot_sources", [])))
	_button(form, "Choose 3D model", func(): _picker("model", _bind_model))
	_button(form, "Choose icon texture", func(): _picker("texture", _bind_icon))
	_button(form, "Icon crop rectangle", func(): _json_editor("icon_region", selected.get("icon_region", [0, 0, 16, 16])))

func _set_item_removed(removed: bool) -> void:
	var id: String = selected.id
	if not store.set_item_removed(id, removed):
		_status(store.error, true)
		return
	_refresh_records()
	if not removed or show_removed.button_pressed:
		_select_id(id)
	_dirty()
	_status("Item removed from future loot and shops. Save changes to apply; Show removed items lets you restore it." if removed else "Item restored. Save changes to apply.")

func _asset_form() -> void:
	for key in ["usage", "kind", "pack", "author", "license", "source_file"]:
		_label(form, key.capitalize() + ": " + str(selected.get(key, "")), 13).autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label(form, "Usage describes catalogue references, not observed encounters.", 12, Color("a1afc4")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for reason in selected.references.slice(0, 12):
		_label(form, "• " + reason, 12, Color("71dcca")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(form, "Open source folder", func(): OS.shell_open(ProjectSettings.globalize_path("res://" + selected.source_file).get_base_dir()))
	if selected.staged:
		if selected.kind == "model":
			_button(form, "Add as monster", func(): _adopt("enemies"))
		if selected.kind in ["model", "texture"]:
			var kind := OptionButton.new()
			for text in ["material", "consumable", "equipment", "furnishing"]:
				kind.add_item(text)
			form.add_child(kind)
			_button(form, "Add as item", func(): _adopt("items", kind.get_item_text(kind.selected)))
		if not editing_target.is_empty() and selected.kind == "model":
			_button(form, "Use model for last selected record", _assign_last)
	else:
		_label(form, "Stage the source before adopting it. Original files and attribution are retained.", 13).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stage_button := _button(form, "Stage selected asset + rebuild", _stage_asset)
		stage_button.disabled = selected.pack == "unregistered" or selected.path.get_extension().to_lower() == "fbx"
		if stage_button.disabled:
			_label(form, "SOURCE.json metadata or a supported glTF/GLB/OBJ export is required.", 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _set_field(key: String, value) -> void:
	selected[key] = value
	if key == "icon_region" and value == null:
		selected.erase(key)
	if key == "kind" and value == "equipment":
		if not selected.has("slot"):
			_set_field("slot", "weapon")
		if not selected.has("classes"):
			_set_field("classes", ["mage", "sword", "spellsword"])
	if key == "name":
		title.text = value
	var patch: Dictionary = store.document[section].get(selected.id, {}).duplicate(true)
	patch[key] = value
	store.patch(section, selected.id, patch)
	_dirty()
	preview.definition = selected.duplicate(true) if section == "enemies" else {}
	if key in ["name", "height", "facing_degrees", "visual_mode", "source_asset", "asset_id", "icon", "icon_region", "animations", "kind"]:
		preview_timer.start()
	else:
		_stats_label()

func _set_drop(key: String, value) -> void:
	var drops: Dictionary = selected.get("drops", {}).duplicate(true)
	drops[key] = value
	_set_field("drops", drops)

func _dirty() -> void:
	save_button.text = "Save changes *" if store.dirty else "Save changes"
	_status("Unsaved changes. Preview uses the edited record.")

func _save() -> void:
	if store.save():
		save_button.text = "Save changes"
		_status("Saved content_edits.json. Previous file backed up. Restart the local game to apply.")
	else:
		_status(store.error, true)

func _reload() -> void:
	if store.dirty:
		_status("Save changes before reloading, or use Revert on the selected record.", true)
		return
	if not store.reload():
		_status(store.error, true)
		return
	store.load_catalogues()
	assets.build(store)
	_fill_packs()
	_refresh_records()
	_status("Catalogues and source usage refreshed.")

func _discard() -> void:
	if not store.dirty:
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Discard all unsaved edits and reload the saved file?"
	dialog.confirmed.connect(func():
		if store.reload():
			save_button.text = "Save changes"
			_refresh_records()
		else:
			_status(store.error, true)
	)
	root.add_child(dialog)
	dialog.popup_centered()

func _update_preview() -> void:
	if selected.is_empty() or not is_instance_valid(preview.stage):
		return
	if section == "enemies":
		preview.monster(selected, biome.selected, body_context.selected == 0)
	elif section == "items":
		preview.item(selected, biome.selected)
	else:
		preview.asset(selected)
	_stats_label()

func _stats_label() -> void:
	if section == "enemies" and not selected.is_empty():
		var stats := Edits.combat_stats(selected, int(depth.value))
		_status("Preview level %s: health %.1f, attack %.1f. Motion uses speed, range, windup and recovery on a clear test floor." % [stats.level, stats.hp, stats.damage])

func _bind_model(asset: Dictionary) -> void:
	if section == "enemies":
		_set_field("source_asset", asset.id)
		_set_field("visual", {"tags": [], "pack": asset.pack, "patterns": [asset.id]})
	else:
		_set_field("asset_id", asset.id)
	_status("Model selected. Save changes to use it in local games.")

func _bind_icon(asset: Dictionary) -> void:
	_set_field("icon", asset.path)
	_set_field("icon_region", null)
	if not selected.has("asset_id"):
		_set_field("source_asset", asset.id)

func _assign_last() -> void:
	var asset := selected.duplicate(true)
	var target := editing_target.duplicate()
	_switch(target.section)
	_select_id(target.id)
	_bind_model(asset)

func _adopt(target_section: String, kind: String = "material") -> void:
	var id := store.adopt(selected, target_section, kind)
	if id.is_empty():
		_status(store.error, true)
		return
	assets.build(store)
	_switch(target_section)
	_select_id(id)
	_dirty()

func _select_id(id: String) -> void:
	search.text = id
	page = 0
	_filter()
	if not filtered.is_empty():
		list.select(0)
		_select(0)

func _picker(kind: String, callback: Callable) -> void:
	var choices: Array = assets.rows.filter(func(asset): return asset.staged and asset.kind == kind)
	_choice_popup("Choose " + kind, choices, callback)

func _drop_picker() -> void:
	var choices: Array = store.entries("items").filter(func(item): return item.kind != "bound" and store.Items.available(item))
	_choice_popup("Add drop item", choices, func(item):
		var entries: Array = selected.get("drops", {}).get("entries", []).duplicate(true)
		entries.append({"item": item.id, "weight": 1})
		_set_drop("entries", entries)
		_select(list.get_selected_items()[0])
	)

func _choice_popup(heading: String, choices: Array, callback: Callable) -> void:
	var popup := Window.new()
	popup.title = heading
	popup.size = Vector2i(700, 500)
	popup.transient = true
	root.add_child(popup)
	var layout := _column(popup)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var query := LineEdit.new()
	query.placeholder_text = "Search name or ID; first 100 matches shown"
	layout.add_child(query)
	var options := ItemList.new()
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(options)
	var matches: Array = []
	var filter := func():
		matches.assign(choices.filter(func(entry): return query.text.is_empty() or query.text.to_lower() in (str(entry.get("name", entry.get("title", ""))) + " " + entry.id).to_lower()).slice(0, 100))
		options.clear()
		for entry in matches:
			options.add_item(str(entry.get("name", entry.get("title", ""))) + " | " + entry.id)
	query.text_changed.connect(func(_text): filter.call())
	_button(layout, "Use selected", func():
		if not options.get_selected_items().is_empty():
			callback.call(matches[options.get_selected_items()[0]])
			popup.queue_free()
	)
	popup.close_requested.connect(popup.queue_free)
	filter.call()
	popup.popup_centered()

func _json_editor(key: String, value) -> void:
	var popup := Window.new()
	popup.title = key.capitalize()
	popup.size = Vector2i(620, 450)
	root.add_child(popup)
	var layout := _column(popup)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text := CodeEdit.new()
	text.text = JSON.stringify(value, "\t")
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(text)
	var message := _label(layout, "Animation names: " + str(preview.clips()) if key == "animations" else "Use valid JSON; values are checked before saving.", 12)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(layout, "Apply", func():
		var parsed = JSON.parse_string(text.text)
		var patch := {}
		patch[key] = parsed
		if not Edits.patch_valid(patch, section):
			message.text = "Invalid " + key + ". Fix the JSON values."
			return
		_set_field(key, parsed)
		popup.queue_free()
		_select(list.get_selected_items()[0])
	)
	popup.close_requested.connect(popup.queue_free)
	popup.popup_centered()

func _simulate_drops() -> void:
	var definitions := Edits.items(store.base_items, store.document)
	store.Items.EnemyLoot.choices.clear()
	var tally := {}
	for ordinal in range(1, 1001):
		var chance: float = selected.get("drops", {}).get("item_chance", store.Items.policy.enemy_item_chance)
		var id: String = store.Items.EnemyLoot.reward(42, ordinal, selected, {"class": reward_class, "biome": biome.selected, "family": reward_family, "facet": "", "level": Edits.combat_stats(selected, int(depth.value)).level}, definitions) if store.Items._chance(42, ordinal, "item-chance", chance) else ""
		if not id.is_empty():
			tally[id] = int(tally.get(id, 0)) + 1
		if store.Items.available(definitions.get("ember_shard", {})) and store.Items.enemy_shard(42, ordinal, selected):
			tally.ember_shard = int(tally.get("ember_shard", 0)) + 1
		var orb := store.Items.enemy_orb(42, ordinal, selected)
		if not orb.is_empty():
			tally[orb + "_orb"] = int(tally.get(orb + "_orb", 0)) + 1
	tally.gold_coin = int(selected.get("drops", {}).get("coins", 1)) * 1000 if store.Items.available(definitions.get("gold_coin", {})) else 0
	var popup := Window.new()
	popup.title = "1,000 deterministic " + reward_class + " reward rolls"
	popup.size = Vector2i(650, 450)
	root.add_child(popup)
	var view := TextEdit.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.editable = false
	view.text = JSON.stringify(tally, "\t")
	popup.add_child(view)
	popup.close_requested.connect(popup.queue_free)
	popup.popup_centered()

func _export_report() -> void:
	var report := assets.report()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/asset-usage.json", FileAccess.WRITE)
	if file == null:
		_status("Cannot write artifacts/asset-usage.json.", true)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	_status("Saved artifacts/asset-usage.json: " + str(report.counts))

func _stage_asset() -> void:
	if rebuilding or store.dirty:
		_status("Save edits before staging assets and restarting the workbench.", true)
		return
	rebuilding = true
	worker = Thread.new()
	var id: String = selected.id
	worker.start(func():
		var output := []
		var result := OS.execute("ruby", [ProjectSettings.globalize_path("res://tools/content_editor/import_asset.rb"), "--asset", id], output, true)
		if result == 0:
			result = OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--headless", "--editor", "--quit"], output, true)
		var text := "\n".join(output)
		if "SCRIPT ERROR:" in text or "ERROR:" in text:
			result = 1
		return {"status": result, "log": text}
	)
	_status("Staging the selected source, rebuilding catalogues and importing resources...")

func _process(_delta: float) -> bool:
	if rebuilding and worker != null and not worker.is_alive():
		worker_result = worker.wait_to_finish()
		rebuilding = false
		worker = null
		var file := FileAccess.open("res://artifacts/content-editor-import.log", FileAccess.WRITE)
		if file != null:
			file.store_string(worker_result.log)
			file.close()
		if worker_result.status == 0:
			OS.create_process(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/content_editor/editor.gd"])
			quit()
		else:
			_status("Import failed. See artifacts/content-editor-import.log. The workbench remains open.", true)
	return false

func _close() -> void:
	if rebuilding:
		_status("Wait for the active import to finish.", true)
		return
	if store.dirty:
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "Close and discard unsaved changes?"
		dialog.confirmed.connect(func(): quit())
		root.add_child(dialog)
		dialog.popup_centered()
	else:
		quit()

func _text_field(key: String, caption: String, value: String) -> void:
	_label(form, caption, 13)
	var edit := LineEdit.new()
	edit.text = value
	form.add_child(edit)
	edit.text_changed.connect(func(text): _set_field(key, text))
	controls[key] = edit

func _number_field(key: String, caption: String, value: float, low: float, high: float, step: float, divisor: float = 1) -> void:
	var row := _row(form)
	_label(row, caption, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = minf(step, low) if low > 0 else step
	spin.value = value
	spin.custom_minimum_size.x = 115
	row.add_child(spin)
	spin.value_changed.connect(func(number): _set_field(key, number / divisor))
	controls[key] = spin

func _drop_number(key: String, caption: String, value: float, low: float, high: float, step: float, divisor: float = 1) -> void:
	var row := _row(form)
	_label(row, caption, 13).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	row.add_child(spin)
	spin.value_changed.connect(func(number): _set_drop(key, number / divisor))

func _bool_field(key: String, caption: String, value: bool) -> void:
	var check := CheckBox.new()
	check.text = caption
	check.button_pressed = value
	form.add_child(check)
	check.toggled.connect(func(enabled): _set_field(key, enabled))
	controls[key] = check

func _smoke_test() -> void:
	var original := store
	var path := "user://workbench-smoke-%s.json" % Time.get_ticks_usec()
	store = Store.new(path)
	store.load_catalogues()
	_select_id("crypt_skeleton")
	controls.hp.value = 150
	controls.aggressive.button_pressed = false
	await process_frame
	await process_frame
	assert(store.document.enemies.crypt_skeleton.hp == 150 and not store.document.enemies.crypt_skeleton.aggressive, str({"record": selected.id, "edits": store.document.enemies, "control_hp": controls.hp.value, "control_aggressive": controls.aggressive.button_pressed}))
	await create_timer(.4).timeout
	preview.mode = "Pursuit"
	var before := preview.actor.position
	await create_timer(.3).timeout
	assert(preview.actor.position.is_equal_approx(before), "Neutral preview must not chase before provocation")
	preview.provoked = store.Enemies.after_hit(selected, false)
	await create_timer(.3).timeout
	assert(preview.actor.position.distance_to(before) > .05, "Neutral preview must move after provocation")
	controls.retaliates.button_pressed = false
	await create_timer(.4).timeout
	preview.provoked = store.Enemies.after_hit(selected, false)
	before = preview.actor.position
	await create_timer(.3).timeout
	assert(preview.actor.position.is_equal_approx(before), "Passive preview must ignore provocation")
	assert(store.save(), store.error)
	var restored := Store.new(path)
	assert(restored.document.enemies.crypt_skeleton.hp == 150)
	assert(not restored.document.enemies.crypt_skeleton.aggressive and not restored.document.enemies.crypt_skeleton.retaliates)
	_switch("items")
	_select_id("health_potion")
	controls.removal.emit_signal("pressed")
	assert(store.document.items.health_potion.removed and filtered.is_empty() and selected.is_empty(), "Remove button must hide its record and clear the inspector")
	show_removed.button_pressed = true
	_select_id("health_potion")
	assert(selected.removed and controls.removal.text == "Restore item")
	assert(store.save(), store.error)
	assert(Store.new(path).document.items.health_potion.removed)
	if "--capture-removal" in OS.get_cmdline_user_args():
		await create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/content-editor-removal.png")
	controls.removal.emit_signal("pressed")
	assert(not selected.removed and controls.removal.text == "Remove item")
	show_removed.button_pressed = false
	assert(filtered.size() == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".backup"))
	store = original
	print("PASS: live stats, aggression preview, item remove/show/restore controls and atomic persistence")

func _choice_field(key: String, caption: String, choices: Array, value: String) -> void:
	_label(form, caption, 13)
	var choice := OptionButton.new()
	for name in choices:
		choice.add_item(name)
	choice.select(maxi(0, choices.find(value)))
	form.add_child(choice)
	choice.item_selected.connect(func(index): _set_field(key, choices[index]))

func _heading(text: String) -> void:
	var separator := HSeparator.new()
	form.add_child(separator)
	_label(form, text, 16, Color("71dcca"))

func _status(text: String, failed: bool = false) -> void:
	status.text = text
	status.modulate = Color("f2a59e") if failed else Color("aebdd2")

func _column(parent: Node) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", 9)
	parent.add_child(result)
	return result

func _row(parent: Node) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	parent.add_child(result)
	return result

func _label(parent: Node, text: String, size: int = 14, color: Color = Color("d7e1f0")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _panel(parent: Node) -> MarginContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192333")
	style.border_color = Color("2b3b51")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	return margin

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	for type in ["Button", "LineEdit", "OptionButton", "ItemList", "TextEdit"]:
		theme.set_color("font_color", type, Color("d7e1f0"))
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("27364d") if state == "hover" else Color("121d2d")
			style.border_color = Color("65bfb0") if state == "focus" else Color("344661")
			style.set_border_width_all(1)
			style.set_corner_radius_all(5)
			style.content_margin_left = 9
			style.content_margin_right = 9
			style.content_margin_top = 7
			style.content_margin_bottom = 7
			theme.set_stylebox(state, type, style)
	return theme
