class_name PaintBall
extends Node3D
## A pooled paint ball (GDD section 9.2).
##
## It leaves the Gauntlet muzzle at 40 m/s toward the aim target and flies at most 7 m of path. Each
## physics frame it sweeps a ray from its old to its new position (so a fast ball never tunnels), and it
## only reports what happened: the PaintManager decides what each ending means (surface, stack, air dock
## or wasted). It never collides with Pip, with its own paint or with other balls.

signal hit_something(ball: PaintBall, hit: Dictionary)
signal range_ended(ball: PaintBall, end_point: Vector3)
signal fell_into_clouds(ball: PaintBall, point: Vector3)

enum State { IDLE, FLYING, FALLING }

@export var mesh_path: NodePath = ^"Mesh"
@export var trail_path: NodePath = ^"Trail"
@export var speed: float = 40.0
@export var max_range: float = 7.0
@export var fall_gravity: float = 6.0
## A ball only lands on top of a blob (a stack) when it comes down at least this steeply, in degrees below the
## horizontal. A shallower ball flies over the paint it passes, so holding fire along a bridge never builds pillars.
@export_range(0.0, 80.0) var stack_min_pitch_deg: float = 30.0
## Horizontal speed kept once the ball runs out of range with no head in reach (it arcs away and falls).
@export var fall_forward_speed: float = 5.0
## Height of the cloud sea surface: a falling ball splashes here.
@export var cloud_level: float = -12.0
## World, Enemies, Paint and Hurtboxes.
@export_flags_3d_physics var hit_mask: int = 1 | 4 | 8 | 64

static var _next_shot_id: int = 1

var style: PaintStyle
## A unique number per launch (pooled balls are reused, so the instance id cannot identify a shot).
var shot_id: int = 0
var state: State = State.IDLE
var direction: Vector3 = Vector3.FORWARD
var velocity: Vector3 = Vector3.ZERO
var travelled: float = 0.0
## Why the ball ended the way it did (read by the debug panel).
var note: String = ""
## Where the ball left the muzzle.
var origin: Vector3 = Vector3.ZERO
## Where the line of fire of a Span bridge starts: the shooter's own axis at muzzle height, not the muzzle itself (the
## Gauntlet is on his right hand, and a ribbon planned from the muzzle would run half a meter to the right of him).
var line_origin: Vector3 = Vector3.ZERO
## The point the reticle ray found, when it is within the ball's range: the paint lands there. A level surface the ball meets
## on the way (the edge of a crate beside Pip's hand: the muzzle sits to the side of the camera) is flown through, so a shot
## never splashes beside what the reticle was on.
var aim_point: Vector3 = Vector3.INF
## How far from the aim point a level surface may be and still stop the ball.
@export var aim_slack: float = 0.9
## How many times the manager stretched this flight to reach the tip of the bridge it extends.
var extensions: int = 0

var _mesh: MeshInstance3D
var _trail: GPUParticles3D
var _exclude: Array[RID] = []
var _base_range: float = 7.0


func _ready() -> void:
	_mesh = get_node(mesh_path) as MeshInstance3D
	_trail = get_node_or_null(trail_path) as GPUParticles3D
	_base_range = max_range
	_idle()


## Starts the flight from the muzzle toward a direction.
func launch(from: Vector3, toward: Vector3, new_style: PaintStyle, exclude: Array[RID], line_from: Vector3 = Vector3.INF, reticle_point: Vector3 = Vector3.INF) -> void:
	style = new_style
	_exclude = exclude
	direction = toward.normalized()
	velocity = direction * speed
	travelled = 0.0
	max_range = _base_range
	extensions = 0
	origin = from
	line_origin = from if line_from == Vector3.INF else line_from
	aim_point = reticle_point
	note = ""
	shot_id = _next_shot_id
	_next_shot_id += 1
	state = State.FLYING
	global_position = from
	visible = true
	_mesh.material_override = style.ball_material
	if _trail != null:
		_trail.material_override = style.ball_material
		_trail.restart()
		_trail.emitting = true
	set_physics_process(true)
	reset_physics_interpolation()


## A Span ball that ends in open air flies on to the tip of the bridge it extends: the flight is stretched to `total`
## meters from the muzzle, so the ball is seen landing on the new blob instead of vanishing short of it.
func extend_flight(total: float) -> void:
	max_range = maxf(max_range, total)
	extensions += 1


## No head in reach: the ball arcs away with gravity and splashes into the cloud sea.
func begin_fall() -> void:
	state = State.FALLING
	aim_point = Vector3.INF
	velocity = direction * fall_forward_speed


## Back to the pool.
func recycle() -> void:
	_idle()


func _idle() -> void:
	state = State.IDLE
	visible = false
	if _trail != null:
		_trail.emitting = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_fly(delta)
		State.FALLING:
			_fall(delta)


func _fly(delta: float) -> void:
	var step: float = minf(speed * delta, max_range - travelled)
	var from: Vector3 = global_position
	var to: Vector3 = from + direction * step
	var hit: Dictionary = _cast(from, to)
	if not hit.is_empty():
		global_position = hit["position"]
		hit_something.emit(self, hit)
		return
	global_position = to
	travelled += step
	if travelled >= max_range - 0.0001:
		range_ended.emit(self, global_position)


func _fall(delta: float) -> void:
	velocity.y -= fall_gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var hit: Dictionary = _cast(from, to)
	if not hit.is_empty():
		global_position = hit["position"]
		hit_something.emit(self, hit)
		return
	global_position = to
	if to.y < cloud_level:
		fell_into_clouds.emit(self, to)


## Sweeps the segment. Paint blobs only stop a ball on their top face and only when it comes down steeply (a
## stack): their sides and undersides are passed through, and so are their tops for a shallow ball, so a ball
## never plasters itself on the trail it is extending.
func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var skipped: Array[RID] = _exclude.duplicate()
	var steep: bool = (to - from).normalized().y < -sin(deg_to_rad(stack_min_pitch_deg))
	for attempt: int in 8:
		var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask)
		query.collide_with_areas = true
		query.exclude = skipped
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return hit
		var collider := hit["collider"] as Node
		if collider != null and collider.get_parent() is PaintBlob and (not steep or (hit["normal"] as Vector3).y < 0.7):
			skipped.append(hit["rid"])
			continue
		if aim_point != Vector3.INF and collider is StaticBody3D and (hit["position"] as Vector3).distance_to(aim_point) > aim_slack:
			skipped.append(hit["rid"])
			continue
		return hit
	return {}
