class_name Hud
extends UIScreen
## In-flight HUD: wave card with timer, hearts, flower counter (with a live
## render of the flower model), compass, altitude lever, steer-side glows,
## floating popups and the centre banner.

@export var task_title_path: NodePath = ^"TopBar/Row/TaskCard/TaskColumn/TaskTitle"
@export var task_detail_path: NodePath = ^"TopBar/Row/TaskCard/TaskColumn/TaskDetail"
@export var task_card_path: NodePath = ^"TopBar/Row/TaskCard"
@export var timer_bar_path: NodePath = ^"TopBar/Row/TaskCard/TaskColumn/TimerBar"
@export var hearts_path: NodePath = ^"TopBar/Row/Hearts"
@export var counter_card_path: NodePath = ^"TopBar/Row/CounterCard"
@export var counter_label_path: NodePath = ^"TopBar/Row/CounterCard/CounterRow/CountLabel"
@export var compass_path: NodePath = ^"Compass"
@export var distance_label_path: NodePath = ^"Compass/DistanceLabel"
@export var lever_path: NodePath = ^"AltitudeLever"
@export var left_glow_path: NodePath = ^"LeftGlow"
@export var right_glow_path: NodePath = ^"RightGlow"
@export var popups_path: NodePath = ^"Popups"
@export var banner_path: NodePath = ^"Banner"
@export var hint_path: NodePath = ^"SteerHint"
@export var float_text_scene_path: String = "res://scenes/ui/float_text.tscn"
@export var timer_ok_color: Color = Color("#f3e7c4")
@export var timer_low_color: Color = Color("#ff6b5a")
@export var low_time_ratio: float = 0.35
@export var glow_alpha: float = 0.55

var _task_title: Label
var _task_detail: Label
var _task_card: Control
var _timer_bar: ProgressBar
var _hearts: Control
var _counter_card: Control
var _counter: Label
var _compass: Compass
var _distance: Label
var _lever: AltitudeLever
var _left_glow: Control
var _right_glow: Control
var _popups: Control
var _banner: Label
var _hint: Control
var _float_scene: PackedScene
var _shown_count: int = 0
var _count_tween: Tween
var _low_time: bool = false


func _ready() -> void:
	super._ready()
	_task_title = get_node_or_null(task_title_path) as Label
	_task_detail = get_node_or_null(task_detail_path) as Label
	_task_card = get_node_or_null(task_card_path) as Control
	_timer_bar = get_node_or_null(timer_bar_path) as ProgressBar
	_hearts = get_node_or_null(hearts_path) as Control
	_counter_card = get_node_or_null(counter_card_path) as Control
	_counter = get_node_or_null(counter_label_path) as Label
	_compass = get_node_or_null(compass_path) as Compass
	_distance = get_node_or_null(distance_label_path) as Label
	_lever = get_node_or_null(lever_path) as AltitudeLever
	_left_glow = get_node_or_null(left_glow_path) as Control
	_right_glow = get_node_or_null(right_glow_path) as Control
	_popups = get_node_or_null(popups_path) as Control
	_banner = get_node_or_null(banner_path) as Label
	_hint = get_node_or_null(hint_path) as Control
	_float_scene = load(float_text_scene_path) as PackedScene
	if _left_glow:
		_left_glow.modulate.a = 0.0
	if _right_glow:
		_right_glow.modulate.a = 0.0
	if _banner:
		_banner.modulate.a = 0.0
	clear_task()


func get_lever() -> AltitudeLever:
	return _lever


## Fresh run: counter to 0, lever to its start height, steering hint shown.
func begin_run(lever_start: float) -> void:
	_shown_count = 0
	if _counter:
		_counter.text = "0"
	if _lever:
		_lever.value = lever_start
	if _hint:
		_hint.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(_hint, "modulate:a", 1.0, 0.4)
		tween.tween_interval(5.0)
		tween.tween_property(_hint, "modulate:a", 0.0, 0.8)


func set_task(title: String, detail: String) -> void:
	if _task_title:
		_task_title.text = title
	if _task_detail:
		_task_detail.text = detail
	if _task_card:
		_task_card.visible = true
		_task_card.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(_task_card, "modulate:a", 1.0, 0.25)
		UIJuice.pop(_task_card, 1.08)
	if _compass:
		_compass.visible = true


func set_detail(detail: String) -> void:
	if _task_detail:
		_task_detail.text = detail
		UIJuice.pop(_task_detail, 1.1)


func clear_task() -> void:
	if _task_card and _task_card.visible:
		var tween: Tween = create_tween()
		tween.tween_property(_task_card, "modulate:a", 0.0, 0.25)
		tween.tween_callback(_task_card.hide)
	if _compass:
		_compass.visible = false
	_low_time = false


## Remaining time as 0..1. The bar turns red under [member low_time_ratio].
func set_timer(ratio: float) -> void:
	if _timer_bar == null:
		return
	_timer_bar.value = ratio * 100.0
	var low: bool = ratio < low_time_ratio
	if low != _low_time:
		_low_time = low
		var tween: Tween = create_tween()
		tween.tween_property(_timer_bar, "self_modulate", timer_low_color if low else timer_ok_color, 0.3)
		if low:
			UIJuice.shake(_task_card, 8.0, 0.35)


## Flower counter counts up to the new total and pops.
func set_flowers(total: int) -> void:
	if _counter == null or total == _shown_count:
		return
	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_method(_set_count_text, _shown_count, total, 0.35)
	UIJuice.pop(_counter_card, 1.12)


## Hearts are the run's lives. A lost heart pops, greys out and the row shakes.
func set_lives(count: int) -> void:
	if _hearts == null:
		return
	var lost: bool = false
	var index: int = 0
	for child: Node in _hearts.get_children():
		var heart := child as HeartIcon
		if heart == null:
			continue
		var alive: bool = index < count
		if heart.filled and not alive:
			lost = true
		heart.set_filled(alive)
		index += 1
	if lost:
		UIJuice.shake(_hearts, 16.0, 0.45)


## Floating text that rises from a screen position and fades.
func popup(text: String, screen_position: Vector2, color: Color) -> void:
	if _float_scene == null or _popups == null:
		return
	var label := _float_scene.instantiate() as FloatText
	_popups.add_child(label)
	label.play(text, screen_position, color)


## Big centred banner ("All collected!", "Too late!").
func show_banner(text: String, color: Color) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_color_override(&"font_color", color)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 0.6
	var tween: Tween = create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.9)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


## Edge glow on the side being touched.
func set_sides(left: bool, right: bool) -> void:
	_fade_glow(_left_glow, left)
	_fade_glow(_right_glow, right)


## Points the compass at the target, relative to the camera's facing.
func update_compass(camera: Camera3D, from: Vector3, target: Vector3) -> void:
	if _compass == null or camera == null or not _compass.visible:
		return
	var to_target: Vector3 = target - from
	var flat: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	cam_forward.y = 0.0
	if flat.length() < 0.01 or cam_forward.length() < 0.01:
		return
	var angle: float = cam_forward.normalized().signed_angle_to(flat.normalized(), Vector3.UP)
	_compass.set_angle(-angle)
	if _distance:
		var dy: float = to_target.y
		var arrow: String = "  ▲" if dy > 4.0 else ("  ▼" if dy < -4.0 else "")
		_distance.text = "%d m%s" % [int(to_target.length()), arrow]


func _fade_glow(glow: Control, on: bool) -> void:
	if glow == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(glow, "modulate:a", glow_alpha if on else 0.0, 0.12 if on else 0.3)


func _set_count_text(value: int) -> void:
	_shown_count = value
	if _counter:
		_counter.text = str(value)
