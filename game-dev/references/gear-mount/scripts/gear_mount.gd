@tool
class_name GearMount
extends BoneAttachment3D

## Socket for the blaster and tank (GDD §17). Offsets are data, adjusted live
## in the editor with the animation scrubber, stored in a WeaponMountProfile.

@export var mount_profile: WeaponMountProfile:
	set(value):
		mount_profile = value
		_apply()
@export var offset_position: Vector3 = Vector3.ZERO:
	set(value):
		offset_position = value
		_write_profile()
		_apply()
@export var offset_rotation_degrees: Vector3 = Vector3.ZERO:
	set(value):
		offset_rotation_degrees = value
		_write_profile()
		_apply()
@export var offset_scale: Vector3 = Vector3.ONE:
	set(value):
		offset_scale = value
		_write_profile()
		_apply()
@export var reset: bool = false:
	set(value):
		if value:
			offset_position = Vector3.ZERO
			offset_rotation_degrees = Vector3.ZERO
			offset_scale = Vector3.ONE

@export_group("Capture (editor only)")
## Workflow: select the gear CHILD (Blaster/Tank) in the viewport and move,
## rotate, or scale it with the normal Godot gizmo — WORLD axes work (keep the
## toolbar "Use Local Space" toggle off). Then tick this on the mount to bake
## the result into the profile offsets. Without capturing, gizmo edits are
## overwritten by the profile on the next scene load.
@export var capture_from_gear: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_capture()

@export_group("Preview (editor only)")
@export var preview_player_path: NodePath
@export var preview_animation: String = "":
	set(value):
		preview_animation = value
		_scrub()
@export_range(0.0, 1.0) var preview_time: float = 0.0:
	set(value):
		preview_time = value
		_scrub()


var _loading: bool = false


func _ready() -> void:
	if mount_profile != null:
		_loading = true
		offset_position = mount_profile.position_offset
		offset_rotation_degrees = mount_profile.rotation_degrees_offset
		offset_scale = mount_profile.scale_factor
		_loading = false
	_apply()
	# The external skeleton bind resolves after ready: re-apply once settled.
	_apply.call_deferred()


func _apply() -> void:
	# During scene load the setters fire before the node enters the tree:
	# skip; _ready (and its deferred re-run) applies once everything exists.
	if not is_inside_tree() or get_child_count() == 0:
		return
	var gear: Node3D = get_child(0) as Node3D
	if gear == null:
		return
	# The skeleton carries a tiny import scale (cm rig): compensate so the
	# profile's offsets read in metres and the gear renders at world scale.
	# Read the scale from the SKELETON node itself, not from our own global
	# basis: our basis is only valid after the bone bind resolves, and reading
	# it too early baked garbage transforms into the scene. The profile is the
	# single source of truth; whatever the scene stored gets overwritten here.
	var parent_scale: Vector3 = global_basis.get_scale()
	if use_external_skeleton:
		var sk: Node3D = get_node_or_null(get_external_skeleton()) as Node3D
		if sk != null:
			parent_scale = sk.global_basis.get_scale()
	if parent_scale.x < 0.0001 or parent_scale.y < 0.0001 or parent_scale.z < 0.0001:
		parent_scale = Vector3.ONE
	var inv: Vector3 = Vector3(1.0 / parent_scale.x, 1.0 / parent_scale.y, 1.0 / parent_scale.z)
	gear.position = offset_position * inv
	gear.rotation_degrees = offset_rotation_degrees
	gear.scale = offset_scale * inv


func _write_profile() -> void:
	# Profile writes are an editor tuning feature: never clobber at runtime.
	# is_node_ready() guard: while a scene FILE loads, the exported setters fire
	# one by one BEFORE _ready — writing then would store a half-default profile
	# (the exact bug that once wiped the tank scale). Only inspector edits made
	# after the node is ready may write.
	if mount_profile == null or _loading or not Engine.is_editor_hint() or not is_node_ready():
		return
	mount_profile.position_offset = offset_position
	mount_profile.rotation_degrees_offset = offset_rotation_degrees
	mount_profile.scale_factor = offset_scale


func _capture() -> void:
	# Inverse of _apply: read the gear child's current local transform (the
	# viewport gizmo already converted any world-space manipulation into it,
	# pose-independent) and store it as profile offsets in metres/degrees.
	if get_child_count() == 0:
		return
	var gear: Node3D = get_child(0) as Node3D
	if gear == null:
		return
	var parent_scale: Vector3 = global_basis.get_scale()
	if use_external_skeleton:
		var sk: Node3D = get_node_or_null(get_external_skeleton()) as Node3D
		if sk != null:
			parent_scale = sk.global_basis.get_scale()
	if parent_scale.x < 0.0001 or parent_scale.y < 0.0001 or parent_scale.z < 0.0001:
		parent_scale = Vector3.ONE
	offset_position = gear.position * parent_scale
	offset_rotation_degrees = gear.rotation_degrees
	offset_scale = gear.scale * parent_scale
	print("[GearMount] %s captured -> pos=%s rot=%s scale=%s (profile updated, save the scene)" % [
		name, offset_position, offset_rotation_degrees, offset_scale])


func _scrub() -> void:
	# Pose the skeleton straight from the animation tracks: AnimationPlayer
	# play()+seek() does not evaluate reliably inside the editor.
	if not Engine.is_editor_hint():
		return
	var sk: Skeleton3D = get_node_or_null(get_external_skeleton()) as Skeleton3D
	var ap: AnimationPlayer = get_node_or_null(preview_player_path) as AnimationPlayer
	if sk == null or ap == null:
		return
	if preview_animation.is_empty():
		sk.reset_bone_poses()
		return
	if not ap.has_animation(preview_animation):
		push_warning("[GearMount] preview animation '%s' not found" % preview_animation)
		return
	var anim: Animation = ap.get_animation(preview_animation)
	var t: float = clampf(preview_time, 0.0, 1.0) * anim.length
	for i: int in anim.get_track_count():
		var bone: String = String(anim.track_get_path(i)).get_slice(":", 1)
		var bi: int = sk.find_bone(bone)
		if bi == -1:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(bi, anim.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(bi, anim.position_track_interpolate(i, t))
			Animation.TYPE_SCALE_3D:
				sk.set_bone_pose_scale(bi, anim.scale_track_interpolate(i, t))
