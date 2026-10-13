extends "res://server/world_worker.gd"

var replies: Array[Dictionary] = []
var failures: Array[String] = []

func _process(_delta: float) -> bool:
	return false

func _send(value: Dictionary) -> void:
	replies.append(value.duplicate(true))

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)
	return condition

func _initialize() -> void:
	_command({"type": "init", "seed": "91", "generator_version": 7, "request": 1})
	if not check(initialized and edition == 7 and replies.back().get("ready", false), "Actual worker initialization must accept edition7"):
		quit(1)
		return
	_command({"type": "join", "id": "private-contract", "username": "Audit", "class_id": "mage", "request": 2})
	if not check(players.has("private-contract") and players["private-contract"].world.generator_version == 7, "Actual worker join must construct the edition7 provider"):
		quit(1)
		return
	_command({"type": "chunks", "id": "private-contract", "coordinates": [[2, 6]], "request": 3})
	var packet: Dictionary = replies.back()
	check(packet.has("chunks") and packet.chunks.size() == 1, "Actual worker must supply requested edition7 terrain")
	if packet.has("chunks") and not packet.chunks.is_empty():
		var decoded := Codec.decode(packet.chunks[0].cells)
		check(decoded.ok and decoded.value.size() == 256, "Actual edition7 worker terrain must preserve the authoritative chunk schema")
		if decoded.ok:
			for info in decoded.value.values():
				check(info.has("composition_zone") and World.Biomes.valid_cell(info), "Actual worker cells must transport composition plus valid ecology")
	_command({"type": "init", "seed": "91", "generator_version": 8, "request": 4})
	check(replies.back().get("error") == "Unsupported generation edition", "Worker must keep rejecting unsupported editions")
	players.clear()
	if failures.is_empty():
		print("PASS: inherited actual worker init/join/chunk commands accept7 and reject8 without any transport or live authority")
	quit(0 if failures.is_empty() else 1)
