extends SceneTree

const World = preload("res://scripts/world.gd")
const Finite = preload("res://scripts/finite_world.gd")
const Life = preload("res://scripts/world_life.gd")
const Store = preload("res://scripts/save_store.gd")
const Client = preload("res://scripts/online_client.gd")
const Build = preload("res://scripts/character_build.gd")
const Profile = preload("res://scripts/character_profile.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Codec = preload("res://scripts/map_chunk_codec.gd")
const LEGACY := ["bolt", "fire", "nova", "blink", "strike", "cleave", "guard", "dash", "storm", "meteor", "mend", "whirlwind", "second_wind", "execute", "runeblade"]
var directory := OS.get_cache_dir().path_join("endless-test-composition-editions-%s" % OS.get_process_id())
var failures: Array[String] = []

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	return condition

func envelope(edition: int) -> Dictionary:
	var build := Build.new()
	build.reset("mage")
	var cooldowns := {}
	for spell in LEGACY:
		cooldowns[spell] = .4
	return {
		"generator_version": edition, "saved_at": 1, "seed": "91", "rng_state": "1", "build": build.snapshot(),
		"location": {"layer": "overworld", "name": "Journey", "point": [0, 0], "surface_return": [0, 0], "sanctuary": [0, 0], "site_cell": [0, 0], "aim": [0, 1], "heading": [0, 1], "site_id": "", "selected": "", "grounded": true, "player_y": 0, "velocity": 0, "depth": 1},
		"stats": {"hp": 100, "mana": 100, "kills": 0, "elapsed": 0, "guard": 0, "invulnerable": 0, "best_depth": 1, "cooldowns": cooldowns},
		"view": {"yaw": 0, "target_yaw": 0, "surface_zoom": 20, "dungeon_zoom": 20},
		"progress": {"lore": {"books": [], "speakers": [], "heard": {}, "returns": {}}, "encounters": {}, "floors": {}, "discovery": {}, "claimed": [], "cities": [], "waypoint": "", "waypoint_cell": [0, 0]},
		"pickups": [], "projectiles": []
	}

func saves() -> void:
	var store := Store.new()
	store.directory = directory
	for edition in [4, 5, 6, 7]:
		var data := envelope(edition)
		if edition >= 5:
			data.progress.life = {"version": 1, "tick": 0, "fraction": .0, "actors": {}, "context": {"edition": edition, "seed": "91", "roads": 2 if edition >= 6 else 1}}
		check(store.validate(data), "Actual save envelope must accept edition%s and matching Life context" % edition)
		check(store.write(edition - 4, data), "Edition%s must persist through the real save writer" % edition)
		var read: Dictionary = store.read(edition - 4)
		check(read.has("data") and read.data.generator_version == edition, "Edition%s must restore its actual disk edition" % edition)
		if edition >= 5:
			var restored := Life.new()
			check(restored.restore(data.progress.life, 91) and restored.world_edition == edition, "Life must retain actual edition%s" % edition)
			var mismatch := data.duplicate(true)
			mismatch.progress.life.context.edition = 6 if edition == 7 else 7
			check(not store.validate(mismatch), "Outer edition%s must reject a different nested Life edition" % edition)
	for invalid in [3, 8, 7.5, "7", NAN, INF]:
		var data := envelope(7)
		data.generator_version = invalid
		check(not store.validate(data), "Unsupported or nonintegral editions must remain rejected")
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	check(not DirAccess.dir_exists_absolute(directory), "Isolated disk save artifacts must clean up")

func providers() -> void:
	var world := World.new()
	world.generate(91, 7)
	var point := Vector2i(40, 100)
	var info := world.cell_info(point)
	check(info.has("composition_zone") and World.Biomes.valid_cell(info), "Actual edition7 World must produce composition and valid reused ecology")
	var climate_reference := World.new()
	climate_reference.generate(91, 6)
	check(world.temperature.frequency == climate_reference.temperature.frequency and world.moisture.frequency == climate_reference.moisture.frequency, "Edition7 retains the exact established edition6 fivefold climate geometry")
	var old := Finite.new()
	old.generate(91, 6)
	var current := Finite.new()
	current.generate(91, 7)
	check(current.generator_version == 7 and current.authored_sites() == old.authored_sites(), "Finite provider accepts hero edition7 while retaining actual authored destinations")
	for cell in [current.start, current.return_portal, Vector2i(0, 0), Vector2i(2047, 2047)]:
		check(current.cell_info(cell) == old.cell_info(cell), "Hero edition7 must preserve actual finite terrain at %s" % cell)

func welcome() -> void:
	var build := Build.new()
	build.reset("mage")
	var player := {"id": "edition-contract", "username": "Audit", "class_id": "mage", "profile": Profile.new().snapshot(), "build": build.snapshot(), "inventory": Inventory.new().snapshot(), "position": [0, 0], "heading": [0, 1]}
	var client := Client.new()
	client.content_revision = "edition-contract"
	client.receive({"type": "welcome", "protocol": 1, "token": "isolated-test-token", "player": player, "players": [player], "world": {"id": "test", "seed": "91", "generator_version": 7, "content_revision": "edition-contract"}})
	check(not client.bootstrap.is_empty() and client.remote_world != null and client.remote_world.generator_version == 7, "Actual welcome consumer must bootstrap an edition7 RemoteWorld")
	check(not client.session and client.socket == null, "Welcome eligibility must retain the received-map requirement without opening a socket")
	client.lobby.root.free()
	client.lobby.free()
	client.free()

func legacy_cells() -> void:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/biome_edition6_before_composition.json"))
	var worlds := {}
	for record in records:
		var seed_value := int(record.seed)
		if not worlds.has(seed_value):
			worlds[seed_value] = World.new()
			worlds[seed_value].generate(seed_value, 6)
		var cell := Vector2i(record.cell[0], record.cell[1])
		var decoded := Codec.decode(record.info)
		check(decoded.ok and worlds[seed_value].cell_info(cell) == decoded.value, "Actual old6 cell must retain its complete pre-composition record at seed%s %s" % [seed_value, cell])
	print("LEGACY6: ", records.size(), " exact cell records")

func _init() -> void:
	saves()
	providers()
	welcome()
	legacy_cells()
	if failures.is_empty():
		print("PASS: composition edition7 save/Life/provider/welcome eligibility and exact pre-hook edition6 cells with preserved legacy support")
	quit(0 if failures.is_empty() else 1)
