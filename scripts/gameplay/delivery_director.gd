class_name DeliveryDirector
extends Node
## Runs the endless postal shift. Hands out one task at a time, tracks its timer,
## the score, the combo and the stamps (lives). It spawns only saved scenes
## (letters, sky rings) and targets the homes and bounce pads already authored in
## the forest chunks. The UI and juice listen to its signals.

signal task_started(title: String, detail: String)
signal task_progress(detail: String)
signal task_completed(title: String, reward: int, world_position: Vector3)
signal task_failed(title: String)
signal pickup_collected(world_position: Vector3, points: int)
signal score_changed(score: int, combo: int)
signal stamps_changed(stamps: int)
signal shift_over(score: int, deliveries: int)

enum Kind { NONE, DELIVER, GATHER, SKY }

@export var courier_path: NodePath
@export var streamer_path: NodePath
@export var letter_scene_path: String = "res://scenes/gameplay/letter_pickup.tscn"
@export var ring_scene_path: String = "res://scenes/gameplay/sky_ring.tscn"

@export_group("Rules")
@export var start_stamps: int = 3
@export var next_task_delay: float = 1.4
## Order of task kinds, repeated. 1 = deliver, 2 = gather, 3 = sky mail.
@export var task_pattern: PackedInt32Array = PackedInt32Array([1, 2, 1, 3])
## Deliveries needed to reach the top run speed.
@export var ramp_deliveries: float = 14.0

@export_group("Distances and time")
@export var pickup_distance: float = 40.0
@export var deliver_min_distance: float = 55.0
@export var deliver_max_distance: float = 150.0
@export var gather_count: int = 5
@export var gather_spacing: float = 16.0
@export var sky_min_distance: float = 35.0
@export var sky_max_distance: float = 150.0
@export var ring_forward: float = 40.0
## Ring height above cruise altitude (an updraft reaches about +22 m).
@export var ring_height: float = 18.0
@export var time_slack: float = 1.9
@export var time_base: float = 9.0

@export_group("Rewards")
@export var deliver_reward: int = 150
@export var time_bonus_per_second: int = 6
@export var gather_letter_points: int = 25
@export var gather_reward: int = 120
@export var sky_reward: int = 250
@export var combo_step: float = 0.25

const RESIDENTS: PackedStringArray = [
	"Old Moss", "Bramble", "Fernsby", "Juniper", "Puffcap", "Willa Wren",
	"Tobias Toad", "Mira Moth", "Hazel", "Nettle", "Thistle", "Pip Acorn",
]
const WORLD_MASK: int = 1
const WATER_MASK: int = 4

var running: bool = false
var score: int = 0
var deliveries: int = 0
var combo: int = 0
var stamps: int = 0
var time_left: float = 0.0
var time_total: float = 1.0

var _courier: Glider
var _streamer: ChunkStreamer
var _letter_scene: PackedScene
var _ring_scene: PackedScene
var _kind: Kind = Kind.NONE
var _title: String = ""
var _carrying: bool = false
var _resident: String = ""
var _home: MushroomHome
var _pad: BounceMushroom
var _spawned: Array[Node3D] = []
var _gather_left: int = 0
var _pattern_index: int = 0
var _delay_left: float = 0.0


func _ready() -> void:
	_courier = get_node_or_null(courier_path) as Glider
	_streamer = get_node_or_null(streamer_path) as ChunkStreamer
	_letter_scene = load(letter_scene_path) as PackedScene
	_ring_scene = load(ring_scene_path) as PackedScene


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _kind == Kind.NONE:
		_delay_left -= delta
		if _delay_left <= 0.0:
			_start_next_task()
		return
	time_left -= delta
	if time_left <= 0.0:
		_fail()
		return
	if _kind == Kind.DELIVER and _carrying and not is_instance_valid(_home):
		_retarget_home()


## Starts a fresh shift: score, combo and stamps reset.
func start_shift() -> void:
	_clear_task()
	score = 0
	deliveries = 0
	combo = 0
	stamps = start_stamps
	_pattern_index = 0
	_delay_left = 0.8
	running = true
	if _courier:
		_courier.speed_bonus = 0.0
	score_changed.emit(score, combo)
	stamps_changed.emit(stamps)


func stop_shift() -> void:
	running = false
	_clear_task()


func has_target() -> bool:
	return _kind != Kind.NONE


## Where the compass should point for the current task step.
func get_target_position() -> Vector3:
	match _kind:
		Kind.DELIVER:
			if _carrying and is_instance_valid(_home):
				return _home.get_target_point()
			return _nearest_spawned()
		Kind.GATHER:
			return _nearest_spawned()
		Kind.SKY:
			if _courier and _courier.is_in_updraft() and not _spawned.is_empty():
				return _nearest_spawned()
			if is_instance_valid(_pad):
				return _pad.global_position + Vector3.UP * 1.5
			return _nearest_spawned()
	return Vector3.ZERO


## Remaining time as 0..1.
func get_time_ratio() -> float:
	return clampf(time_left / maxf(time_total, 0.01), 0.0, 1.0)


func get_task_title() -> String:
	return _title


func _start_next_task() -> void:
	var kind: int = task_pattern[_pattern_index % task_pattern.size()]
	_pattern_index += 1
	if kind == Kind.SKY and _start_sky():
		return
	if kind == Kind.GATHER and _start_gather():
		return
	if _start_deliver():
		return
	_start_gather()


func _start_deliver() -> bool:
	if _courier == null or _letter_scene == null:
		return false
	_kind = Kind.DELIVER
	_carrying = false
	_resident = RESIDENTS[randi() % RESIDENTS.size()]
	_title = "Mail for %s" % _resident
	var spot: Vector3 = _ahead_point(pickup_distance, randf_range(-7.0, 7.0))
	var letter: LetterPickup = _spawn_letter(spot)
	letter.collected.connect(_on_deliver_letter)
	_set_timer(pickup_distance)
	task_started.emit(_title, "Grab the leaf-letter")
	return true


func _on_deliver_letter(letter: LetterPickup) -> void:
	_spawned.erase(letter)
	pickup_collected.emit(letter.global_position, 0)
	_carrying = true
	if not _retarget_home():
		_complete(deliver_reward, letter.global_position)
		return
	task_progress.emit("Bring it to %s's mushroom" % _resident)


func _retarget_home() -> bool:
	if is_instance_valid(_home):
		_home.set_targeted(false)
		if _streamer:
			_streamer.unpin_node(_home)
	_home = _find_home()
	if _home == null:
		return false
	_home.set_targeted(true)
	if not _home.courier_arrived.is_connected(_on_home_arrived):
		_home.courier_arrived.connect(_on_home_arrived)
	if _streamer:
		_streamer.pin_node(_home)
	_set_timer(_flat_distance(_home.global_position))
	return true


func _on_home_arrived(home: MushroomHome) -> void:
	if home != _home or _kind != Kind.DELIVER or not _carrying:
		return
	home.celebrate()
	var bonus: int = int(time_left) * time_bonus_per_second
	_complete(deliver_reward + bonus, home.get_target_point())


func _start_gather() -> bool:
	if _courier == null or _letter_scene == null:
		return false
	_kind = Kind.GATHER
	_title = "Scattered letters"
	_gather_left = gather_count
	var phase: float = randf() * TAU
	for i: int in gather_count:
		var along: float = 30.0 + i * gather_spacing
		var side: float = sin(phase + i * 0.9) * 10.0
		var letter: LetterPickup = _spawn_letter(_ahead_point(along, side))
		letter.collected.connect(_on_gather_letter)
	_set_timer(30.0 + gather_count * gather_spacing)
	task_started.emit(_title, "Collect %d letters" % gather_count)
	return true


func _on_gather_letter(letter: LetterPickup) -> void:
	_spawned.erase(letter)
	_gather_left -= 1
	score += gather_letter_points
	score_changed.emit(score, combo)
	pickup_collected.emit(letter.global_position, gather_letter_points)
	if _gather_left <= 0:
		_complete(gather_reward, letter.global_position)
	else:
		task_progress.emit("%d letters left" % _gather_left)


func _start_sky() -> bool:
	if _courier == null or _ring_scene == null:
		return false
	_pad = _find_pad()
	if _pad == null:
		return false
	_kind = Kind.SKY
	_title = "Sky mail"
	var to_pad: Vector3 = _pad.global_position - _courier.global_position
	to_pad.y = 0.0
	var dir: Vector3 = to_pad.normalized() if to_pad.length() > 0.5 else _courier.get_forward()
	var ring: SkyRing = _ring_scene.instantiate() as SkyRing
	get_tree().current_scene.add_child(ring)
	var ring_ground: Vector3 = _pad.global_position + dir * ring_forward
	ring.global_position = Vector3(ring_ground.x, _ground_at(ring_ground) + _courier.cruise_height + ring_height, ring_ground.z)
	ring.look_at(ring.global_position + dir, Vector3.UP)
	ring.collected.connect(_on_ring)
	_spawned.append(ring)
	if _streamer:
		_streamer.pin_node(_pad)
	_set_timer(_flat_distance(_pad.global_position) + ring_forward + 10.0)
	task_started.emit(_title, "Bounce on a shelf mushroom, glide through the ring")
	return true


func _on_ring(ring: SkyRing) -> void:
	_spawned.erase(ring)
	_complete(sky_reward, ring.global_position)


func _complete(reward: int, world_position: Vector3) -> void:
	combo += 1
	var total: int = int(round(reward * (1.0 + combo_step * float(combo - 1))))
	score += total
	deliveries += 1
	if _courier:
		_courier.speed_bonus = clampf(float(deliveries) / ramp_deliveries, 0.0, 1.0)
	var title: String = _title
	_clear_task()
	task_completed.emit(title, total, world_position)
	score_changed.emit(score, combo)
	_delay_left = next_task_delay


func _fail() -> void:
	var title: String = _title
	_clear_task()
	combo = 0
	stamps -= 1
	task_failed.emit(title)
	stamps_changed.emit(stamps)
	score_changed.emit(score, combo)
	if stamps <= 0:
		running = false
		shift_over.emit(score, deliveries)
	else:
		_delay_left = next_task_delay


func _clear_task() -> void:
	for node: Node3D in _spawned:
		if is_instance_valid(node):
			if node.has_method("dismiss"):
				node.call("dismiss")
			else:
				node.queue_free()
	_spawned.clear()
	if is_instance_valid(_home):
		_home.set_targeted(false)
	_home = null
	_pad = null
	if _streamer:
		_streamer.clear_pins()
	_kind = Kind.NONE
	_carrying = false
	_title = ""


func _set_timer(distance: float) -> void:
	var speed: float = 8.0
	if _courier:
		speed = maxf(lerpf(_courier.cruise_speed, _courier.max_speed, _courier.speed_bonus), 4.0)
	time_total = distance / speed * time_slack + time_base
	time_left = time_total


func _spawn_letter(world_position: Vector3) -> LetterPickup:
	var letter: LetterPickup = _letter_scene.instantiate() as LetterPickup
	get_tree().current_scene.add_child(letter)
	letter.global_position = world_position
	_spawned.append(letter)
	return letter


func _nearest_spawned() -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF
	for node: Node3D in _spawned:
		if not is_instance_valid(node):
			continue
		var d: float = node.global_position.distance_squared_to(_courier.global_position)
		if d < best_d:
			best_d = d
			best = node.global_position
	return best


func _find_home() -> MushroomHome:
	var best: MushroomHome = null
	var best_score: float = -INF
	var forward: Vector3 = _courier.get_forward()
	for node: Node in get_tree().get_nodes_in_group(&"homes"):
		var home := node as MushroomHome
		if home == null or not home.is_inside_tree():
			continue
		var to_home: Vector3 = home.global_position - _courier.global_position
		to_home.y = 0.0
		var d: float = to_home.length()
		if d < deliver_min_distance or d > deliver_max_distance:
			continue
		var facing: float = forward.dot(to_home / d)
		var value: float = facing * 2.0 + randf() * 0.8
		if value > best_score:
			best_score = value
			best = home
	return best


func _find_pad() -> BounceMushroom:
	var best: BounceMushroom = null
	var best_score: float = -INF
	var forward: Vector3 = _courier.get_forward()
	for node: Node in get_tree().get_nodes_in_group(&"bounce_pads"):
		var pad := node as BounceMushroom
		if pad == null or not pad.is_inside_tree():
			continue
		var to_pad: Vector3 = pad.global_position - _courier.global_position
		to_pad.y = 0.0
		var d: float = to_pad.length()
		if d < sky_min_distance or d > sky_max_distance:
			continue
		var value: float = forward.dot(to_pad / d) * 2.0 - d * 0.01
		if value > best_score:
			best_score = value
			best = pad
	return best


func _ahead_point(along: float, side: float) -> Vector3:
	var forward: Vector3 = _courier.get_forward()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var origin: Vector3 = _courier.global_position + forward * along + right * side
	return _find_free_point(origin)


func _find_free_point(origin: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = _courier.get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 2.5
	var bodies: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	bodies.shape = shape
	bodies.collision_mask = WORLD_MASK
	bodies.exclude = [_courier.get_rid()]
	var water: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	water.shape = shape
	water.collision_mask = WATER_MASK
	water.collide_with_bodies = false
	water.collide_with_areas = true
	for i: int in 16:
		var offset: Vector3 = Vector3.ZERO
		if i > 0:
			offset = Vector3(cos(i * 2.4), 0.0, sin(i * 2.4)) * (1.5 + i * 0.9)
		var p: Vector3 = Vector3(origin.x + offset.x, 0.0, origin.z + offset.z)
		p.y = _ground_at(p) + _courier.cruise_height
		bodies.transform = Transform3D(Basis(), p)
		water.transform = bodies.transform
		if space.intersect_shape(bodies, 1).is_empty() and space.intersect_shape(water, 1).is_empty():
			return p
	return Vector3(origin.x, _ground_at(origin) + _courier.cruise_height, origin.z)


func _flat_distance(world_position: Vector3) -> float:
	var d: Vector3 = world_position - _courier.global_position
	d.y = 0.0
	return d.length()


func _ground_at(world_position: Vector3) -> float:
	var terrain := get_tree().get_first_node_in_group(&"terrain") as TerrainField
	if terrain == null:
		return 0.0
	return terrain.height_at(world_position.x, world_position.z)
