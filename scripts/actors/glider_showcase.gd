class_name GliderShowcase
extends Node3D
## Rotating glider shown on the customization screen (inside its own SubViewport
## world). Uses the same tint material as the flying glider.

@export var pivot_path: NodePath = ^"Pivot"
@export var model_root_path: NodePath = ^"Pivot/ModelPivot"
@export var model_material: ShaderMaterial
@export var spin_speed: float = 0.6
@export var tilt_amount: float = 0.12

var _pivot: Node3D
var _material: ShaderMaterial
var _time: float = 0.0
var _pop: Tween


func _ready() -> void:
	_pivot = get_node_or_null(pivot_path) as Node3D
	if model_material:
		_material = model_material.duplicate() as ShaderMaterial
		var root := get_node_or_null(model_root_path)
		if root:
			for node: Node in root.find_children("*", "MeshInstance3D", true, false):
				(node as MeshInstance3D).material_override = _material
	set_color_index(GliderPalette.load_index(), false)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_time += delta
	_pivot.rotation = Vector3(sin(_time * 0.9) * tilt_amount * 0.5, _pivot.rotation.y + spin_speed * delta, sin(_time * 1.3) * tilt_amount)


## Shows colour [param index], with a small pop when [param animate].
func set_color_index(index: int, animate: bool = true) -> void:
	GliderPalette.apply(_material, index)
	if not animate or _pivot == null:
		return
	if _pop and _pop.is_valid():
		_pop.kill()
	_pivot.scale = Vector3.ONE * 0.9
	_pop = create_tween()
	_pop.tween_property(_pivot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
