class_name PlayerCamera
extends Node3D

## SpringArm follow rig. Soft lag, trauma shake, punch, precision aim, fall detach.

@export var player_path: NodePath = ^".."
@export var follow_height: float = 1.5
@export var normal_length: float = 5.2
@export var aim_length: float = 3.4
@export var normal_fov: float = 75.0
@export var aim_fov: float = 62.0

@export var pitch_min: float = -60.0
@export var pitch_max: float = 45.0

var yaw: float = 0.0
var pitch: float = -12.0
var detached: bool = false
var _trauma: float = 0.0
var _punch: float = 0.0
var _fall_bias: float = 0.0
var _noise_t: float = 0.0

@onready var _player: Player = get_node(player_path)
@onready var _spring: SpringArm3D = $SpringArm3D
@onready var _cam: Camera3D = $SpringArm3D/ArmEnd/Camera3D

const SHOULDER_OFFSET: Vector3 = Vector3(0.55, 0.3, 0.0)


func _ready() -> void:
	top_level = true
	_noise_t = randf() * 100.0
	EventBus.camera_trauma.connect(add_trauma)


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func aim_origin() -> Vector3:
	return _cam.global_position


func aim_direction() -> Vector3:
	return -_cam.global_basis.z


func camera() -> Camera3D:
	return _cam


func add_trauma(amount: float) -> void:
	if SettingsManager.reduce_shake:
		amount *= 0.35
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func punch(amount: float) -> void:
	_punch = clampf(_punch + amount, -0.5, 0.5)


func reset_behind(spawn: Transform3D) -> void:
	detached = false
	yaw = spawn.basis.get_euler().y + PI
	pitch = -12.0
	global_position = spawn.origin + Vector3(0.0, follow_height, 0.0)


func detach_and_watch() -> void:
	detached = true


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or detached:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		# Same angular rate on both axes: free look, Fortnite-style.
		var sens_deg: float = 0.1375 * SettingsManager.mouse_sensitivity
		yaw -= deg_to_rad(motion.relative.x * sens_deg)
		var invert: float = -1.0 if SettingsManager.invert_y else 1.0
		pitch = clampf(pitch - motion.relative.y * sens_deg * invert, pitch_min, pitch_max)


func _process(delta: float) -> void:
	if detached:
		_watch_fall(delta)
		return
	# Gamepad look
	var look: Vector2 = Vector2(
		Input.get_action_strength("look_right") - Input.get_action_strength("look_left"),
		Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
	)
	if look.length_squared() > 0.01:
		var gp_sens: float = 2.6 * SettingsManager.gamepad_sensitivity
		yaw -= look.x * gp_sens * delta
		var invert: float = -1.0 if SettingsManager.invert_y else 1.0
		pitch = clampf(pitch - look.y * gp_sens * 80.0 * invert * delta, pitch_min, pitch_max)

	# Follow the INTERPOLATED body transform so the 60 Hz physics step never
	# stair-steps into the render-rate camera.
	# The follow is FULLY RIGID on all axes. Any exponential lerp trails the
	# body by speed/k metres (rubber-band lag); a clamped vertical ease rides
	# at the clamp bound during fast falls, which reads as lag too. Softness
	# belongs in rotation, FOV and shake - never in the follow position.
	# See docs/third-person-camera.md.
	var vel: Vector3 = _player.velocity
	var body_pos: Vector3 = _player.get_global_transform_interpolated().origin
	global_position = body_pos + Vector3(0.0, follow_height, 0.0)

	# Falling bias: look down so the player sees the landing
	var bias_target: float = 0.0
	if vel.y < -9.0:
		bias_target = clampf((-vel.y - 9.0) * 1.4, 0.0, 18.0)
	var bias_k: float = 1.0 - exp(-4.0 * delta)
	_fall_bias = lerpf(_fall_bias, bias_target, bias_k)

	rotation = Vector3(deg_to_rad(pitch - _fall_bias), yaw, 0.0)

	# Precision aim: shorter spring, tighter fov, eased
	var aim_k: float = 1.0 - exp(-10.0 * delta)
	var want_len: float = aim_length if _player.aiming else normal_length
	var want_fov: float = aim_fov if _player.aiming else normal_fov
	_spring.spring_length = lerpf(_spring.spring_length, want_len, aim_k)
	_cam.fov = lerpf(_cam.fov, want_fov, aim_k)

	# Trauma shake: shake = trauma^2, decays
	_trauma = maxf(0.0, _trauma - 1.6 * delta)
	var shake: float = _trauma * _trauma
	_noise_t += delta * 30.0
	if shake > 0.0001:
		var sx: float = sin(_noise_t * 1.13) * cos(_noise_t * 0.71)
		var sy: float = sin(_noise_t * 0.97 + 4.0) * cos(_noise_t * 1.31)
		var sr: float = sin(_noise_t * 1.51 + 9.0)
		_cam.rotation = Vector3(sx * shake * 0.045, sy * shake * 0.045, sr * shake * 0.02)
	else:
		_cam.rotation = Vector3.ZERO

	# Punch: eased return
	_punch = lerpf(_punch, 0.0, 1.0 - exp(-9.0 * delta))
	_cam.position = SHOULDER_OFFSET + Vector3(0.0, 0.0, _punch)


func _watch_fall(delta: float) -> void:
	# Hang in the air and watch the painter tumble into the haze.
	var target: Vector3 = _player.global_position
	var forward: Vector3 = (target - global_position).normalized()
	if forward.length_squared() < 0.001:
		return
	var up: Vector3 = Vector3.UP
	if absf(forward.dot(up)) > 0.92:
		up = Vector3.FORWARD
	var current: Basis = global_basis.orthonormalized()
	var look: Transform3D = global_transform.looking_at(target, up)
	var k: float = 1.0 - exp(-5.0 * delta)
	global_basis = current.slerp(look.basis.orthonormalized(), k).orthonormalized()
	var fov_k: float = 1.0 - exp(-0.8 * delta)
	_cam.fov = lerpf(_cam.fov, 55.0, fov_k)
