class_name UIJuice
extends RefCounted
## Small shared UI feedback helpers: button scale on hover and press, pops and shakes.
## All tweens run while the tree is paused.


## Hover grows a button to 1.06, press squashes it to 0.97 (skill default).
static func wire_button(button: BaseButton) -> void:
	if button == null or button.has_meta(&"juiced"):
		return
	button.set_meta(&"juiced", true)
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(func() -> void: _scale_to(button, 1.06, 0.12))
	button.mouse_exited.connect(func() -> void: _scale_to(button, 1.0, 0.15))
	button.focus_entered.connect(func() -> void: _scale_to(button, 1.06, 0.12))
	button.focus_exited.connect(func() -> void: _scale_to(button, 1.0, 0.15))
	button.button_down.connect(func() -> void: _scale_to(button, 0.97, 0.06))
	button.button_up.connect(func() -> void: _scale_to(button, 1.0, 0.18))


## Overshoot pop: scale up, settle back.
static func pop(control: Control, amount: float = 1.18, time: float = 0.32) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", Vector2.ONE * amount, time * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, time * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Horizontal shake used for rejected or lost things.
static func shake(control: Control, strength: float = 14.0, time: float = 0.4) -> void:
	if control == null:
		return
	var origin: float = control.position.x
	var tween: Tween = control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var steps: int = 6
	for i: int in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(control, "position:x", origin + dir * strength * falloff, time / float(steps + 1))
	tween.tween_property(control, "position:x", origin, time / float(steps + 1))


static func _scale_to(control: Control, value: float, time: float) -> void:
	var tween: Tween = control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", Vector2.ONE * value, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
