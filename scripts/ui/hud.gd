class_name Hud
extends UIScreen
## In-shift HUD: task card with timer, score and combo, stamps (lives), compass,
## steer-side glows, floating score popups and the delivery banner.
## Minimal by rule: anything the world already shows is not repeated here.

signal pause_pressed

@export var task_title_path: NodePath = ^"TopBar/Row/TaskCard/TaskColumn/TaskTitle"
@export var task_detail_path: NodePath = ^"TopBar/Row/TaskCard/TaskColumn/TaskDetail"
@export var task_card_path: NodePath = ^"TopBar/Row/TaskCard"
@export var timer_bar_path: NodePath = ^"TopBar/Row/TaskCard/TaskColumn/TimerBar"
@export var score_label_path: NodePath = ^"TopBar/Row/ScoreCard/ScoreColumn/ScoreLabel"
@export var combo_label_path: NodePath = ^"TopBar/Row/ScoreCard/ScoreColumn/ComboLabel"
@export var stamps_path: NodePath = ^"TopBar/Row/Stamps"
@export var pause_button_path: NodePath = ^"TopBar/Row/PauseButton"
@export var compass_path: NodePath = ^"Compass"
@export var distance_label_path: NodePath = ^"Compass/DistanceLabel"
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
var _score_label: Label
var _combo_label: Label
var _stamps: Control
var _compass: Compass
var _distance: Label
var _left_glow: Control
var _right_glow: Control
var _popups: Control
var _banner: Label
var _hint: Control
var _float_scene: PackedScene
var _shown_score: int = 0
var _score_tween: Tween
var _stamp_count: int = -1
var _low_time: bool = false


func _ready() -> void:
	super._ready()
	_task_title = get_node_or_null(task_title_path) as Label
	_task_detail = get_node_or_null(task_detail_path) as Label
	_task_card = get_node_or_null(task_card_path) as Control
	_timer_bar = get_node_or_null(timer_bar_path) as ProgressBar
	_score_label = get_node_or_null(score_label_path) as Label
	_combo_label = get_node_or_null(combo_label_path) as Label
	_stamps = get_node_or_null(stamps_path) as Control
	_compass = get_node_or_null(compass_path) as Compass
	_distance = get_node_or_null(distance_label_path) as Label
	_left_glow = get_node_or_null(left_glow_path) as Control
	_right_glow = get_node_or_null(right_glow_path) as Control
	_popups = get_node_or_null(popups_path) as Control
	_banner = get_node_or_null(banner_path) as Label
	_hint = get_node_or_null(hint_path) as Control
	_float_scene = load(float_text_scene_path) as PackedScene
	var pause := get_node_or_null(pause_button_path) as Button
	if pause:
		pause.pressed.connect(func() -> void: pause_pressed.emit())
	if _left_glow:
		_left_glow.modulate.a = 0.0
	if _right_glow:
		_right_glow.modulate.a = 0.0
	if _banner:
		_banner.modulate.a = 0.0
	clear_task()


## Fresh shift: resets numbers and shows the steering hint for a few seconds.
func begin_shift() -> void:
	_shown_score = 0
	if _score_label:
		_score_label.text = "0"
	set_combo(0)
	if _hint:
		_hint.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(_hint, "modulate:a", 1.0, 0.4)
		tween.tween_interval(4.5)
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


## Score counts up to the new value instead of jumping.
func set_score(score: int, combo: int) -> void:
	set_combo(combo)
	if _score_label == null or score == _shown_score:
		return
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(_set_score_text, _shown_score, score, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UIJuice.pop(_score_label, 1.22)


func set_combo(combo: int) -> void:
	if _combo_label == null:
		return
	var was_visible: bool = _combo_label.modulate.a > 0.5
	_combo_label.text = "Combo x%d" % combo
	var visible_now: bool = combo >= 2
	var tween: Tween = create_tween()
	tween.tween_property(_combo_label, "modulate:a", 1.0 if visible_now else 0.0, 0.25)
	if visible_now and (combo > 2 or not was_visible):
		UIJuice.pop(_combo_label, 1.3)


## Stamps are the shift's lives. A lost stamp shakes and dims.
func set_stamps(count: int) -> void:
	if _stamps == null:
		return
	var lost: bool = _stamp_count >= 0 and count < _stamp_count
	_stamp_count = count
	var index: int = 0
	for child: Node in _stamps.get_children():
		var stamp := child as Control
		if stamp == null:
			continue
		var alive: bool = index < count
		stamp.pivot_offset = stamp.size * 0.5
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(stamp, "modulate", Color.WHITE if alive else Color(0.35, 0.3, 0.3, 0.55), 0.3)
		tween.tween_property(stamp, "scale", Vector2.ONE if alive else Vector2.ONE * 0.8, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		index += 1
	if lost:
		UIJuice.shake(_stamps, 16.0, 0.45)


## Floating text that rises from a screen position and fades.
func popup(text: String, screen_position: Vector2, color: Color) -> void:
	if _float_scene == null or _popups == null:
		return
	var label := _float_scene.instantiate() as FloatText
	_popups.add_child(label)
	label.play(text, screen_position, color)


## Big centred banner ("Delivered!", "Missed!").
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
	to_target.y = 0.0
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	cam_forward.y = 0.0
	if to_target.length() < 0.01 or cam_forward.length() < 0.01:
		return
	var angle: float = cam_forward.normalized().signed_angle_to(to_target.normalized(), Vector3.UP)
	_compass.set_angle(-angle)
	if _distance:
		_distance.text = "%d m" % int(to_target.length())


func _fade_glow(glow: Control, on: bool) -> void:
	if glow == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(glow, "modulate:a", glow_alpha if on else 0.0, 0.12 if on else 0.3)


func _set_score_text(value: int) -> void:
	_shown_score = value
	if _score_label:
		_score_label.text = str(value)
