extends SceneTree

const Game = preload("res://scripts/game.gd")
const Profile = preload("res://scripts/character_profile.gd")
const Player = preload("res://scripts/player_voxels.gd")
var directory := "user://test-character-styles-%s" % Time.get_ticks_usec()

func fresh():
	var game := Game.new()
	game.records_enabled = false
	game.save_directory = directory
	game.settings_path = directory.path_join("settings.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	return game

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game = fresh()
	game.start_run(12345)
	var choices := Profile.premades()
	assert(choices.size() == 12 and choices.all(func(entry): return entry.geometry == "voxel"))
	var stats := [game.max_hp, game.max_mana, game.damage_multiplier, game.rng.state, game.inventory.snapshot()]
	for entry in choices:
		assert(game.customize_character({"model": entry.id}))
		assert(game.profile.model == entry.id and not game.player_mesh.imported)
		assert(game.player_mesh.body.get_meta("geometry") == "voxel")
		assert(game.player_mesh.animations.size() == 1)
		var bounds: AABB = game.player_mesh.visual_bounds()
		assert(bounds.size.y > .75 and bounds.size.y < 1.7 and absf(bounds.position.y) < .001)
		var skin: int = (game.profile.skin + 1) % Profile.SKINS.size()
		assert(game.customize_character({"skin": skin, "outerwear": "scarf"}), "Preset parts must remain editable")
		assert(game.profile.skin == skin and game.profile.outerwear == "scarf")
		assert([game.max_hp, game.max_mana, game.damage_multiplier, game.rng.state, game.inventory.snapshot()] == stats)
	var selected: String = choices[6].id
	assert(game.customize_character({"model": selected, "name": "Nara", "headwear": "circlet", "trim": 10, "gloves": "leather"}))
	var exact: Dictionary = game.profile.snapshot()
	assert(not game.customize_character({"model": "res://project.godot"}) and game.profile.snapshot() == exact)
	assert(not game.customize_character({"model": "kaykit_adventures/content/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb"}))
	assert(not game.customize_character({"costume": "sword_sentinel"}) and game.profile.snapshot() == exact)
	game._clear_actors()
	assert(game.use_sanctum_sigil() and game.save_game(1))
	game.queue_free()
	await process_frame
	game = fresh()
	assert(game.load_game(1) and game.profile.snapshot() == exact and not game.player_mesh.imported)
	assert(game.leave_sanctum() and game.profile.snapshot() == exact)
	var scene = game.player_mesh.body
	var meshes := Player.mesh_cache.size()
	assert(game.customize_character({"name": "Nara of the road"}))
	assert(Player.mesh_cache.size() == meshes, "Renaming must reuse geometry")
	assert(scene != game.player_mesh.body and game.profile.model == selected)
	game.state = "title"
	game.choose_class("sword")
	assert(game.customize_character({"costume": "sword_sentinel"}))
	game.choose_class("mage")
	assert(game.profile.costume == "class_default", "Class-specific old clothes must not survive an incompatible class")
	var legacy: Dictionary = game.make_save_data()
	legacy.character = {"name": "Old hero", "ancestry": "dwarf", "skin": 3, "hair": 2, "outfit": 4, "head": "beard", "costume": "mage_scholar", "model": "kaykit_adventures/content/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb"}
	assert(game.saves.validate(legacy) and game.Journey.restore(game, legacy))
	assert(game.profile.model == "custom" and game.profile.beard == "full" and game.profile.display_name == "Old hero")
	assert(game.profile.skin == 3 and game.profile.outfit == 4 and not game.player_mesh.imported)
	assert(game.save_game(2) and game.load_game(2) and game.profile.appearance_version == 2)
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("PASS: twelve editable voxel presets, unchanged stats/inventory/RNG, valid class wardrobe, atomic option rejection, fresh disk/home carry, name-independent geometry cache and migrated imported heroes")
	quit()
