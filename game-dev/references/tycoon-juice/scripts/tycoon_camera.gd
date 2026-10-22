class_name TycoonCamera
extends Node3D
## Fixed angle perspective camera rig for a tycoon (never orthographic). The
## Camera3D is a child of this rig with its pitch and distance authored in the
## scene; the rig only translates, so the angle never changes and the world
## always reads the same.
##
## Three jobs: follow the player with a soft lag, cut away to show what a
## purchase unlocked and come back (the "focus beat"), and add small
## perceptual shake and FOV kicks.

@export var target: Node3D
@export var camera: Camera3D
@export var follow_k: float = 5.0
@export var base_fov: float = 38.0
@export var shake_max_offset: float = 0.3
@export var shake_decay: float = 1.6

var _focus_point: Vector3 = Vector3.ZERO
var _focus_weight: float = 0.0
var _trauma: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float = 0.0
var _fov_tween: Tween = null


func _ready() -> void:
	_noise.frequency = 1.0
	if camera != null:
		camera.fov = base_fov
	if target != null:
		global_position = target.global_position


func _process(delta: float) -> void:
	_time += delta
	if target != null:
		var goal: Vector3 = target.global_position.lerp(_focus_point, _focus_weight)
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_k * delta))
	if camera != null:
		_trauma = maxf(_trauma - shake_decay * delta, 0.0)
		var amount: float = _trauma * _trauma
		camera.h_offset = _noise.get_noise_2d(_time * 55.0, 0.0) * shake_max_offset * amount * 3.0
		camera.v_offset = _noise.get_noise_2d(0.0, _time * 55.0) * shake_max_offset * amount * 3.0


## Cuts away to `point`, holds, returns to the player. Used when a pad unlocks
## something the player cannot see from where they stand.
func focus_beat(point: Vector3, travel: float = 0.55, hold: float = 0.9, back: float = 0.7) -> void:
	_focus_point = point
	var tween: Tween = create_tween()
	tween.tween_property(self, "_focus_weight", 1.0, travel).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(hold)
	tween.tween_property(self, "_focus_weight", 0.0, back).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Small shake for a chop, a purchase, a landing. 0.25 is a tick, 0.6 a boom.
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## FOV widens for a moment (speed upgrade, big reveal) then settles.
func fov_kick(extra_degrees: float = 4.0, time: float = 0.4) -> void:
	if camera == null:
		return
	if _fov_tween != null and _fov_tween.is_valid():
		_fov_tween.kill()
	camera.fov = base_fov + extra_degrees
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", base_fov, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
