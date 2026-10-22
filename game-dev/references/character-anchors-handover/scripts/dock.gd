extends Node2D

signal passenger_boarded(kind: StringName, destination: StringName)
signal passenger_delivered(fare: int)

@export var dock_id: StringName = &"forest"
@export var island_icon: Texture2D
@export var show_art: bool = true
## Where the waiting animal's feet stand (the animals' origin is their feet).
## Island docks get it from their IslandData `stand_point`; Lilyport's dock sets
## it here, measured the same way on the Lilyport base art.
@export var stand_offset: Vector2 = Vector2(-145.0, -12.0)
## Where a delivered passenger lands, relative to `stand_offset`.
const LANDING_FROM_STAND: Vector2 = Vector2(34.0, 6.0)
## Seconds inside the ring before a passenger boards or is delivered.
const DWELL_TIME: float = 1.0

@onready var art: Sprite2D = $DockArt
@onready var waiting: AnimatedSprite2D = $Waiting
@onready var delivered: AnimatedSprite2D = $Delivered
@onready var bubble: Sprite2D = $Bubble
@onready var destination_icon: Sprite2D = $Bubble/DestinationIcon
@onready var heart: Sprite2D = $Heart
@onready var planks: StaticBody2D = $Planks
@onready var coin_fly: Array[Sprite2D] = [$CoinFly1, $CoinFly2, $CoinFly3]
@onready var confetti_dock: CPUParticles2D = $ConfettiDock
@onready var confetti_boat: CPUParticles2D = $ConfettiBoat
## The seated pose of the passenger that is flying on or off the boat. It
## moves with the standing sprite and cross-fades with it, and at the seat end
## it is identical to the boat's seat sprite (texture, scale, rotation,
## bottom anchor), so the hand-over is invisible (feedback round 5).
## One per direction: a delivery and a boarding often fly at the same time.
@onready var seated_on: Sprite2D = $FlyingSeatedOn
@onready var seated_off: Sprite2D = $FlyingSeatedOff

const WHITE_RING: Color = Color(1.0, 1.0, 1.0, 0.10)
const BLUE_RING: Color = Color(0.247, 0.627, 0.91, 0.28)
const GREEN_RING: Color = Color(0.482, 0.831, 0.416, 0.46)
## The speech bubble is drawn 1.75x its round-4 size (feedback round 5). The
## tail offset is measured at the old 0.32 scale and grows with it, so the tail
## tip stays on the animal's mouth.
const BUBBLE_GROWTH: float = 1.75
const BUBBLE_SCALE: float = 0.32 * BUBBLE_GROWTH
const BUBBLE_TAIL_LOCAL: Vector2 = Vector2(-50.0, 40.0) * BUBBLE_GROWTH
const BUBBLE_FLOAT_OFFSET: Vector2 = Vector2(18.0, -12.0)
const MOUTH_OFFSETS: Dictionary = {
	"rabbit": Vector2(16.0, -71.0),
	"hedgehog": Vector2(28.0, -72.0),
	"duck": Vector2(24.0, -82.0)
}

var boat: Node2D
var waiting_kind: StringName = &""
var destination: StringName = &""
var respawn_timer: float = -1.0
var slow_timer: float = 0.0
var ring_color: Color = WHITE_RING
var ring_state: StringName = &"white"
var elapsed: float = 0.0
var boarding_in_progress: bool = false
## While a passenger flies between dock and boat its rotation is animated, so
## the per-frame upright billboarding leaves it alone.
var waiting_flying: bool = false
var delivered_flying: bool = false
const HOP_TIME: float = 0.55
const HOP_ARC: float = 90.0

func _ready() -> void:
	add_to_group(&"docks")
	planks.add_to_group(&"dock_hazard")
	art.visible = show_art
	waiting.position = stand_offset
	waiting.visible = false
	delivered.visible = false
	bubble.visible = false
	bubble.scale = Vector2.ONE * BUBBLE_SCALE
	heart.visible = false
	boat = get_tree().current_scene.get_node_or_null("Boat")
	call_deferred(&"spawn_waiter")

## Moves the standing spot (islands set it from their measured deck anchor).
func set_stand_offset(offset: Vector2) -> void:
	stand_offset = offset
	if not boarding_in_progress:
		waiting.position = stand_offset

func _process(delta: float) -> void:
	elapsed += delta
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			spawn_waiter()
	if boat == null:
		return
	var data: BoatData = boat.get("data") as BoatData
	if data == null:
		return
	var distance: float = global_position.distance_to(boat.global_position)
	var inside: bool = distance <= _ring_radius(data)
	# Feedback round 4: one second anywhere inside the ring does the job, at
	# any speed; the ring fills up to show it.
	var can_board: bool = waiting.visible and not boarding_in_progress and boat.call("has_free_seat")
	var green: bool = inside and (dock_id == &"lilyport" or can_board or _has_delivery())
	if green:
		ring_state = &"green"
	elif inside:
		ring_state = &"blue"
	else:
		ring_state = &"white"
	var target: Color = GREEN_RING if green else (BLUE_RING if inside else WHITE_RING)
	ring_color = ring_color.lerp(target, 1.0 - exp(-delta / 0.15))
	# The dwell timer runs only when there is someone to drop off or pick up.
	# Lilyport's ring is always green (it is also the harbour), so gating on
	# `green` alone had excluded it and nobody could leave or board there.
	if inside and (can_board or _has_delivery()):
		slow_timer += delta
		if slow_timer >= DWELL_TIME:
			slow_timer = 0.0
			_deliver()
			if can_board:
				_board()
	else:
		slow_timer = 0.0
	# The sea camera turns with the boat, so the animals, the heart and the
	# speech bubble stand upright on screen (rotating about their feet and the
	# bubble's tail) instead of lying down with the dock.
	var upright: float = -get_viewport().get_canvas_transform().get_rotation() - global_rotation
	if not waiting_flying:
		waiting.rotation = upright
	if not delivered_flying:
		delivered.rotation = upright
	heart.rotation = upright
	if bubble.visible:
		var mouth_offset: Vector2 = MOUTH_OFFSETS.get(String(waiting_kind), Vector2(0.0, -75.0))
		var mouth_point: Vector2 = waiting.position + mouth_offset.rotated(upright)
		bubble.rotation = upright
		bubble.position = mouth_point + (-BUBBLE_TAIL_LOCAL + BUBBLE_FLOAT_OFFSET + Vector2(0.0, sin(elapsed * TAU / 1.6) * 3.0)).rotated(upright)
	queue_redraw()

func _draw() -> void:
	var radius: float = 270.0
	if boat != null:
		var data: BoatData = boat.get("data") as BoatData
		if data != null:
			radius = _ring_radius(data)
	# Feedback round 5: the ring is only drawn at a drop-off for someone aboard.
	# Pickups stay invisible until the boat is inside, then only the one second
	# progress arc shows.
	var delivering: bool = boat != null and _has_delivery()
	if delivering:
		draw_circle(Vector2.ZERO, radius, Color(ring_color.r, ring_color.g, ring_color.b, 0.025))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, ring_color, 4.0, true)
	if slow_timer > 0.0:
		var fill: float = clampf(slow_timer / DWELL_TIME, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * fill, 96, Color(1.0, 1.0, 1.0, 0.95), 12.0, true)
	# A drop-off waiting for one of the passengers aboard beacons in gold.
	if delivering and ring_state != &"green":
		var beat: float = 0.5 + 0.5 * sin(elapsed * TAU / 1.2)
		draw_arc(Vector2.ZERO, radius + 10.0 + beat * 18.0, 0.0, TAU, 96, Color(1.0, 0.74, 0.01, 0.35 + 0.45 * (1.0 - beat)), 7.0, true)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.74, 0.01, 0.06))

func _standing_height(sprite: AnimatedSprite2D) -> float:
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle", 0) if sprite.sprite_frames != null else null
	return maxf(1.0, texture.get_height() * absf(sprite.scale.y)) if texture != null else 100.0

func _dress_flying_seated(sprite: Sprite2D, kind: StringName) -> void:
	sprite.texture = load("res://assets/images/%s_seated.png" % String(kind))
	sprite.offset = Vector2(0.0, -sprite.texture.get_height() * 0.5)
	sprite.visible = true

## Same bottom anchor, on-screen height and rotation as the boat's seat sprite.
func _pose_flying_seated(sprite: Sprite2D, at: Vector2, height: float, turn: float, alpha: float) -> void:
	sprite.position = at
	sprite.rotation = turn
	sprite.scale = Vector2.ONE * (height / float(sprite.texture.get_height()))
	sprite.modulate.a = alpha

## A hop between two dock-local points, arcing up in the middle.
func _arc(from: Vector2, to: Vector2, t: float) -> Vector2:
	var eased: float = t * t * (3.0 - 2.0 * t)
	return from.lerp(to, eased) + Vector2.UP * HOP_ARC * 4.0 * t * (1.0 - t)

## Small confetti pop where a passenger lands (boat seat or dock).
func _burst(emitter: CPUParticles2D, at: Vector2) -> void:
	emitter.global_position = at + Vector2(0.0, -30.0)
	emitter.restart()

func _ring_radius(data: BoatData) -> float:
	return data.hull_length * 1.1 + 60.0

func get_ring_state() -> StringName:
	return ring_state

func has_waiting_passenger() -> bool:
	return waiting.visible and not boarding_in_progress

func spawn_waiter() -> void:
	var destinations: Array[Node] = get_tree().get_nodes_in_group(&"docks")
	destinations = destinations.filter(func(d: Node) -> bool: return d != self and d is Node2D)
	if destinations.is_empty():
		respawn_timer = 1.0
		return
	destinations.sort_custom(func(a: Node, b: Node) -> bool:
		return global_position.distance_squared_to((a as Node2D).global_position) < global_position.distance_squared_to((b as Node2D).global_position))
	var target: Node = destinations[randi_range(0, mini(1, destinations.size() - 1))] if randf() < 0.5 else destinations[randi_range(mini(2, destinations.size() - 1), destinations.size() - 1)]
	destination = target.get("dock_id")
	destination_icon.texture = target.get("island_icon")
	if destination_icon.texture != null:
		# 15% bigger than round 4 (feedback round 5).
		destination_icon.scale = Vector2.ONE * (184.0 / float(destination_icon.texture.get_height()))
	waiting_kind = [&"rabbit", &"hedgehog", &"duck"].pick_random()
	var frames: SpriteFrames = load("res://assets/animations/passenger_%s.tres" % String(waiting_kind)) as SpriteFrames
	var transforms: AnimationTransformData = load("res://data/passenger_%s_transforms.tres" % String(waiting_kind)) as AnimationTransformData
	waiting.sprite_frames = frames
	waiting.scale = Vector2.ONE * transforms.scale_for(&"idle")
	waiting.offset = transforms.offset_for(&"idle")
	waiting.play(&"idle")
	waiting.visible = true
	waiting.reset_physics_interpolation()
	bubble.visible = true
	respawn_timer = -1.0

func _board() -> void:
	if boarding_in_progress or not waiting.visible or boat == null:
		return
	var destination_dock: Node2D = _find_dock(destination)
	if destination_dock == null:
		return
	boarding_in_progress = true
	var kind_now: StringName = waiting_kind
	var destination_now: StringName = destination
	var fare: int = maxi(15, 15 + 5 * roundi(global_position.distance_to(destination_dock.global_position) / 400.0))
	# Lilyport's bakeries raise every fare.
	fare = roundi(float(fare) * float(get_node("/root/GameState").call("fare_multiplier")))
	var standing_position: Vector2 = waiting.position
	var standing_scale: Vector2 = waiting.scale
	var standing_rotation: float = waiting.rotation
	# Fly to the seat it will take (tracking the boat if it drifts), turning
	# and shrinking into the exact pose of the seated sprite, and only then
	# swap to it (feedback round 5).
	var seat_index: int = int(boat.call("get_seat_count"))
	var standing_height: float = _standing_height(waiting)
	var seated_height: float = float(boat.call("seated_height"))
	_dress_flying_seated(seated_on, kind_now)
	bubble.visible = false
	waiting.z_index = 1
	waiting_flying = true
	get_node("/root/Audio").call("play_sfx", &"hop")
	var hop: Tween = create_tween()
	hop.tween_method(func(t: float) -> void:
		if boat == null:
			return
		var seat_local: Vector2 = to_local(boat.call("seat_point", seat_index))
		var height: float = lerpf(standing_height, seated_height, smoothstep(0.3, 1.0, t))
		var turn: float = lerp_angle(standing_rotation, boat.global_rotation - global_rotation, smoothstep(0.2, 1.0, t))
		var blend: float = smoothstep(0.45, 0.85, t)
		waiting.position = _arc(standing_position, seat_local, t)
		waiting.scale = standing_scale * (height / standing_height)
		waiting.rotation = turn
		waiting.modulate.a = 1.0 - blend
		_pose_flying_seated(seated_on, waiting.position, height, turn, blend), 0.0, 1.0, HOP_TIME)
	await hop.finished
	seated_on.visible = false
	if boat != null:
		_burst(confetti_boat, boat.call("seat_point", seat_index))
	waiting_flying = false
	waiting.position = standing_position
	waiting.scale = standing_scale
	waiting.rotation = standing_rotation
	waiting.modulate.a = 1.0
	waiting.z_index = 0
	waiting.reset_physics_interpolation()
	if boat == null or not bool(boat.call("board_passenger", kind_now, destination_now, dock_id, fare)):
		bubble.visible = true
		boarding_in_progress = false
		return
	waiting.visible = false
	respawn_timer = randf_range(4.0, 10.0)
	passenger_boarded.emit(kind_now, destination_now)
	boarding_in_progress = false

func _deliver() -> void:
	if boat == null:
		return
	var kind_now: StringName = &""
	var seat_index: int = 0
	var onboard_now: Array = boat.get("onboard")
	for index in range(onboard_now.size()):
		if onboard_now[index]["destination"] == dock_id:
			kind_now = onboard_now[index]["kind"]
			seat_index = index
			break
	var seat_global: Vector2 = boat.call("seat_point", seat_index)
	var seat_rotation: float = boat.global_rotation - global_rotation
	var fare: int = int(boat.call("deliver_at", dock_id))
	if fare <= 0:
		return
	if not kind_now.is_empty():
		var frames: SpriteFrames = load("res://assets/animations/passenger_%s.tres" % String(kind_now)) as SpriteFrames
		var transforms: AnimationTransformData = load("res://data/passenger_%s_transforms.tres" % String(kind_now)) as AnimationTransformData
		delivered.sprite_frames = frames
		var full_scale: Vector2 = Vector2.ONE * transforms.scale_for(&"idle")
		delivered.offset = transforms.offset_for(&"idle")
		# Leave from the seat as an exact copy of the seat sprite, then
		# cross-fade to the standing animal while it straightens and grows.
		delivered.scale = full_scale
		var standing_height: float = _standing_height(delivered)
		var seated_height: float = float(boat.call("seated_height"))
		var seat_start: Vector2 = to_local(seat_global)
		_dress_flying_seated(seated_off, kind_now)
		_pose_flying_seated(seated_off, seat_start, seated_height, seat_rotation, 1.0)
		delivered.scale = full_scale * (seated_height / standing_height)
		delivered.rotation = seat_rotation
		delivered.position = seat_start
		delivered.modulate.a = 0.0
		delivered.visible = true
		delivered.play(&"idle")
		# After it is visible, or the first frame interpolates from its old
		# transform. Drawn above the hull while it leaves the boat.
		delivered.reset_physics_interpolation()
		seated_off.reset_physics_interpolation()
		delivered.z_index = 1
		delivered_flying = true
		var landing: Vector2 = stand_offset + LANDING_FROM_STAND
		var upright: float = -get_viewport().get_canvas_transform().get_rotation() - global_rotation
		get_node("/root/Audio").call("play_sfx", &"hop")
		var hop: Tween = create_tween()
		hop.tween_method(func(t: float) -> void:
			var height: float = lerpf(seated_height, standing_height, smoothstep(0.0, 0.7, t))
			var turn: float = lerp_angle(seat_rotation, upright, smoothstep(0.0, 0.8, t))
			var blend: float = 1.0 - smoothstep(0.15, 0.55, t)
			delivered.position = _arc(seat_start, landing, t)
			delivered.scale = full_scale * (height / standing_height)
			delivered.rotation = turn
			delivered.modulate.a = 1.0 - blend
			_pose_flying_seated(seated_off, delivered.position, height, turn, blend), 0.0, 1.0, HOP_TIME)
		await hop.finished
		seated_off.visible = false
		delivered.modulate.a = 1.0
		delivered_flying = false
		_burst(confetti_dock, to_global(landing))
		delivered.z_index = 0
	get_node("/root/Audio").call("play_sfx", &"chime")
	get_node("/root/Audio").call("play_sfx", &"coin")
	heart.visible = true
	heart.scale = Vector2.ZERO
	heart.modulate.a = 1.0
	var heart_tween: Tween = create_tween()
	heart_tween.tween_property(heart, "scale", Vector2.ONE * 0.23, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	heart_tween.tween_interval(0.6)
	heart_tween.tween_property(heart, "modulate:a", 0.0, 0.3)
	heart_tween.tween_callback(func() -> void: heart.visible = false; heart.modulate.a = 1.0)
	_animate_coins()
	await get_tree().create_timer(0.65).timeout
	get_node("/root/GameState").call("add_coins", fare)
	passenger_delivered.emit(fare)
	await get_tree().create_timer(2.0).timeout
	if delivered.visible:
		var fade_out: Tween = create_tween()
		fade_out.tween_property(delivered, "modulate:a", 0.0, 0.5)
		await fade_out.finished
		delivered.visible = false
		delivered.modulate.a = 1.0

func _animate_coins() -> void:
	var hud_target: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * Vector2(85.0, 75.0)
	for index in range(coin_fly.size()):
		var coin: Sprite2D = coin_fly[index]
		coin.global_position = global_position
		coin.scale = Vector2.ONE * 0.12
		coin.visible = true
		var middle: Vector2 = global_position.lerp(hud_target, 0.45) + Vector2(0.0, -120.0 - 24.0 * index)
		var flight: Tween = create_tween()
		flight.tween_interval(0.08 * index)
		flight.tween_property(coin, "global_position", middle, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flight.tween_property(coin, "global_position", hud_target, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		flight.tween_property(coin, "scale", Vector2.ZERO, 0.12)
		flight.tween_callback(Callable(self, "_hide_coin").bind(coin))

func _hide_coin(coin: Sprite2D) -> void:
	coin.visible = false
	coin.scale = Vector2.ONE * 0.12

func _has_delivery() -> bool:
	for passenger in boat.get("onboard"):
		if passenger["destination"] == dock_id:
			return true
	return false

func _find_dock(id: StringName) -> Node2D:
	for candidate in get_tree().get_nodes_in_group(&"docks"):
		if candidate.get("dock_id") == id:
			return candidate as Node2D
	return null
