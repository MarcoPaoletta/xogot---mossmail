class_name SkyRing
extends Area3D
## A ring of petals hanging in the air. Glide through it to deliver sky mail.

signal collected(ring: SkyRing)

@export var visual_path: NodePath = ^"Visual"
@export var burst_path: NodePath = ^"Burst"
@export var spin_speed: float = 0.8

var _visual: Node3D
var _burst: GPUParticles3D
var _visual_scale: Vector3 = Vector3.ONE
var _taken: bool = false


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node3D
	_burst = get_node_or_null(burst_path) as GPUParticles3D
	if _visual:
		_visual_scale = _visual.scale
		_visual.scale = Vector3.ZERO
		var pop: Tween = create_tween()
		pop.tween_property(_visual, "scale", _visual_scale, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _visual and not _taken:
		_visual.rotate_object_local(Vector3.FORWARD, spin_speed * delta)


func dismiss() -> void:
	if _taken:
		return
	_taken = true
	set_deferred("monitoring", false)
	var fade: Tween = create_tween()
	if _visual:
		fade.tween_property(_visual, "scale", Vector3.ZERO, 0.35) \
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
		tween.tween_property(_visual, "scale", _visual_scale * 1.5, 0.15) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_visual, "scale", Vector3.ZERO, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.2)
	tween.tween_callback(queue_free)
