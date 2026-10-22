class_name PaintManager
extends Node
## Owns the pools of balls and blobs and every rule of the paint (GDD section 9).
##
## What a ball does when it ends:
##   1. It hits a solid surface within range: a blob is placed flush with the surface (a stack when it lands
##      on top of a blob, a flush patch on a wall). Within a blob's reach of a live blob of the same paint it docks:
##      the new blob snaps to the dock distance so overlaps are even.
##   2. A Span ball that reaches maximum range in open air extends the bridge in front of it (see "The Span bridge
##      assist" below): it flies on to the tip of the ribbon and the air dock places a real blob one dock distance
##      beyond the tip, which becomes the new tip. A Grip ball does the same on a wall with a live patch within reach.
##   3. Otherwise it falls with gravity and splashes into the cloud sea.
## Caps: 96 live blobs and 40 balls in flight, all pooled. When the cap is reached the oldest blob dissolves.

## Debug readout per ball: how it ended and the dock distance to its head (GDD 9 acceptance).
signal ball_ended(kind: int, outcome: StringName, dock_distance: float)
signal tag_landed(position: Vector3, kind: int)
signal blob_placed(blob: PaintBlob)
signal splash(position: Vector3, normal: Vector3, kind: int, wasted: bool)
## A Spring pad launched Pip (the effects and the camera answer).
signal spring_launched(position: Vector3)

const SPAN: int = 0
const GRIP: int = 1
const SPRING: int = 2
const WORLD_MASK: int = 1

@export var ball_scene: PackedScene = preload("res://scenes/paint/paint_ball.tscn")
@export var blob_scene: PackedScene = preload("res://scenes/paint/paint_blob.tscn")
## Decorative puddles (a popped enemy, a Grip ball on a floor, a bleach splash) have their own small pool, so they
## never count toward the blob cap and never push a bridge blob out.
@export var puddle_scene: PackedScene = preload("res://scenes/paint/paint_puddle.tscn")
@export var puddle_pool_size: int = 12
## Indexed by paint kind: Span, Grip, Spring, then Bleach (white, never fired by the player).
@export var styles: Array[PaintStyle] = [preload("res://resources/paint_span.tres"), preload("res://resources/paint_grip.tres"), preload("res://resources/paint_spring.tres"), preload("res://resources/paint_bleach.tres")]
@export var balls_path: NodePath = ^"Balls"
@export var blobs_path: NodePath = ^"Blobs"
@export var ball_pool_size: int = 40
## A few spare blobs beyond the cap so dissolving blobs never starve the pool.
@export var blob_pool_size: int = 112
@export var blob_cap: int = 96
@export var dock_snap_reach: float = 2.0
## A wall patch docks to a live patch this close (the reticle ray can never reach a point within about a meter of the
## camera pivot, so a climber whose last patch is level with his chest needs the wider reach to keep the chain going).
@export var patch_snap_reach: float = 3.2
## A Grip ball that ends in open air docks to a live patch whose wall is this close to its end point.
@export var air_dock_reach: float = 8.0
## An air dock closer than this to a live blob of the same paint is redundant and refused.
@export var redundant_distance: float = 1.1
@export var wall_angle_deg: float = 35.0
## A Spring pad is placed on floors and top surfaces only.
@export var spring_min_normal_y: float = 0.7
## A blob never lands inside Pip or an enemy: it is nudged this far toward the aim direction.
@export var nudge_distance: float = 1.2
@export var capsule_radius: float = 0.4
@export var capsule_height: float = 1.5

## The Span bridge assist (Marco, 2026-10-11: a bridge was almost impossible to build by hand, because the old rule
## wanted the aim to hit a 6 m window at the right height for every ball). Now you hold fire and look across the gap:
## the first ball goes to the lip of the ledge Pip stands at, and every Span ball that ends in open air flies on to the
## tip of the ribbon nearest to the line of fire and adds one blob there. The ribbon heads for the line of fire, runs
## level and, when a gap lies ahead, climbs or drops by itself to meet the far side.
## How far from the muzzle, along the line of fire, the tip of a ribbon may be for a ball to extend it.
@export var span_reach: float = 24.0
## How far behind the muzzle a blob still counts as part of the bridge (the first blob lies at Pip's feet).
@export var span_behind: float = 2.0
## How far to the side of the line of fire a blob still counts as part of this bridge: a narrow window next to Pip that
## widens with the distance along the line (a blob lying beside him is not the start of the bridge he is aiming at, but a
## tip far ahead may be a few meters off the line and the ribbon will come back to it).
@export var span_lateral_start: float = 0.9
@export var span_lateral_growth: float = 0.25
@export var span_lateral: float = 3.2
## A blob that would land inside Pip or an enemy slides on along the ribbon by at most this much (the gap between two
## docked blobs then stays under the width of one, so the ribbon is still one road).
@export var span_slide_max: float = 0.45
## The new blob steers for the line of fire this many meters ahead of the tip.
@export var span_lookahead: float = 3.0
## The share of the ribbon's own heading the new blob keeps, so a shaky aim does not bend the bridge, and the most a
## ribbon turns at one blob (a sweep of the camera bends it gradually instead of branching it).
@export_range(0.0, 1.0) var span_persistence: float = 0.4
@export var span_max_turn_deg: float = 35.0
## An aim within this angle of level, with no far side in sight, builds a level ribbon.
@export var span_level_deadzone_deg: float = 7.0
## The steepest climb and drop of a ribbon, as rise over run.
@export var span_slope_up: float = 0.4
@export var span_slope_down: float = 0.24
## When the far side of a gap is found, the ribbon is pulled this much toward the middle of the ground it will land on
## (the chord of the far island at the entry point), so a sloppy aim still lands on the island and not on its rim.
@export_range(0.0, 1.0) var span_landing_pull: float = 0.6
@export var span_landing_depth: float = 2.0
## The far side of a gap is looked for this far ahead of the tip, from this high above it down to this far below it.
@export var span_plan_reach: float = 26.0
@export var span_plan_step: float = 1.0
@export var span_plan_up: float = 10.0
@export var span_plan_down: float = 12.0
## A Span ball never flies farther than this from the muzzle, and is stretched at most this many times.
@export var span_max_flight: float = 28.0
@export var span_max_extensions: int = 6
## A ball counts as arrived when the blob it extends is this close ahead of it or less.
@export var span_arrive_tolerance: float = 0.5
## Looking for the ledge Pip stands at: how far ahead of his feet, in steps of this size. Ground that is lower than the
## drop (or missing) is the other side of the ledge; the first blob lies this far back from the lip. A ball aimed
## steeper than the minimum pitch at the floor is a normal shot, not the start of a bridge.
@export var seed_reach: float = 5.5
@export var seed_step: float = 0.25
@export var seed_drop: float = 0.9
@export var seed_inset: float = 0.3
@export var seed_min_pitch_deg: float = -28.0
@export var recent_outcomes_kept: int = 24

var _balls_free: Array[PaintBall] = []
var _blobs_free: Array[PaintBlob] = []
var _blobs_live: Array[PaintBlob] = []
var _puddles_free: Array[PaintBlob] = []
var _puddles_live: Array[PaintBlob] = []
var _serial: int = 0
var _recent: Array[Dictionary] = []
## How far a ball flies before it ends (read from the pool, so it follows the ball scene).
var _ball_range: float = 7.0


func _ready() -> void:
	add_to_group(&"paint_manager")
	var balls_root: Node = get_node(balls_path)
	var blobs_root: Node = get_node(blobs_path)
	for i: int in ball_pool_size:
		var ball := ball_scene.instantiate() as PaintBall
		balls_root.add_child(ball)
		ball.hit_something.connect(_on_ball_hit)
		ball.range_ended.connect(_on_ball_range_end)
		ball.fell_into_clouds.connect(_on_ball_fell)
		_balls_free.append(ball)
	if not _balls_free.is_empty():
		_ball_range = _balls_free[0].max_range
	for i: int in blob_pool_size:
		var blob := blob_scene.instantiate() as PaintBlob
		blobs_root.add_child(blob)
		blob.expired.connect(_on_blob_expired)
		blob.sprung.connect(_on_blob_sprung)
		_blobs_free.append(blob)
	for i: int in puddle_pool_size:
		var puddle := puddle_scene.instantiate() as PaintBlob
		blobs_root.add_child(puddle)
		puddle.expired.connect(_on_puddle_expired)
		_puddles_free.append(puddle)
	var body_rids: Array[RID] = []
	for blob: PaintBlob in _blobs_free + _puddles_free:
		body_rids.append(blob.body_rid())
	for rig: Node in get_tree().get_nodes_in_group(&"camera_rig"):
		if rig.has_method(&"ignore_bodies"):
			rig.call(&"ignore_bodies", body_rids)


## Fires one ball from the muzzle toward the target (the ink is infinite: a ball only fails when the pool is empty).
## `aim_hit` says whether the reticle ray found a surface (false: it ran out into open air). A Span ball aimed across a
## gap at no ribbon yet goes to the lip of the ledge Pip stands at, so the first blob of a bridge lies where it has to.
func fire(muzzle: Vector3, target: Vector3, kind: int, exclude: Array[RID] = [], aim_hit: bool = true) -> bool:
	if _balls_free.is_empty() or kind < 0 or kind > SPRING:
		return false
	var aim_target: Vector3 = target
	var shooter := get_tree().get_first_node_in_group(&"player") as Node3D
	var line_from: Vector3 = muzzle
	if shooter != null:
		line_from = Vector3(shooter.global_position.x, muzzle.y, shooter.global_position.z)
	if kind == SPAN:
		var lip: Variant = _ledge_seed(muzzle, line_from, target, aim_hit)
		if lip != null:
			aim_target = lip
	var reticle_point: Vector3 = Vector3.INF
	if aim_target != target:
		reticle_point = aim_target
	elif aim_hit and muzzle.distance_to(target) <= _ball_range + 0.5:
		reticle_point = target
	var ball: PaintBall = _balls_free.pop_back()
	ball.launch(muzzle, aim_target - muzzle, styles[kind], exclude, line_from, reticle_point)
	return true


## The live blobs (read only): Erasers look for the trail among them.
func live_blobs() -> Array[PaintBlob]:
	return _blobs_live


## A decorative puddle of a paint (an enemy popped, a glob splashed). `seconds` is how long it stays.
func leave_puddle(point: Vector3, kind: int, seconds: float = 10.0) -> void:
	var down: Dictionary = _surface_ray(point + Vector3.UP * 0.6, point + Vector3.DOWN * 2.0)
	var at: Vector3 = point
	var normal: Vector3 = Vector3.UP
	if not down.is_empty():
		at = down["position"]
		normal = down["normal"]
	var blob: PaintBlob = _spawn_blob(styles[clampi(kind, 0, styles.size() - 1)], at, normal, false, null, true)
	if blob != null:
		blob.lifetime = seconds


## Number of live blobs of every paint.
func live_count() -> int:
	return _blobs_live.size()


## The last ball outcomes, newest last: {kind, outcome, dock_distance}.
func recent_outcomes() -> Array[Dictionary]:
	return _recent


## Nearest live blob of a paint kind within reach of a point (the head to dock to).
func nearest_head(kind: int, point: Vector3, reach: float, want_patch: bool = false) -> PaintBlob:
	var best: PaintBlob = null
	var best_distance: float = reach
	for blob: PaintBlob in _blobs_live:
		if blob.kind != kind or not blob.is_live() or blob.is_patch != want_patch:
			continue
		var distance: float = blob.global_position.distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = blob
	return best


## Dissolves every live blob with the normal animation (F1 "Clear paint").
func clear_paint() -> void:
	for blob: PaintBlob in _blobs_live.duplicate():
		blob.dissolve()
	for puddle: PaintBlob in _puddles_live.duplicate():
		puddle.dissolve()


## Returns every ball and blob to the pool at once (a run reset).
func reset_all() -> void:
	for blob: PaintBlob in _blobs_live.duplicate():
		blob.recycle_now()
	for puddle: PaintBlob in _puddles_live.duplicate():
		puddle.recycle_now()
	for ball: Node in get_node(balls_path).get_children():
		var paint_ball := ball as PaintBall
		if paint_ball != null and paint_ball.state != PaintBall.State.IDLE:
			paint_ball.recycle()
			if not _balls_free.has(paint_ball):
				_balls_free.append(paint_ball)


## Shows or hides the showcase blobs (the concept shots and the title show them, a run hides them).
func set_showcase_visible(value: bool) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"showcase_blob"):
		var blob := node as PaintBlob
		if blob != null:
			blob.set_showcase_visible(value)


func _on_ball_hit(ball: PaintBall, hit: Dictionary) -> void:
	var style: PaintStyle = ball.style
	var position: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"] if hit.has("normal") else Vector3.UP
	var collider: Object = hit["collider"]
	if collider is Node and (collider as Node).has_method(&"accept_tag"):
		var accepted: bool = (collider as Node).call(&"accept_tag", style.kind_index, position, ball.shot_id)
		if accepted:
			RunState.count_tag()
			tag_landed.emit(position, style.kind_index)
		splash.emit(position, normal, style.kind_index, false)
		_finish(ball, &"tag" if accepted else &"clink", 0.0)
		return
	_place_on_surface(ball, position, normal, collider)


func _on_ball_range_end(ball: PaintBall, end_point: Vector3) -> void:
	var kind: int = ball.style.kind_index
	if kind == SPRING:
		ball.note = "spring never air docks"
		ball.begin_fall()
		return
	if kind == SPAN:
		var plan: Dictionary = _plan_span(ball)
		if not plan.is_empty():
			# Fly on to the tip of the ribbon, then add the blob there (the plan is made again on arrival: another ball
			# may have extended the ribbon in the meantime).
			var ahead: float = ((plan["position"] as Vector3) - ball.global_position).dot(ball.direction)
			var flown: float = ball.global_position.distance_to(ball.origin)
			if ahead > span_arrive_tolerance and ball.extensions < span_max_extensions and flown + ahead <= span_max_flight:
				ball.extend_flight(ball.travelled + ahead)
				return
			_air_dock_span(ball, plan)
			return
	elif kind == GRIP:
		var patch: PaintBlob = nearest_head(GRIP, end_point, air_dock_reach, true)
		if patch != null and _air_dock_grip(ball, patch, end_point):
			return
	if ball.note.is_empty():
		ball.note = "no ribbon to extend along the line of fire" if kind == SPAN else "no live patch within %.1f m of the end point" % air_dock_reach
	ball.begin_fall()


func _on_ball_fell(ball: PaintBall, point: Vector3) -> void:
	splash.emit(point, Vector3.UP, ball.style.kind_index, true)
	_finish(ball, &"wasted", 0.0)


func _on_blob_sprung(blob: PaintBlob) -> void:
	spring_launched.emit(blob.global_position)


func _on_blob_expired(blob: PaintBlob) -> void:
	_blobs_live.erase(blob)
	if not _blobs_free.has(blob):
		_blobs_free.append(blob)


func _finish(ball: PaintBall, outcome: StringName, dock_distance: float) -> void:
	var kind: int = ball.style.kind_index
	var note: String = ball.note
	_play_outcome(outcome, kind, ball.global_position, dock_distance)
	ball.recycle()
	if not _balls_free.has(ball):
		_balls_free.append(ball)
	_recent.append({"kind": kind, "outcome": outcome, "dock_distance": dock_distance, "note": note})
	while _recent.size() > recent_outcomes_kept:
		_recent.pop_front()
	ball_ended.emit(kind, outcome, dock_distance)


## The sound of how a ball ended: a wet splat for a placed blob, a chime when it docks, a suction for Grip.
func _play_outcome(outcome: StringName, kind: int, point: Vector3, dock_distance: float) -> void:
	match outcome:
		&"surface", &"stack", &"patch", &"air_dock":
			Audio.sfx_at(&"ball_splat", point)
			if dock_distance > 0.0:
				Audio.sfx_at(&"dock_chime", point, -5.0, 0.04)
			if kind == GRIP:
				Audio.sfx_at(&"grip_suction", point, -3.0)
		&"puddle":
			Audio.sfx_at(&"ball_splat", point, -6.0)
		&"tag":
			Audio.sfx_at(&"tag_hit", point)
		&"clink":
			Audio.sfx_at(&"dry_click", point, 3.0, 0.2)
		_:
			Audio.sfx_at(&"wasted_splat", point, -4.0)


func _place_on_surface(ball: PaintBall, position: Vector3, normal: Vector3, collider: Object) -> void:
	var style: PaintStyle = ball.style
	var kind: int = style.kind_index
	var on_wall: bool = absf(normal.y) <= sin(deg_to_rad(wall_angle_deg))
	var stacked: bool = collider is Node and (collider as Node).get_parent() is PaintBlob and normal.y > 0.7
	if kind == SPRING and normal.y < spring_min_normal_y:
		splash.emit(position, normal, kind, true)
		_finish(ball, &"wasted", 0.0)
		return
	if kind == GRIP and not on_wall:
		# A Grip ball on a floor leaves a decorative puddle that does nothing.
		var puddle_at: Vector3 = _nudge_clear_of_bodies(position, normal, ball.direction)
		_spawn_blob(style, puddle_at, normal, false, null, true)
		splash.emit(puddle_at, normal, kind, false)
		_finish(ball, &"puddle", 0.0)
		return
	var as_patch: bool = on_wall
	var aim: Vector3 = ball.direction
	var dock_distance: float = 0.0
	var parent: PaintBlob = null
	var placed_position: Vector3 = position
	var placed_normal: Vector3 = normal
	var head: PaintBlob = null
	if not stacked:
		head = nearest_head(kind, position, patch_snap_reach if as_patch else dock_snap_reach, as_patch)
	if head != null:
		var spacing: float = style.dock_distance
		var offset: Vector3 = position - head.global_position
		offset -= normal * offset.dot(normal)
		if offset.length_squared() < 0.0001:
			offset = aim - normal * aim.dot(normal)
		if offset.length_squared() > 0.0001:
			var snapped_to: Vector3 = head.global_position + offset.normalized() * spacing
			var seat: Dictionary = _surface_ray(snapped_to + normal * 0.7, snapped_to - normal * 0.7)
			if not seat.is_empty():
				placed_position = seat["position"]
				placed_normal = seat["normal"]
				if kind != SPRING:
					parent = head
				dock_distance = spacing
	placed_position = _nudge_clear_of_bodies(placed_position, placed_normal, aim)
	if _overlaps_body(placed_position) or _inside_solid(placed_position + placed_normal * 0.12):
		splash.emit(position, normal, kind, true)
		_finish(ball, &"wasted", 0.0)
		return
	_spawn_blob(style, placed_position, placed_normal, as_patch, parent)
	splash.emit(placed_position, placed_normal, kind, false)
	var outcome: StringName = &"stack" if stacked else (&"patch" if as_patch else &"surface")
	_finish(ball, outcome, dock_distance)


func _air_dock_span(ball: PaintBall, plan: Dictionary) -> void:
	var style: PaintStyle = ball.style
	var head: PaintBlob = plan["head"]
	var placed: Vector3 = plan["position"]
	# A blob never lands inside Pip or an enemy: it slides on along the ribbon, but only as far as the gap to its
	# neighbor stays closed. A hole in the ribbon would be worse than a wasted ball, so past that the dock is refused.
	var slid: float = 0.0
	while _overlaps_body(placed) and slid < span_slide_max:
		slid += 0.15
		placed += (plan["toward"] as Vector3) * 0.15
	if _already_covered(placed, style.kind_index):
		ball.note = "air dock refused: the trail already covers the end point"
		ball.begin_fall()
		return
	if _inside_solid(placed + Vector3.UP * 0.15) or _overlaps_body(placed):
		ball.note = "air dock refused: inside solid or overlapping a body"
		ball.begin_fall()
		return
	# On a climb or a drop the blob lies along the slope, so the ribbon is a ramp Pip walks up without a step.
	var toward: Vector3 = plan["toward"]
	var run: float = Vector2(placed.x - head.global_position.x, placed.z - head.global_position.z).length()
	var lie: Vector3 = Vector3.UP
	var rise: float = placed.y - head.global_position.y
	if run > 0.01 and absf(rise) > 0.02:
		var slope: float = rise / run
		lie = Vector3(-toward.x * slope, 1.0, -toward.z * slope).normalized()
	_spawn_blob(style, placed, lie, false, head)
	splash.emit(placed, lie, style.kind_index, false)
	_finish(ball, &"air_dock", style.dock_distance)


## The blob at the tip of the ribbon nearest to a line of fire: of the Span blobs that have no blob docked after them (the
## tips of the ribbons), the one farthest along the line, within the lateral tolerance and within reach. Only tips
## count, so a ribbon is one chain that grows from its end: aiming elsewhere never starts a branch from its middle.
## Null when there is none.
func _find_span_head(line_from: Vector3, direction: Vector3) -> PaintBlob:
	var forward := Vector3(direction.x, 0.0, direction.z)
	if forward.length_squared() < 0.04:
		return null
	forward = forward.normalized()
	var has_child: Dictionary = {}
	for blob: PaintBlob in _blobs_live:
		var parent: PaintBlob = blob.dock_parent
		# A recycled blob keeps its old children's pointers: only a parent older than the child is a real parent.
		if parent != null and is_instance_valid(parent) and parent.serial < blob.serial:
			has_child[parent] = true
	var best: PaintBlob = null
	var best_along: float = -INF
	for blob: PaintBlob in _blobs_live:
		if blob.kind != SPAN or blob.is_patch or not blob.is_live() or has_child.has(blob):
			continue
		var rel: Vector3 = blob.global_position - line_from
		var along: float = rel.x * forward.x + rel.z * forward.z
		if along < -span_behind or along > span_reach:
			continue
		var allowed: float = minf(span_lateral, span_lateral_start + span_lateral_growth * maxf(along, 0.0))
		if absf(rel.x * forward.z - rel.z * forward.x) > allowed:
			continue
		if along > best_along:
			best_along = along
			best = blob
	return best


## Where the next blob of the bridge goes: {head, position}, or an empty dictionary when there is no ribbon to extend.
## One dock distance beyond the tip, toward the line of fire a few meters ahead (so the ribbon comes back to the line
## when it strayed), keeping part of its own heading, at the height `_span_rise` gives.
func _plan_span(ball: PaintBall) -> Dictionary:
	var head: PaintBlob = _find_span_head(ball.line_origin, ball.direction)
	if head == null:
		return {}
	var forward := Vector3(ball.direction.x, 0.0, ball.direction.z).normalized()
	var tip: Vector3 = head.global_position
	var rel: Vector3 = tip - ball.line_origin
	var along: float = rel.x * forward.x + rel.z * forward.z
	var steer_for: Vector3 = ball.line_origin + forward * (along + span_lookahead)
	var toward := Vector3(steer_for.x - tip.x, 0.0, steer_for.z - tip.z).normalized()
	if head.dock_parent != null and is_instance_valid(head.dock_parent):
		var parent_at: Vector3 = head.dock_parent.global_position
		var heading := Vector3(tip.x - parent_at.x, 0.0, tip.z - parent_at.z)
		if heading.length_squared() > 0.01:
			heading = heading.normalized()
			toward = _limit_turn(heading, toward.lerp(heading, span_persistence).normalized())
			var landing: Dictionary = _landing_ahead(tip, toward)
			if not landing.is_empty():
				var landing_at: Vector3 = landing["point"]
				var pull := Vector3(landing_at.x - tip.x, 0.0, landing_at.z - tip.z).normalized()
				toward = _limit_turn(heading, toward.lerp(pull, span_landing_pull).normalized())
	var spacing: float = ball.style.dock_distance
	var placed: Vector3 = tip + toward * spacing
	placed.y = tip.y + _span_rise(tip, toward, ball.direction, spacing)
	return {"head": head, "position": placed, "toward": toward}


## `toward` turned back so it is at most the maximum turn away from `heading`.
func _limit_turn(heading: Vector3, toward: Vector3) -> Vector3:
	var turn: float = heading.angle_to(toward)
	var limit: float = deg_to_rad(span_max_turn_deg)
	if turn > limit:
		return heading.slerp(toward, limit / turn).normalized()
	return toward


## How far above (or below) the tip the next blob sits: level by default; when a gap lies ahead the ribbon climbs or
## drops evenly to meet the far side; with no far side in sight an aim clearly above or below level bends it that way.
func _span_rise(tip: Vector3, toward: Vector3, direction: Vector3, spacing: float) -> float:
	var limit_up: float = span_slope_up * spacing
	var limit_down: float = span_slope_down * spacing
	var landing: Dictionary = _landing_ahead(tip, toward)
	if not landing.is_empty():
		var run: float = maxf(float(landing["distance"]), spacing)
		return clampf((float(landing["height"]) - tip.y) * spacing / run, -limit_down, limit_up)
	var pitch: float = asin(clampf(direction.y, -1.0, 1.0))
	if absf(pitch) <= deg_to_rad(span_level_deadzone_deg):
		return 0.0
	return clampf(tan(pitch) * spacing, -limit_down, limit_up)


## Walks out from the tip of a ribbon and returns the height of the first reachable ground found after open air (the far
## side of a gap) as {height, distance, point}, or an empty dictionary when there is none within the plan reach. Ground
## that the ribbon could not climb or drop to in the distance left (the top of a tower a few meters ahead and eight above)
## does not count, as ground or as a gap: the ribbon heads for the platform it can actually reach.
func _landing_ahead(tip: Vector3, toward: Vector3) -> Dictionary:
	var seen_void: bool = _surface_ray(tip + Vector3.UP * 0.4, tip + Vector3.DOWN * 1.2).is_empty()
	for step: int in range(1, int(span_plan_reach / span_plan_step) + 1):
		var distance: float = span_plan_step * float(step)
		var column: Vector3 = tip + toward * distance
		var ground: Dictionary = _reachable_ground(column, tip.y, distance)
		if ground.is_empty():
			seen_void = true
		elif seen_void:
			var height: float = (ground["position"] as Vector3).y
			return {"height": height, "distance": distance, "point": _landing_middle(tip, toward, distance, height)}
	return {}


## The top facing surface in a column of space that is closest to a height and within what a ribbon can climb or drop over
## `distance` (with a meter to spare), or an empty dictionary. A column holds several surfaces where islands overlap in view.
func _reachable_ground(column: Vector3, from_y: float, distance: float) -> Dictionary:
	var best: Dictionary = {}
	var best_gap: float = INF
	var top: float = from_y + span_plan_up
	for attempt: int in 5:
		var hit: Dictionary = _surface_ray(Vector3(column.x, top, column.z), Vector3(column.x, from_y - span_plan_down, column.z))
		if hit.is_empty():
			break
		var y: float = (hit["position"] as Vector3).y
		top = y - 0.1
		if (hit["normal"] as Vector3).y < 0.5:
			continue
		var rise: float = y - from_y
		if rise > span_slope_up * distance + 1.0 or -rise > span_slope_down * distance + 1.0:
			continue
		if absf(rise) < best_gap:
			best_gap = absf(rise)
			best = hit
	return best


## The middle of the ground that the ribbon will land on: a little way in from the entry column, the stretch of ground across
## the line (up to 5 m each way) that is unbroken around the line, and its center.
func _landing_middle(tip: Vector3, toward: Vector3, distance: float, height: float) -> Vector3:
	var side := Vector3(-toward.z, 0.0, toward.x)
	var base: Vector3 = tip + toward * (distance + span_landing_depth)
	var edges: Array[float] = [0.0, 0.0]
	for direction: int in 2:
		var sign: float = 1.0 if direction == 0 else -1.0
		for k: int in range(1, 6):
			var column: Vector3 = base + side * (sign * float(k))
			if _reachable_ground(column, height, 0.0).is_empty():
				break
			edges[direction] = float(k)
	var middle: Vector3 = base + side * ((edges[0] - edges[1]) * 0.5)
	middle.y = height
	return middle


## The point on the floor, a little back from the lip, of the ledge Pip stands at, when a Span shot is the start of a
## bridge: aimed across a gap (not at something within reach, not steeply down) with no ribbon along the line of fire
## yet. Null in every other case, and the shot goes where it was aimed.
func _ledge_seed(muzzle: Vector3, line_from: Vector3, target: Vector3, aim_hit: bool) -> Variant:
	var pip := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if pip == null or not pip.is_on_floor():
		return null
	var line: Vector3 = target - muzzle
	if line.length_squared() < 0.0001:
		return null
	var direction: Vector3 = line.normalized()
	if aim_hit and line.length() <= _ball_range + 0.5:
		return null
	if direction.y < sin(deg_to_rad(seed_min_pitch_deg)) or Vector2(direction.x, direction.z).length() < 0.3:
		return null
	if _find_span_head(line_from, direction) != null:
		return null
	var forward := Vector3(direction.x, 0.0, direction.z).normalized()
	var feet: Vector3 = pip.global_position
	var last_ground: Vector3 = feet
	var lip_found: bool = false
	for step: int in range(1, int(seed_reach / seed_step) + 1):
		var column: Vector3 = feet + forward * (seed_step * float(step))
		var ground: Dictionary = _ground_at(column, feet.y)
		if ground.is_empty():
			# A wall ahead also reads as missing ground (the ray starts inside it): that is not a ledge.
			var wall: Dictionary = _surface_ray(feet + Vector3.UP * 0.6, column + Vector3.UP * 0.6)
			if not wall.is_empty():
				return null
			lip_found = true
			break
		last_ground = ground["position"]
	if not lip_found:
		return null
	# The lip lies between the last ground and the first missing ground: halve the interval a few times.
	var lo: float = 0.0
	var hi: float = seed_step
	for refine: int in 4:
		var mid: float = (lo + hi) * 0.5
		if _ground_at(last_ground + forward * mid, feet.y).is_empty():
			hi = mid
		else:
			lo = mid
	var seat: Vector3 = last_ground + forward * lo - forward * seed_inset
	var floor_hit: Dictionary = _ground_at(seat, feet.y)
	if floor_hit.is_empty():
		return null
	seat = floor_hit["position"]
	if seat.distance_to(muzzle) > _ball_range - 0.3:
		return null
	return seat


## The floor under a point: a ray from a little above Pip's feet down to the drop distance below them, against the
## level only. Ground lower than that counts as missing.
func _ground_at(column: Vector3, feet_y: float) -> Dictionary:
	var hit: Dictionary = _surface_ray(Vector3(column.x, feet_y + 0.5, column.z), Vector3(column.x, feet_y - seed_drop - 0.5, column.z))
	if hit.is_empty() or (hit["position"] as Vector3).y < feet_y - seed_drop:
		return {}
	return hit


## The air dock of a wall patch projects the end point onto the wall plane of the head.
func _air_dock_grip(ball: PaintBall, head: PaintBlob, end_point: Vector3) -> bool:
	var style: PaintStyle = ball.style
	var wall_normal: Vector3 = head.global_basis.y.normalized()
	var projected: Vector3 = end_point - wall_normal * (end_point - head.global_position).dot(wall_normal)
	var along: Vector3 = projected - head.global_position
	if along.length_squared() < 0.0001:
		return false
	var placed: Vector3 = head.global_position + along.normalized() * style.dock_distance
	var seat: Dictionary = _surface_ray(placed + wall_normal * 0.5, placed - wall_normal * 0.8)
	if seat.is_empty():
		return false
	placed = seat["position"]
	var seat_normal: Vector3 = seat["normal"]
	if _already_covered(placed, style.kind_index, true):
		ball.note = "air dock refused: the trail already covers the end point"
		return false
	_spawn_blob(style, placed, seat_normal, true, head)
	splash.emit(placed, seat_normal, style.kind_index, false)
	_finish(ball, &"air_dock", style.dock_distance)
	return true


func _spawn_blob(style: PaintStyle, position: Vector3, normal: Vector3, as_patch: bool, parent: PaintBlob, decor: bool = false) -> PaintBlob:
	if decor:
		return _spawn_puddle(style, position, normal)
	if _blobs_live.size() >= blob_cap:
		var oldest: PaintBlob = _oldest_live()
		if oldest != null:
			oldest.dissolve()
	if _blobs_free.is_empty():
		var fallback: PaintBlob = _oldest_live()
		if fallback == null:
			return null
		fallback.recycle_now()
	var blob: PaintBlob = _blobs_free.pop_back()
	_serial += 1
	blob.activate(style, Transform3D(_surface_basis(normal), position + normal * 0.004), as_patch, parent, _serial, decor)
	_blobs_live.append(blob)
	blob_placed.emit(blob)
	return blob


## A decorative puddle from its own pool: when every puddle is out, the oldest one makes room.
func _spawn_puddle(style: PaintStyle, position: Vector3, normal: Vector3) -> PaintBlob:
	if _puddles_free.is_empty():
		if _puddles_live.is_empty():
			return null
		_puddles_live[0].recycle_now()
	var puddle: PaintBlob = _puddles_free.pop_back()
	_serial += 1
	puddle.activate(style, Transform3D(_surface_basis(normal), position + normal * 0.004), false, null, _serial, true)
	_puddles_live.append(puddle)
	return puddle


func _on_puddle_expired(puddle: PaintBlob) -> void:
	_puddles_live.erase(puddle)
	if not _puddles_free.has(puddle):
		_puddles_free.append(puddle)


func _oldest_live() -> PaintBlob:
	var oldest: PaintBlob = null
	for blob: PaintBlob in _blobs_live:
		if blob.is_live() and (oldest == null or blob.serial < oldest.serial):
			oldest = blob
	return oldest


## A basis whose up axis is the surface normal, with a random spin around it for variety.
func _surface_basis(normal: Vector3) -> Basis:
	var tilt: Basis = Basis.IDENTITY
	if normal.dot(Vector3.UP) < -0.999:
		tilt = Basis(Vector3.RIGHT, PI)
	elif normal.dot(Vector3.UP) < 0.999:
		tilt = Basis(Quaternion(Vector3.UP, normal))
	return tilt * Basis(Vector3.UP, randf() * TAU)


## True when a live blob of the same paint already sits within `redundant_distance` of a point.
func _already_covered(point: Vector3, kind: int, patches: bool = false) -> bool:
	for blob: PaintBlob in _blobs_live:
		if blob.kind != kind or blob.is_patch != patches or not blob.is_live():
			continue
		var offset: Vector3 = blob.global_position - point
		if patches:
			if offset.length() < redundant_distance:
				return true
		elif Vector2(offset.x, offset.z).length() < redundant_distance and absf(offset.y) < 0.6:
			return true
	return false


## The bodies of every live blob: queries that look for the level itself skip them.
func _blob_bodies() -> Array[RID]:
	var rids: Array[RID] = []
	for blob: PaintBlob in _blobs_live:
		rids.append(blob.body_rid())
	return rids


## A ray against the level only (blobs excluded), used to seat a docked blob on the surface it belongs to.
func _surface_ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	query.exclude = _blob_bodies()
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)


func _inside_solid(point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collision_mask = WORLD_MASK
	query.collide_with_bodies = true
	query.exclude = _blob_bodies()
	return not get_viewport().world_3d.direct_space_state.intersect_point(query, 1).is_empty()


## The body (Pip or an enemy) a blob placed at this point would overlap, or null.
func _overlapping_body(point: Vector3) -> Node3D:
	for group_name: StringName in [&"player", &"enemy"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			var body := node as Node3D
			if body == null or not body.is_visible_in_tree():
				continue
			var horizontal: float = Vector2(point.x - body.global_position.x, point.z - body.global_position.z).length()
			var feet: float = body.global_position.y
			if horizontal < styles[SPAN].radius * 0.9 + capsule_radius and feet < point.y + styles[SPAN].thickness - 0.02 and feet + capsule_height > point.y:
				return body
	return null


func _overlaps_body(point: Vector3) -> bool:
	return _overlapping_body(point) != null


## A step shot or a ground shot that would overlap Pip or an enemy is nudged toward the aim direction.
func _nudge_clear_of_bodies(point: Vector3, normal: Vector3, aim: Vector3) -> Vector3:
	var body: Node3D = _overlapping_body(point)
	if body == null:
		return point
	var push: Vector3 = Vector3(aim.x, 0.0, aim.z)
	if push.length_squared() < 0.0001 and body.has_method(&"facing_direction"):
		push = body.call(&"facing_direction")
	if push.length_squared() < 0.0001:
		return point
	var moved: Vector3 = point + push.normalized() * nudge_distance
	var seat: Dictionary = _surface_ray(moved + normal * 0.6, moved - normal * 0.9)
	if not seat.is_empty():
		moved = seat["position"]
	return moved
