extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--manifest-sha256" and FileAccess.get_sha256("res://config/network_manifest.json") != arguments[1]:
		failures.append("Exported network manifest differs from coordinated release")
	for path in ["res://assets/imported/catalog.json", "res://assets/bundles/catalog.json", "res://assets/world_construction/catalog.json", "res://assets/lore/catalog.json", "res://config/network_manifest.json", "res://CREDITS.md"]:
		if not FileAccess.file_exists(path):
			failures.append("Missing raw runtime file: " + path)
	for path in DirAccess.get_files_at("res://config"):
		if path.ends_with(".json") and not JSON.parse_string(FileAccess.get_file_as_string("res://config/" + path)) is Dictionary:
			failures.append("Missing or invalid config: " + path)
	var catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://assets/imported/catalog.json"))
	var resources := 0
	if catalogue is Dictionary:
		for entry in catalogue.get("assets", []):
			if entry.get("kind", "") == "text":
				continue
			resources += 1
			if not ResourceLoader.exists(entry.path):
				failures.append("Missing dynamic asset: " + str(entry.path))
		for pack in catalogue.get("packs", {}):
			if not FileAccess.file_exists("res://assets/imported/packs/%s/SOURCE.json" % pack):
				failures.append("Missing pack source notice: " + str(pack))
		for relative_path in catalogue.get("files", {}):
			var file_name: String = str(relative_path).get_file().to_lower()
			if str(relative_path).get_extension().to_lower() not in ["json", "txt", "md", "html"] and not file_name.begins_with("license") and not file_name.begins_with("licence"):
				continue
			var path: String = "res://assets/imported/" + str(relative_path)
			if FileAccess.get_sha256(path) != catalogue.files[relative_path].sha256:
				failures.append("Missing or changed raw notice: " + path)
	for path in ["res://assets/items/gold_coin.svg", "res://assets/fonts/OFL.txt"]:
		if not FileAccess.file_exists(path):
			failures.append("Missing raw icon or font license: " + path)
	for directory in ["res://import_assets", "res://server", "res://tests", "res://tools", "res://.tools", "res://artifacts", "res://addons/web_raw_files"]:
		if DirAccess.dir_exists_absolute(directory):
			failures.append("Development directory exported: " + directory)
	if failures.is_empty():
		print("PASS: Web export pack (%d dynamic resources, raw catalogues, SVG and notices; development directories excluded)" % resources)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
