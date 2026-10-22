@tool
class_name MenuCameraShot
extends Node3D

## One menu shot. Its transform is the start; movement type + params do the rest.
## Reorder in the tree to reorder the sequence (GDD §20).

enum Movement { STATIC, MOVE, ORBIT }

@export var enabled: bool = true
@export var duration: float = 3.5
@export var movement: Movement = Movement.MOVE
@export var fov: float = 65.0
@export_group("Move")
@export var end_offset: Vector3 = Vector3(0, -2, 0)
@export var end_rotation_offset_degrees: Vector3 = Vector3.ZERO
@export_group("Orbit")
@export var orbit_target: Vector3 = Vector3.ZERO
@export var orbit_degrees: float = 40.0
@export_group("Common")
@export var look_at_target: bool = false
@export var look_target: Vector3 = Vector3.ZERO
@export var ease_ends: bool = true


func sample(t: float) -> Transform3D:
	var f: float = t
	if ease_ends:
		f = t * t * (3.0 - 2.0 * t)
	var xf: Transform3D = global_transform
	match movement:
		Movement.STATIC:
			pass
		Movement.MOVE:
			xf.origin = global_transform.origin + end_offset * f
			var rot: Vector3 = end_rotation_offset_degrees * f
			xf.basis = global_transform.basis * Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
		Movement.ORBIT:
			var angle: float = deg_to_rad(orbit_degrees) * f
			var offset: Vector3 = global_transform.origin - orbit_target
			var rotated: Vector3 = offset.rotated(Vector3.UP, angle)
			xf.origin = orbit_target + rotated
			xf.basis = global_transform.basis.rotated(Vector3.UP, angle)
	if look_at_target:
		var up: Vector3 = Vector3.UP
		var forward: Vector3 = (look_target - xf.origin).normalized()
		if forward.length_squared() > 0.001 and absf(forward.dot(up)) < 0.99:
			xf = xf.looking_at(look_target, up)
	return xf
