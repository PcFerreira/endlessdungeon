# Public world client

The browser starts at the account lobby with an empty remote map. It receives nearby map cells and region structures from the server before entering the world. The browser does not generate terrain or plan towns. Native builds retain their separate offline journeys.

The first online slice supports account registration, sign-in, remembered sessions, a shared overworld, authoritative movement and nearby player avatars. Combat, loot, trade, quests, homes, interiors, dungeons and object placement require future server services. Their existing offline entry methods stop during an online session. The online account cannot write an offline journey slot.

`OnlineClient` polls a JSON WebSocket connection independently of menus. At 20 Hz it sends camera-transformed movement direction and a sequence number. It does not send a position, elapsed time, inventory, damage, world edits or save snapshot. The server supplies positions. The client interpolates them for display, including while its own menu is open. Menus and an unfocused window send zero movement.

The receive queue has a 32 MiB byte limit and capacity for 4,096 packets. Each individual message remains limited to 1 MiB. These separate limits let incoming map/state packets wait during browser rendering without the earlier 128-packet queue overflow. They remain finite; the native burst check does not establish a public concurrency or browser performance limit.

A welcome must match `config/network_manifest.json`. The client buffers the character and any early position updates until all 25 nearby chunks and their region records arrive. The gateway sends this initial window automatically; the client does not send a duplicate bootstrap request. `RemoteWorld` decodes those records and supplies geometry queries to the existing renderer. During movement, its requested window follows the newest authoritative position, rather than the interpolated display position. Valid requests that arrive after another server boundary crossing are filtered to the current server window; automatic streaming supplies the new window. Unknown cells stay unavailable until the server sends them.

The online atlas charts nearby downloaded cells and places. A site appears only when its own cell has arrived, even if surrounding region metadata is already cached. Incoming map packets refresh a stationary player's map. This display does not record offline discovery knowledge; ordinary waypoint identities and offline atlas filtering remain unchanged.

For LAN development, an HTTP page on a private IPv4 or localhost address at port 8000 automatically connects to the same machine at port 8080. For example, opening `http://192.168.1.20:8000` selects `ws://192.168.1.20:8080/play`. The static host and gateway must listen on network interfaces for another machine to reach them. HTTPS pages retain their own host/port and use `wss://.../play` through the production proxy. Native development defaults to `ws://127.0.0.1:8080/play` and can enter a LAN address in the lobby.

Plain WebSocket endpoints accept localhost, IPv4 loopback and the private ranges 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16. Public IP/domain endpoints require WSS. Listening on 0.0.0.0 allows LAN connections; it does not configure an Internet domain, TLS or router forwarding. Production Internet hosting must provide HTTPS and proxy `/play` to the gateway. `tests/test_online_endpoints.gd` checks the private-range boundaries, public-address denial, page port selection and malformed URLs.

Only the server-issued resume token and its endpoint are stored in `user://online.cfg`. Password fields clear after submission. Passwords are never saved to settings, journey slots or account configuration. A failed sign-in leaves the form open for another attempt. Leaving or losing an active connection removes peer avatars and returns to the main menu. Native clients restore the prior in-memory offline journey without writing it to disk; browsers discard the received map.

`tests/test_online_client.gd` exercises actual Game snapshots, map bootstrap through JSON, isometric steering, menu/focus input, mutation refusal, snapshot ordering, two avatar positions and offline cleanup. `tests/test_online_socket.gd` requires a running isolated gateway and exercises two real Game accounts, streamed server map data, authoritative movement, peer visibility and remembered-token resume. Browser export and actual browser acceptance remain separate checks.

Both fixtures passed against the current client. The socket test also passed with native rendering and produced `artifacts/online-lobby.png`, `online-public-world.png` and `online-world-menu.png`; all three were reviewed. Ordinary offline gameplay, store transactions and surface item custody passed their focused regressions after the session guards were added.

The packet-queue fixture exercises a real WebSocket burst of 512 frames with 32 KiB payloads, retaining more than 16 MiB without draining the peer. It failed with the earlier queue settings and passes with the current limits. This fixture is not registered in `check.sh` because it requires a separate local test server. The main client fixture is registered and includes the authoritative boundary-window check.

To reproduce the packet check, use two terminals at the repository root with the workspace's Node/Godot tools and installed `server` dependencies. Start the private burst server in the first terminal and wait for `READY online packet burst`:

```sh
.tools/node/bin/node tests/fixtures/online_packet_burst.mjs
```

Run the check in the second terminal:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_online_packet_queue.gd --quit-after 1000
```

Require the `PASS actual WebSocket burst` line and no engine errors. Stop the first command with Ctrl-C after the check. The fixture uses localhost port 18089 and creates no game accounts, database or save files. Actual Chrome bootstrap, movement and connection checks must still be repeated after a browser export; the rejected browser build is not certified by this native fixture.
