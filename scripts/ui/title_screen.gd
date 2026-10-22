class_name TitleScreen
extends UIScreen
## Title over the living forest: play, tilt toggle, best score and credits.

signal play_pressed
signal tilt_toggled(enabled: bool)

@export var play_button_path: NodePath = ^"Center/Card/Margin/Column/PlayButton"
@export var tilt_button_path: NodePath = ^"Center/Card/Margin/Column/TiltButton"
@export var best_label_path: NodePath = ^"Center/Card/Margin/Column/BestLabel"
@export var title_path: NodePath = ^"Center/Card/Margin/Column/Title"

var tilt_enabled: bool = true

var _play: Button
var _tilt: Button
var _best: Label
var _title: Label
var _time: float = 0.0


func _ready() -> void:
	super._ready()
	_play = get_node_or_null(play_button_path) as Button
	_tilt = get_node_or_null(tilt_button_path) as Button
	_best = get_node_or_null(best_label_path) as Label
	_title = get_node_or_null(title_path) as Label
	if _play:
		_play.pressed.connect(func() -> void: play_pressed.emit())
	if _tilt:
		_tilt.pressed.connect(_on_tilt)
	_refresh_tilt()


func _process(delta: float) -> void:
	if not visible or _title == null:
		return
	_time += delta
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = sin(_time * 1.3) * 0.025
	_title.scale = Vector2.ONE * (1.0 + sin(_time * 2.1) * 0.015)


func set_best(best: int) -> void:
	if _best:
		_best.text = "Best shift: %d" % best if best > 0 else "Your first flight awaits"


func show_screen() -> void:
	super.show_screen()
	if _play:
		_play.grab_focus.call_deferred()


func _on_tilt() -> void:
	tilt_enabled = not tilt_enabled
	_refresh_tilt()
	UIJuice.pop(_tilt, 1.08)
	tilt_toggled.emit(tilt_enabled)


func _refresh_tilt() -> void:
	if _tilt:
		_tilt.text = "Tilt steering: ON" if tilt_enabled else "Tilt steering: OFF"
