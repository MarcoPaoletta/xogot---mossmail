class_name TitleScreen
extends UIScreen
## Title over the living forest: just the game name and a Start button.

signal play_pressed

@export var play_button_path: NodePath = ^"Center/Card/Margin/Column/PlayButton"
@export var title_path: NodePath = ^"Center/Card/Margin/Column/Title"

var _play: Button
var _title: Label
var _time: float = 0.0


func _ready() -> void:
	super._ready()
	_play = get_node_or_null(play_button_path) as Button
	_title = get_node_or_null(title_path) as Label
	if _play:
		_play.pressed.connect(func() -> void: play_pressed.emit())


func _process(delta: float) -> void:
	if not visible or _title == null:
		return
	_time += delta
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = sin(_time * 1.3) * 0.025
	_title.scale = Vector2.ONE * (1.0 + sin(_time * 2.1) * 0.015)


func show_screen() -> void:
	super.show_screen()
	if _play:
		_play.grab_focus.call_deferred()
