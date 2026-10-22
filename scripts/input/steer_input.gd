class_name SteerInput
extends Node
## Turns every steering source into one smoothed value in [-1, 1].
## Sources: touches on the left/right half of the screen, the steer_left /
## steer_right actions (keyboard), and device tilt (accelerometer gravity).
## Read [member steer]; listen to [signal sides_changed] for touch feedback.

signal sides_changed(left_held: bool, right_held: bool)

## Device tilt steering. The neutral angle is captured by [method calibrate_tilt].
@export var tilt_enabled: bool = true
## How strongly a tilt turns. 1.0 means a full 90 degree roll gives full steer.
@export var tilt_sensitivity: float = 2.4
## Tilt below this (after sensitivity) is ignored, so a resting hand does not drift.
@export var tilt_deadzone: float = 0.06
## Smoothing rate of the final value (1 - exp(-k * delta)).
@export var response: float = 11.0

## Final steer value, positive turns right.
var steer: float = 0.0
## Input is ignored while false (menus, results).
var enabled: bool = false

var _touches: Dictionary = {}
var _tilt_neutral: float = 0.0
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


## Captures the current device roll as "straight ahead".
func calibrate_tilt() -> void:
	_tilt_neutral = _read_tilt_raw()


## Current tilt contribution in [-1, 1], 0 when tilt is off or unsupported.
func get_tilt() -> float:
	if not tilt_enabled:
		return 0.0
	var value: float = (_read_tilt_raw() - _tilt_neutral) * tilt_sensitivity
	if absf(value) < tilt_deadzone:
		return 0.0
	return clampf(value - signf(value) * tilt_deadzone, -1.0, 1.0)


## Drops every held touch (used when a menu opens).
func clear() -> void:
	_touches.clear()
	_refresh_sides()


func is_left_held() -> bool:
	return _left_held


func is_right_held() -> bool:
	return _right_held


func _read_tilt_raw() -> float:
	var gravity: Vector3 = Input.get_gravity()
	if gravity.length_squared() < 0.01:
		return 0.0
	return gravity.x / gravity.length()


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
