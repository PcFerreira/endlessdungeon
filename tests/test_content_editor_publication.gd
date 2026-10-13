extends SceneTree

const Store = preload("res://tools/content_editor/store.gd")
const Edits = preload("res://scripts/content_edits.gd")
var folder := "user://workbench-publication-%s" % Time.get_ticks_usec()
var path := folder.path_join("edits.json")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var store := Store.new(path)
	assert(store.save(), store.error)
	assert(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock")) == OK)
	assert(not store.save(), "Cooperating writers must not publish while another save owns the lock")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock"))
	for index in range(4000):
		store.document.add_items.append({"id": "editor:publication_%s" % index, "name": "Publication material", "description": "x".repeat(4096), "kind": "material", "stack": 1, "icon": "res://assets/items/oak_chair.svg", "source_pack": "editor"})
	var thread := Thread.new()
	assert(thread.start(intervene) == OK)
	var saved := store.save()
	var intervention: bool = thread.wait_to_finish()
	assert(intervention, "The external writer must exercise the actual publication window")
	assert(not saved and store.error.contains("changed"))
	var final := Edits.read_document(path)
	assert(final.items.ember_shard.name == "External publication" and final.add_items.is_empty())
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path + ".lock")))
	for filename in DirAccess.get_files_at(folder):
		assert(not ".tmp-" in filename, "Rejected saves must clean their own staged file")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("PASS: cooperating writer exclusion and retained external edits during real 16MB publication, with rejected-save cleanup")
	quit()

func intervene() -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		for filename in DirAccess.get_files_at(folder):
			if not filename.begins_with("edits.json.tmp-"):
				continue
			var document := Edits.empty_document()
			document.items.ember_shard = {"name": "External publication"}
			var temporary := path + ".other"
			var file := FileAccess.open(temporary, FileAccess.WRITE)
			file.store_string(JSON.stringify(document))
			file.close()
			return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK
		OS.delay_msec(1)
	return false
