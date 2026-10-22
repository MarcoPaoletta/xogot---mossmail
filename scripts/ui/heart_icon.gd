@tool
class_name HeartIcon
extends Control
## One life heart, drawn as a smooth vector heart with an outline and a shine.
## Losing it shrinks and greys it; regaining it pops it back.

@export var filled: bool = true:
	set(v):
		filled = v
		queue_redraw()
@export var fill_color: Color = Color("#ff4f64")
@export var empty_color: Color = Color(0.22, 0.2, 0.2, 0.75)
@export var outline_color: Color = Color("#3a0d16")
@export var shine_color: Color = Color(1, 1, 1, 0.55)
@export var outline_width: float = 5.0

var _beat: float = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not filled:
		return
	_beat += delta
	queue_redraw()


## Sets the heart, with a pop or a shrink-and-grey animation.
func set_filled(on: bool) -> void:
	if on == filled:
		return
	pivot_offset = size * 0.5
	var tween: Tween = create_tween()
	if on:
		filled = true
		scale = Vector2.ONE * 0.5
		tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, "scale", Vector2.ONE * 1.35, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: filled = false)
		tween.tween_property(self, "scale", Vector2.ONE * 0.85, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var pulse: float = 1.0 + (sin(_beat * 3.2) * 0.03 if filled else 0.0)
	var unit: float = minf(size.x / 34.0, size.y / 32.0) * pulse
	var center: Vector2 = size * 0.5 + Vector2(0, unit * 1.5)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 64:
		var t: float = TAU * float(i) / 64.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		points.append(center + Vector2(x, -y) * unit)
	draw_colored_polygon(points, fill_color if filled else empty_color)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, outline_color, outline_width, true)
	if filled:
		draw_circle(center + Vector2(-7.5, -6.5) * unit, 3.2 * unit, shine_color)
		draw_circle(center + Vector2(-3.8, -9.0) * unit, 1.6 * unit, shine_color)
