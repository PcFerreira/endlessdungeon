extends Node

const Profile = preload("res://scripts/character_profile.gd")
const Build = preload("res://scripts/character_build.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Visual = preload("res://scripts/character_visual.gd")
const Lobby = preload("res://scripts/online_lobby.gd")
const RemoteWorld = preload("res://scripts/remote_world.gd")
var game
var socket: WebSocketPeer
var session := false
var connecting := false
var authenticated := false
var endpoint := ""
var content_revision := ""
var player_id := ""
var status := "Join the public world. Shared exploration is available; combat, trade and building are forthcoming."
var pending: Dictionary = {}
var players: Dictionary = {}
var avatars: Dictionary = {}
var offline_backup: Dictionary = {}
var offline_had_journey := false
var config_path := "user://online.cfg"
var lobby := Lobby.new()
var sequence := 0
var tick := -1
var input_clock := 0.0
var connection_clock := 0.0
var snapshot_clock := 0.0
var bootstrap: Dictionary = {}
var bootstrap_state: Dictionary = {}
var remote_world
var map_revision := 0
var travel_target := Vector2.INF
var travel_clock := 0.0
var travel_destination := ""

func _ready() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://config/network_manifest.json")) if FileAccess.file_exists("res://config/network_manifest.json") else null
	if manifest is Dictionary:
		content_revision = manifest.get("content_revision", "")
	endpoint = default_endpoint()
	var config := ConfigFile.new()
	if config.load(config_path) == OK and not OS.has_feature("web"):
		endpoint = config.get_value("connection", "endpoint", endpoint)
	lobby.client = self
	add_child(lobby)

static func default_endpoint() -> String:
	if OS.has_feature("web"):
		var page = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify({protocol:location.protocol,hostname:location.hostname,port:location.port})")))
		return page_endpoint(page.protocol, page.hostname, page.port)
	return "ws://127.0.0.1:8080/play"

static func page_endpoint(protocol: String, hostname: String, port: String = "") -> String:
	if protocol not in ["http:", "https:"]:
		return ""
	if protocol == "http:" and port == "8000" and local_host(hostname):
		port = "8080"
	if hostname.contains(":") and not hostname.begins_with("["):
		hostname = "[" + hostname + "]"
	return "%s://%s%s/play" % ["wss" if protocol == "https:" else "ws", hostname, ":" + port if not port.is_empty() else ""]

static func local_host(hostname: String) -> bool:
	if hostname.to_lower() == "localhost":
		return true
	var parts := hostname.split(".")
	if parts.size() != 4:
		return false
	var octets: Array[int] = []
	for part in parts:
		if not part.is_valid_int() or str(part.to_int()) != part or part.to_int() < 0 or part.to_int() > 255:
			return false
		octets.append(part.to_int())
	return octets[0] in [10, 127] or octets[0] == 172 and octets[1] >= 16 and octets[1] <= 31 or octets[0] == 192 and octets[1] == 168

static func endpoint_allowed(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^(ws|wss)://(\\[[0-9A-Fa-f:.]+\\]|[A-Za-z0-9.-]+)(?::([0-9]{1,5}))?(/[^\\s#]*)?$")
	var result := expression.search(value)
	if result == null:
		return false
	var port := result.get_string(3)
	if not port.is_empty() and (port.to_int() < 1 or port.to_int() > 65535):
		return false
	return result.get_string(1) == "wss" or local_host(result.get_string(2))

func open_lobby() -> void:
	if session or game.state == "online_lobby":
		return
	offline_backup = game.make_save_data() if not OS.has_feature("web") else {}
	offline_had_journey = game.has_journey
	game.has_journey = false
	game.state = "online_lobby"
	game.rotating_camera = false
	game.player.hide()
	game.interface.previous_state = ""
	lobby.show_form()

func credential_problem(username: String, password: String) -> String:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z0-9_]{3,24}$")
	if expression.search(username) == null:
		return "Use 3–24 letters, numbers or underscores for your account name."
	if password.length() < 12 or password.length() > 128:
		return "Use a password of 12–128 characters."
	return ""

func connect_account(action: String, username: String = "", password: String = "", class_id: String = "mage") -> void:
	if connecting or session or game.state != "online_lobby":
		return
	if content_revision.is_empty():
		set_status("This copy of the game cannot join a shared world. Try a newer release.")
		return
	if not endpoint_allowed(endpoint):
		set_status("Use wss:// for an Internet world, or ws:// with a local network address.")
		return
	pending = {"type": action, "content_revision": content_revision}
	if action == "resume":
		var token := saved_token()
		if token.is_empty():
			set_status("Sign in once to remember this world on this device.")
			return
		pending.token = token
	elif action in ["login", "register"]:
		var problem := credential_problem(username, password)
		if not problem.is_empty():
			set_status(problem)
			return
		pending.merge({"username": username, "password": password, "class_id": class_id})
	else:
		return
	socket = create_socket()
	var result := socket.connect_to_url(endpoint)
	if result != OK:
		pending.clear()
		set_status("Could not connect to that world.")
		return
	connecting = true
	authenticated = false
	connection_clock = 0
	snapshot_clock = 0
	set_status("Connecting to the public world…")

static func create_socket() -> WebSocketPeer:
	var peer := WebSocketPeer.new()
	peer.inbound_buffer_size = 33554432
	peer.max_queued_packets = 4096
	return peer

func set_status(message: String) -> void:
	status = message
	lobby.update_status()

func saved_token() -> String:
	var config := ConfigFile.new()
	if config.load(config_path) != OK or config.get_value("connection", "endpoint", "") != endpoint:
		return ""
	return config.get_value("connection", "token", "")

func remember_token(token: String) -> void:
	var config := ConfigFile.new()
	config.set_value("connection", "endpoint", endpoint)
	config.set_value("connection", "token", token)
	config.save(config_path)

func _process(delta: float) -> void:
	if socket == null:
		return
	socket.poll()
	var ready := socket.get_ready_state()
	if ready == WebSocketPeer.STATE_OPEN:
		if not authenticated:
			send(pending)
			pending.clear()
			authenticated = true
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			if not socket.was_string_packet() or packet.size() > 1048576:
				disconnect_world("The world sent an unsupported message.")
				return
			var message = JSON.parse_string(packet.get_string_from_utf8())
			if not message is Dictionary:
				disconnect_world("The world sent an unreadable message.")
				return
			receive(message)
			if socket == null:
				return
	elif ready == WebSocketPeer.STATE_CLOSED:
		fail_connection("Disconnected from the public world.")
		return
	if connecting:
		connection_clock += delta
		if connection_clock > 15:
			fail_connection("The world did not respond. Try again.")
	if session:
		snapshot_clock += delta
		if snapshot_clock > 10:
			disconnect_world("The world stopped responding. Your last server position is retained.")

func send(message: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))

static func valid_vector(value) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 100000000:
			return false
	return true

static func valid_player(record) -> bool:
	if not record is Dictionary or not record.get("id") is String or not record.get("username") is String or record.id.is_empty() or record.id.length() > 128 or record.username.length() > 24:
		return false
	if not Build.CLASSES.has(record.get("class_id")) or not valid_vector(record.get("position")) or not valid_vector(record.get("heading")):
		return false
	return Profile.new().restore(record.get("profile"), record.class_id)

static func valid_players(records) -> bool:
	if not records is Array or records.size() > 256:
		return false
	var ids := {}
	for record in records:
		if not valid_player(record) or ids.has(record.id):
			return false
		ids[record.id] = true
	return true

func receive(message: Dictionary) -> void:
	match message.get("type", ""):
		"welcome":
			if session or not bootstrap.is_empty() or not message.get("world") is Dictionary or not valid_players(message.get("players")) or not valid_player(message.get("player")):
				fail_connection("The world sent an invalid welcome.")
				return
			var world: Dictionary = message.world
			var edition = world.get("generator_version")
			if message.get("protocol") != 1 or world.get("content_revision") != content_revision or not world.get("seed") is String or not world.seed.is_valid_int() or not (edition is int or edition is float) or not is_finite(float(edition)) or edition != floorf(edition) or int(edition) not in [4, 5, 6]:
				fail_connection("This world needs another game build. Update and reconnect.")
				return
			var build := Build.new()
			var inventory := Inventory.new()
			if not message.player.get("build") is Dictionary or not build.restore(message.player.build) or build.class_id != message.player.class_id or not inventory.restore(message.player.get("inventory"), build.class_id) or not message.get("token") is String or message.token.is_empty():
				fail_connection("The world sent an invalid character.")
				return
			if not message.players.any(func(record): return record.id == message.player.id):
				fail_connection("The world omitted your character.")
				return
			player_id = message.player.id
			bootstrap = message
			remote_world = RemoteWorld.new()
			map_revision = 0
			remote_world.content_revision = content_revision
			remote_world.generate(world.seed.to_int(), int(world.generator_version))
			remote_world.chunks_requested.connect(request_chunks)
			remote_world.load_around(Vector2(message.player.position[0], message.player.position[1]))
			connecting = true
			connection_clock = 0
			set_status("Entering the public world…")
		"chunks":
			if remote_world == null:
				return
			if not remote_world.ingest(message):
				fail_connection("The world sent invalid map data. Update this build and reconnect.")
				return
			map_revision += 1
			if session:
				game.world_view.sync(game.world)
				finish_travel()
			else:
				finish_bootstrap()
		"state":
			if not session and not bootstrap.is_empty():
				bootstrap_state = message
				return
			var number = message.get("tick")
			if not session or not (number is float or number is int) or not is_finite(float(number)) or number != floorf(number) or number < 0:
				return
			if message.tick <= tick:
				return
			if not valid_players(message.get("players")):
				disconnect_world("The world sent an invalid player update.")
				return
			if not apply_players(message.players):
				disconnect_world("Your player is missing from the world update.")
				return
			tick = int(message.tick)
			snapshot_clock = 0
		"hub_travel":
			if session and valid_player(message.get("player")) and message.player.id == player_id:
				players[player_id] = message.player
				travel_target = Vector2(message.player.position[0], message.player.position[1])
				travel_destination = message.get("destination", "world")
				travel_clock = 0
				game.state = "hub_travel_loading"
				game.player.hide()
				game.world_view.hide()
				game.floating_hub.show_travel(travel_destination)
				remote_world.load_around(travel_target)
				finish_travel()
		"error":
			var explanation: String = str(message.get("message", "The world refused the request.")).left(240)
			if session and message.get("code") in ["hub_travel_refused", "invalid_hub_travel"]:
				game.notify(explanation)
				return
			if message.get("code") in ["invalid_token", "session_expired", "session_replaced"]:
				remember_token("")
			fail_connection(explanation)
		"bye":
			fail_connection("The world closed the connection.")

func finish_travel() -> void:
	if travel_target == Vector2.INF or not remote_world.ready_around(travel_target):
		return
	game.player_point = travel_target
	game._snap_camera()
	game.world_view.show()
	game.player.show()
	game.floating_hub.close()
	game.state = "playing"
	game.floating_hub.apply_lighting()
	game.notify("Arrived in Lanternwake." if travel_destination == "hub" else "Arrived in the wandering lands.")
	travel_target = Vector2.INF

func request_chunks(coordinates: Array) -> void:
	if not bootstrap.is_empty():
		return
	var requested := []
	for coordinate in coordinates:
		requested.append([coordinate.x, coordinate.y] if coordinate is Vector2i else coordinate)
	if not requested.is_empty():
		send({"type": "chunks", "coordinates": requested})

func finish_bootstrap() -> void:
	if bootstrap.is_empty():
		return
	var record: Dictionary = bootstrap.player
	if not remote_world.ready_around(Vector2(record.position[0], record.position[1])):
		return
	var build := Build.new()
	build.restore(record.build)
	var inventory := Inventory.new()
	inventory.restore(record.inventory, build.class_id)
	session = true
	connecting = false
	sequence = 0
	tick = -1
	input_clock = 0
	snapshot_clock = 0
	game.begin_online(bootstrap, build, inventory, remote_world)
	if OS.has_feature("web"):
		print("ONLINE_BOOTSTRAP source=server chunks=%s regions=%s offline_generation_calls=%s" % [remote_world.chunks.size(), remote_world.regions.size(), game.offline_generation_calls])
	apply_players(bootstrap.players)
	players[player_id] = record
	remember_token(bootstrap.token)
	bootstrap.clear()
	lobby.hide_form()
	set_status("Public world: shared exploration. Combat, trade and building are forthcoming.")
	game.notify(status)
	if not bootstrap_state.is_empty():
		var latest := bootstrap_state.duplicate()
		bootstrap_state.clear()
		receive(latest)

func fail_connection(reason: String) -> void:
	if session:
		disconnect_world(reason)
		return
	if socket != null:
		socket.close()
		socket = null
	pending.clear()
	bootstrap.clear()
	bootstrap_state.clear()
	remote_world = null
	connecting = false
	authenticated = false
	set_status(reason)

func apply_players(records: Array) -> bool:
	var latest := {}
	for record in records:
		latest[record.id] = record
		if record.id == player_id:
			continue
		if not avatars.has(record.id):
			var node := Node3D.new()
			var visual := Visual.new()
			var profile := Profile.new()
			profile.restore(record.profile, record.class_id)
			node.add_child(visual)
			visual.configure(record.class_id, profile)
			var label := Label3D.new()
			label.text = record.username
			label.position.y = 1.65
			label.font_size = 28
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			node.add_child(label)
			game.add_child(node)
			node.position = Vector3(record.position[0], game.world.ground_height(Vector2(record.position[0], record.position[1])), record.position[1])
			avatars[record.id] = {"node": node, "visual": visual}
	for id in avatars.keys():
		if not latest.has(id):
			avatars[id].node.queue_free()
			avatars.erase(id)
	players = latest
	return latest.has(player_id)

func movement(direction: Vector2, focused: bool) -> Vector2:
	return game.screen_movement(direction).limit_length() if session and game.state == "playing" and focused else Vector2.ZERO

func step(delta: float) -> void:
	input_clock += delta
	if input_clock >= .05:
		var direction := movement(Input.get_vector("move_left", "move_right", "move_up", "move_down"), game.get_window().has_focus())
		sequence += 1
		send({"type": "input", "seq": sequence, "direction": [direction.x, direction.y]})
		input_clock = 0
	render(delta)

func render(delta: float) -> void:
	if not session or not players.has(player_id):
		return
	if travel_target != Vector2.INF:
		travel_clock += delta
		finish_travel()
		if travel_target != Vector2.INF:
			if travel_clock > 20:
				disconnect_world("The Worldgate could not complete the route. Reconnect to continue.")
			return
	var local: Dictionary = players[player_id]
	var target := Vector2(local.position[0], local.position[1])
	var moving: bool = game.player_point.distance_to(target) > .002
	game.player_point = interpolate(game.player_point, target, delta)
	if game.world.load_around(target):
		game.world_view.sync(game.world)
	game.player_y = game.world.ground_height(game.player_point)
	game.player.position = Vector3(game.player_point.x, game.player_y, game.player_point.y)
	game.move_heading = Vector2(local.heading[0], local.heading[1])
	game.aim = game.move_heading
	game.player.rotation.y = atan2(game.aim.x, game.aim.y)
	game.player_mesh.animate(moving, true)
	game.world_view.update_visibility(game.player_point, game.player_y, game.camera_yaw)
	game.time += delta
	game.notification_time = maxf(0, game.notification_time - delta)
	game._update_camera(delta)
	for id in avatars:
		var record: Dictionary = players[id]
		var avatar: Dictionary = avatars[id]
		var point := Vector2(avatar.node.position.x, avatar.node.position.z)
		var destination := Vector2(record.position[0], record.position[1])
		avatar.visual.animate(point.distance_to(destination) > .002, true)
		point = interpolate(point, destination, delta)
		avatar.node.position = Vector3(point.x, game.world.ground_height(point), point.y)
		avatar.node.rotation.y = atan2(record.heading[0], record.heading[1])
		avatar.node.visible = point.distance_to(game.player_point) < 70 and game.world.cells.has(Vector2i(point.round()))

static func interpolate(point: Vector2, target: Vector2, delta: float) -> Vector2:
	return target if point.distance_to(target) > 2 else point.lerp(target, 1 - exp(-20 * delta))

func disconnect_world(reason: String = "Left the public world.") -> void:
	travel_target = Vector2.INF
	travel_clock = 0
	game.floating_hub.close()
	if socket != null:
		send({"type": "bye"})
		socket.close(1000, "Leaving")
		socket = null
	pending.clear()
	bootstrap.clear()
	bootstrap_state.clear()
	remote_world = null
	connecting = false
	authenticated = false
	session = false
	for avatar in avatars.values():
		avatar.node.queue_free()
	avatars.clear()
	players.clear()
	player_id = ""
	game.rotating_camera = false
	set_status(reason)
	if not offline_backup.is_empty():
		game.state = "menu"
		if game.Journey.restore(game, offline_backup):
			game.has_journey = offline_had_journey
			offline_backup.clear()
		else:
			game.has_journey = false
			reason = "Left the public world. Your offline save files are unchanged; load your journey from the main menu."
		game.player.show()
	elif OS.has_feature("web"):
		game._clear_actors()
		game.world_view.reset()
		game.world = RemoteWorld.new()
		game.world.generate(0)
		game.dungeon = game.world
		game.has_journey = false
		game.player.hide()
	game.state = "menu"
	game.menu_notice = reason
	game.interface.previous_state = ""
	lobby.hide_form()

func _exit_tree() -> void:
	if socket != null:
		socket.close()
