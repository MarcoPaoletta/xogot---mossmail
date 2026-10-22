@tool
class_name AnimFrameEntry
extends Resource
# One per-animation transform "struct": which animation, and the scale + offset it needs.
# Held in AnimFrameTransform.entries as a typed array, so each shows as an editable row
# (anim name + two Vector2 fields) in the inspector, which is where you calibrate them.

@export var anim: StringName = &""
@export var scale: Vector2 = Vector2.ONE
@export var offset: Vector2 = Vector2.ZERO
# Which way the clip's art faces by default. Combine with the actor's facing when setting flip_h,
# because Makko clips do not all face the same way (Starling boss: idle faced left, walk/attack/die faced right).
@export var native_faces_right: bool = true
