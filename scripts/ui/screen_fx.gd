class_name ScreenFx
extends ColorRect
## Full-screen mood layer in one draw call: vignette, film grain, speed lines
## and a tweened colour flash (bumps, deliveries).

var _material: ShaderMaterial
var _flash_tween: Tween
var _speed: float = 0.0
var _speed_target: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = material as ShaderMaterial


func _process(delta: float) -> void:
	if _material == null:
		return
	_speed = lerpf(_speed, _speed_target, 1.0 - exp(-4.0 * delta))
	_material.set_shader_parameter(&"speed_lines", _speed)


## Rises fast, falls slow (skill: ~0.06 s up, ~0.45 s down).
func flash(tint: Color, peak: float = 0.5, rise: float = 0.06, fall: float = 0.45) -> void:
	if _material == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_material.set_shader_parameter(&"flash_color", Color(tint.r, tint.g, tint.b, 0.0))
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash.bind(tint), 0.0, peak, rise)
	_flash_tween.tween_method(_set_flash.bind(tint), peak, 0.0, fall) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 0..1 strength of the radial speed streaks (gliding, sprinting).
func set_speed_lines(amount: float) -> void:
	_speed_target = clampf(amount, 0.0, 1.0)


func _set_flash(alpha: float, tint: Color) -> void:
	_material.set_shader_parameter(&"flash_color", Color(tint.r, tint.g, tint.b, alpha))
