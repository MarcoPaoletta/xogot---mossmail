class_name UnlockPad
extends Area3D
## The glowing buy square. You do not press a button: you STAND on it and the
## money drains out of you into the pad, slowly at first and then faster, while
## the price counts down. When it reaches zero the thing you paid for pops into
## the world. This one mechanic carries the whole expansion loop of the genre.
##
## Authored in the pad scene (editor tools): the Area3D with its collision,
## the floor plate mesh, a Label3D for the price, a ring or fill shader. The
## `reveal_targets` are saved scenes already placed in the level, hidden. The
## script only drains the wallet, reports progress and reveals the targets.
##
## Needs the `Wallet` autoload (wallet.gd) and a player body in group `player`.

signal progress_changed(paid: int, price: int)
signal coin_paid(amount: int, from_position: Vector3)
signal rejected_poor
signal unlocked

@export var price: int = 100
## Cash per second at the first moment of standing on the pad.
@export var pay_rate_start: float = 30.0
## The rate multiplies up to this while you keep standing there.
@export var pay_rate_boost: float = 8.0
@export var boost_time: float = 1.4
@export var reveal_targets: Array[Node3D] = []
@export var coin_scene: PackedScene
@export var coin_interval: float = 0.05
@export var coin_height: float = 1.4

var _paid: int = 0
var _carrier: Node3D = null
var _held: float = 0.0
var _accumulator: float = 0.0
var _coin_cooldown: float = 0.0
var _done: bool = false
var _poor_notified: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	progress_changed.emit(_paid, price)


func remaining() -> int:
	return price - _paid


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not _done:
		_carrier = body
		_held = 0.0
		_poor_notified = false


func _on_body_exited(body: Node3D) -> void:
	if body == _carrier:
		_carrier = null


func _process(delta: float) -> void:
	if _carrier == null or _done:
		return
	var wallet: Node = get_node_or_null("/root/Wallet")
	if wallet == null:
		return
	if int(wallet.get("cash")) <= 0:
		if not _poor_notified:
			_poor_notified = true
			rejected_poor.emit()
		return
	_held += delta
	var boost: float = lerpf(1.0, pay_rate_boost, ease(clampf(_held / boost_time, 0.0, 1.0), 2.0))
	_accumulator += pay_rate_start * boost * delta
	var chunk: int = mini(int(_accumulator), remaining())
	chunk = mini(chunk, int(wallet.get("cash")))
	if chunk <= 0:
		return
	_accumulator -= float(chunk)
	if not wallet.call("try_spend", chunk):
		return
	_paid += chunk
	progress_changed.emit(_paid, price)
	var head: Vector3 = _carrier.global_position + Vector3.UP * coin_height
	coin_paid.emit(chunk, head)
	_spawn_coin(head, delta)
	if _paid >= price:
		_complete()


func _spawn_coin(from: Vector3, delta: float) -> void:
	_coin_cooldown -= delta
	if coin_scene == null or _coin_cooldown > 0.0:
		return
	_coin_cooldown = coin_interval
	var coin: Node3D = coin_scene.instantiate() as Node3D
	get_parent().add_child(coin)
	coin.global_position = from
	var pad_center: Vector3 = global_position + Vector3.UP * 0.2
	ItemFlight.fly(coin, func() -> Vector3: return pad_center, 0.3, 0.5, 1.0, func(c: Node3D) -> void:
		if is_instance_valid(c):
			c.queue_free()
	)


func _complete() -> void:
	_done = true
	_carrier = null
	monitoring = false
	unlocked.emit()
	var stagger: float = 0.0
	for target in reveal_targets:
		if not is_instance_valid(target):
			continue
		get_tree().create_timer(stagger).timeout.connect(func() -> void:
			if is_instance_valid(target):
				ItemFlight.pop_in(target, 0.4, 1.15)
		)
		stagger += 0.08
	# The pad itself shrinks away once what it bought has appeared.
	var shrink: Tween = create_tween()
	shrink.tween_interval(0.25)
	shrink.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shrink.tween_callback(func() -> void: visible = false)
