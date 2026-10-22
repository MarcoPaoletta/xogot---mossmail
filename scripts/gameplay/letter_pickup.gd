class_name LetterPickup
extends Area3D
## A leaf-letter floating in the forest. Pops in when spawned, bobs and spins,
## and bursts into petals when the courier runs through it.

signal collected(pickup: LetterPickup)

@export var visual_path: NodePath = ^"Visual"
@export var burst_path: NodePath = ^"Burst"
@export var glow_path: NodePath = ^"Glow"
@export var bob_height: float = 0.22
@export var bob_speed: float = 2.4
@export var spin_speed: float = 1.7

var _visual: Node3D
var _burst: GPUParticles3D
var _glow: OmniLight3D
var _visual_scale: Vector3 = Vector3.ONE
var _base_y: float = 0.0
var _time: float = 0.0
var _taken: bool = false


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node3D
	_burst = get_node_or_null(burst_path) as GPUParticles3D
	_glow = get_node_or_null(glow_path) as OmniLight3D
	_time = randf() * TAU
	if _visual:
		_visual_scale = _visual.scale
		_base_y = _visual.position.y
		_visual.scale = Vector3.ZERO
		var pop: Tween = create_tween()
		pop.tween_property(_visual, "scale", _visual_scale, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _visual == null or _taken:
		return
	_time += delta
	_visual.position.y = _base_y + sin(_time * bob_speed) * bob_height
	_visual.rotation.y += spin_speed * delta


## Removes the letter without a reward (task failed or cancelled).
func dismiss() -> void:
	if _taken:
		return
	_taken = true
	set_deferred("monitoring", false)
	var fade: Tween = create_tween()
	if _visual:
		fade.tween_property(_visual, "scale", Vector3.ZERO, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	fade.tween_callback(queue_free)


func _on_body_entered(body: Node3D) -> void:
	if _taken or not body is Glider:
		return
	_taken = true
	set_deferred("monitoring", false)
	collected.emit(self)
	if _burst:
		_burst.restart()
	var tween: Tween = create_tween()
	if _visual:
		tween.set_parallel(true)
		tween.tween_property(_visual, "scale", _visual_scale * 1.7, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_visual, "position:y", _visual.position.y + 1.2, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(_visual, "scale", Vector3.ZERO, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _glow:
		tween.parallel().tween_property(_glow, "light_energy", 0.0, 0.5)
	tween.chain().tween_interval(1.0)
	tween.chain().tween_callback(queue_free)
