@tool
class_name MenuCameraDirector
extends Node3D

## Plays the child MenuCameraShot sequence in tree order, hard cut between shots.
## The menu shows the real game; the camera never sits still.

@export var active: bool = false:
	set(value):
		active = value
		if active:
			_shot_index = -1
			_advance()
@export_group("Preview (editor only)")
@export var preview_shot: int = 0:
	set(value):
		preview_shot = value
		_preview()
@export_range(0.0, 1.0) var preview_t: float = 0.0:
	set(value):
		preview_t = value
		_preview()

var _shot_index: int = -1
var _shot_time: float = 0.0
var _current: MenuCameraShot

@onready var _camera: Camera3D = $Camera3D


func _shots() -> Array[MenuCameraShot]:
	var result: Array[MenuCameraShot] = []
	for child in get_children():
		if child is MenuCameraShot and (child as MenuCameraShot).enabled:
			result.append(child)
	return result


func make_current() -> void:
	_camera.current = true


func _advance() -> void:
	var shots: Array[MenuCameraShot] = _shots()
	if shots.is_empty():
		return
	_shot_index = (_shot_index + 1) % shots.size()
	_current = shots[_shot_index]
	_shot_time = 0.0
	if _camera != null:
		_camera.fov = _current.fov


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not active or _current == null:
		return
	_shot_time += delta
	if _shot_time >= _current.duration:
		_advance()
	var t: float = clampf(_shot_time / _current.duration, 0.0, 1.0)
	_camera.global_transform = _current.sample(t)


func _preview() -> void:
	if not Engine.is_editor_hint() or _camera == null:
		return
	var shots: Array[MenuCameraShot] = _shots()
	if shots.is_empty():
		return
	var shot: MenuCameraShot = shots[clampi(preview_shot, 0, shots.size() - 1)]
	_camera.fov = shot.fov
	_camera.global_transform = shot.sample(preview_t)
