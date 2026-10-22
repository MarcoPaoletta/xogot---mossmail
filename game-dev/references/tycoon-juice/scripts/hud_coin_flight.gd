class_name HudCoinFlight
extends Control
## Money that is FELT arrives as coins that fly from where it was earned to
## the HUD counter, and the number only goes up when each coin lands. Never
## add the cash first and play the coins afterwards.
##
## `collect()` splits an amount into a few coins, projects the world position
## to the screen, flies each coin on an arc to the counter, and calls
## `Wallet.add` per coin as it lands, so the counter ticks up in step with the
## chime. The coin is a saved Control scene (a TextureRect with the coin art).
## Put this node on the HUD CanvasLayer, full rect, mouse filter ignore.

signal coin_landed(index: int, total: int)

@export var camera: Camera3D
@export var counter: Control
@export var coin_scene: PackedScene
@export var max_coins: int = 8
@export var coin_stagger: float = 0.045
@export var flight_time: float = 0.55
@export var arc_height: float = 140.0
@export var chime: AudioStreamPlayer
@export var pitch_step: float = 0.06
@export var pitch_max: float = 2.0


## Splits `amount` into up to `max_coins` coins. Each landing adds its share.
func collect(world_position: Vector3, amount: int) -> void:
	if amount <= 0:
		return
	var coins: int = clampi(amount, 1, max_coins)
	var start: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
	if camera != null and not camera.is_position_behind(world_position):
		start = camera.unproject_position(world_position)
	var wallet: Node = get_node_or_null("/root/Wallet")
	var per_coin: int = floori(float(amount) / float(coins))
	var remainder: int = amount - per_coin * coins
	for i in coins:
		var share: int = per_coin + (remainder if i == coins - 1 else 0)
		get_tree().create_timer(coin_stagger * float(i)).timeout.connect(
			func() -> void: _launch(start, share, i, coins, wallet)
		)


func _launch(start: Vector2, share: int, index: int, total: int, wallet: Node) -> void:
	if coin_scene == null or counter == null:
		if wallet != null:
			wallet.call("add", share)
		return
	var coin: Control = coin_scene.instantiate() as Control
	add_child(coin)
	coin.pivot_offset = coin.size * 0.5
	coin.position = start - coin.pivot_offset
	var end: Vector2 = counter.global_position + counter.size * 0.5 - coin.pivot_offset
	var control: Vector2 = (start + end) * 0.5 + Vector2(randf_range(-60.0, 60.0), -arc_height)
	var tween: Tween = coin.create_tween()
	var step: Callable = func(t: float) -> void:
		var q0: Vector2 = start.lerp(control, t)
		var q1: Vector2 = control.lerp(end, t)
		coin.position = q0.lerp(q1, t) - coin.pivot_offset
		coin.scale = Vector2.ONE * (1.0 + 0.25 * sin(PI * t))
	var method_tween: MethodTweener = tween.tween_method(step, 0.0, 1.0, flight_time)
	method_tween.set_trans(Tween.TRANS_SINE)
	method_tween.set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if wallet != null:
			wallet.call("add", share)
		if chime != null:
			chime.pitch_scale = minf(1.0 + pitch_step * float(index), pitch_max)
			chime.play()
		coin_landed.emit(index, total)
		coin.queue_free()
	)
