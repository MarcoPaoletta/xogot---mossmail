@tool
class_name Compass
extends Control
## Leaf-shaped arrow that points toward the current task target.
## Angle 0 points straight up (ahead of the camera); positive turns clockwise.

@export var arrow_color: Color = Color("#ffd27a")
@export var outline_color: Color = Color("#24382c")
@export var disc_color: Color = Color(0.1, 0.16, 0.12, 0.55)
@export var smoothing: float = 10.0

var _angle: float = 0.0
var _target_angle: float = 0.0
var _time: float = 0.0


func set_angle(radians: float) -> void:
	_target_angle = radians


func _process(delta: float) -> void:
	_time += delta
	_angle = lerp_angle(_angle, _target_angle, 1.0 - exp(-smoothing * delta))
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	draw_circle(center, radius, disc_color)
	var pulse: float = 1.0 + sin(_time * 5.0) * 0.05
	var r: float = radius * 0.78 * pulse
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -r),
		Vector2(r * 0.55, r * 0.15),
		Vector2(r * 0.2, r * 0.02),
		Vector2(r * 0.2, r * 0.62),
		Vector2(-r * 0.2, r * 0.62),
		Vector2(-r * 0.2, r * 0.02),
		Vector2(-r * 0.55, r * 0.15),
	])
	var xform: Transform2D = Transform2D(_angle, center)
	var placed: PackedVector2Array = xform * points
	draw_colored_polygon(placed, arrow_color)
	var outline: PackedVector2Array = placed.duplicate()
	outline.append(placed[0])
	draw_polyline(outline, outline_color, 3.0, true)
