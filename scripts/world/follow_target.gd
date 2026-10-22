extends Node3D
## Keeps this node centred under a target on the ground plane.
## Used by the ground plane (snapped, so its world-space shader never swims)
## and by ambient particle volumes such as the fireflies.

@export var target_path: NodePath
## Grid step in metres. 0 follows exactly.
@export var snap: float = 0.0
@export var follow_height: bool = false
@export var offset: Vector3 = Vector3.ZERO

var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D


func _process(_delta: float) -> void:
	if _target == null:
		return
	var p: Vector3 = _target.global_position + offset
	if snap > 0.0:
		p.x = snappedf(p.x, snap)
		p.z = snappedf(p.z, snap)
	var current: Vector3 = global_position
	global_position = Vector3(p.x, p.y if follow_height else current.y, p.z)
