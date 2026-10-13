extends SceneTree

const Client = preload("res://scripts/online_client.gd")

func _initialize() -> void:
	assert(Client.page_endpoint("http:", "192.168.1.20", "8000") == "ws://192.168.1.20:8080/play")
	assert(Client.page_endpoint("http:", "localhost", "8000") == "ws://localhost:8080/play")
	assert(Client.page_endpoint("http:", "10.8.2.3", "8080") == "ws://10.8.2.3:8080/play")
	assert(Client.page_endpoint("https:", "game.example", "") == "wss://game.example/play")
	assert(Client.page_endpoint("https:", "game.example", "8443") == "wss://game.example:8443/play")
	for host in ["localhost", "127.0.0.1", "10.0.0.1", "10.255.255.255", "172.16.0.1", "172.31.255.255", "192.168.0.1", "192.168.255.255"]:
		assert(Client.endpoint_allowed("ws://" + host + ":8080/play"), "LAN endpoint must be allowed: " + host)
	for host in ["9.255.255.255", "11.0.0.0", "172.15.255.255", "172.32.0.0", "192.167.255.255", "192.169.0.0", "169.254.1.1", "8.8.8.8", "game.example", "10.256.1.1", "010.0.0.1", "192.168.1.2.evil.example"]:
		assert(not Client.endpoint_allowed("ws://" + host + ":8080/play"), "Public or malformed unencrypted endpoint must be denied: " + host)
	for endpoint in ["wss://game.example/play", "wss://8.8.8.8/play", "wss://[::1]:443/play"]:
		assert(Client.endpoint_allowed(endpoint))
	for endpoint in ["http://192.168.1.1:8080/play", "ws://192.168.1.1:0/play", "ws://192.168.1.1:65536/play", "ws://name:password@192.168.1.1:8080/play", "ws://192.168.1.1:8080/play#fragment"]:
		assert(not Client.endpoint_allowed(endpoint))
	print("PASS: LAN page endpoint selection, private IPv4 boundaries, public WSS and malformed URL rejection")
	quit()
