extends SceneTree

const Client = preload("res://scripts/online_client.gd")

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("run_checks")

func run_checks() -> void:
	var socket := Client.create_socket()
	assert(socket.connect_to_url("ws://127.0.0.1:18089/") == OK)
	var deadline := Time.get_ticks_msec() + 10000
	while socket.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() < deadline:
		socket.poll()
		await process_frame
	assert(socket.get_ready_state() == WebSocketPeer.STATE_OPEN)
	socket.send_text("burst")
	while socket.get_available_packet_count() < 512 and Time.get_ticks_msec() < deadline:
		socket.poll()
		await process_frame
	assert(socket.get_available_packet_count() == 512, "A renderer stall must retain the bounded state/map burst without dropping packets")
	for tick in range(512):
		var message = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		assert(message is Dictionary and message.tick == tick and message.padding.length() == 32768)
	socket.close()
	print("PASS actual WebSocket burst retains 512 queued frames and more than 16 MiB before draining")
	quit()
