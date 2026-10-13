extends Node3D
## Standalone example controls. No autoloads or InputMap setup required.

var _camera: Camera3D
var _home_transform: Transform3D
var _home_size: float
const GATE_GROUP := "vmf_gate_hinges"
const LID_GROUP := "vmf_lid_hinges"
const GATE_OPEN_ANGLE := -15.0
const LID_OPEN_ANGLE := -68.0
const ZOOM_FACTOR := 0.9
const MIN_CAMERA_SIZE := 1.2
const MAX_CAMERA_SIZE := 32.0
const PAN_PIXELS_PER_UNIT := 900.0
const CLIPS: Array[AudioStream] = [
	preload("res://addons/voxel_micro_farm/audio/SFX_VMF_Click.wav"),
	preload("res://addons/voxel_micro_farm/audio/SFX_VMF_Harvest.wav"),
	preload("res://addons/voxel_micro_farm/audio/SFX_VMF_Seed.wav"),
	preload("res://addons/voxel_micro_farm/audio/SFX_VMF_Ship.wav"),
	preload("res://addons/voxel_micro_farm/audio/SFX_VMF_Till.wav"),
	preload("res://addons/voxel_micro_farm/audio/SFX_VMF_Water.wav"),
]

@export var start_hinges_open := false
@export_range(-40.0, 0.0) var preview_volume_db := -8.0

var _opened := false
var _audio_index := 0
var _player: AudioStreamPlayer
var _gate_hinges: Array[Node3D] = []
var _lid_hinges: Array[Node3D] = []

func _ready() -> void:
	_camera = $Camera3D
	_home_transform = _camera.transform
	_home_size = _camera.size
	_player = AudioStreamPlayer.new()
	_player.volume_db = preview_volume_db
	add_child(_player)
	for node in get_tree().get_nodes_in_group(GATE_GROUP):
		if node is Node3D and is_ancestor_of(node):
			_gate_hinges.append(node)
	for node in get_tree().get_nodes_in_group(LID_GROUP):
		if node is Node3D and is_ancestor_of(node):
			_lid_hinges.append(node)
	_opened = start_hinges_open
	_apply_hinges()

func _apply_hinges() -> void:
	for hinge in _gate_hinges:
		hinge.rotation.y = deg_to_rad(GATE_OPEN_ANGLE if _opened else 0.0)
	for hinge in _lid_hinges:
		hinge.rotation.x = deg_to_rad(LID_OPEN_ANGLE if _opened else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.size = maxf(MIN_CAMERA_SIZE, _camera.size * ZOOM_FACTOR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.size = minf(MAX_CAMERA_SIZE, _camera.size / ZOOM_FACTOR)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_camera.position += (-_camera.basis.x * event.relative.x + _camera.basis.y * event.relative.y) * _camera.size / PAN_PIXELS_PER_UNIT
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_camera.transform = _home_transform
				_camera.size = _home_size
			KEY_1:
				get_tree().change_scene_to_file("res://addons/voxel_micro_farm/examples/farm_showcase.tscn")
			KEY_2:
				get_tree().change_scene_to_file("res://addons/voxel_micro_farm/examples/asset_overview.tscn")
			KEY_H:
				_opened = not _opened
				_apply_hinges()
			KEY_SPACE:
				_player.stream = CLIPS[_audio_index % CLIPS.size()]
				_player.play()
				_audio_index += 1
