class_name CarryStack
extends Node3D
## The stack on the player's back. This is the single most recognisable image
## of the genre: a tower of goods that trails behind the runner, leans into
## every turn, wobbles at the top and swallows each new item with a pop.
##
## Put this script on a node called `BackStack` (a child of the player scene,
## placed on the character's back and rotated so +Y points up). The node and
## its pickup AudioStreamPlayer are authored in the player scene with the
## editor tools. The script only moves the items it is handed.
##
## Items must be Node3D instances of a saved scene, already in the tree
## (spawned by the thing that produced them: the water, a table, a tray).
## Tag each item with `item.set_meta("kind", &"fish")` so stations can ask for
## a kind.
##
## The trailing look comes from ONE idea: every item chases its slot with its
## own stiffness, stiff at the bottom and loose at the top. At speed v an item
## with stiffness k trails its slot by about v / k metres, so the tower bends
## smoothly with no overlap and no spring simulation.

signal item_added(item: Node3D, count: int)
signal item_removed(item: Node3D, count: int)
signal rejected_full
signal capacity_changed(new_capacity: int)

@export_group("Capacity")
@export var capacity: int = 6:
	set(value):
		capacity = maxi(value, 1)
		capacity_changed.emit(capacity)
@export var item_height: float = 0.2

@export_group("Trailing")
## Stiffness of the bottom item. High means glued to the back.
@export var follow_k_bottom: float = 40.0
## Stiffness of the top item. Lag in metres at speed v is about v / k.
@export var follow_k_top: float = 11.0
@export var yaw_k: float = 9.0
@export var reference_speed: float = 6.0
@export var sway_amount: float = 0.03
@export var sway_speed: float = 9.0
@export var idle_wobble_degrees: float = 4.0
@export var teleport_snap_distance: float = 3.0

@export_group("Pickup flight")
@export var pickup_duration: float = 0.3
@export var pickup_apex: float = 0.7
@export var pickup_spin_turns: float = 0.5
@export var land_squash: float = 0.28

@export_group("Audio")
@export var pickup_sound: AudioStreamPlayer
@export var pitch_step: float = 0.05
@export var pitch_max: float = 2.0

var _stacked: Array[Node3D] = []
var _flying: int = 0
var _velocity: Vector3 = Vector3.ZERO
var _last_position: Vector3 = Vector3.ZERO
var _time: float = 0.0


func _ready() -> void:
	_last_position = global_position


func _process(delta: float) -> void:
	_time += delta
	var raw: Vector3 = (global_position - _last_position) / maxf(delta, 0.0001)
	_last_position = global_position
	_velocity = _velocity.lerp(raw, 1.0 - exp(-10.0 * delta))
	var speed01: float = clampf(Vector2(_velocity.x, _velocity.z).length() / reference_speed, 0.0, 1.0)
	var span: float = float(maxi(capacity - 1, 1))
	var right: Vector3 = global_transform.basis.x
	for i in _stacked.size():
		var item: Node3D = _stacked[i]
		if not is_instance_valid(item):
			continue
		var k: float = lerpf(follow_k_bottom, follow_k_top, float(i) / span)
		var target: Vector3 = slot_global_position(i)
		target += right * sin(_time * sway_speed + float(i) * 0.6) * sway_amount * float(i) * speed01
		if item.global_position.distance_to(target) > teleport_snap_distance:
			item.global_position = target
		else:
			item.global_position = item.global_position.lerp(target, 1.0 - exp(-k * delta))
		var yaw_target: float = global_rotation.y + float(item.get_meta("stack_yaw", 0.0))
		item.global_rotation.y = lerp_angle(item.global_rotation.y, yaw_target, 1.0 - exp(-yaw_k * delta))
		item.global_rotation.z = deg_to_rad(idle_wobble_degrees) * sin(_time * 5.0 + float(i) * 1.7)


## World position of slot `index`. Index 0 is the bottom of the stack.
func slot_global_position(index: int) -> Vector3:
	return global_transform * Vector3(0.0, (float(index) + 0.5) * item_height, 0.0)


func count() -> int:
	return _stacked.size()


func free_slots() -> int:
	return capacity - _stacked.size() - _flying


func is_full() -> bool:
	return free_slots() <= 0


func is_empty() -> bool:
	return _stacked.is_empty()


func has_kind(kind: StringName) -> bool:
	return _find_top_index(kind) >= 0


## Takes ownership of `item` and flies it onto the stack. False when full
## (the caller should keep the item where it was and a reject cue fires).
func add_item(item: Node3D) -> bool:
	if is_full():
		rejected_full.emit()
		return false
	var slot: int = _stacked.size() + _flying
	var keep: Transform3D = item.global_transform
	if item.get_parent() != self:
		item.reparent(self, true)
	item.top_level = true
	item.global_transform = keep
	item.set_meta("stack_yaw", randf_range(-0.2, 0.2))
	item.set_meta("base_scale", item.scale)
	_flying += 1
	var live_slot: Callable = func() -> Vector3:
		return slot_global_position(mini(slot, _stacked.size()))
	ItemFlight.fly(item, live_slot, pickup_duration, pickup_apex, pickup_spin_turns, _on_item_landed)
	return true


## Pops the topmost item of `kind` (any kind when empty) and flies it to
## `target`. Items above it settle down into the gap. Returns the item, or
## null if there was none. `on_arrive` receives the item.
func send_top(
	target: Callable,
	duration: float = 0.24,
	apex: float = 0.6,
	on_arrive: Callable = Callable(),
	kind: StringName = &""
) -> Node3D:
	var index: int = _find_top_index(kind)
	if index < 0:
		return null
	var item: Node3D = _stacked[index]
	_stacked.remove_at(index)
	item_removed.emit(item, _stacked.size())
	ItemFlight.fly(item, target, duration, apex, 0.25, on_arrive)
	return item


func _find_top_index(kind: StringName) -> int:
	for i in range(_stacked.size() - 1, -1, -1):
		if kind == &"" or _stacked[i].get_meta("kind", &"") == kind:
			return i
	return -1


func _on_item_landed(item: Node3D) -> void:
	_flying = maxi(_flying - 1, 0)
	_stacked.append(item)
	ItemFlight.squash(item, land_squash)
	_ripple()
	_play_pickup()
	item_added.emit(item, _stacked.size())


## A quick wave up the tower, so the whole stack acknowledges each pickup.
func _ripple() -> void:
	for i in _stacked.size() - 1:
		var item: Node3D = _stacked[i]
		if not is_instance_valid(item):
			continue
		var base: Vector3 = item.get_meta("base_scale", item.scale)
		var tween: Tween = item.create_tween()
		tween.tween_interval(0.02 * float(i))
		tween.tween_property(item, "scale", base * 1.08, 0.06).set_trans(Tween.TRANS_SINE)
		tween.tween_property(item, "scale", base, 0.1).set_trans(Tween.TRANS_SINE)


func _play_pickup() -> void:
	if pickup_sound == null:
		return
	pickup_sound.pitch_scale = minf(1.0 + pitch_step * float(_stacked.size() - 1), pitch_max)
	pickup_sound.play()
