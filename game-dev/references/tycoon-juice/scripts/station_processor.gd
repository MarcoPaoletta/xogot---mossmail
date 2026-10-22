class_name StationProcessor
extends Node3D
## A processing station: the "cut fish" table. The player walks into the input
## zone and the stack empties onto it one item at a time, faster and faster.
## The station chops (with a tick per cut), and the result lands on an output
## tray the player walks into to scoop it back onto their stack.
##
## Authored in the station scene (editor tools): two Area3D zones, two
## Marker3D points, an ItemTray, the table mesh, a progress ring. The script
## wires them and runs the cycle. Visuals and sound hang off the signals.
##
## The player body must be in group `player` and expose a `carry_stack`
## property that holds its CarryStack.

signal input_received(buffered: int)
signal buffer_changed(buffered: int)
signal cycle_started
signal progress_changed(value: float)
signal chop(index: int, total: int)
signal cycle_completed(outputs: int)
signal blocked_changed(is_blocked: bool)

@export_group("Authored nodes")
@export var input_zone: Area3D
@export var output_zone: Area3D
@export var input_point: Marker3D
@export var output_point: Marker3D
@export var output_tray: ItemTray

@export_group("Recipe")
@export var accepts_kind: StringName = &"fish"
@export var output_scene: PackedScene
@export var output_kind: StringName = &"fillet"
@export var outputs_per_input: int = 2
@export var buffer_capacity: int = 10
@export var process_time: float = 1.2
@export var chops_per_cycle: int = 3

@export_group("Cadence")
## The player's stack empties onto the station faster the longer they stand.
@export var feed_interval_start: float = 0.22
@export var feed_interval_min: float = 0.06
@export var feed_accel: float = 0.85
@export var pickup_interval_start: float = 0.16
@export var pickup_interval_min: float = 0.05
@export var pickup_accel: float = 0.88
@export var input_flight: float = 0.22

var _feeder: CarryStack = null
var _picker: CarryStack = null
var _feed_interval: float = 0.0
var _feed_cooldown: float = 0.0
var _pick_interval: float = 0.0
var _pick_cooldown: float = 0.0
var _buffer: int = 0
var _in_flight: int = 0
var _busy: bool = false
var _pending_outputs: int = 0
var _chops_done: int = 0
var _is_blocked: bool = false


func _ready() -> void:
	_feed_interval = feed_interval_start
	_pick_interval = pickup_interval_start
	input_zone.body_entered.connect(_on_input_entered)
	input_zone.body_exited.connect(_on_input_exited)
	output_zone.body_entered.connect(_on_output_entered)
	output_zone.body_exited.connect(_on_output_exited)
	output_tray.changed.connect(_on_tray_changed)


func _process(delta: float) -> void:
	_feed_cooldown -= delta
	_pick_cooldown -= delta
	if _feeder != null and _feed_cooldown <= 0.0 and _buffer + _in_flight < buffer_capacity:
		var sent: Node3D = _feeder.send_top(
			func() -> Vector3: return input_point.global_position,
			input_flight, 0.5, _on_input_arrived, accepts_kind
		)
		if sent != null:
			_in_flight += 1
			_feed_interval = maxf(_feed_interval * feed_accel, feed_interval_min)
			_feed_cooldown = _feed_interval
	if _picker != null and _pick_cooldown <= 0.0 and not output_tray.is_empty():
		if output_tray.transfer_to_stack(_picker):
			_pick_interval = maxf(_pick_interval * pickup_accel, pickup_interval_min)
			_pick_cooldown = _pick_interval


func buffered() -> int:
	return _buffer


func is_busy() -> bool:
	return _busy


func _stack_of(body: Node) -> CarryStack:
	if not body.is_in_group("player"):
		return null
	return body.get("carry_stack") as CarryStack


func _on_input_entered(body: Node3D) -> void:
	_feeder = _stack_of(body)
	_feed_interval = feed_interval_start
	_feed_cooldown = 0.0


func _on_input_exited(body: Node3D) -> void:
	if _stack_of(body) == _feeder:
		_feeder = null


func _on_output_entered(body: Node3D) -> void:
	_picker = _stack_of(body)
	_pick_interval = pickup_interval_start
	_pick_cooldown = 0.0


func _on_output_exited(body: Node3D) -> void:
	if _stack_of(body) == _picker:
		_picker = null


func _on_input_arrived(item: Node3D) -> void:
	_in_flight = maxi(_in_flight - 1, 0)
	if is_instance_valid(item):
		item.queue_free()
	_buffer += 1
	buffer_changed.emit(_buffer)
	input_received.emit(_buffer)
	_try_start()


func _try_start() -> void:
	if _busy or _buffer <= 0 or _pending_outputs > 0:
		return
	_busy = true
	_buffer -= 1
	_chops_done = 0
	buffer_changed.emit(_buffer)
	cycle_started.emit()
	var tween: Tween = create_tween()
	tween.tween_method(_on_progress, 0.0, 1.0, maxf(process_time, 0.05))
	tween.tween_callback(_finish_cycle)


func _on_progress(t: float) -> void:
	progress_changed.emit(t)
	var due: int = floori(t * float(chops_per_cycle))
	while _chops_done < due:
		_chops_done += 1
		chop.emit(_chops_done, chops_per_cycle)


func _finish_cycle() -> void:
	# Make sure the last chop always fires, even on a very short process_time.
	while _chops_done < chops_per_cycle:
		_chops_done += 1
		chop.emit(_chops_done, chops_per_cycle)
	progress_changed.emit(0.0)
	_pending_outputs += outputs_per_input
	_flush_outputs()
	_busy = false
	cycle_completed.emit(outputs_per_input)
	_try_start()


## Spawns pending results at the output point and flies them to the tray, one
## after another. If the tray is full the station waits, visibly blocked.
func _flush_outputs() -> void:
	var launched: int = 0
	while _pending_outputs > 0 and not output_tray.is_full():
		var piece: Node3D = output_scene.instantiate() as Node3D
		output_point.add_child(piece)
		piece.global_position = output_point.global_position
		piece.set_meta("kind", output_kind)
		ItemFlight.pop_in(piece, 0.18, 1.1)
		output_tray.push(piece, 0.08 * float(launched))
		_pending_outputs -= 1
		launched += 1
	var now_blocked: bool = _pending_outputs > 0
	if now_blocked != _is_blocked:
		_is_blocked = now_blocked
		blocked_changed.emit(_is_blocked)


func _on_tray_changed(_count: int) -> void:
	if _pending_outputs > 0:
		_flush_outputs()
		if _pending_outputs == 0:
			_try_start()
