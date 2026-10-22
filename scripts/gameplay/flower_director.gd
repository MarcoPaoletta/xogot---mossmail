class_name FlowerDirector
extends Node
## Runs the endless flight: waves of glowing flowers floating at different
## heights along the glider's path. Collect every flower of a wave before the
## timer runs out; a missed wave costs a heart. Flowers are placed clear of
## tree canopies (ChunkStreamer.is_point_clear). The HUD listens to the signals.

signal wave_started(title: String, detail: String)
signal wave_progress(detail: String)
signal wave_completed(world_position: Vector3)
signal wave_failed
signal flower_collected(world_position: Vector3, total: int)
signal lives_changed(lives: int)
signal run_over(flowers: int)

@export var glider_path: NodePath
@export var streamer_path: NodePath
@export var flower_scene_path: String = "res://scenes/gameplay/flower_pickup.tscn"

@export_group("Rules")
@export var start_lives: int = 3
@export var next_wave_delay: float = 1.6
## Waves needed to reach the glider's top speed.
@export var ramp_waves: float = 10.0

@export_group("Waves")
@export var base_count: int = 5
@export var max_count: int = 9
@export var first_distance: float = 38.0
@export var spacing: float = 20.0
@export var side_amplitude: float = 11.0
## How far flower heights swing around the glider's current height (metres).
@export var height_amplitude: float = 15.0
## Flowers stay this far inside the lever's height range.
@export var height_margin: float = 3.0
@export var time_slack: float = 1.8
@export var time_base: float = 8.0
## Gap kept between a flower and any tree canopy or home.
@export var canopy_margin: float = 2.0

var running: bool = false
var flowers: int = 0
var wave: int = 0
var lives: int = 0
var time_left: float = 0.0
var time_total: float = 1.0

var _glider: Glider
var _streamer: ChunkStreamer
var _scene: PackedScene
var _spawned: Array[Node3D] = []
var _left: int = 0
var _wave_active: bool = false
var _delay_left: float = 0.0


func _ready() -> void:
	_glider = get_node_or_null(glider_path) as Glider
	_streamer = get_node_or_null(streamer_path) as ChunkStreamer
	_scene = load(flower_scene_path) as PackedScene


func _physics_process(delta: float) -> void:
	if not running:
		return
	if not _wave_active:
		_delay_left -= delta
		if _delay_left <= 0.0:
			_start_wave()
		return
	time_left -= delta
	if time_left <= 0.0:
		_fail_wave()


## Starts a fresh run: flowers and hearts reset.
func start_run() -> void:
	_clear_wave()
	flowers = 0
	wave = 0
	lives = start_lives
	_delay_left = 0.8
	running = true
	if _glider:
		_glider.speed_bonus = 0.0
	lives_changed.emit(lives)


func stop_run() -> void:
	running = false
	_clear_wave()


func has_target() -> bool:
	return _wave_active and not _spawned.is_empty()


## Nearest flower still waiting in the current wave.
func get_target_position() -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF
	for node: Node3D in _spawned:
		if not is_instance_valid(node):
			continue
		var d: float = node.global_position.distance_squared_to(_glider.global_position)
		if d < best_d:
			best_d = d
			best = node.global_position
	return best


## Remaining time as 0..1.
func get_time_ratio() -> float:
	return clampf(time_left / maxf(time_total, 0.01), 0.0, 1.0)


func _start_wave() -> void:
	if _glider == null or _scene == null:
		return
	wave += 1
	var count: int = mini(base_count + int(float(wave - 1) * 0.5), max_count)
	var phase: float = randf() * TAU
	var h0: float = _glider.get_target_height()
	var low: float = _glider.min_height + height_margin
	var high: float = _glider.max_height - height_margin
	var forward: Vector3 = _glider.get_forward()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	for i: int in count:
		var along: float = first_distance + i * spacing
		var side: float = sin(phase + i * 0.8) * side_amplitude
		var height: float = clampf(h0 + sin(phase * 1.7 + i * 0.9) * height_amplitude, low, high)
		var p: Vector3 = _glider.global_position + forward * along + right * side
		p.y = _ground_at(p) + height
		var flower: Collectible = _scene.instantiate() as Collectible
		get_tree().current_scene.add_child(flower)
		flower.global_position = _clear_point(p, right)
		flower.collected.connect(_on_flower)
		_spawned.append(flower)
	_left = count
	_wave_active = true
	var speed: float = maxf(lerpf(_glider.cruise_speed, _glider.max_speed, _glider.speed_bonus), 4.0)
	time_total = (first_distance + count * spacing) / speed * time_slack + time_base
	time_left = time_total
	wave_started.emit("Collect %d flowers" % count, "%d left" % count)


func _on_flower(item: Collectible) -> void:
	_spawned.erase(item)
	flowers += 1
	_left -= 1
	flower_collected.emit(item.global_position, flowers)
	if _left <= 0:
		_complete_wave(item.global_position)
	else:
		wave_progress.emit("%d left" % _left)


func _complete_wave(world_position: Vector3) -> void:
	_wave_active = false
	if _glider:
		_glider.speed_bonus = clampf(float(wave) / ramp_waves, 0.0, 1.0)
	wave_completed.emit(world_position)
	_delay_left = next_wave_delay


func _fail_wave() -> void:
	_clear_wave()
	lives -= 1
	wave_failed.emit()
	lives_changed.emit(lives)
	if lives <= 0:
		running = false
		run_over.emit(flowers)
	else:
		_delay_left = next_wave_delay


func _clear_wave() -> void:
	for node: Node3D in _spawned:
		if is_instance_valid(node) and node.has_method(&"dismiss"):
			node.call(&"dismiss")
	_spawned.clear()
	_wave_active = false
	_left = 0


## Moves a flower out of any canopy: sideways first, then above the treetops.
func _clear_point(p: Vector3, right: Vector3) -> Vector3:
	if _streamer == null or _streamer.is_point_clear(p, canopy_margin):
		return p
	for step: float in [5.0, -5.0, 10.0, -10.0, 15.0, -15.0]:
		var q: Vector3 = p + right * step
		q.y = _ground_at(q) + (p.y - _ground_at(p))
		if _streamer.is_point_clear(q, canopy_margin):
			return q
	var top: float = _streamer.get_obstacle_top(p, canopy_margin)
	return Vector3(p.x, maxf(p.y, top + canopy_margin + 1.5), p.z)


func _ground_at(world_position: Vector3) -> float:
	var terrain := get_tree().get_first_node_in_group(&"terrain") as TerrainField
	if terrain == null:
		return 0.0
	return terrain.height_at(world_position.x, world_position.z)
