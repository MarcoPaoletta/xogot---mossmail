class_name PaintFx
extends Node3D
## Paint effects (GDD 12 and 15): pooled instances of the saved burst scenes. A splash is driven by the
## PaintManager's `splash` signal; an enemy pop and a bleach splash are called by the enemies and globs. Every
## burst is in the color of the paint that landed. A wasted ball is a thin, small burst so it never reads as a hit.

@export var manager_path: NodePath = ^".."
@export var burst_scene: PackedScene = preload("res://scenes/fx/paint_burst.tscn")
@export var confetti_scene: PackedScene = preload("res://scenes/fx/confetti_burst.tscn")
@export var ring_scene: PackedScene = preload("res://scenes/fx/spring_ring.tscn")
@export var pool_size: int = 18
@export var confetti_pool_size: int = 6
@export var ring_pool_size: int = 3
## The view kick of a Spring launch (degrees up, seconds to settle).
@export var spring_nudge_degrees: float = 2.2
@export var spring_nudge_time: float = 0.45
@export var bleach_material: Material = preload("res://assets/materials/paint_ball_bleach.tres")

var _manager: PaintManager
var _bursts: Array[GPUParticles3D] = []
var _confetti: Array[GPUParticles3D] = []
var _rings: Array[GPUParticles3D] = []
var _next: int = 0
var _next_confetti: int = 0
var _next_ring: int = 0


func _ready() -> void:
	add_to_group(&"paint_fx")
	_manager = get_node(manager_path) as PaintManager
	_manager.splash.connect(_on_splash)
	_manager.spring_launched.connect(_on_spring_launched)
	for i: int in pool_size:
		var burst := burst_scene.instantiate() as GPUParticles3D
		add_child(burst)
		_bursts.append(burst)
	for i: int in confetti_pool_size:
		var confetti := confetti_scene.instantiate() as GPUParticles3D
		add_child(confetti)
		_confetti.append(confetti)
	for i: int in ring_pool_size:
		var ring := ring_scene.instantiate() as GPUParticles3D
		add_child(ring)
		_rings.append(ring)


func _on_splash(point: Vector3, normal: Vector3, kind: int, wasted: bool) -> void:
	_burst(point, normal, _manager.styles[kind].ball_material, 0.3 if wasted else 1.0)


## A Spring pad launched Pip: a ring of amber droplets around the pad and a small kick of the view.
func _on_spring_launched(point: Vector3) -> void:
	var ring: GPUParticles3D = _rings[_next_ring]
	_next_ring = (_next_ring + 1) % _rings.size()
	ring.emitting = false
	ring.global_position = point + Vector3(0.0, 0.2, 0.0)
	ring.restart()
	ring.emitting = true
	var rig := get_tree().get_first_node_in_group(&"camera_rig") as CameraRig
	if rig != null:
		rig.nudge_pitch(spring_nudge_degrees, spring_nudge_time)


## An enemy popped: a big burst of its last paint and a puff of confetti.
func pop(point: Vector3, kind: int) -> void:
	var material: Material = _manager.styles[clampi(kind, 0, _manager.styles.size() - 1)].ball_material
	_burst(point, Vector3.UP, material, 1.0)
	_burst(point + Vector3(0.0, 0.2, 0.0), Vector3.UP, material, 1.0)
	var confetti: GPUParticles3D = _confetti[_next_confetti]
	_next_confetti = (_next_confetti + 1) % _confetti.size()
	confetti.emitting = false
	confetti.global_position = point
	confetti.restart()
	confetti.emitting = true


## A bleach glob splashed: a white burst.
func bleach_splash(point: Vector3, normal: Vector3 = Vector3.UP) -> void:
	_burst(point, normal, bleach_material, 1.0)


func _burst(point: Vector3, normal: Vector3, material: Material, amount_ratio: float) -> void:
	var burst: GPUParticles3D = _bursts[_next]
	_next = (_next + 1) % _bursts.size()
	burst.emitting = false
	burst.material_override = material
	burst.global_position = point + normal * 0.06
	burst.global_basis = _basis_up(normal)
	burst.amount_ratio = amount_ratio
	burst.restart()
	burst.emitting = true


## A basis whose up axis is the surface normal.
func _basis_up(normal: Vector3) -> Basis:
	if normal.dot(Vector3.UP) > 0.999:
		return Basis.IDENTITY
	if normal.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, normal))
