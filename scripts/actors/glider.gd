class_name Glider
extends CharacterBody3D
## The Mossmail hang glider. Always flying: the player only steers left or right
## (the glider banks into turns). It holds a cruise height above the rolling
## hills, rides updrafts from shelf mushrooms high into the sky, and staggers
## when it clips a giant tree. The body never rotates; [member heading] drives
## the Visual node.

signal bumped(strength: float)
signal launched

@export_group("Flight")
@export var cruise_speed: float = 13.0
@export var max_speed: float = 19.0
@export var menu_speed: float = 9.0
@export var acceleration: float = 1.5
@export var turn_rate_deg: float = 72.0
## Height kept above the ground under and ahead of the glider (metres).
@export var cruise_height: float = 22.0
@export var height_response: float = 1.4
@export var climb_rate: float = 7.0
@export var sink_rate: float = 4.5
@export var terrain_lookahead: float = 14.0
## Extra height an updraft adds, how long it holds, and how fast it fades.
@export var updraft_height: float = 22.0
@export var updraft_hold: float = 3.5
@export var updraft_decay: float = 3.0
@export var min_clearance: float = 4.0

@export_group("Bumps")
@export var bump_cooldown: float = 0.8
@export var stumble_time: float = 0.6
@export var stumble_speed_factor: float = 0.45

@export_group("Look")
@export var max_bank_deg: float = 38.0
@export var pitch_per_climb_deg: float = 2.5
@export var bob_amount: float = 0.25
@export var bob_speed: float = 1.3
@export var visual_response: float = 5.0
## Gentle circle flown on the title and results screens (-1..1).
@export var menu_steer: float = 0.28

## Replaces the downloaded glider's material. The model ships without normals,
## so an unshaded material with its own texture is the safe way to draw it.
@export var model_material: Material

@export_group("Nodes")
@export var visual_path: NodePath = ^"Visual"
@export var model_root_path: NodePath = ^"Visual/ModelPivot"
@export var trail_paths: Array[NodePath] = [^"Visual/TrailLeft", ^"Visual/TrailRight"]

## Heading in radians; 0 flies toward +Z.
var heading: float = 0.0
## Steering in [-1, 1], positive turns right. Written by the game every frame.
var steer: float = 0.0
## False on menus: the glider circles slowly on its own.
var active: bool = false
## 0..1 difficulty ramp toward [member max_speed].
var speed_bonus: float = 0.0

var _terrain: TerrainField
var _visual: Node3D
var _trails: Array[GPUParticles3D] = []
var _speed: float = 0.0
var _extra_height: float = 0.0
var _hold_left: float = 0.0
var _bump_left: float = 0.0
var _stumble_left: float = 0.0
var _bank: float = 0.0
var _pitch: float = 0.0
var _time: float = 0.0
var _visual_base: Vector3 = Vector3.ZERO
var _vertical_speed: float = 0.0


func _ready() -> void:
	rotation = Vector3.ZERO
	_visual = get_node_or_null(visual_path) as Node3D
	if _visual:
		_visual_base = _visual.position
		heading = _visual.rotation.y
	for path: NodePath in trail_paths:
		var trail := get_node_or_null(path) as GPUParticles3D
		if trail:
			_trails.append(trail)
	_speed = menu_speed
	var model_root := get_node_or_null(model_root_path)
	if model_root and model_material:
		for node: Node in model_root.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = model_material


func _physics_process(delta: float) -> void:
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group(&"terrain") as TerrainField
	_time += delta
	_bump_left = maxf(_bump_left - delta, 0.0)
	_stumble_left = maxf(_stumble_left - delta, 0.0)

	var target_speed: float = lerpf(cruise_speed, max_speed, speed_bonus) if active else menu_speed
	if _stumble_left > 0.0:
		target_speed *= stumble_speed_factor
	_speed = lerpf(_speed, target_speed, 1.0 - exp(-acceleration * delta))

	var steer_now: float = steer if active else menu_steer
	heading = wrapf(heading - steer_now * deg_to_rad(turn_rate_deg) * delta, -PI, PI)
	var forward: Vector3 = get_forward()

	if _hold_left > 0.0:
		_hold_left -= delta
	else:
		_extra_height = maxf(_extra_height - updraft_decay * delta, 0.0)
	var ground: float = get_ground_height()
	var target_y: float = ground + cruise_height + _extra_height
	_vertical_speed = clampf((target_y - global_position.y) * height_response, -sink_rate, climb_rate)

	velocity = forward * _speed + Vector3.UP * _vertical_speed
	move_and_slide()
	var floor_y: float = _ground_below() + min_clearance
	if global_position.y < floor_y:
		global_position.y = floor_y
	_check_bump(forward)
	_update_visual(delta, steer_now)


## Unit vector of the flight direction on the ground plane.
func get_forward() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


func get_speed() -> float:
	return _speed


## Vertical speed in m/s (positive while climbing).
func get_vertical_speed() -> float:
	return _vertical_speed


func is_gliding() -> bool:
	return true


func is_airborne() -> bool:
	return true


## True while an updraft is still lifting or holding the glider.
func is_in_updraft() -> bool:
	return _extra_height > 1.0


## Highest ground under or just ahead of the glider (it climbs early for hills).
func get_ground_height() -> float:
	if _terrain == null:
		return 0.0
	var p: Vector3 = global_position
	var ahead: Vector3 = p + get_forward() * terrain_lookahead
	return maxf(_terrain.height_at(p.x, p.z), _terrain.height_at(ahead.x, ahead.z))


## Height above the ground directly below.
func get_altitude() -> float:
	return global_position.y - _ground_below()


## Updraft: lifts the glider by [param extra] metres above cruise.
func launch(extra: float = -1.0) -> void:
	_extra_height = maxf(_extra_height, updraft_height if extra <= 0.0 else extra)
	_hold_left = updraft_hold
	launched.emit()


## Places the glider at cruise height over [param world_position].
func reset_to(world_position: Vector3, new_heading: float) -> void:
	var p: Vector3 = world_position
	if _terrain:
		p.y = _terrain.height_at(p.x, p.z) + cruise_height
	global_position = p
	velocity = Vector3.ZERO
	heading = new_heading
	_extra_height = 0.0
	_hold_left = 0.0
	_update_visual(1.0, 0.0)
	reset_physics_interpolation()


func _ground_below() -> float:
	if _terrain == null:
		return 0.0
	return _terrain.height_at(global_position.x, global_position.z)


func _check_bump(forward: Vector3) -> void:
	if _bump_left > 0.0:
		return
	for i: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(i)
		var normal: Vector3 = hit.get_normal()
		var flat: Vector3 = Vector3(normal.x, 0.0, normal.z)
		if flat.length() < 0.3:
			continue
		flat = flat.normalized()
		if flat.dot(-forward) < 0.35:
			continue
		var tangent: Vector3 = forward - flat * forward.dot(flat)
		if tangent.length() > 0.15:
			heading = atan2(tangent.x, tangent.z)
		else:
			heading = atan2(flat.x, flat.z)
		var strength: float = clampf(_speed / max_speed, 0.35, 1.0)
		_bump_left = bump_cooldown
		_stumble_left = stumble_time
		bumped.emit(strength)
		return


func _update_visual(delta: float, steer_now: float) -> void:
	for trail: GPUParticles3D in _trails:
		trail.emitting = true
	if _visual == null:
		return
	var wobble: float = sin(_time * 22.0) * 0.18 * (_stumble_left / stumble_time) if stumble_time > 0.0 else 0.0
	var bank_target: float = deg_to_rad(max_bank_deg) * steer_now + wobble
	var pitch_target: float = -deg_to_rad(pitch_per_climb_deg) * _vertical_speed
	var k: float = 1.0 - exp(-visual_response * delta)
	_bank = lerpf(_bank, bank_target, k)
	_pitch = lerpf(_pitch, pitch_target, k)
	_visual.rotation = Vector3(_pitch, heading, _bank)
	_visual.position = _visual_base + Vector3.UP * sin(_time * bob_speed) * bob_amount
