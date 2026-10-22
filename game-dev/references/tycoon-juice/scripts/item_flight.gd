class_name ItemFlight
extends RefCounted
## Every transfer of value in a tycoon is a visible object on an arc.
## Fish leave the water, fillets leave the table, cash leaves the counter.
## This helper flies a Node3D that already lives in the tree to a target that
## may keep moving (the player's back slot), then squashes it on arrival.
##
## Behavior only. The item is an instance of a saved scene (Rule 1c).


## Quadratic bezier. `control` is the arc handle, not a point on the curve.
static func bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	var q0: Vector3 = a.lerp(control, t)
	var q1: Vector3 = control.lerp(b, t)
	return q0.lerp(q1, t)


## Flies `item` to `target.call()` (a Callable returning a world Vector3,
## re-read every frame so a moving slot is followed). `apex_height` is how far
## above the straight line the arc peaks. `on_land` receives the item.
static func fly(
	item: Node3D,
	target: Callable,
	duration: float = 0.3,
	apex_height: float = 0.7,
	spin_turns: float = 0.0,
	on_land: Callable = Callable()
) -> Tween:
	item.top_level = true
	var start: Vector3 = item.global_position
	var start_yaw: float = item.global_rotation.y
	var base_scale: Vector3 = item.scale
	var tween: Tween = item.create_tween()
	var step: Callable = func(t: float) -> void:
		if not is_instance_valid(item):
			return
		var end: Vector3 = target.call()
		var control: Vector3 = (start + end) * 0.5 + Vector3.UP * apex_height * 2.0
		item.global_position = bezier(start, control, end, t)
		item.global_rotation.y = start_yaw + TAU * spin_turns * t
		# Stretch a little at mid flight so the item reads as fast.
		var stretch: float = 1.0 + 0.12 * sin(PI * t)
		item.scale = base_scale * stretch
	var method_tween: MethodTweener = tween.tween_method(step, 0.0, 1.0, maxf(duration, 0.01))
	method_tween.set_trans(Tween.TRANS_SINE)
	method_tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(item):
			return
		item.scale = base_scale
		if on_land.is_valid():
			on_land.call(item)
	)
	return tween


## Landing squash: wide and short, overshoot tall, settle. Never instant.
static func squash(item: Node3D, strength: float = 0.28, time: float = 0.22) -> void:
	if not is_instance_valid(item):
		return
	var base: Vector3 = item.scale
	item.scale = Vector3(base.x * (1.0 + strength), base.y * (1.0 - strength), base.z * (1.0 + strength))
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "scale", base, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pop in from nothing with a back ease (builds, reveals, spawned props).
static func pop_in(node: Node3D, time: float = 0.35, overshoot_to: float = 1.15) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector3 = node.scale
	node.visible = true
	node.scale = base * 0.01
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", base * overshoot_to, time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", base, time * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
