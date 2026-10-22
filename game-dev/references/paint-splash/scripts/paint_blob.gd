class_name PaintBlob
extends Node3D
## One blob of paint (GDD section 9). The scene `paint_blob.tscn` is the shared base for the three paints;
## the PaintStyle data decides the color and the behavior (solid, wall patch or bounce pad).
##
## A blob lives 10 seconds. In its last 1.5 seconds it blinks, desaturates toward clay white and its drips
## retract; the dissolve takes 0.4 s (scale to zero with a fizz) and removes the collision when it starts.
## Showcase blobs are authored in scenes for the concept shots and the title: they never decay and are
## hidden when a run starts.

## Emitted when the blob returns to the pool (the manager forgets it).
signal expired(blob: PaintBlob)
## Emitted when a Spring pad launches Pip.
signal sprung(blob: PaintBlob)

enum State { IDLE, LIVE, WARNING, DISSOLVING }

const PAINT_LAYERS: int = 9
const GRIP: int = 1
const SPRING: int = 2
## Physics layer the drips look at: the level and the other blobs (both are on layer 1).
const DRIP_CLEARANCE_MASK: int = 1
const DRIP_RAY_LIFT: float = 0.15
## The size the scene's Mesh was authored at (a slab of radius 0.8 m and 0.35 m thick): showcase blobs keep it so the
## concept shots do not change. A blob of a run takes its size from its PaintStyle.
const REFERENCE_RADIUS: float = 0.8
## The top of the slab as a fraction of the mesh scale (the paint shader's top_height).
const TOP_HEIGHT: float = 0.4375
## The Spring trigger is a disc this fraction of the blob's radius and this tall, sitting on top of the pad.
const TRIGGER_RADIUS_FRACTION: float = 0.875
const TRIGGER_HEIGHT: float = 0.3
## Wall patches and decorative puddles are not solid things: they are paint that tints the surface they land on, drawn as a
## Decal that wraps whatever is under it (a column, an uneven floor, a corner), with one of these splat shapes.
const SPLATS: Array[Texture2D] = [
	preload("res://assets/paint/splat_0.png"), preload("res://assets/paint/splat_1.png"), preload("res://assets/paint/splat_2.png"),
	preload("res://assets/paint/splat_3.png"), preload("res://assets/paint/splat_4.png"), preload("res://assets/paint/splat_5.png"),
]
const CLAY: Color = Color("#F8E0C9")
## Paint is matte to the decal: full roughness and no metal (occlusion, roughness, metallic in R, G, B), so the wall under it
## cannot add its own sheen and the color stays the same on every structure.
const SPLAT_ORM: Texture2D = preload("res://assets/paint/splat_orm.png")
## Characters draw on this visual layer only and the splat decals skip it, so paint tints the level and not Pip or an enemy.
const CHARACTER_LAYER: int = 1 << 19

@export var mesh_path: NodePath = ^"Mesh"
@export var body_path: NodePath = ^"Body"
@export var trigger_path: NodePath = ^"Trigger"
@export var link_path: NodePath = ^"Link"
@export var drips_path: NodePath = ^"Mesh/Drips"
@export var coil_path: NodePath = ^"Mesh/Coil"
@export var fizz_path: NodePath = ^"Fizz"
@export var splat_path: NodePath = ^"Splat"
## A splat is this many radii wide (the shape fills about 90 percent of it), a decorative puddle this share of that, and the
## decal reaches this far in front of the surface and behind it.
@export var splat_width: float = 2.8
@export var puddle_share: float = 0.75
@export var splat_depth: float = 0.9
@export var splat_glow: float = 1.2
## The splat color is the paint color times this (the lit level is brighter than the paint was authored for, so an untoned
## decal reads pale), measured against the solid blob.
@export var splat_tone: float = 1.0
@export var lifetime: float = 10.0
@export var warning_time: float = 1.5
@export var dissolve_time: float = 0.4
@export var bleach_time: float = 0.8
## The back ease of the pop in adds about 10 percent past this value: 1.05 makes the measured peak 1.15 (GDD 15).
@export var pop_overshoot: float = 1.05
@export var pop_time: float = 0.22
@export var spring_launch_speed: float = 15.5
@export var spring_cooldown: float = 0.3
## Wall patches are thinner: the mesh scale along the surface normal is multiplied by this.
@export_range(0.1, 1.0) var patch_thickness_scale: float = 0.32
## The link between two docked blobs is a stretched dome of the same material: it reaches this far past each
## blob center (meters) and its height and width are fractions of a blob's (mesh scale factors).
@export var link_extra: float = 0.3
@export var link_scale_y: float = 0.66
@export var link_scale_z: float = 0.62
## Teardrops hung from the rim, measured in mesh units (the mesh is a unit sphere before its scale). The
## outline wobble and the rim flare are the paint shader's own, repeated here so the drips start on the rim.
@export var drip_count: int = 7
## Beads scattered around a blob that rests on a surface (its drips would hang into the floor).
@export var spatter_count: int = 5
@export var spatter_radius: Vector2 = Vector2(0.045, 0.085)
@export var drip_length_min: float = 0.18
@export var drip_length_max: float = 0.6
@export var drip_bead_radius: Vector2 = Vector2(0.07, 0.1)
## The stream is this fraction of the bead's radius, drawn per drip.
@export var drip_stream_ratio: Vector2 = Vector2(0.5, 0.7)
## A drip starts this high on the rim and sits this far inside it, so its stream hides in the slab and shows
## only where the underside curves away.
@export var drip_anchor_height: float = -0.05
@export var drip_sink: float = 0.05
@export var patch_drip_scale: float = 2.7
@export var rim_wobble: float = 0.07
@export var rim_flare: float = 0.07
@export var splat_reach: float = 0.3
## The coil inside a Spring pad: a helix of beads, in mesh units (the dome is a unit sphere before its scale).
@export var coil_turns: float = 2.5
@export var coil_radius: float = 0.42
@export var coil_base: float = 0.06
@export var coil_top: float = 0.52
@export var coil_wire: float = 0.05
## Authored in a scene for the concept shots and the title: never decays, hidden when a run starts.
@export var showcase: bool = false
@export var showcase_style: PaintStyle
## A showcase wall patch: flat, no collision, no climbing.
@export var showcase_patch: bool = false
## The showcase blob this one is drawn as linked to (a ribbon).
@export var showcase_link_path: NodePath
@export var showcase_scale: float = 1.0

var style: PaintStyle
var kind: int = 0
var is_patch: bool = false
## A decorative puddle: no collision, never climbable.
var is_decor: bool = false
var dock_parent: PaintBlob
var age: float = 0.0
## Activation order: the manager dissolves the lowest serial first when the cap is reached.
var serial: int = 0
var state: State = State.IDLE

var _mesh: MeshInstance3D
var _body: StaticBody3D
var _trigger: Area3D
var _link: MeshInstance3D
var _drips: MultiMeshInstance3D
var _coil: MultiMeshInstance3D
var _coil_laid: bool = false
var _fizz: GPUParticles3D
var _base_scale: Vector3 = Vector3.ONE
## The mesh scale this blob rests at once it has popped in (a wall patch is thinner than this).
var _rest_scale: Vector3 = Vector3.ONE
var _splat: Decal
var _splat_size: Vector3 = Vector3.ONE
var _splat_alpha: float = 1.0
var _desat: float = 0.0
var _bleach: float = 0.0
var _body_shape: CollisionShape3D
var _trigger_shape: CollisionShape3D
var _pop_tween: Tween
var _end_tween: Tween
var _spring_left: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_mesh = get_node(mesh_path) as MeshInstance3D
	_body = get_node(body_path) as StaticBody3D
	_trigger = get_node_or_null(trigger_path) as Area3D
	_link = get_node_or_null(link_path) as MeshInstance3D
	_drips = get_node_or_null(drips_path) as MultiMeshInstance3D
	_coil = get_node_or_null(coil_path) as MultiMeshInstance3D
	_fizz = get_node_or_null(fizz_path) as GPUParticles3D
	_splat = get_node_or_null(splat_path) as Decal
	if _splat != null:
		_splat.visible = false
	_base_scale = _mesh.scale
	_rest_scale = _base_scale
	# Every pooled blob owns its shapes, so a run can size them from the PaintStyle without touching the others.
	_body_shape = _body.get_node_or_null("Shape") as CollisionShape3D
	if _body_shape != null and _body_shape.shape != null:
		_body_shape.shape = _body_shape.shape.duplicate()
	if _trigger != null:
		_trigger_shape = _trigger.get_node_or_null("Shape") as CollisionShape3D
		if _trigger_shape != null and _trigger_shape.shape != null:
			_trigger_shape.shape = _trigger_shape.shape.duplicate()
		_trigger.body_entered.connect(_on_trigger_body_entered)
	if showcase and showcase_style != null:
		_activate_showcase()
	else:
		_hide_idle()


## Moves every mesh under a character to the layer the splat decals do not tint.
static func exempt_from_splats(root: Node) -> void:
	for node: Node in root.find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = CHARACTER_LAYER


## The physics body, so queries can skip the paint and look at the level only.
func body_rid() -> RID:
	return _body.get_rid()


## True while the blob can be stood on, climbed or docked to (warning included, dissolving excluded).
func is_live() -> bool:
	return state == State.LIVE or state == State.WARNING


## Seconds left before the blob expires (infinite for showcase blobs).
func remaining() -> float:
	if showcase:
		return INF
	return maxf(lifetime - age, 0.0)


## Brings a pooled blob to life at a transform. `xform` has its up axis along the surface normal.
func activate(new_style: PaintStyle, xform: Transform3D, patch: bool, parent: PaintBlob, new_serial: int, decor: bool = false) -> void:
	_kill_tweens()
	style = new_style
	lifetime = style.lifetime
	kind = style.kind_index
	is_patch = patch or decor
	is_decor = decor
	dock_parent = parent
	serial = new_serial
	age = 0.0
	state = State.LIVE
	showcase = false
	global_transform = xform
	visible = true
	set_physics_process(true)
	_mesh.material_override = style.blob_material
	_seed = randf()
	_set_param(&"seed", _seed)
	_set_param(&"splat", 1.0 if is_patch else 0.0)
	_set_param(&"desaturate", 0.0)
	_set_param(&"drip_retract", 0.0)
	_set_param(&"bleach", 0.0)
	_set_param(&"flash", 0.0)
	var target_scale: Vector3 = Vector3(style.radius, style.thickness / TOP_HEIGHT, style.radius)
	_rest_scale = target_scale
	if is_patch:
		target_scale.y *= patch_thickness_scale
	var as_splat: bool = is_patch and _splat != null
	_mesh.visible = not as_splat
	_size_collision()
	if not as_splat:
		_layout_drips(target_scale)
	_layout_coil()
	_register_groups()
	_set_collision(not is_patch)
	_set_trigger(kind == SPRING and not is_patch)
	_update_link()
	_pop_tween = create_tween()
	if as_splat:
		_start_splat()
		var full: Vector3 = _splat_size
		_splat.size = Vector3(full.x * 0.25, full.y, full.z * 0.25)
		_pop_tween.tween_property(_splat, "size", Vector3(full.x * pop_overshoot, full.y, full.z * pop_overshoot), pop_time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(_splat, "size", full, pop_time * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		# Pop in: 0 to overshoot with a back ease, then settle.
		_mesh.scale = Vector3.ZERO
		_pop_tween.tween_property(_mesh, "scale", target_scale * pop_overshoot, pop_time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pop_tween.tween_property(_mesh, "scale", target_scale, pop_time * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reset_physics_interpolation()


## Paint on a wall or a floor is a decal that tints whatever lies under it: the shape, color and glow of this splat.
func _start_splat() -> void:
	var width: float = style.radius * splat_width * (puddle_share if is_decor else 1.0)
	_splat_size = Vector3(width, splat_depth, width)
	var texture: Texture2D = SPLATS[int(_seed * 1000.0) % SPLATS.size()]
	_splat.texture_albedo = texture
	_splat.texture_emission = texture
	_splat.texture_orm = SPLAT_ORM
	_splat.emission_energy = splat_glow
	_splat.size = _splat_size
	_splat.position = Vector3.ZERO
	_splat_alpha = 1.0
	_desat = 0.0
	_bleach = 0.0
	_update_splat_color()
	_splat.visible = true


func _update_splat_color() -> void:
	var color: Color = style.color.lerp(CLAY, _desat)
	color = Color(color.r * splat_tone, color.g * splat_tone, color.b * splat_tone).lerp(Color.WHITE, _bleach)
	_splat.modulate = Color(color.r, color.g, color.b, _splat_alpha)


## Adds extra age (an Eraser rubbing drains the blob three times faster: pass twice the frame time).
func drain(extra_seconds: float) -> void:
	if is_live() and not showcase:
		age += extra_seconds


## Starts the normal dissolve: collision gone at once, scale to zero with a fizz.
func dissolve() -> void:
	if not is_live():
		return
	_begin_end()
	Audio.sfx_at(&"blob_fizz", global_position, -4.0)
	if _fizz != null:
		_fizz.material_override = style.ball_material
		_fizz.restart()
		_fizz.emitting = true
	_end_tween = create_tween()
	if _splat != null and _splat.visible:
		_end_tween.tween_method(_set_splat_alpha, _splat_alpha, 0.0, dissolve_time)
	else:
		_end_tween.tween_property(_mesh, "scale", Vector3.ZERO, dissolve_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_end_tween.finished.connect(_return_to_pool)


func _set_splat_alpha(value: float) -> void:
	_splat_alpha = value
	_update_splat_color()


## Bleach (Spritzer glob, Big Eraser ring): turns white, then dissolves, 0.8 s in all.
func bleach_away() -> void:
	if not is_live():
		return
	_begin_end()
	Audio.sfx_at(&"bleach_splash", global_position, -6.0)
	var half: float = bleach_time * 0.5
	_end_tween = create_tween()
	_end_tween.tween_method(func(v: float) -> void: _set_param(&"bleach", v), 0.0, 1.0, half)
	if _splat != null and _splat.visible:
		_end_tween.tween_method(_set_splat_alpha, _splat_alpha, 0.0, half)
	else:
		_end_tween.tween_property(_mesh, "scale", Vector3.ZERO, half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_end_tween.finished.connect(_return_to_pool)


## Immediately hides a pooled blob without any animation (a run reset).
func recycle_now() -> void:
	_kill_tweens()
	_return_to_pool()


## Showcase blobs appear in the title and the ConceptCam shots and vanish when a run starts.
func set_showcase_visible(value: bool) -> void:
	if not showcase:
		return
	visible = value
	_set_collision(value and not is_patch)
	_set_trigger(value and kind == SPRING and not is_patch)


func _activate_showcase() -> void:
	style = showcase_style
	kind = style.kind_index
	state = State.LIVE
	is_patch = showcase_patch
	dock_parent = get_node_or_null(showcase_link_path) as PaintBlob
	_mesh.material_override = style.blob_material
	_seed = randf()
	_set_param(&"seed", _seed)
	_set_param(&"splat", 1.0 if is_patch else 0.0)
	var shown_scale: Vector3 = _base_scale * showcase_scale
	_rest_scale = shown_scale
	if is_patch:
		shown_scale.y *= patch_thickness_scale
	_mesh.scale = shown_scale
	_layout_drips(shown_scale)
	_layout_coil()
	_register_groups()
	_set_collision(not is_patch)
	_set_trigger(kind == SPRING and not is_patch)
	add_to_group(&"showcase_blob")
	_update_link()
	set_physics_process(false)


func _hide_idle() -> void:
	if _splat != null:
		_splat.visible = false
	_mesh.visible = true
	visible = false
	state = State.IDLE
	_set_collision(false)
	_set_trigger(false)
	if _link != null:
		_link.visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	_spring_left = maxf(0.0, _spring_left - delta)
	if state == State.LIVE or state == State.WARNING:
		age += delta
		var left: float = lifetime - age
		if left <= warning_time:
			if state == State.LIVE:
				state = State.WARNING
				Audio.sfx_at(&"blob_warn", global_position, -6.0)
			var t: float = clampf(1.0 - left / warning_time, 0.0, 1.0)
			_set_param(&"desaturate", t * 0.85)
			_set_param(&"drip_retract", t)
			_set_param(&"flash", 0.12 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)) * t)
		if left <= 0.0:
			dissolve()
			return
	_update_link()


func _begin_end() -> void:
	_kill_tweens()
	state = State.DISSOLVING
	_set_collision(false)
	_set_trigger(false)
	if _link != null:
		_link.visible = false
	remove_from_group(&"grip_patch")


func _return_to_pool() -> void:
	state = State.IDLE
	dock_parent = null
	for group_name: StringName in [&"paint_blob", &"grip_patch", &"spring_pad", &"showcase_blob"]:
		remove_from_group(group_name)
	_hide_idle()
	expired.emit(self)


func _register_groups() -> void:
	add_to_group(&"paint_blob")
	if kind == GRIP and is_patch and not is_decor:
		add_to_group(&"grip_patch")
	if kind == SPRING:
		add_to_group(&"spring_pad")


## Sizes the standing collision and the Spring trigger from the style: what you see is what you stand on.
func _size_collision() -> void:
	if _body_shape != null:
		var cylinder := _body_shape.shape as CylinderShape3D
		cylinder.radius = style.radius
		cylinder.height = style.thickness
		_body_shape.position.y = style.thickness * 0.5
	if _trigger_shape != null:
		var disc := _trigger_shape.shape as CylinderShape3D
		disc.radius = style.radius * TRIGGER_RADIUS_FRACTION
		disc.height = TRIGGER_HEIGHT
		_trigger_shape.position.y = style.thickness + TRIGGER_HEIGHT * 0.5


func _set_collision(enabled: bool) -> void:
	_body.set_deferred("collision_layer", PAINT_LAYERS if enabled else 0)


func _set_trigger(enabled: bool) -> void:
	if _trigger != null:
		_trigger.set_deferred("monitoring", enabled)


func _set_param(param: StringName, value: float) -> void:
	if _splat != null and _splat.visible:
		if param == &"desaturate":
			_desat = value
			_update_splat_color()
		elif param == &"bleach":
			_bleach = value
			_update_splat_color()
	_mesh.set_instance_shader_parameter(param, value)
	if _drips != null:
		_drips.set_instance_shader_parameter(param, value)
	if _coil != null:
		_coil.set_instance_shader_parameter(param, value)
	if _link != null:
		_link.set_instance_shader_parameter(param, value)


func _kill_tweens() -> void:
	for tween: Tween in [_pop_tween, _end_tween]:
		if tween != null and tween.is_valid():
			tween.kill()


## A Spring pad shows its coil through the gel: a helix of beads, laid out once, in the style's accent material.
## Every other paint (and every wall patch) hides it.
func _layout_coil() -> void:
	if _coil == null:
		return
	var show_coil: bool = style.accent_material != null and not is_patch
	_coil.visible = show_coil
	if not show_coil:
		return
	_coil.material_override = style.accent_material
	if _coil_laid:
		return
	_coil_laid = true
	var multi: MultiMesh = _coil.multimesh
	var beads: int = multi.instance_count
	for i: int in beads:
		var t: float = float(i) / float(beads - 1)
		var angle: float = t * coil_turns * TAU
		var centre := Vector3(cos(angle) * coil_radius, lerpf(coil_base, coil_top, t) + coil_wire, sin(angle) * coil_radius)
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, centre))
		multi.set_instance_custom_data(i, Color(coil_wire * 2.0, coil_wire, coil_wire, 0.0))
	multi.visible_instance_count = beads


## The outline of the slab as a fraction of its radius, the same function as the paint shader's.
func _outline(angle: float) -> float:
	if is_patch:
		var arms: float = 0.55 * sin(angle * 3.0 + _seed * 17.0) + 0.45 * sin(angle * 5.0 + _seed * 29.0 + 2.0) + 0.3 * sin(angle * 8.0 + _seed * 43.0 + 4.0) + 0.2 * sin(angle * 11.0 + _seed * 7.0 + 1.0)
		return arms * splat_reach
	return (sin(angle * 3.0 + _seed * TAU) * 0.55 + sin(angle * 5.0 + _seed * 11.0 + 1.3) * 0.45) * rim_wobble


## Hangs teardrops from the rim, at angles and lengths drawn from the blob's seed. They hang along the WORLD down
## direction, so a wall patch drips down the wall, and only from the part of the rim that faces down. A ray down
## from each drip cuts it short where the ground or a lower blob is in the way; a blob that rests on a surface
## gets a few beads of spatter around it instead. The mesh scale is passed in because the mesh may be mid pop
## (scale zero) when this runs.
func _layout_drips(mesh_scale: Vector3) -> void:
	if _drips == null:
		return
	_drips.material_override = style.blob_material
	var multi: MultiMesh = _drips.multimesh
	var mesh_basis: Basis = global_basis * Basis.from_scale(mesh_scale)
	var hang: Vector3 = mesh_basis.inverse() * Vector3.DOWN
	if hang.length() < 0.0001:
		multi.visible_instance_count = 0
		return
	hang = hang.normalized()
	var mesh_xform := Transform3D(mesh_basis, global_position)
	var per_unit: float = maxf((mesh_basis * -hang).length(), 0.001)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_seed)
	var around: bool = Vector2(hang.x, hang.z).length() < 0.4
	var hang_angle: float = atan2(hang.z, hang.x)
	var tilt := Basis(Quaternion(Vector3.UP, -hang))
	var length_scale: float = patch_drip_scale if is_patch else 1.0
	var turn: float = rng.randf() * TAU
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = DRIP_CLEARANCE_MASK
	query.exclude = [_body.get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var wanted: int = mini(drip_count, multi.instance_count - spatter_count)
	var shown: int = 0
	var blocked: int = 0
	for i: int in wanted:
		var along: float = (float(i) + rng.randf_range(0.15, 0.85)) / float(wanted)
		var angle: float = turn + TAU * along if around else hang_angle + lerpf(-1.35, 1.35, along)
		var radius: float = (1.0 + rim_flare) * (1.0 + _outline(angle)) - drip_sink
		var length: float = lerpf(drip_length_min, drip_length_max, pow(rng.randf(), 1.5)) * length_scale
		var bead: float = rng.randf_range(drip_bead_radius.x, drip_bead_radius.y)
		var stream: float = bead * rng.randf_range(drip_stream_ratio.x, drip_stream_ratio.y)
		var anchor := Vector3(cos(angle) * radius, drip_anchor_height, sin(angle) * radius)
		# The ray starts a little above the anchor so a rim that sits right on the ground still sees the ground.
		query.from = mesh_xform * anchor + Vector3.UP * DRIP_RAY_LIFT
		query.to = query.from + Vector3.DOWN * (DRIP_RAY_LIFT + (length + bead) * per_unit)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var room: float = ((hit["position"] as Vector3).distance_to(query.from) - DRIP_RAY_LIFT) / per_unit - bead
			if room < drip_length_min:
				blocked += 1
				continue
			length = minf(length, room)
		multi.set_instance_transform(shown, Transform3D(tilt, anchor))
		multi.set_instance_custom_data(shown, Color(length, bead, stream, 0.12))
		shown += 1
	if blocked > 0:
		for i: int in mini(spatter_count, blocked + 1):
			var angle: float = rng.randf() * TAU
			var radius: float = (1.0 + rim_flare) * (1.0 + _outline(angle)) * rng.randf_range(1.12, 1.5)
			var bead: float = rng.randf_range(spatter_radius.x, spatter_radius.y)
			multi.set_instance_transform(shown, Transform3D(tilt, Vector3(cos(angle) * radius, bead * 0.4, sin(angle) * radius)))
			multi.set_instance_custom_data(shown, Color(bead * 2.0, bead, bead, 0.0))
			shown += 1
	multi.visible_instance_count = shown


## Draws the link between this blob and the one it docked to: a stretched dome of the same material, so the
## two read as one ribbon and blink and dissolve together.
func _update_link() -> void:
	if _link == null:
		return
	var show_link: bool = dock_parent != null and is_instance_valid(dock_parent) and dock_parent.is_live() and is_live() and not is_patch
	_link.visible = show_link
	if not show_link:
		return
	var from: Vector3 = global_position
	var to: Vector3 = dock_parent.global_position
	var along: Vector3 = to - from
	var length: float = along.length()
	if length < 0.05:
		_link.visible = false
		return
	var up: Vector3 = global_basis.y.normalized()
	var x_axis: Vector3 = along / length
	var z_axis: Vector3 = x_axis.cross(up).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	# The link follows the size of the blobs it joins (the numbers above were tuned for the reference blob).
	var wide: float = _rest_scale.x / REFERENCE_RADIUS
	var tall: float = _rest_scale.y / REFERENCE_RADIUS
	var link_basis := Basis(x_axis * (length * 0.5 + link_extra * wide), y_axis * link_scale_y * tall, z_axis * link_scale_z * wide)
	_link.material_override = style.blob_material
	_link.global_transform = Transform3D(link_basis, (from + to) * 0.5)


func _on_trigger_body_entered(body: Node3D) -> void:
	if kind != SPRING or not is_live() or _spring_left > 0.0:
		return
	if not body.has_method(&"launch"):
		return
	var vertical: Variant = body.get(&"velocity")
	if vertical is Vector3 and (vertical as Vector3).y > 2.0:
		return
	_spring_left = spring_cooldown
	Audio.sfx_at(&"spring_boing", global_position)
	body.call(&"launch", spring_launch_speed)
	sprung.emit(self)
	# Squash and stretch on contact.
	var squash := create_tween()
	squash.tween_property(_mesh, "scale", Vector3(_rest_scale.x * 1.18, _rest_scale.y * 0.45, _rest_scale.z * 1.18), 0.06)
	squash.tween_property(_mesh, "scale", Vector3(_rest_scale.x * 0.88, _rest_scale.y * 1.35, _rest_scale.z * 0.88), 0.1).set_trans(Tween.TRANS_SINE)
	squash.tween_property(_mesh, "scale", _rest_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
