class_name CourierCamera
extends Node3D
## Chase camera rig for the glider.
## Position follows rigidly (third-person-camera reference: no positional lerp,
## no lag); smoothing lives in yaw, roll, FOV and shake. Leans with the glider's
## bank. In menu mode it orbits the glider; switching modes blends the poses.

@export var target_path: NodePath
@export var camera_path: NodePath = ^"Camera3D"

@export_group("Chase")
@export var distance: float = 9.0
@export var height: float = 3.2
@export var look_height: float = 0.5
@export var look_ahead: float = 10.0
@export var look_down: float = 3.0
@export var yaw_follow: float = 3.2
## Fraction of the glider's bank the camera leans with.
@export var roll_follow: float = 0.3

@export_group("Field of view")
@export var base_fov: float = 66.0
@export var fov_per_speed: float = 1.1
@export var boost_fov: float = 10.0
@export var fov_smoothing: float = 3.0

@export_group("Framing")
## Sideways lens shift in flight (metres). 0 keeps the glider centred.
@export var frame_offset: float = 0.0
## Sideways lens shift on menus. Negative puts the glider on the right side of
## the screen, clear of the menu cards on the left.
@export var menu_frame_offset: float = -3.4

@export_group("Shake")
## Shake offset in metres at full trauma (kept large enough to survive video).
@export var max_shake_offset: float = 0.35
@export var shake_decay: float = 1.8

@export_group("Collision")
## Physics layers that block the camera (giant trees, homes, rocks).
@export_flags_3d_physics var collision_mask: int = 1
@export var collision_margin: float = 0.5

@export_group("Menu orbit")
@export var menu_distance: float = 12.0
@export var menu_height: float = 2.5
@export var menu_orbit_speed: float = 0.1
@export var mode_blend_rate: float = 1.8

## True on the title and results screens.
var menu_mode: bool = true

var _target: Glider
var _camera: Camera3D
var _yaw: float = 0.0
var _roll: float = 0.0
var _orbit: float = 0.0
var _mode_blend: float = 1.0
var _trauma: float = 0.0
var _fov_punch: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	top_level = true
	# The rig is placed every rendered frame from the glider's interpolated
	# transform. Letting physics interpolation also smooth it between physics
	# ticks fights that placement and stutters, most visibly while climbing.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_target = get_node_or_null(target_path) as Glider
	_camera = get_node_or_null(camera_path) as Camera3D
	if _target:
		_yaw = _target.heading
		_orbit = 0.9


## Adds screen shake. 0..1, squared before use.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Kicks the FOV wider for a moment (degrees).
func punch_fov(degrees: float) -> void:
	_fov_punch += degrees


func get_camera() -> Camera3D:
	return _camera


func _process(delta: float) -> void:
	if _target == null or _camera == null:
		return
	_time += delta
	var t: Vector3 = _target.get_global_transform_interpolated().origin

	_mode_blend = lerpf(_mode_blend, 1.0 if menu_mode else 0.0, 1.0 - exp(-mode_blend_rate * delta))
	_yaw = lerp_angle(_yaw, _target.heading, 1.0 - exp(-yaw_follow * delta))

	var back: Vector3 = -Vector3(sin(_yaw), 0.0, cos(_yaw))
	var chase_pos: Vector3 = t + back * distance + Vector3.UP * height
	var ahead: Vector3 = Vector3(sin(_target.heading), 0.0, cos(_target.heading)) * look_ahead
	var chase_look: Vector3 = t + Vector3.UP * look_height + ahead - Vector3.UP * look_down

	_orbit += menu_orbit_speed * delta
	var orbit_yaw: float = _target.heading + PI * 0.75 + sin(_orbit) * 0.5
	var menu_pos: Vector3 = t + Vector3(sin(orbit_yaw), 0.0, cos(orbit_yaw)) * menu_distance + Vector3.UP * menu_height
	var menu_look: Vector3 = t

	var pos: Vector3 = chase_pos.lerp(menu_pos, _mode_blend)
	var look: Vector3 = chase_look.lerp(menu_look, _mode_blend)
	pos = _resolve_collision(t, pos)
	global_position = pos
	if pos.distance_squared_to(look) > 0.01:
		look_at(look, Vector3.UP)
	var roll_target: float = 0.0
	if not menu_mode:
		roll_target = -_target.steer * deg_to_rad(_target.max_bank_deg) * roll_follow
	_roll = lerpf(_roll, roll_target, 1.0 - exp(-3.0 * delta))
	rotate_object_local(Vector3.FORWARD, _roll)

	var fov_target: float = base_fov + maxf(_target.get_speed() - _target.cruise_speed, 0.0) * fov_per_speed
	if _target.is_boosting():
		fov_target += boost_fov
	fov_target = lerpf(fov_target, base_fov - 6.0, _mode_blend)
	_camera.fov = lerpf(_camera.fov, fov_target + _fov_punch, 1.0 - exp(-fov_smoothing * delta))
	_fov_punch = lerpf(_fov_punch, 0.0, 1.0 - exp(-5.0 * delta))

	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var shake: float = _trauma * _trauma * max_shake_offset
	var frame: float = lerpf(frame_offset, menu_frame_offset, _mode_blend)
	_camera.h_offset = frame + (sin(_time * 41.0) + sin(_time * 23.7) * 0.6) * 0.62 * shake
	_camera.v_offset = (sin(_time * 37.3 + 1.7) + sin(_time * 19.1) * 0.6) * 0.62 * shake


## Pulls the camera in front of anything between the glider and the camera.
func _resolve_collision(from: Vector3, to: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	if _target:
		query.exclude = [_target.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return to
	var point: Vector3 = hit["position"]
	var dir: Vector3 = (to - from).normalized()
	return point - dir * collision_margin
