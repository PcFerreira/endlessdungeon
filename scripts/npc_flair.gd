extends Node3D

const Catalog = preload("res://scripts/ambience_catalog.gd")
const Decor = preload("res://scripts/decor_geometry.gd")
static var catalog: Dictionary = Catalog.load_data()
var charm := Node3D.new()
var clock := 0.0
var phase := 0.0
var orbit := false
var family := ""

func configure(style: Dictionary) -> void:
	family = style.visual_family
	set_meta("visual_family", family)
	phase = style.palette * 1.1
	var color := Color(catalog.npc_palettes[style.palette])
	var recipe: Dictionary = catalog.npc_recipes[catalog.npc_roles.get(style.role, "delver_pack")]
	orbit = recipe.orbit
	var colors := {"accent": color, "shade": color.darkened(.35), "paper": Color("f5e5bb"), "slate": Color("4b6975")}
	for piece in recipe.pieces:
		_block(charm if piece.charm else self, Vector3(piece.size[0],piece.size[1],piece.size[2]), Vector3(piece.point[0],piece.point[1],piece.point[2]), colors[piece.color], piece.glow)
	add_child(charm)
	_animate()

func _block(parent: Node3D, size: Vector3, point: Vector3, color: Color, glow: bool = false) -> void:
	var mesh := Decor.node([[Vector3.ZERO, size, color]], family, "npc_charm" if parent == charm else "npc_kit")
	mesh.position = point
	if glow:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = .65
		mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

func _process(delta: float) -> void:
	clock += delta
	_animate()

func _animate() -> void:
	var angle := clock * .5 + phase
	charm.position = Vector3(cos(angle) * .42 if orbit else .38, 1.0 + sin(angle * 2) * .06, sin(angle) * .42 if orbit else .08)
	charm.rotation.y = angle
