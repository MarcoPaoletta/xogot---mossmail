extends Node2D

@onready var boat: CharacterBody2D = $Boat
@onready var camera: Camera2D = $Boat/Camera
@onready var water: ColorRect = $WaterLayer/Water
@onready var foam_viewport: SubViewport = $FoamViewport
@onready var concept_pose: Marker2D = $ConceptPose
@onready var lilyport_dock: Node2D = $LilyportDock
@onready var decorations: Array[Sprite2D] = [$LilyPadsPort, $LilyPadsNorth, $LilyPadsSouth, $ReedsWest, $ReedsEast, $ReedsNorth]

const WORLD_RECT: Rect2 = Rect2(0.0, 0.0, 4800.0, 2700.0)
## The foam mask renders at this share of the screen resolution; the water
## shader filters it and cuts crisp foam edges with its own cells.
const FOAM_MASK_SCALE: float = 0.5
## How far the camera dives into Lilyport's island when sailing home.
const TRAVEL_ZOOM: float = 1.3
const RESPAWN_POINT: Vector2 = Vector2(1370.0, 2100.0)
const BOUNDARY_BAND: float = 200.0
const CRASH_ROCK_THRESHOLD: float = 0.15
const CRASH_SHORE_THRESHOLD: float = 0.4
const CRASH_DAMAGE_MIN: float = 8.0
const CRASH_DAMAGE_MAX: float = 26.0
const CRASH_INVULNERABLE_TIME: float = 0.7

var last_crash_time: float = -10.0

var overview: bool = false
var sinking: bool = false
var decoration_origins: Array[Vector2] = []
var scene_time: float = 0.0

func _ready() -> void:
	boat.connect(&"impact", Callable(self, "_on_boat_impact"))
	# One water surface: the boat's foam mask feeds the water shader. The
	# material is shared with the town and the title backdrop, so the sea
	# takes its own copy before plugging in a texture that dies with it.
	water.material = water.material.duplicate()
	(water.material as ShaderMaterial).set_shader_parameter(&"foam_mask", foam_viewport.get_texture())
	for decoration in decorations:
		decoration_origins.append(decoration.position)
	get_node("/root/Audio").call("set_context", &"sea")
	get_node("/root/Fade").call("prefetch", "res://scenes/town/Lilyport.tscn")
	var state: Node = get_node("/root/GameState")
	var saved_onboard: Array = state.call("take_onboard_manifest")
	if not saved_onboard.is_empty():
		boat.set("onboard", saved_onboard)
		boat.call("seat_sprites_refresh")

func _process(delta: float) -> void:
	scene_time += delta
	for index in range(decorations.size()):
		decorations[index].position = decoration_origins[index] + Vector2(0.0, sin(scene_time * TAU / 2.5 + index) * 2.0)
	_sync_foam_viewport()

## The foam mask sees the world through the same (moving, zooming, turning)
## camera as the screen, at FOAM_MASK_SCALE resolution, so the water shader can
## read it with SCREEN_UV.
func _sync_foam_viewport() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var mask_size: Vector2i = Vector2i((screen_size * FOAM_MASK_SCALE).ceil())
	if foam_viewport.size != mask_size:
		foam_viewport.size = mask_size
	foam_viewport.canvas_transform = get_viewport().get_canvas_transform().scaled(Vector2.ONE * FOAM_MASK_SCALE)

func _physics_process(_delta: float) -> void:
	if sinking:
		return
	var motion: BoatMotion = boat.get("motion") as BoatMotion
	var data: BoatData = boat.get("data") as BoatData
	if motion == null or data == null:
		return
	var position_now: Vector2 = boat.global_position
	var inside_distance: float = minf(minf(position_now.x, WORLD_RECT.size.x - position_now.x), minf(position_now.y, WORLD_RECT.size.y - position_now.y))
	if inside_distance < BOUNDARY_BAND:
		var factor: float = lerpf(0.25, 1.0, clampf(inside_distance / BOUNDARY_BAND, 0.0, 1.0))
		motion.velocity = motion.velocity.limit_length(data.max_speed * factor)
	var clamped: Vector2 = Vector2(clampf(position_now.x, 80.0, WORLD_RECT.size.x - 80.0), clampf(position_now.y, 80.0, WORLD_RECT.size.y - 80.0))
	if clamped != position_now:
		boat.global_position = clamped
		motion.velocity *= -0.35

func _on_boat_impact(hazard: Node2D, speed: float, point: Vector2, normal: Vector2) -> void:
	if sinking:
		return
	var data: BoatData = boat.get("data") as BoatData
	var motion: BoatMotion = boat.get("motion") as BoatMotion
	if data == null or motion == null:
		return
	var strength: float = clampf(speed / data.max_speed, 0.0, 1.0)
	var is_rock: bool = hazard.is_in_group(&"rock_hazard")
	# Rocks bite from a gentle bump; shores and docks only from a real ram.
	var threshold: float = CRASH_ROCK_THRESHOLD if is_rock else CRASH_SHORE_THRESHOLD
	var now: float = Time.get_ticks_msec() * 0.001
	if strength < threshold or now - last_crash_time < CRASH_INVULNERABLE_TIME:
		motion.velocity *= 0.4
		return
	last_crash_time = now
	var severity: float = inverse_lerp(threshold, 1.0, strength)
	# Fountains and lighthouses in Lilyport soften every crash.
	var damage: float = maxf(1.0, roundf(lerpf(CRASH_DAMAGE_MIN, CRASH_DAMAGE_MAX, severity) * (1.0 if is_rock else 0.7) * float(get_node("/root/GameState").call("crash_damage_multiplier"))))
	boat.call("play_crash", point, normal, severity)
	_spawn_damage_number(point, int(damage))
	var remaining: float = float(get_node("/root/GameState").call("damage_hull", damage))
	if remaining <= 0.0:
		_sink()
	elif severity > 0.45:
		_hit_stop(0.07)

func _hit_stop(duration: float) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

## Ephemeral juice: a red "-12" that pops out of the contact point and floats up.
func _spawn_damage_number(point: Vector2, amount: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override(&"font_size", 54)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.27))
	label.add_theme_color_override(&"font_outline_color", Color(0.29, 0.17, 0.06))
	label.add_theme_constant_override(&"outline_size", 14)
	label.z_index = 20
	label.z_as_relative = false
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	# Upright on screen and floating screen-up, whichever way the camera faces.
	var screen_up: Vector2 = Vector2.UP.rotated(-get_viewport().get_canvas_transform().get_rotation())
	label.rotation = -get_viewport().get_canvas_transform().get_rotation()
	label.position = point - label.size * 0.5 + screen_up * 30.0
	label.scale = Vector2.ZERO
	var pop: Tween = label.create_tween()
	pop.tween_property(label, "scale", Vector2.ONE * 1.15, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "scale", Vector2.ONE, 0.1)
	pop.parallel().tween_property(label, "position", label.position + screen_up * 110.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(label, "modulate:a", 0.0, 0.3)
	pop.tween_callback(label.queue_free)

func _sink() -> void:
	sinking = true
	boat.set("input_locked", true)
	get_node("/root/Audio").call("play_sfx", &"sink")
	get_node("/root/Audio").call("play_sfx", &"bubble")
	boat.set("trauma", 1.0)
	boat.get_node("SinkBubbles").set("emitting", true)
	boat.get_node("BowSplash").set("emitting", false)
	var tween: Tween = create_tween()
	tween.tween_property(boat, "scale", Vector2.ONE * 0.55, 1.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(boat, "modulate", Color(0.18, 0.48, 0.78, 0.05), 1.6)
	var wobble: Tween = create_tween()
	var heading: float = boat.rotation
	wobble.tween_property(boat, "rotation", heading + deg_to_rad(12.0), 0.4)
	wobble.tween_property(boat, "rotation", heading - deg_to_rad(12.0), 0.4)
	wobble.tween_property(boat, "rotation", heading + deg_to_rad(12.0), 0.4)
	wobble.tween_property(boat, "rotation", heading, 0.4)
	await tween.finished
	boat.visible = false
	var fade: Node = get_node("/root/Fade")
	fade.call("fade_call", func() -> void:
		boat.global_position = RESPAWN_POINT
		boat.get("motion").reset()
		boat.set("velocity", Vector2.ZERO)
		boat.call("clear_passengers")
		boat.scale = Vector2.ONE
		boat.modulate = Color.WHITE
		boat.visible = true
		boat.rotation = 0.0
		boat.get_node("SinkBubbles").set("emitting", false)
		get_node("/root/GameState").call("repair_hull")
		for trail in foam_viewport.get_children():
			if trail.has_method(&"clear_trail"):
				trail.call("clear_trail")
		boat.call("snap_camera")
	)
	await fade.transition_finished
	boat.set("input_locked", false)
	sinking = false

## Sail home to Lilyport from anywhere on the map. Passengers stay aboard.
func travel() -> void:
	if sinking:
		return
	boat.set("input_locked", true)
	get_node("/root/GameState").set("onboard_manifest", boat.get("onboard").duplicate(true))
	# Dive into Lilyport's island; the town arrives zoomed out and settles in.
	var base: Node2D = get_node("LilyportBase") as Node2D
	get_node("/root/Fade").call("travel_to", "res://scenes/town/Lilyport.tscn", camera, base.global_position, TRAVEL_ZOOM)

func moor() -> void:
	travel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and lilyport_dock.call("get_ring_state") == &"green":
		travel()

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_TAB:
		boat.global_position = concept_pose.global_position
		boat.get("motion").heading = deg_to_rad(-64.0)
		boat.get("motion").velocity = boat.get("motion").forward_vector() * boat.get("data").max_speed
	elif event.physical_keycode == KEY_F9:
		get_node("/root/GameState").call("add_coins", 500)
	elif event.physical_keycode == KEY_F10:
		overview = not overview
		camera.zoom = Vector2.ONE * (0.4 if overview else float(camera.get("default_zoom")))
		if overview:
			boat.global_position = Vector2(2400.0, 1350.0)
