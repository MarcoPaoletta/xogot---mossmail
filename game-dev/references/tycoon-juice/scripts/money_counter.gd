class_name MoneyCounter
extends Label
## HUD cash counter. The number never jumps: it rolls toward the real value,
## punches up when money arrives (green flash) and shakes red when a purchase
## is rejected. Big on purpose: this is the number the whole genre watches.
##
## Reads the `Wallet` autoload if there is one. Set the font size, outline and
## theme in the HUD scene; this script only animates.

@export var roll_speed: float = 10.0
@export var gain_color: Color = Color(0.55, 1.0, 0.5)
@export var loss_color: Color = Color(1.0, 0.35, 0.3)
@export var rest_color: Color = Color(1.0, 1.0, 1.0)
@export var prefix: String = "$"
@export var punch_scale: float = 1.25

var _shown: float = 0.0
var _target: int = 0
var _punch: Tween = null
var _rest_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_rest_scale = scale
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	var wallet: Node = get_node_or_null("/root/Wallet")
	if wallet != null:
		_target = int(wallet.get("cash"))
		_shown = float(_target)
		wallet.connect("changed", set_value)
		wallet.connect("rejected", func(_amount: int) -> void: reject())
	_refresh()


func _process(delta: float) -> void:
	if is_equal_approx(_shown, float(_target)):
		return
	_shown = lerpf(_shown, float(_target), 1.0 - exp(-roll_speed * delta))
	if absf(_shown - float(_target)) < 0.5:
		_shown = float(_target)
	_refresh()


func set_value(value: int) -> void:
	var gained: bool = value > _target
	_target = value
	_flash(gain_color if gained else loss_color)
	if gained:
		_pop()


func reject() -> void:
	_flash(loss_color)
	if _punch != null and _punch.is_valid():
		_punch.kill()
	_punch = create_tween()
	for i in 4:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		_punch.tween_property(self, "rotation", side * 0.06, 0.04)
	_punch.tween_property(self, "rotation", 0.0, 0.05)


func _refresh() -> void:
	text = prefix + EconomyCurves.format_compact(roundf(_shown))


func _pop() -> void:
	if _punch != null and _punch.is_valid():
		_punch.kill()
	scale = _rest_scale * punch_scale
	_punch = create_tween()
	_punch.tween_property(self, "scale", _rest_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(color: Color) -> void:
	modulate = color
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", rest_color, 0.35).set_trans(Tween.TRANS_SINE)
