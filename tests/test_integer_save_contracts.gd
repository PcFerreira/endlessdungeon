extends SceneTree

const Build = preload("res://scripts/character_build.gd")
const Store = preload("res://scripts/save_store.gd")
const Life = preload("res://scripts/world_life.gd")
const Travel = preload("res://scripts/surface_travel.gd")
const MINIMUM := "-9223372036854775808"
const MAXIMUM := "9223372036854775807"
const OVERSIZED := ["9223372036854775808","9223372036854775809","-9223372036854775809","999999999999999999999999999999999999999999999999999999999999999999"]
const INPUTS := ["scripts/save_store.gd","scripts/world_life.gd","scripts/surface_travel.gd","scripts/character_build.gd","tests/test_integer_save_contracts.gd"]
var failures: Array[String] = []
var checked := 0

func hashes() -> Dictionary:
	var result := {}
	for path in INPUTS:
		result[path] = FileAccess.get_sha256("res://"+path)
	return result

func expect(value: bool, message: String) -> void:
	checked += 1
	if not value:
		failures.append(message)
		print("FAIL: ",message)

func envelope() -> Dictionary:
	var build := Build.new()
	build.reset("mage")
	var cooldowns := {}
	for spell in Build.ABILITIES:
		cooldowns[spell] = .4
	return {
		"generator_version":4,"saved_at":1,"seed":"91","rng_state":"1","build":build.snapshot(),
		"location":{"layer":"overworld","name":"Journey","point":[0,0],"surface_return":[0,0],"sanctuary":[0,0],"site_cell":[0,0],"aim":[0,1],"heading":[0,1],"site_id":"","selected":"","grounded":true,"player_y":0,"velocity":0,"depth":1},
		"stats":{"hp":100,"mana":100,"kills":0,"elapsed":0,"guard":0,"invulnerable":0,"best_depth":1,"cooldowns":cooldowns},
		"view":{"yaw":0,"target_yaw":0,"surface_zoom":20,"dungeon_zoom":20},
		"progress":{"lore":{"books":[],"speakers":[],"heard":{},"returns":{}},"encounters":{},"floors":{},"discovery":{},"claimed":[],"cities":[],"waypoint":"","waypoint_cell":[0,0]},
		"pickups":[],"projectiles":[]
	}

func empty_life() -> Dictionary:
	return {"version":Life.VERSION,"tick":0,"fraction":0,"actors":{}}

func _init() -> void:
	var before := hashes()
	var store := Store.new()
	var base := envelope()
	expect(store.validate(base),"Minimal complete save envelope must remain valid")
	var allowed := [MINIMUM,MAXIMUM,"0","91","-91","00091","-00091"]
	for text in ["+91","+00091"]:
		if text.is_valid_int():
			allowed.append(text)
	for field in ["seed","rng_state"]:
		for text in allowed:
			var data := base.duplicate(true)
			data[field] = text
			expect(store.validate(data),"Valid int64 save %s must retain compatibility: %s" % [field,text])
		for invalid in OVERSIZED+[true,false,91,91.0,NAN,INF,null,[],{},"","91.0","91x","--1"]:
			var data := base.duplicate(true)
			data[field] = invalid
			expect(not store.validate(data),"Save %s must reject oversized/typed-invalid integer before load: %s" % [field,str(invalid)])
	expect(Life.valid_snapshot(empty_life()),"Minimal empty Life snapshot must remain valid")
	for text in allowed:
		var data := empty_life()
		data.context = {"edition":5,"seed":text,"roads":1}
		expect(Life.valid_snapshot(data),"Valid int64 Life context seed must remain accepted: "+text)
	for invalid in OVERSIZED+[true,false,91,91.0,null,[],{},"","91.0","91x"]:
		var data := empty_life()
		data.context = {"edition":5,"seed":invalid,"roads":1}
		expect(not Life.valid_snapshot(data),"Life context must reject oversized/typed-invalid seed before conversion: "+str(invalid))
	for format_id in ["roamer:%s:%s:0","city:%s:%s:npc:0","habitat:%s:%s:animal:0","road:%s:%s:0:0","watch:%s:%s:0"]:
		for axis in range(2):
			for text in OVERSIZED+[MINIMUM,MAXIMUM,"2147483648","-2147483649"]:
				var fields := ["0","0"]
				fields[axis] = text
				var id: String = format_id % fields
				var data := empty_life()
				data.actors[id] = {}
				expect(not Life.valid_snapshot(data),"Life actor axis must reject before conversion diagnostics: "+id)
	var ordinary := Travel.fields("road5:0:0:1:0:0")
	expect(not ordinary.is_empty() and ordinary.first==Vector2i.ZERO and ordinary.last==Vector2i(1,0) and ordinary.slot==0,"Ordinary independent road identity must preserve parsed fields")
	for index in range(1,6):
		for text in OVERSIZED+[MINIMUM,MAXIMUM,"2147483648","4294967296","-4294967296","0000","+0","true","1.0"]:
			var fields := ["road5","0","0","1","0","0"]
			fields[index] = text
			var id := ":".join(fields)
			expect(Travel.fields(id).is_empty(),"Independent road must reject overflow/wrap/noncanonical axis or slot: "+id)
	expect(before==hashes(),"Integer contract inputs changed during validation")
	print("SOURCE_HASHES: ",{"before":before,"after":hashes()})
	if failures.is_empty():
		print("PASS: ",checked," data-only int64 save/context boundaries, legacy decimal spelling and actor-axis rejection contracts; no gameplay/disk mutation")
	else:
		print("FAIL: ",failures.size()," of ",checked," integer save validation contracts")
	quit(0 if failures.is_empty() else 1)
