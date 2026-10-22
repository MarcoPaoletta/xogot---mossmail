class_name BounceMushroom
extends Node3D
## An updraft mushroom. A column of warm spores rises from it; flying through
## the column lifts the glider high into the sky (sky rings live up there).
## Squashes and bursts spores on every lift.

signal bounced(pad: BounceMushroom)

@export var trigger_path: NodePath = ^"Trigger"
@export var model_path: NodePath = ^"Model"
@export var spores_path: NodePath = ^"Spores"
## Extra metres of height the updraft gives (glider default when <= 0).
@export var lift_height: float = -1.0

var _trigger: Area3D
var _model: Node3D
var _spores: GPUParticles3D
var _model_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	add_to_group(&"bounce_pads")
	_trigger = get_node_or_null(trigger_path) as Area3D
	_model = get_node_or_null(model_path) as Node3D
	_spores = get_node_or_null(spores_path) as GPUParticles3D
	if _model:
		_model_scale = _model.scale
	if _trigger:
		_trigger.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var glider := body as Glider
	if glider == null:
		return
	glider.launch(lift_height)
	bounced.emit(self)
	if _spores:
		_spores.restart()
	if _model:
		var tween: Tween = create_tween()
		tween.tween_property(_model, "scale", _model_scale * Vector3(1.2, 0.6, 1.2), 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_model, "scale", _model_scale, 0.7) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
