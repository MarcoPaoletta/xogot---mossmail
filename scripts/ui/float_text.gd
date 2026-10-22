class_name FloatText
extends Label
## Score popup: pops in, rises, fades, frees itself.

@export var rise: float = 90.0
@export var lifetime: float = 1.0


func play(value: String, screen_position: Vector2, color: Color) -> void:
	text = value
	add_theme_color_override(&"font_color", color)
	reset_size()
	position = screen_position - size * 0.5
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 0.4
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.tween_property(self, "position:y", position.y - rise, lifetime) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)
