class_name Player
extends CharacterBody3D

## The painter. Tight, forgiving, expressive. Knockback never steals control.

signal state_entered(state: int)
signal jet_toggled(active: bool)
signal aim_toggled(aiming: bool)

enum State { IDLE, RUN, JUMP, FALL, JET, DASH, KNOCKED, EXTRACTING, DRY, DEAD }

@export var profile: MovementProfile
@export var model_path: NodePath = ^"PainterModel"
@export var camera_path: NodePath = ^"CameraPivot"

var state: State = State.IDLE
var move_input: Vector2 = Vector2.ZERO
var aiming: bool = false
var input_enabled: bool = true
var splash_guard_available: bool = false
var slick_areas: int = 0

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jet_budget: float = 0.0
var _jet_active: bool = false
var _dash_available: bool = true
var _dash_time: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _knocked_time: float = 0.0
var _knocked_total: float = 0.25
var _was_on_floor: bool = true
var _prev_vy: float = 0.0
var _last_wish: Vector3 = Vector3.ZERO
## The model's yaw is OWNED here and written as a full euler triple every
## frame. Never read back from the basis: euler decomposition flips
## representation by quadrant and a read-modify loop settles 90 deg off.
var _model_yaw: float = 0.0
var _footstep_accum: float = 0.0
var _spawn_transform: Transform3D
var _extract_lock: bool = false

@onready var _model: Node3D = get_node(model_path)
@onready var _camera: PlayerCamera = get_node(camera_path)
@onready var _jet_particles: GPUParticles3D = $JetParticles
@onready var _jet_audio: AudioStreamPlayer3D = $JetAudio


func _ready() -> void:
	add_to_group("player")
	if profile == null:
		profile = MovementProfile.new()
	_spawn_transform = global_transform
	_jet_budget = profile.jet_budget
	jet_toggled.connect(_on_jet_toggled)
	PaintEconomy.dried_out.connect(enter_dry)
	EventBus.player_landed.connect(_on_landed_squash)
	EventBus.player_jumped.connect(_on_jump_stretch)
	if ResourceLoader.exists("res://audio/sfx/jet_loop.wav"):
		var jet_stream: AudioStream = load("res://audio/sfx/jet_loop.wav")
		if jet_stream is AudioStreamWAV:
			var wav: AudioStreamWAV = jet_stream
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = wav.data.size() / 2
		_jet_audio.stream = jet_stream


func _on_jet_toggled(active: bool) -> void:
	_jet_particles.emitting = active
	if active:
		_jet_audio.play()
	else:
		_jet_audio.stop()


var _squash_tween: Tween


func _on_landed_squash(fall_speed: float, _pos: Vector3) -> void:
	var amount: float = clampf(0.1 + fall_speed * 0.012, 0.1, 0.32)
	_play_squash(Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount))


func _on_jump_stretch() -> void:
	_play_squash(Vector3(0.88, 1.16, 0.88))


func _play_squash(target: Vector3) -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_model.scale = target
	_squash_tween = create_tween()
	_squash_tween.tween_property(_model, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func camera_rig() -> PlayerCamera:
	return _camera


func reset_for_run(spawn: Transform3D) -> void:
	# The physics body NEVER rotates: facing lives on the model. Copying the
	# spawn basis onto the body would offset every world-space facing we set.
	global_position = spawn.origin
	rotation = Vector3.ZERO
	reset_physics_interpolation()
	_spawn_transform = spawn
	_model_yaw = spawn.basis.get_euler().y
	_model.rotation = Vector3(0.0, _model_yaw, 0.0)
	velocity = Vector3.ZERO
	input_enabled = true
	_extract_lock = false
	_jet_budget = profile.jet_budget
	_dash_available = true
	splash_guard_available = PaintEconomy.has_powerup(&"splash_guard")
	_set_state(State.IDLE)
	_camera.reset_behind(spawn)


func _physics_process(delta: float) -> void:
	var dt: float = delta
	_coyote = maxf(0.0, _coyote - dt)
	_jump_buffer = maxf(0.0, _jump_buffer - dt)

	_read_input()

	match state:
		State.DASH:
			_physics_dash(dt)
		State.EXTRACTING:
			_physics_extracting(dt)
		State.DRY, State.DEAD:
			_physics_limp(dt)
		_:
			_physics_default(dt)

	_was_on_floor = is_on_floor()
	_prev_vy = velocity.y


func _read_input() -> void:
	if not input_enabled or state == State.DRY or state == State.DEAD or state == State.EXTRACTING:
		move_input = Vector2.ZERO
		if aiming:
			aiming = false
			aim_toggled.emit(false)
		return
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var was_aiming: bool = aiming
	aiming = Input.is_action_pressed("aim")
	if aiming != was_aiming:
		aim_toggled.emit(aiming)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = profile.jump_buffer_time
	if Input.is_action_just_released("jump") and velocity.y > 0.0 and (state == State.JUMP):
		velocity.y *= profile.jump_cut_factor
	if Input.is_action_just_pressed("dash"):
		_try_dash()


func _wish_dir() -> Vector3:
	if move_input.length_squared() < 0.0001:
		return Vector3.ZERO
	var cam_basis: Basis = _camera.yaw_basis()
	var dir: Vector3 = cam_basis * Vector3(move_input.x, 0.0, move_input.y)
	dir.y = 0.0
	return dir.normalized() * minf(1.0, move_input.length())


func _physics_default(dt: float) -> void:
	var grounded: bool = is_on_floor()
	if grounded:
		_coyote = profile.coyote_time
		_jet_budget = profile.jet_budget
		_dash_available = true

	# --- Jump ---
	if _jump_buffer > 0.0 and (grounded or _coyote > 0.0) and state != State.KNOCKED:
		velocity.y = profile.jump_velocity()
		_jump_buffer = 0.0
		_coyote = 0.0
		grounded = false
		EventBus.player_jumped.emit()
		_set_state(State.JUMP)

	# --- Gravity + paint jet ---
	var jet_wanted: bool = (
		not grounded and input_enabled
		and Input.is_action_pressed("jump")
		and velocity.y < 2.0
		and _jet_budget > 0.0
		and PaintEconomy.meter > 0.0
		and state != State.KNOCKED
	)
	if jet_wanted:
		if not _jet_active:
			_jet_active = true
			jet_toggled.emit(true)
		_jet_budget = maxf(0.0, _jet_budget - dt)
		PaintEconomy.try_spend(profile.jet_cost_per_second * dt)
		velocity.y = move_toward(velocity.y, -profile.jet_fall_speed, profile.jet_up_accel * dt)
	else:
		if _jet_active:
			_jet_active = false
			jet_toggled.emit(false)
		var gravity: float = profile.rise_gravity() if velocity.y > 0.0 else profile.fall_gravity()
		velocity.y = maxf(velocity.y - gravity * dt, -profile.max_fall_speed)

	# --- Horizontal ---
	var wish: Vector3 = _wish_dir()
	_last_wish = wish
	var speed_scale: float = PaintEconomy.move_speed_scale()
	if aiming and grounded:
		speed_scale *= profile.aim_move_mult
	var target: Vector3 = wish * profile.run_speed * speed_scale
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	var authority: float = 1.0
	if state == State.KNOCKED:
		_knocked_time += dt
		var recover_start: float = _knocked_total
		if _knocked_time < recover_start:
			authority = profile.knocked_authority
		else:
			var t: float = clampf((_knocked_time - recover_start) / profile.knocked_recover_time, 0.0, 1.0)
			authority = lerpf(profile.knocked_authority, 1.0, t)
			if t >= 1.0:
				_set_state(State.FALL if not grounded else State.IDLE)

	var accel: float
	if wish.length_squared() > 0.001:
		var turn: bool = horizontal.length() > 0.5 and horizontal.normalized().dot(wish.normalized()) < -0.1
		accel = profile.turn_accel if turn else profile.run_accel
	else:
		accel = profile.run_decel
	if not grounded:
		accel *= profile.air_control
	elif _on_slick():
		accel *= 0.16 if wish.length_squared() < 0.001 else 0.45
	accel *= authority

	horizontal = horizontal.move_toward(target, accel * dt)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	# --- Landing ---
	if is_on_floor() and not _was_on_floor:
		EventBus.player_landed.emit(absf(_prev_vy), global_position)
		if state == State.KNOCKED and _knocked_time >= _knocked_total:
			_set_state(State.IDLE)

	# --- State resolution ---
	if state != State.KNOCKED:
		if is_on_floor():
			_set_state(State.RUN if horizontal.length() > 0.6 else State.IDLE)
		elif _jet_active:
			_set_state(State.JET)
		elif velocity.y > 0.5:
			_set_state(State.JUMP)
		else:
			_set_state(State.FALL)

	_face_movement(dt)
	_footsteps(dt, horizontal)


func _physics_dash(dt: float) -> void:
	_dash_time -= dt
	var dash_speed: float = profile.dash_distance / profile.dash_duration
	velocity = _dash_dir * dash_speed
	velocity.y = 0.0
	move_and_slide()
	_face_movement(dt)
	if _dash_time <= 0.0:
		velocity = _dash_dir * profile.run_speed
		_set_state(State.FALL if not is_on_floor() else State.RUN)


func _physics_extracting(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, profile.run_decel * dt)
	velocity.z = move_toward(velocity.z, 0.0, profile.run_decel * dt)
	if not is_on_floor():
		velocity.y -= profile.fall_gravity() * dt
	move_and_slide()


func _physics_limp(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, profile.run_decel * 0.4 * dt)
	velocity.z = move_toward(velocity.z, 0.0, profile.run_decel * 0.4 * dt)
	velocity.y = maxf(velocity.y - profile.fall_gravity() * dt, -profile.max_fall_speed)
	move_and_slide()


func _try_dash() -> void:
	if not PaintEconomy.has_powerup(&"thinner"):
		return
	if is_on_floor() or not _dash_available or state == State.DASH or state == State.KNOCKED:
		return
	if not PaintEconomy.try_spend(profile.dash_cost):
		return
	var wish: Vector3 = _wish_dir()
	_dash_dir = wish.normalized() if wish.length_squared() > 0.001 else -_model.global_basis.z
	_dash_dir.y = 0.0
	_dash_dir = _dash_dir.normalized()
	_dash_available = false
	_dash_time = profile.dash_duration
	_set_state(State.DASH)
	AudioDirector.play_3d(&"dash", global_position, 1.0, 0.0, 0.06)


## Yaw the body needs while aiming so the BARREL lines up with the camera
## forward. Measured from the aim pose: spine twist (barrel - hips) = +102.6 deg.
@export var aim_yaw_offset_deg: float = -102.6


func _face_movement(dt: float) -> void:
	var target_yaw: float
	if (aiming or Input.is_action_pressed("fire")) and input_enabled and state != State.EXTRACTING and state != State.DRY:
		target_yaw = _camera.yaw + PI + deg_to_rad(aim_yaw_offset_deg)
	elif state == State.EXTRACTING:
		target_yaw = _camera.yaw + PI
	elif _last_wish.length_squared() > 0.01 and state != State.KNOCKED:
		# Face the steering input, not the velocity: velocity trails the stick
		# by the whole acceleration ramp, which reads as running sideways.
		target_yaw = atan2(_last_wish.x, _last_wish.z)
	else:
		var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if horizontal.length() < 0.8:
			return
		target_yaw = atan2(horizontal.x, horizontal.z)
	var k: float = 1.0 - exp(-16.0 * dt)
	_model_yaw = lerp_angle(_model_yaw, target_yaw, k)
	_model.rotation = Vector3(0.0, _model_yaw, 0.0)


func _footsteps(dt: float, horizontal: Vector3) -> void:
	if not is_on_floor() or horizontal.length() < 1.0:
		_footstep_accum = 0.0
		return
	_footstep_accum += horizontal.length() * dt
	if _footstep_accum >= 2.6:
		_footstep_accum = 0.0
		var sfx: StringName = &"footstep_wet" if _on_paint() else &"footstep"
		AudioDirector.play_3d(sfx, global_position, 1.0, -12.0, 0.12)


func _on_slick() -> bool:
	if slick_areas > 0:
		return true
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("slick"):
			return true
	return false


func _on_paint() -> bool:
	for i in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group("painted"):
			return true
	return false


func apply_knockback(info: KnockbackInfo) -> void:
	if state == State.DRY or state == State.DEAD or state == State.EXTRACTING:
		return
	if splash_guard_available:
		splash_guard_available = false
		AudioDirector.play_3d(&"guard_pop", global_position, 1.0, 2.0)
		EventBus.camera_trauma.emit(0.15)
		return
	var scaled: Vector3 = info.impulse * PaintEconomy.knockback_scale()
	velocity += scaled
	_knocked_time = 0.0
	_knocked_total = info.stagger_duration
	_set_state(State.KNOCKED)
	EventBus.player_knocked.emit(info)
	EventBus.hit_stop_requested.emit(info.hit_stop_frames)
	EventBus.camera_trauma.emit(0.45)
	AudioDirector.play_3d(&"knockback", global_position, 1.0, 2.0, 0.08)


func begin_extracting() -> void:
	if state == State.DRY or state == State.DEAD:
		return
	_set_state(State.EXTRACTING)


func cancel_extracting() -> void:
	if state == State.EXTRACTING:
		_set_state(State.IDLE)


func enter_dry() -> void:
	_set_state(State.DRY)
	input_enabled = false


func enter_fall_death() -> void:
	if state == State.DEAD:
		return
	_set_state(State.DEAD)
	input_enabled = false
	_camera.detach_and_watch()


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_entered.emit(state)
