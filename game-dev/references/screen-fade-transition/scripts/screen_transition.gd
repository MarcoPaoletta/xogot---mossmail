class_name ScreenFadeTransition
extends CanvasLayer

@export_range(0.05, 2.0, 0.01) var default_duration: float = 0.24

@onready var _fade: ColorRect = $Overlay/Fade as ColorRect

var _active_tween: Tween
var _transitioning: bool = false
var _tween_serial: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_out(duration: float = -1.0) -> bool:
	var use_duration: float = default_duration if duration <= 0.0 else duration
	_transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	return await _tween_alpha(1.0, use_duration)


func fade_in(duration: float = -1.0) -> bool:
	var use_duration: float = default_duration if duration <= 0.0 else duration
	var completed: bool = await _tween_alpha(0.0, use_duration)
	if not completed:
		return false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	return true


func snap_to_black() -> void:
	_tween_serial += 1
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_fade.modulate.a = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_transitioning = true


func get_fade_alpha() -> float:
	return _fade.modulate.a


func is_transitioning() -> bool:
	return _transitioning


func _tween_alpha(target_alpha: float, duration: float) -> bool:
	_tween_serial += 1
	var serial: int = _tween_serial
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(
		Tween.EASE_IN if target_alpha > _fade.modulate.a else Tween.EASE_OUT
	)
	_active_tween.tween_property(
		_fade,
		^"modulate:a",
		target_alpha,
		duration
	)
	while (
		serial == _tween_serial
		and _active_tween != null
		and _active_tween.is_running()
	):
		await get_tree().process_frame
	return (
		serial == _tween_serial
		and is_equal_approx(_fade.modulate.a, target_alpha)
	)
