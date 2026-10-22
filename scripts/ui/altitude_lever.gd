@tool
class_name AltitudeLever
extends Control
## Vertical altitude lever in the bottom-right corner. Drag the knob up to climb,
## down to dive; it stays where you leave it. Device up/down tilt moves it too
## (the game calls [method nudge]). Consumes its own touches so they never steer.

signal value_changed(value: float)

@export_range(0.0, 1.0) var value: float = 0.4:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var track_color: Color = Color(0.07, 0.13, 0.1, 0.82)
@export var track_border: Color = Color(0.95, 0.88, 0.7, 0.7)
@export var fill_color: Color = Color("#ffd27a")
@export var knob_color: Color = Color("#f6ecd0")
@export var knob_outline: Color = Color("#1d3327")
@export var track_width: float = 64.0
@export var knob_radius: float = 53.0
@export var end_padding: float = 64.0
@export var touch_margin: float = 48.0

var _touch_index: int = -1
var _mouse_drag: bool = false
var _knob_scale: float = 1.0


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and _hit(touch.position):
			_touch_index = touch.index
			_grab(true)
			_set_from(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_grab(false)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_set_from(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and _hit(button.position):
				_mouse_drag = true
				_set_from(button.position)
			elif not button.pressed:
				_mouse_drag = false
	elif event is InputEventMouseMotion and _mouse_drag:
		_set_from((event as InputEventMouseMotion).position)


## Moves the lever by [param amount] (0..1 units), used by device tilt.
func nudge(amount: float) -> void:
	if amount == 0.0 or _touch_index != -1:
		return
	value += amount
	value_changed.emit(value)


func is_held() -> bool:
	return _touch_index != -1 or _mouse_drag


func _hit(screen_position: Vector2) -> bool:
	return get_global_rect().grow(touch_margin).has_point(screen_position)


func _set_from(screen_position: Vector2) -> void:
	var local_y: float = screen_position.y - get_global_rect().position.y
	var travel: float = maxf(size.y - end_padding * 2.0, 1.0)
	value = 1.0 - clampf((local_y - end_padding) / travel, 0.0, 1.0)
	value_changed.emit(value)


func _grab(on: bool) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(func(s: float) -> void:
		_knob_scale = s
		queue_redraw(), _knob_scale, 1.18 if on else 1.0, 0.12)


func _draw() -> void:
	var cx: float = size.x * 0.5
	var track: Rect2 = Rect2(cx - track_width * 0.5, 0.0, track_width, size.y)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = track_color
	box.border_color = track_border
	box.set_border_width_all(3)
	box.set_corner_radius_all(int(track_width * 0.5))
	box.corner_detail = 8
	draw_style_box(box, track)
	var travel: float = size.y - end_padding * 2.0
	var knob_y: float = end_padding + (1.0 - value) * travel
	var inset: float = track_width * 0.17
	var fill: Rect2 = Rect2(cx - track_width * 0.5 + inset, knob_y, track_width - inset * 2.0, size.y - end_padding * 0.6 - knob_y)
	if fill.size.y > 0.0:
		var fill_box: StyleBoxFlat = StyleBoxFlat.new()
		fill_box.bg_color = Color(fill_color, 0.55)
		fill_box.set_corner_radius_all(int((track_width - inset * 2.0) * 0.5))
		fill_box.corner_detail = 8
		draw_style_box(fill_box, fill)
	var unit: float = track_width / 46.0
	_draw_chevron(Vector2(cx, 28.0 * unit), -1.0, unit)
	_draw_chevron(Vector2(cx, size.y - 28.0 * unit), 1.0, unit)
	var r: float = knob_radius * _knob_scale
	draw_circle(Vector2(cx, knob_y + 4.0 * unit), r, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(cx, knob_y), r, knob_outline)
	draw_circle(Vector2(cx, knob_y), r - 5.0 * unit, knob_color)
	for i: int in 3:
		var y: float = knob_y + (i - 1) * 12.0 * unit
		draw_line(Vector2(cx - r * 0.42, y), Vector2(cx + r * 0.42, y), knob_outline, 4.0 * unit, true)


func _draw_chevron(center: Vector2, direction: float, unit: float) -> void:
	var w: float = 12.0 * unit
	var h: float = 8.0 * unit * direction
	draw_polyline(PackedVector2Array([center + Vector2(-w, -h), center + Vector2(0, h), center + Vector2(w, -h)]), fill_color, 4.0 * unit, true)
