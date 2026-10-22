extends Node2D
## Paints one layer of the boat's foam into the foam mask (a SubViewport that
## mirrors the main camera, see sea.gd). The water shader turns the mask into
## foam with its own cell texture, so wake and sea are one surface.
##
## The trail is a triangle strip drawn straight through the RenderingServer so
## every point carries its exact age in UV.x (shaders/foam_mask.gdshader); a
## Line2D could only stretch UVs over its whole length, which made the foam
## jump whenever the trail grew or shrank. Points can also drift outward as
## they age, which draws the two bow-wave arms of a real wake.

@export var boat_path: NodePath
@export var lifetime: float = 2.4
@export var sample_distance: float = 9.0
## Ribbon width in hull widths when a point is laid, and when it dies.
@export var width_start: float = 0.9
@export var width_end: float = 2.6
## Where the trail is laid along the hull: 0.4 is the stern, negative is
## towards the bow. `lateral_fraction` moves it sideways in hull widths.
@export_range(-0.6, 0.6, 0.01) var longitudinal_fraction: float = 0.40
@export_range(-1.0, 1.0, 0.01) var lateral_fraction: float = 0.0
## Outward drift per second as a share of the boat's speed when laid (bow arms).
@export var spread_ratio: float = 0.0
@export_range(0.0, 1.0, 0.01) var strength: float = 1.0
## Below this share of max speed no new foam is laid.
@export_range(0.0, 1.0, 0.01) var min_speed_fraction: float = 0.10

var boat: Node2D
var origins: Array[Vector2] = []
var outwards: Array[Vector2] = []
var times: Array[float] = []
var speeds: Array[float] = []
var laying: bool = false
var head: Vector2 = Vector2.ZERO
var head_outward: Vector2 = Vector2.ZERO
var head_speed: float = 0.0

func _ready() -> void:
	boat = get_node_or_null(boat_path) as Node2D

func _process(_delta: float) -> void:
	if boat == null:
		return
	var motion: BoatMotion = boat.get("motion") as BoatMotion
	var data: BoatData = boat.get("data") as BoatData
	if motion == null or data == null:
		return
	var now: float = Time.get_ticks_msec() * 0.001
	var right: Vector2 = Vector2.RIGHT.rotated(boat.rotation)
	var back: Vector2 = Vector2.DOWN.rotated(boat.rotation)
	head = boat.global_position + back * data.hull_length * longitudinal_fraction + right * data.hull_width * lateral_fraction
	head_outward = right * signf(lateral_fraction)
	var speed: float = motion.velocity.length()
	head_speed = speed / data.max_speed
	laying = boat.visible and head_speed > min_speed_fraction
	# A teleport (respawn, debug jump) must not draw foam across the map.
	if not origins.is_empty() and origins.back().distance_to(head) > data.hull_length * 1.5:
		clear_trail()
	if laying and (origins.is_empty() or origins.back().distance_to(head) >= sample_distance):
		origins.append(head)
		outwards.append(head_outward * speed * spread_ratio)
		times.append(now)
		speeds.append(head_speed)
	while not times.is_empty() and now - times.front() > lifetime:
		origins.pop_front()
		outwards.pop_front()
		times.pop_front()
		speeds.pop_front()
	queue_redraw()

func _draw() -> void:
	var data: BoatData = boat.get("data") as BoatData if boat != null else null
	if data == null:
		return
	var now: float = Time.get_ticks_msec() * 0.001
	var centres: PackedVector2Array = PackedVector2Array()
	var ages: PackedFloat32Array = PackedFloat32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	for index in range(origins.size()):
		var seconds: float = now - times[index]
		centres.append(origins[index] + outwards[index] * seconds)
		ages.append(clampf(seconds / lifetime, 0.0, 1.0))
		weights.append(speeds[index])
	if laying:
		centres.append(head)
		ages.append(0.0)
		weights.append(head_speed)
	var count: int = centres.size()
	if count < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	for index in range(count):
		var previous: Vector2 = centres[maxi(0, index - 1)]
		var following: Vector2 = centres[mini(count - 1, index + 1)]
		var along: Vector2 = (following - previous).normalized()
		if along == Vector2.ZERO:
			along = Vector2.UP
		var normal: Vector2 = Vector2(-along.y, along.x)
		var speed_share: float = clampf(weights[index], 0.0, 1.0)
		var half_width: float = data.hull_width * lerpf(width_start, width_end, pow(ages[index], 0.7)) * 0.5 * lerpf(0.55, 1.0, speed_share)
		points.append(centres[index] + normal * half_width)
		points.append(centres[index] - normal * half_width)
		var tint: Color = Color(1.0, 1.0, 1.0, strength * lerpf(0.45, 1.0, speed_share))
		colors.append(tint)
		colors.append(tint)
		uvs.append(Vector2(ages[index], 0.0))
		uvs.append(Vector2(ages[index], 1.0))
	var indices: PackedInt32Array = PackedInt32Array()
	for index in range(count - 1):
		var a: int = index * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors, uvs)

## Drops the whole trail at once (respawn, teleport).
func clear_trail() -> void:
	origins.clear()
	outwards.clear()
	times.clear()
	speeds.clear()
	queue_redraw()
