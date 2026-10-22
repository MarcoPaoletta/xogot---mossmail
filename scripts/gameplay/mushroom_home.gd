class_name MushroomHome
extends Node3D
## A forest-folk home. The delivery director marks one as the target: a beacon
## of rising light shows it from afar. Arriving fires [signal courier_arrived];
## the home then squashes, glows and throws petal confetti.

signal courier_arrived(home: MushroomHome)

@export var zone_path: NodePath = ^"DeliveryZone"
@export var beacon_path: NodePath = ^"Beacon"
@export var beacon_light_path: NodePath = ^"Beacon/BeaconLight"
@export var model_path: NodePath = ^"Model"
@export var confetti_path: NodePath = ^"Confetti"
@export var window_light_path: NodePath = ^"WindowLight"
@export var beacon_energy: float = 6.0
@export var target_height: float = 3.0

var targeted: bool = false

var _zone: Area3D
var _beacon: Node3D
var _beacon_light: OmniLight3D
var _model: Node3D
var _confetti: GPUParticles3D
var _window_light: OmniLight3D
var _model_scale: Vector3 = Vector3.ONE
var _window_energy: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"homes")
	_zone = get_node_or_null(zone_path) as Area3D
	_beacon = get_node_or_null(beacon_path) as Node3D
	_beacon_light = get_node_or_null(beacon_light_path) as OmniLight3D
	_model = get_node_or_null(model_path) as Node3D
	_confetti = get_node_or_null(confetti_path) as GPUParticles3D
	_window_light = get_node_or_null(window_light_path) as OmniLight3D
	if _model:
		_model_scale = _model.scale
	if _window_light:
		_window_energy = _window_light.light_energy
	if _beacon:
		_beacon.visible = false
	if _zone:
		_zone.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not targeted or _beacon_light == null:
		return
	_time += delta
	_beacon_light.light_energy = beacon_energy * (0.75 + 0.25 * sin(_time * 4.0))


## World point the compass should aim at.
func get_target_point() -> Vector3:
	return global_position + Vector3.UP * target_height


## Shows or hides the beacon, with a fade instead of a snap.
func set_targeted(on: bool) -> void:
	targeted = on
	if _beacon == null:
		return
	var tween: Tween = create_tween()
	if on:
		_beacon.visible = true
		_beacon.scale = Vector3(0.2, 0.2, 0.2)
		tween.tween_property(_beacon, "scale", Vector3.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(_beacon, "scale", Vector3(0.05, 0.05, 0.05), 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_beacon.hide)


## Delivery celebration: squash and stretch, window flare, confetti burst.
func celebrate() -> void:
	if _confetti:
		_confetti.restart()
	if _model:
		var squash: Tween = create_tween()
		squash.tween_property(_model, "scale", _model_scale * Vector3(1.15, 0.82, 1.15), 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		squash.tween_property(_model, "scale", _model_scale, 0.6) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _window_light:
		var glow: Tween = create_tween()
		glow.tween_property(_window_light, "light_energy", _window_energy * 5.0, 0.08)
		glow.tween_property(_window_light, "light_energy", _window_energy, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node3D) -> void:
	if targeted and body is Glider:
		courier_arrived.emit(self)
