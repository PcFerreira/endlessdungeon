extends SceneTree

const Game = preload("res://scripts/game.gd")
const Catalog = preload("res://scripts/biome_landmark_catalog.gd")
const Composition = preload("res://scripts/biome_composition.gd")
const GRIDS := [Vector2i(-4,-7), Vector2i(-386,-362), Vector2i(-4,7), Vector2i(-379,-340), Vector2i(5,-4), Vector2i(-4,4), Vector2i(0,1), Vector2i(-378,-343)]
var directory := OS.get_cache_dir().path_join("endless-test-landmark-journal-%s" % OS.get_process_id())
var failures := 0
var game

func _initialize() -> void:
	root.size = Vector2i(1280,800)
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", message)

func run_checks() -> void:
	game = Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_run(91,7)
	game._clear_actors()
	var records: Array[Dictionary] = []
	var seen := {}
	var kinds := {}
	for grid in GRIDS:
		var record := Catalog.plan(game.world, Composition.feature(91, grid * 64 + Vector2i.ONE * 32))
		check(not record.is_empty(), "accepted actual construction grid must still generate a plan: " + str(grid))
		if record.is_empty():
			continue
		records.append(record)
		seen[record.id] = true
		kinds[record.kind] = true
	check(records.size() == 8 and kinds.size() == 8, "journal input must contain all eight actual generated construction kinds")
	check(game.exploration.landmarks.restore({"version":1,"seen":seen,"claimed":{}}, "91"), "actual generated discovery ledger must restore through the real controller")
	game.expansion.toggle_journal()
	check(game.state == "journal", "actual Game journal must open")
	for frame in range(4):
		await process_frame
	var screen: Rect2 = root.get_visible_rect()
	var scrolls: Array[Node] = game.expansion.overlay.find_children("*", "ScrollContainer", true, false)
	check(scrolls.size() == 1, "actual field journal must expose its real scroll viewport")
	if scrolls.size() == 1:
		var scroll: ScrollContainer = scrolls[0]
		var bounds := scroll.get_global_rect()
		check(bounds.position.x >= screen.position.x - 1 and bounds.end.x <= screen.end.x + 1, "actual journal scroll viewport must fit the screen horizontally")
		var horizontal := scroll.get_h_scroll_bar()
		check(horizontal.max_value <= horizontal.page + 1, "actual journal content must have no horizontal scroll overflow")
		var panel := scroll.get_parent()
		while panel != null and not panel is PanelContainer:
			panel = panel.get_parent()
		if panel is PanelContainer:
			var panel_bounds: Rect2 = panel.get_global_rect()
			check(panel_bounds.position.x >= screen.position.x - 1 and panel_bounds.end.x <= screen.end.x + 1, "actual journal panel must remain within screen edges")
		for record in records:
			var names := 0
			var stories := 0
			for control in scroll.find_children("*", "Control", true, false):
				var caption := ""
				if control is Label or control is Button:
					caption = control.text
				if not caption.contains(record.name) and caption != record.flavor:
					continue
				var rect: Rect2 = control.get_global_rect()
				check(rect.position.x >= bounds.position.x - 1 and rect.end.x <= bounds.end.x + 1, "actual name/story must fit the journal viewport: " + record.kind)
				if control is Label:
					check(control.get_visible_line_count() >= control.get_line_count(), "actual full name/story must not lose lines: " + record.kind)
					check(control.size.y + 1 >= control.get_line_count() * control.get_line_height(), "actual text must have height for every displayed line: " + record.kind)
				if caption.contains(record.name):
					names += 1
				if caption == record.flavor:
					stories += 1
			check(names >= 1 and stories >= 1, "actual journal must contain readable full name and flavor: " + record.kind)
		print("ACTUAL JOURNAL: ", {"screen":screen,"viewport":bounds,"horizontal_max":horizontal.max_value,"horizontal_page":horizontal.page,"kinds":kinds.size()})
	game.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
	check(not DirAccess.dir_exists_absolute(directory), "private journal fixture saves/settings must be removed")
	print("PASS: real eight-kind journal layout fits the screen and keeps complete names/stories readable" if failures == 0 else "REJECT: %s actual journal layout failures" % failures)
	quit(0 if failures == 0 else 1)
