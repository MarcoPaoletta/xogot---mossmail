class_name Glider
extends CharacterBody3D
## The Mossmail hang glider. Always flying. The player steers left/right (the
## glider banks) and sets the altitude with the lever or by tilting the iPad
## ([member altitude_input], 0..1 between min and max height above the ground).
## Golden clovers give a burst of super speed. Giant trees stagger it.
## Pickups count only when they touch the wing (Visual/Collector area).
## The body never rotates; [member heading] drives the Visual node.

signal bumped(strength: float)
signal boost_started
signal boost_ended

@export_group("Flight")
@export var cruise_speed: float = 13.0
@export var max_speed: float = 18.0
@export var menu_speed: float = 9.0
@export var acceleration: float = 1.6
@export var turn_rate_deg: float = 72.0
@export var terrain_lookahead: float = 14.0
@export var min_clearance: float = 3.0

@export_group("Altitude")
## Height above the ground at lever 0 and at lever 1.
@export var min_height: float = 6.0
@export var max_height: float = 55.0
## Lever position used on menus and at the start of a flight.
@export_range(0.0, 1.0) var default_altitude: float = 0.4
@export var height_response: float = 1.6
@export var climb_rate: float = 9.0
@export var sink_rate: float = 8.0

@export_group("Super speed")
@export var boost_multiplier: float = 1.75
@export var boost_time: float = 4.0

@export_group("Bumps")
@export var bump_cooldown: float = 0.8
@export var stumble_time: float = 0.6
@export var stumble_speed_factor: float = 0.45

@export_group("Look")
@export var max_bank_deg: float = 38.0
@export var pitch_per_climb_deg: float = 2.2
@export var bob_amount: float = 0.25
@export var bob_speed: float = 1.3
@export var visual_response: float = 5.0
## Gentle circle flown on menus (-1..1).
@export var menu_steer: float = 0.28
## Material for the downloaded glider (glider_tint.gdshader). Duplicated per
## glider so its colour can change.
@export var model_material: ShaderMaterial

@export_group("Nodes")
@export var visual_path: NodePath = ^"Visual"
@export var model_root_path: NodePath = ^"Visual/ModelPivot"
@export var collector_path: NodePath = ^"Visual/Collector"
@export var trail_paths: Array[NodePath] = [^"Visual/TrailLeft", ^"Visual/TrailRight"]
@export var boost_trail_path: NodePath = ^"Visual/BoostTrail"

## Heading in radians; 0 flies toward +Z.
var heading: float = 0.0
## Steering in [-1, 1], positive turns right. Written by the game every frame.
var steer: float = 0.0
## Lever position 0..1 (min_height..max_height above ground).
var altitude_input: float = 0.4
## False on menus: the glider circles slowly on its own.
var active: bool = false
## 0..1 difficulty ramp toward [member max_speed].
var speed_bonus: float = 0.0

var _terrain: TerrainField
var _visual: Node3D
var _material: ShaderMaterial
var _trails: Array[GPUParticles3D] = []
var _boost_trail: GPUParticles3D
var _speed: float = 0.0
var _boost_left: float = 0.0
var _bump_left: float = 0.0
var _stumble_left: float = 0.0
var _bank: float = 0.0
var _pitch: float = 0.0
var _time: float = 0.0
var _visual_base: Vector3 = Vector3.ZERO
var _vertical_speed: float = 0.0


func _ready() -> void:
	rotation = Vector3.ZERO
	altitude_input = default_altitude
	_visual = get_node_or_null(visual_path) as Node3D
	if _visual:
		_visual_base = _visual.position
		heading = _visual.rotation.y
	for path: NodePath in trail_paths:
		var trail := get_node_or_null(path) as GPUParticles3D
		if trail:
			_trails.append(trail)
	_boost_trail = get_node_or_null(boost_trail_path) as GPUParticles3D
	if _boost_trail:
		_boost_trail.emitting = false
	var collector := get_node_or_null(collector_path)
	if collector:
		collector.add_to_group(&"glider_collector")
	_speed = menu_speed
	if model_material:
		_material = model_material.duplicate() as ShaderMaterial
		var model_root := get_node_or_null(model_root_path)
		if model_root:
			for node: Node in model_root.find_children("*", "MeshInstance3D", true, false):
				(node as MeshInstance3D).material_override = _material
	set_color_index(GliderPalette.load_index())


func _physics_process(delta: float) -> void:
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group(&"terrain") as TerrainField
	_time += delta
	_bump_left = maxf(_bump_left - delta, 0.0)
	_stumble_left = maxf(_stumble_left - delta, 0.0)
	if _boost_left > 0.0:
		_boost_left -= delta
		if _boost_left <= 0.0:
			if _boost_trail:
				_boost_trail.emitting = false
			boost_ended.emit()

	var target_speed: float = lerpf(cruise_speed, max_speed, speed_bonus) if active else menu_speed
	if _boost_left > 0.0:
		target_speed *= boost_multiplier
	if _stumble_left > 0.0:
		target_speed *= stumble_speed_factor
	var accel: float = acceleration * (3.0 if _boost_left > 0.0 else 1.0)
	_speed = lerpf(_speed, target_speed, 1.0 - exp(-accel * delta))

	var steer_now: float = steer if active else menu_steer
	heading = wrapf(heading - steer_now * deg_to_rad(turn_rate_deg) * delta, -PI, PI)
	var forward: Vector3 = get_forward()

	var lever: float = altitude_input if active else default_altitude
	var target_y: float = get_ground_height() + lerpf(min_height, max_height, lever)
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


func is_boosting() -> bool:
	return _boost_left > 0.0


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


## Height above ground the lever currently asks for.
func get_target_height() -> float:
	return lerpf(min_height, max_height, altitude_input)


## Super speed for [param duration] seconds (glider default when <= 0).
func boost(duration: float = -1.0) -> void:
	_boost_left = maxf(_boost_left, boost_time if duration <= 0.0 else duration)
	if _boost_trail:
		_boost_trail.emitting = true
	boost_started.emit()


## Recolours the sail (index into GliderPalette).
func set_color_index(index: int) -> void:
	GliderPalette.apply(_material, index)


## Places the glider at the default height over [param world_position].
func reset_to(world_position: Vector3, new_heading: float) -> void:
	var p: Vector3 = world_position
	if _terrain:
		p.y = _terrain.height_at(p.x, p.z) + lerpf(min_height, max_height, default_altitude)
	global_position = p
	velocity = Vector3.ZERO
	heading = new_heading
	altitude_input = default_altitude
	_boost_left = 0.0
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
	var wobble: float = 0.0
	if stumble_time > 0.0:
		wobble = sin(_time * 22.0) * 0.18 * (_stumble_left / stumble_time)
	var bank_target: float = deg_to_rad(max_bank_deg) * steer_now + wobble
	var pitch_target: float = -deg_to_rad(pitch_per_climb_deg) * _vertical_speed
	var k: float = 1.0 - exp(-visual_response * delta)
	_bank = lerpf(_bank, bank_target, k)
	_pitch = lerpf(_pitch, pitch_target, k)
	_visual.rotation = Vector3(_pitch, heading, _bank)
	_visual.position = _visual_base + Vector3.UP * sin(_time * bob_speed) * bob_amount
