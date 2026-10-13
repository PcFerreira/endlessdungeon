extends SceneTree

const World = preload("res://scripts/world.gd")
const Remote = preload("res://scripts/remote_world.gd")
const Codec = preload("res://scripts/map_chunk_codec.gd")
const View = preload("res://scripts/world_view.gd")
var requested: Array = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var source := World.new()
	source.generate(12345)
	source.load_around(Vector2(source.start))
	var payload := {"type":"chunks","revision":"test","chunks":[],"regions":[]}
	for coordinate in source.chunks:
		payload.chunks.append({"coordinate":[coordinate.x,coordinate.y],"cells":Codec.encode(source.chunks[coordinate].cells)})
	for region in source.regions.values():
		payload.regions.append(Codec.encode(region))
	var wire = JSON.parse_string(JSON.stringify(payload,"",false,true))
	var remote := Remote.new()
	remote.content_revision = "test"
	remote.generate(12345)
	assert(remote.chunks.is_empty() and remote.regions.is_empty() and remote.cells.is_empty())
	assert(not remote.cell_info(Vector2i(-5000,2000)).walkable and remote.regions.is_empty(), "Unknown online terrain must never invoke the procedural generator")
	remote.chunks_requested.connect(func(coordinates): requested.append_array(coordinates))
	remote.load_around(Vector2(source.start))
	assert(requested.size() == 25 and not remote.ready_around(Vector2(source.start)))
	assert(remote.ingest(wire) and remote.ready_around(Vector2(source.start)))
	remote.load_around(Vector2(source.start))
	assert(remote.cells == source.cells and remote.tiles == source.tiles, "Serialized server cells must preserve exact collision, height and visual descriptors")
	assert(remote.region_at(source.start) == source.region_at(source.start), "Server city, road, house, lot, magic and source IDs must round-trip exactly: " + difference(remote.region_at(source.start),source.region_at(source.start)))
	for cell in source.cells:
		assert(remote.walkable(Vector2(cell)) == source.walkable(Vector2(cell)))
	var before := remote.cells.duplicate(true)
	var invalid: Dictionary = wire.duplicate(true)
	invalid.chunks[0].cells = {"@":"Object","v":"arbitrary"}
	assert(not remote.ingest(invalid) and remote.cells == before, "Invalid chunk messages must leave the last complete map intact")
	invalid = wire.duplicate(true)
	invalid.revision = "wrong"
	assert(not remote.ingest(invalid) and remote.cells == before)
	assert(not Codec.decode({"@":"v2i","v":[1.5,2]}).ok)
	assert(not Codec.decode({"@":"map","v":[["same",1],["same",2]]}).ok)
	var view := View.new()
	root.add_child(view)
	view.sync(remote)
	assert(view.chunk_nodes.size() == 25, "Actual production terrain/city renderer must consume only server records")
	remote.load_around(Vector2(source.start) + Vector2(16,0))
	assert(remote.chunks.size() == 20 and requested.size() == 30 and not remote.ready_around(Vector2(source.start) + Vector2(16,0)), "Moving across a chunk edge must evict distant cells and request only missing chunks")
	assert(remote.cells.size() == 20 * 256)
	view.queue_free()
	await process_frame
	var ecology_source := World.new()
	ecology_source.generate(12345,6)
	var coordinate := ecology_source.chunk_at(Vector2(ecology_source.start))
	var ecology_cells: Dictionary = ecology_source._build_chunk(coordinate).cells
	var ecology_payload := {"type":"chunks","revision":"ecology","chunks":[{"coordinate":[coordinate.x,coordinate.y],"cells":Codec.encode(ecology_cells)}],"regions":[Codec.encode(ecology_source.region_at(ecology_source.start))]}
	var ecology_remote := Remote.new()
	ecology_remote.content_revision = "ecology"
	ecology_remote.generate(12345,6)
	assert(ecology_remote.ingest(JSON.parse_string(JSON.stringify(ecology_payload))))
	assert(ecology_remote.cells == ecology_cells, "Edition6 ecology IDs and transitions must come unchanged from the authority")
	for cell in ecology_cells:
		var info: Dictionary = ecology_cells[cell]
		var expected := {"biome":info.biome,"biome_id":info.biome_id,"biome_secondary":info.biome_secondary,"biome_blend":info.biome_blend}
		if info.has("biome_mix"):
			expected.biome_mix = info.biome_mix
		assert(ecology_remote.biome_at(cell) == expected, "Public biome queries must preserve received ecology and junction mixtures rather than sample client noise")
	assert(ecology_remote.biome_at(Vector2i(-500000,500000)).is_empty(), "Unreceived ecology cannot be inferred from the server seed")
	var corrupted := ecology_cells.duplicate(true)
	corrupted[corrupted.keys()[0]].biome_id = "unsupported_ecology"
	ecology_payload.chunks[0].cells = Codec.encode(corrupted)
	assert(not ecology_remote.ingest(JSON.parse_string(JSON.stringify(ecology_payload))) and ecology_remote.cells == ecology_cells, "Unknown ecology IDs must atomically reject without invoking local generation")
	ecology_payload.chunks[0].cells = Codec.encode(ecology_cells)
	var bad_region: Dictionary = ecology_source.region_at(ecology_source.start).duplicate(true)
	assert(not bad_region.city.is_empty())
	bad_region.city.biome_secondary = "unsupported_ecology"
	ecology_payload.regions = [Codec.encode(bad_region)]
	assert(not ecology_remote.ingest(JSON.parse_string(JSON.stringify(ecology_payload))))
	print("PASS: real map chunk JSON/variant round-trip, exact production rendering/collision/source records, no client terrain generation, atomic invalid-message rejection and bounded window streaming")
	quit()

func difference(left, right, path: String = "region") -> String:
	if typeof(left) != typeof(right):
		return "%s type %s / %s" % [path,type_string(typeof(left)),type_string(typeof(right))]
	if left is Dictionary:
		for key in right:
			if not left.has(key):
				return path + " missing " + str(key)
			if left[key] != right[key]:
				return difference(left[key],right[key],path + "." + str(key))
	elif left is Array:
		if left.size() != right.size():
			return path + " array size"
		for index in range(right.size()):
			if left[index] != right[index]:
				return difference(left[index],right[index],path + "[%s]" % index)
	return "%s: %s / %s" % [path,str(left).left(180),str(right).left(180)]
