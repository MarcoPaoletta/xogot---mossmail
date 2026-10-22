extends Node3D
## Mossmail game flow: TITLE -> PLAYING <-> PAUSED -> RESULTS -> PLAYING or TITLE.
## Coordinates the courier, camera, steering, delivery director and UI screens,
## and routes feedback (shake, flashes, popups). It constructs no scene content.

enum Flow { TITLE, PLAYING, PAUSED, RESULTS }

const SAVE_PATH: String = "user://mossmail.cfg"

@export var courier_path: NodePath = ^"Glider"
@export var camera_rig_path: NodePath = ^"CameraRig"
@export var steer_path: NodePath = ^"SteerInput"
@export var director_path: NodePath = ^"DeliveryDirector"
@export var title_path: NodePath = ^"UI/TitleScreen"
@export var hud_path: NodePath = ^"UI/Hud"
@export var pause_path: NodePath = ^"UI/PauseScreen"
@export var results_path: NodePath = ^"UI/ResultsScreen"
@export var screen_fx_path: NodePath = ^"FX/ScreenFx"

@export_group("Feedback")
@export var bump_trauma: float = 0.55
@export var launch_fov_punch: float = 8.0
@export var deliver_fov_punch: float = 6.0
@export var deliver_flash: Color = Color(1.0, 0.86, 0.5)
@export var bump_flash: Color = Color(0.9, 0.35, 0.25)
@export var fail_flash: Color = Color(0.7, 0.2, 0.2)

var _flow: Flow = Flow.TITLE
var _best: int = 0
var _courier: Glider
var _rig: CourierCamera
var _steer: SteerInput
var _director: DeliveryDirector
var _title: TitleScreen
var _hud: Hud
var _pause: PauseScreen
var _results: ResultsScreen
var _fx: ScreenFx


func _ready() -> void:
	_courier = get_node_or_null(courier_path) as Glider
	_rig = get_node_or_null(camera_rig_path) as CourierCamera
	_steer = get_node_or_null(steer_path) as SteerInput
	_director = get_node_or_null(director_path) as DeliveryDirector
	_title = get_node_or_null(title_path) as TitleScreen
	_hud = get_node_or_null(hud_path) as Hud
	_pause = get_node_or_null(pause_path) as PauseScreen
	_results = get_node_or_null(results_path) as ResultsScreen
	_fx = get_node_or_null(screen_fx_path) as ScreenFx
	_load_best()
	_connect_signals()
	_enter_title()


func _process(_delta: float) -> void:
	if _courier == null or _steer == null:
		return
	_courier.steer = _steer.steer
	if _flow != Flow.PLAYING:
		return
	if _hud and _director:
		_hud.set_timer(_director.get_time_ratio())
		if _director.has_target() and _rig:
			_hud.update_compass(_rig.get_camera(), _courier.global_position, _director.get_target_position())
	if _fx:
		var fast: float = 0.15
		if _courier.is_in_updraft():
			fast = 0.75
		elif _courier.get_speed() > _courier.cruise_speed + 2.0:
			fast = 0.4
		_fx.set_speed_lines(fast)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if _flow == Flow.PLAYING:
			_pause_game()
		elif _flow == Flow.PAUSED:
			_resume_game()
	elif event.is_action_pressed(&"ui_accept") and _flow == Flow.TITLE:
		_start_shift()


func _connect_signals() -> void:
	if _title:
		_title.play_pressed.connect(_start_shift)
		_title.tilt_toggled.connect(func(on: bool) -> void:
			if _steer:
				_steer.tilt_enabled = on)
	if _hud:
		_hud.pause_pressed.connect(_pause_game)
	if _pause:
		_pause.resume_pressed.connect(_resume_game)
		_pause.quit_pressed.connect(_quit_to_title)
	if _results:
		_results.again_pressed.connect(_start_shift)
		_results.menu_pressed.connect(_enter_title)
	if _steer and _hud:
		_steer.sides_changed.connect(_hud.set_sides)
	if _courier:
		_courier.bumped.connect(_on_bumped)
		_courier.launched.connect(_on_launched)
	if _director:
		_director.task_started.connect(_on_task_started)
		_director.task_progress.connect(_on_task_progress)
		_director.task_completed.connect(_on_task_completed)
		_director.task_failed.connect(_on_task_failed)
		_director.pickup_collected.connect(_on_pickup)
		_director.score_changed.connect(_on_score_changed)
		_director.stamps_changed.connect(_on_stamps_changed)
		_director.shift_over.connect(_on_shift_over)


func _enter_title() -> void:
	get_tree().paused = false
	_flow = Flow.TITLE
	if _director:
		_director.stop_shift()
	if _courier:
		_courier.active = false
	if _steer:
		_steer.enabled = false
		_steer.clear()
	if _rig:
		_rig.menu_mode = true
	if _fx:
		_fx.set_speed_lines(0.0)
	if _hud:
		_hud.hide_screen()
	if _pause:
		_pause.hide_screen()
	if _results:
		_results.hide_screen()
	if _title:
		_title.set_best(_best)
		_title.show_screen()


func _start_shift() -> void:
	get_tree().paused = false
	_flow = Flow.PLAYING
	if _title:
		_title.hide_screen()
	if _results:
		_results.hide_screen()
	if _pause:
		_pause.hide_screen()
	if _hud:
		_hud.show_screen()
		_hud.begin_shift()
	if _rig:
		_rig.menu_mode = false
	if _steer:
		_steer.calibrate_tilt()
		_steer.enabled = true
	if _courier:
		_courier.active = true
	if _director:
		_director.start_shift()


func _pause_game() -> void:
	if _flow != Flow.PLAYING:
		return
	_flow = Flow.PAUSED
	if _steer:
		_steer.clear()
	get_tree().paused = true
	if _pause:
		_pause.show_screen()


func _resume_game() -> void:
	if _flow != Flow.PAUSED:
		return
	_flow = Flow.PLAYING
	get_tree().paused = false
	if _pause:
		_pause.hide_screen()
	if _steer:
		_steer.calibrate_tilt()


func _quit_to_title() -> void:
	_enter_title()


func _on_shift_over(score: int, deliveries: int) -> void:
	_flow = Flow.RESULTS
	if _courier:
		_courier.active = false
	if _steer:
		_steer.enabled = false
		_steer.clear()
	if _rig:
		_rig.menu_mode = true
	if _fx:
		_fx.set_speed_lines(0.0)
	var new_best: bool = score > _best
	if new_best:
		_best = score
		_save_best()
	if _hud:
		_hud.hide_screen()
	if _results:
		_results.show_results(score, deliveries, _best, new_best)


func _on_task_started(title: String, detail: String) -> void:
	if _hud:
		_hud.set_task(title, detail)


func _on_task_progress(detail: String) -> void:
	if _hud:
		_hud.set_detail(detail)


func _on_task_completed(_title_text: String, reward: int, world_position: Vector3) -> void:
	if _hud:
		_hud.clear_task()
		_hud.show_banner("Delivered!", Color("#ffe39a"))
		_hud.popup("+%d" % reward, _to_screen(world_position), Color("#ffe39a"))
	if _rig:
		_rig.punch_fov(deliver_fov_punch)
		_rig.add_trauma(0.2)
	if _fx:
		_fx.flash(deliver_flash, 0.28)


func _on_task_failed(_title_text: String) -> void:
	if _hud:
		_hud.clear_task()
		_hud.show_banner("Too late!", Color("#ff8a75"))
	if _rig:
		_rig.add_trauma(0.35)
	if _fx:
		_fx.flash(fail_flash, 0.35)


func _on_pickup(world_position: Vector3, points: int) -> void:
	if _hud:
		var label: String = "+%d" % points if points > 0 else "Got it!"
		_hud.popup(label, _to_screen(world_position), Color("#f6ecd0"))
	if _rig:
		_rig.punch_fov(3.0)


func _on_score_changed(score: int, combo: int) -> void:
	if _hud:
		_hud.set_score(score, combo)


func _on_stamps_changed(stamps: int) -> void:
	if _hud:
		_hud.set_stamps(stamps)


func _on_bumped(strength: float) -> void:
	if _rig:
		_rig.add_trauma(bump_trauma * strength)
	if _fx:
		_fx.flash(bump_flash, 0.3 * strength)


func _on_launched() -> void:
	if _rig:
		_rig.punch_fov(launch_fov_punch)
		_rig.add_trauma(0.15)
	if _hud and _flow == Flow.PLAYING:
		_hud.show_banner("Updraft!", Color("#ffd27a"))


func _to_screen(world_position: Vector3) -> Vector2:
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	if _rig == null or _rig.get_camera() == null:
		return center
	var camera: Camera3D = _rig.get_camera()
	if camera.is_position_behind(world_position):
		return center
	return camera.unproject_position(world_position)


func _load_best() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		_best = int(config.get_value("shift", "best", 0))


func _save_best() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("shift", "best", _best)
	config.save(SAVE_PATH)
