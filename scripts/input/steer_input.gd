class_name SteerInput
extends Node
## Turns every steering source into smoothed values.
## Horizontal ([member steer], -1..1): touches on the left/right half of the
## screen, the steer_left / steer_right keys and the iPad's left/right tilt.
## Vertical ([method get_pitch], -1..1): tilting the iPad's top edge toward you
## climbs, away from you dives (W / S keys too). The lever consumes its own
## touches, so holding it never steers.

signal sides_changed(left_held: bool, right_held: bool)

## Device tilt steering. Neutral angles are captured by [method calibrate_tilt].
@export var tilt_enabled: bool = true
## How strongly a roll turns. 1.0 means a full 90 degree roll gives full steer.
@export var tilt_sensitivity: float = 2.4
@export var tilt_deadzone: float = 0.06
## Up/down tilt changes the altitude.
@export var pitch_enabled: bool = true
@export var pitch_sensitivity: float = 2.2
@export var pitch_deadzone: float = 0.08
## Flip if tilting toward you should dive instead of climb.
@export var invert_pitch: bool = false
## Smoothing rate of the final value (1 - exp(-k * delta)).
@export var response: float = 11.0

## Final steer value, positive turns right.
var steer: float = 0.0
## Input is ignored while false (menus, results).
var enabled: bool = false

var _touches: Dictionary = {}
var _tilt_neutral: float = 0.0
var _pitch_neutral: float = 0.0
var _left_held: bool = false
var _right_held: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position.x
		else:
			_touches.erase(touch.index)
		_refresh_sides()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touches.has(drag.index):
			_touches[drag.index] = drag.position.x
			_refresh_sides()


func _process(delta: float) -> void:
	var target: float = 0.0
	if enabled:
		if _left_held:
			target -= 1.0
		if _right_held:
			target += 1.0
		target += Input.get_axis(&"steer_left", &"steer_right")
		target += get_tilt()
	target = clampf(target, -1.0, 1.0)
	steer = lerpf(steer, target, 1.0 - exp(-response * delta))


## Captures the current device angles as "straight and level".
func calibrate_tilt() -> void:
	_tilt_neutral = _read_roll_raw()
	_pitch_neutral = _read_pitch_raw()


## Left/right tilt contribution in [-1, 1].
func get_tilt() -> float:
	if not tilt_enabled:
		return 0.0
	return _shape((_read_roll_raw() - _tilt_neutral) * tilt_sensitivity, tilt_deadzone)


## Climb (+) or dive (-) request in [-1, 1] from up/down tilt and W/S keys.
func get_pitch() -> float:
	if not enabled:
		return 0.0
	var keys: float = Input.get_axis(&"dive", &"climb")
	if not pitch_enabled:
		return keys
	var raw: float = (_read_pitch_raw() - _pitch_neutral) * pitch_sensitivity
	if invert_pitch:
		raw = -raw
	return clampf(_shape(raw, pitch_deadzone) + keys, -1.0, 1.0)


## Drops every held touch (used when a menu opens).
func clear() -> void:
	_touches.clear()
	_refresh_sides()


func is_left_held() -> bool:
	return _left_held


func is_right_held() -> bool:
	return _right_held


func _shape(value: float, deadzone: float) -> float:
	if absf(value) < deadzone:
		return 0.0
	return clampf(value - signf(value) * deadzone, -1.0, 1.0)


func _read_roll_raw() -> float:
	var gravity: Vector3 = Input.get_gravity()
	if gravity.length_squared() < 0.01:
		return 0.0
	return gravity.x / gravity.length()


## Angle of the screen around its horizontal axis. Upright is 0; the top edge
## leaning toward the player is negative, away is positive. Returned negated so
## leaning toward the player climbs.
func _read_pitch_raw() -> float:
	var gravity: Vector3 = Input.get_gravity()
	if gravity.length_squared() < 0.01:
		return 0.0
	var n: Vector3 = gravity.normalized()
	return -atan2(-n.z, -n.y)


func _refresh_sides() -> void:
	var half: float = get_viewport().get_visible_rect().size.x * 0.5
	var left: bool = false
	var right: bool = false
	for x: Variant in _touches.values():
		if float(x) < half:
			left = true
		else:
			right = true
	if left != _left_held or right != _right_held:
		_left_held = left
		_right_held = right
		sides_changed.emit(left, right)
