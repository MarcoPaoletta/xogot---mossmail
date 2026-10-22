class_name WeaponMountProfile
extends Resource

## Hand-tuned socket offsets for gear mounted on BoneAttachment3D nodes.
## Adjusted with the @tool scrubber on the mount, stored here as data.

@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_degrees_offset: Vector3 = Vector3.ZERO
@export var scale_factor: Vector3 = Vector3.ONE


func apply_to(node: Node3D) -> void:
	node.position = position_offset
	node.rotation_degrees = rotation_degrees_offset
	node.scale = scale_factor
