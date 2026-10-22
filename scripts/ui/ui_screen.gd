class_name UIScreen
extends Control
## Base for full-screen UI states. Shows and hides with a fade plus a small
## rise, never a snap, and keeps working while the tree is paused.
## Buttons inside get hover and press scale juice automatically.

@export var fade_time: float = 0.35
@export var rise_distance: float = 24.0
@export var start_visible: bool = false

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = start_visible
	modulate.a = 1.0 if start_visible else 0.0
	for button: Node in find_children("*", "BaseButton", true, false):
		UIJuice.wire_button(button as BaseButton)


func show_screen() -> void:
	_kill()
	visible = true
	modulate.a = 0.0
	position.y = rise_distance
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", 0.0, fade_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_screen() -> void:
	if not visible:
		return
	_kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time * 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position:y", -rise_distance * 0.5, fade_time * 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
