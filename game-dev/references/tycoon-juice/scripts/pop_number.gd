class_name PopNumber
extends Label3D
## Floating "+$12" that appears where the money was earned: pops with a back
## ease, rises, fades, frees itself. The Label3D (billboard, no depth test,
## outline) is authored in `pop_number.tscn`; spawners instantiate that scene.
##
## Never a flat text swap: a number that does not move is a dead number.

signal finished

@export var rise_height: float = 1.3
@export var life: float = 0.85
@export var pop_scale: float = 1.3


func pop(label_text: String, color: Color = Color(1.0, 0.92, 0.35)) -> void:
	text = label_text
	modulate = color
	var rest: Vector3 = scale
	scale = rest * 0.01
	var start_y: float = position.y
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", rest * pop_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", start_y + rise_height, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(self, "scale", rest, 0.12).set_trans(Tween.TRANS_SINE)
	var fade: Tween = create_tween()
	fade.tween_interval(life * 0.6)
	fade.tween_property(self, "modulate:a", 0.0, life * 0.4)
	fade.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)
