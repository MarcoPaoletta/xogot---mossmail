class_name Collectible
extends Area3D
## Base for things the glider picks up. Counts only on real contact: it reacts
## to the glider's wing area (group "glider_collector"), not to a large bubble.
## Pops in, bobs and spins, shines (glow overlay on the downloaded model), and
## bursts when collected.

signal collected(item: Collectible)

@export var visual_path: NodePath = ^"Visual"
@export var burst_path: NodePath = ^"Burst"
@export var glow_path: NodePath = ^"Glow"
@export var halo_path: NodePath = ^"Halo"
## Optional additive overlay for the model's meshes (none by default: the model
## keeps its own look and only the halo behind it glows).
@export var glow_overlay: Material
@export var bob_height: float = 0.35
@export var bob_speed: float = 2.2
## Turntable spin. 0 = the item only bobs up and down.
@export var spin_speed: float = 0.0

var _visual: Node3D
var _burst: GPUParticles3D
var _glow: OmniLight3D
var _halo: Node3D
var _visual_scale: Vector3 = Vector3.ONE
var _base_y: float = 0.0
var _time: float = 0.0
var _taken: bool = false


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node3D
	_burst = get_node_or_null(burst_path) as GPUParticles3D
	_glow = get_node_or_null(glow_path) as OmniLight3D
	_halo = get_node_or_null(halo_path) as Node3D
	_time = randf() * TAU
	if _visual:
		_visual_scale = _visual.scale
		_base_y = _visual.position.y
		if glow_overlay:
			for node: Node in _visual.find_children("*", "GeometryInstance3D", true, false):
				(node as GeometryInstance3D).material_overlay = glow_overlay
		_visual.scale = Vector3.ZERO
		var pop: Tween = create_tween()
		pop.tween_property(_visual, "scale", _visual_scale, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _visual == null or _taken:
		return
	_time += delta
	_visual.position.y = _base_y + sin(_time * bob_speed) * bob_height
	if spin_speed != 0.0:
		_visual.rotation.y += spin_speed * delta


## Removes the item without a reward (wave failed or cancelled).
func dismiss() -> void:
	if _taken:
		return
	_taken = true
	set_deferred("monitoring", false)
	var fade: Tween = create_tween().set_parallel(true)
	if _visual:
		fade.tween_property(_visual, "scale", Vector3.ZERO, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _halo:
		fade.tween_property(_halo, "scale", Vector3.ZERO, 0.3)
	fade.chain().tween_callback(queue_free)


## Override for extra effects on pickup (the glider is passed in).
func _on_collected(_glider: Glider) -> void:
	pass


func _on_area_entered(area: Area3D) -> void:
	if _taken or not area.is_in_group(&"glider_collector"):
		return
	_taken = true
	set_deferred("monitoring", false)
	collected.emit(self)
	_on_collected(area.owner as Glider)
	if _burst:
		_burst.restart()
	var tween: Tween = create_tween().set_parallel(true)
	if _visual:
		tween.tween_property(_visual, "scale", _visual_scale * 1.8, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(_visual, "scale", Vector3.ZERO, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _halo:
		tween.tween_property(_halo, "scale", _halo.scale * 2.2, 0.35)
	if _glow:
		tween.tween_property(_glow, "light_energy", 0.0, 0.5)
	tween.chain().tween_interval(1.2)
	tween.chain().tween_callback(queue_free)
