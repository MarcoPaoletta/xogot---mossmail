class_name ItemTray
extends Node3D
## A neat grid of items lying on a surface: the output tray of a station, the
## pile of cash on a counter, the ice tray of a display case. Items fly in on
## an arc, land in the next slot with a squash, and leave from the top.
##
## Slots fill row by row, then climb layer by layer, so a pile visibly grows.
## The node sits on the surface; the script only places the items it is given.

signal changed(count: int)

@export var columns: int = 3
@export var rows: int = 3
@export var layers: int = 4
@export var cell_size: Vector2 = Vector2(0.45, 0.45)
@export var layer_height: float = 0.12
@export var fly_duration: float = 0.28
@export var fly_apex: float = 0.6
@export var land_squash: float = 0.25
@export var random_yaw: float = 0.35

var _items: Array[Node3D] = []
var _incoming: int = 0


func capacity() -> int:
	return columns * rows * layers


func count() -> int:
	return _items.size()


func is_full() -> bool:
	return _items.size() + _incoming >= capacity()


func is_empty() -> bool:
	return _items.is_empty()


func slot_local_position(index: int) -> Vector3:
	var per_layer: int = columns * rows
	var layer: int = floori(float(index) / float(per_layer))
	var within: int = index % per_layer
	var column: int = within % columns
	var row: int = floori(float(within) / float(columns))
	return Vector3(
		(float(column) - float(columns - 1) * 0.5) * cell_size.x,
		(float(layer) + 0.5) * layer_height,
		(float(row) - float(rows - 1) * 0.5) * cell_size.y
	)


## Flies `item` (already in the tree) into the next free slot. False if full.
## The slot is reserved at once; `delay` only staggers the start of the flight.
func push(item: Node3D, delay: float = 0.0) -> bool:
	if is_full():
		return false
	var slot: int = _items.size() + _incoming
	var keep: Transform3D = item.global_transform
	if item.get_parent() != self:
		item.reparent(self, true)
	item.global_transform = keep
	_incoming += 1
	var live_slot: Callable = func() -> Vector3:
		return to_global(slot_local_position(slot))
	var launch: Callable = func() -> void:
		if is_instance_valid(item):
			ItemFlight.fly(item, live_slot, fly_duration, fly_apex, 0.5, _on_landed)
		else:
			_incoming = maxi(_incoming - 1, 0)
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(launch)
	else:
		launch.call()
	return true


## Moves the top item into a CarryStack. False if the tray is empty or the
## stack is full. The stack takes it from here with its own pickup flight.
func transfer_to_stack(stack: CarryStack) -> bool:
	if _items.is_empty() or stack.is_full():
		return false
	var item: Node3D = _items[_items.size() - 1]
	if not stack.add_item(item):
		return false
	_items.remove_at(_items.size() - 1)
	changed.emit(_items.size())
	return true


## Removes the top item and flies it to `target` (cash flying to the HUD, a
## fish leaving a display case to a customer). `on_arrive` receives the item.
func send_top(target: Callable, duration: float = 0.3, apex: float = 0.6, on_arrive: Callable = Callable()) -> Node3D:
	if _items.is_empty():
		return null
	var item: Node3D = _items[_items.size() - 1]
	_items.remove_at(_items.size() - 1)
	changed.emit(_items.size())
	ItemFlight.fly(item, target, duration, apex, 0.25, on_arrive)
	return item


func _on_landed(item: Node3D) -> void:
	_incoming = maxi(_incoming - 1, 0)
	if not is_instance_valid(item):
		return
	var index: int = _items.size()
	item.top_level = false
	item.position = slot_local_position(index)
	item.rotation = Vector3(0.0, randf_range(-random_yaw, random_yaw), 0.0)
	_items.append(item)
	ItemFlight.squash(item, land_squash)
	changed.emit(_items.size())
