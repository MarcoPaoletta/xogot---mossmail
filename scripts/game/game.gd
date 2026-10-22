extends Node3D
## Mossmail game flow: TITLE -> CUSTOMIZE -> PLAYING -> RESULTS -> PLAYING or TITLE.
## Coordinates the glider, camera, steering, altitude lever, flower director
## and UI screens, and routes feedback (shake, flashes, popups). It constructs
## no scene content.

enum Flow { TITLE, CUSTOMIZE, PLAYING, RESULTS }

const SAVE_PATH: String = "user://mossmail.cfg"

@export var courier_path: NodePath = ^"Glider"
@export var camera_rig_path: NodePath = ^"CameraRig"
@export var steer_path: NodePath = ^"SteerInput"
@export var director_path: NodePath = ^"FlowerDirector"
@export var title_path: NodePath = ^"UI/TitleScreen"
@export var customize_path: NodePath = ^"UI/CustomizeScreen"
@export var hud_path: NodePath = ^"UI/Hud"
@export var results_path: NodePath = ^"UI/ResultsScreen"
@export var screen_fx_path: NodePath = ^"FX/ScreenFx"

@export_group("Altitude")
## Lever travel per second at full up/down tilt (0..1 units).
@export var tilt_lever_rate: float = 0.55

@export_group("Feedback")
@export var bump_trauma: float = 0.55
@export var collect_fov_punch: float = 2.5
@export var wave_fov_punch: float = 6.0
@export var boost_fov_punch: float = 9.0
@export var collect_flash: Color = Color(1.0, 0.86, 0.5)
@export var bump_flash: Color = Color(0.9, 0.35, 0.25)
@export var fail_flash: Color = Color(0.7, 0.2, 0.2)

var _flow: Flow = Flow.TITLE
var _best: int = 0
var _glider: Glider
var _rig: CourierCamera
var _steer: SteerInput
var _director: FlowerDirector
var _title: TitleScreen
var _customize: CustomizeScreen
var _hud: Hud
var _results: ResultsScreen
var _fx: ScreenFx
var _lever: AltitudeLever


func _ready() -> void:
	_glider = get_node_or_null(courier_path) as Glider
	_rig = get_node_or_null(camera_rig_path) as CourierCamera
	_steer = get_node_or_null(steer_path) as SteerInput
	_director = get_node_or_null(director_path) as FlowerDirector
	_title = get_node_or_null(title_path) as TitleScreen
	_customize = get_node_or_null(customize_path) as CustomizeScreen
	_hud = get_node_or_null(hud_path) as Hud
	_results = get_node_or_null(results_path) as ResultsScreen
	_fx = get_node_or_null(screen_fx_path) as ScreenFx
	if _hud:
		_lever = _hud.get_lever()
	_load_best()
	_connect_signals()
	_enter_title()


func _process(delta: float) -> void:
	if _glider == null or _steer == null:
		return
	_glider.steer = _steer.steer
	if _flow != Flow.PLAYING:
		return
	if _lever:
		_lever.nudge(_steer.get_pitch() * tilt_lever_rate * delta)
		_glider.altitude_input = _lever.value
	if _hud and _director:
		_hud.set_timer(_director.get_time_ratio())
		if _director.has_target() and _rig:
			_hud.update_compass(_rig.get_camera(), _glider.global_position, _director.get_target_position())
	if _fx:
		var fast: float = 0.15
		if _glider.is_boosting():
			fast = 0.8
		elif _glider.get_speed() > _glider.cruise_speed + 2.0:
			fast = 0.4
		_fx.set_speed_lines(fast)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		if _flow == Flow.TITLE:
			_enter_customize()
		elif _flow == Flow.CUSTOMIZE:
			_start_run()


func _connect_signals() -> void:
	if _title:
		_title.play_pressed.connect(_enter_customize)
	if _customize:
		_customize.play_pressed.connect(_start_run)
		_customize.color_chosen.connect(func(index: int) -> void:
			if _glider:
				_glider.set_color_index(index))
	if _results:
		_results.again_pressed.connect(_start_run)
		_results.menu_pressed.connect(_enter_title)
	if _steer and _hud:
		_steer.sides_changed.connect(_hud.set_sides)
	if _glider:
		_glider.bumped.connect(_on_bumped)
		_glider.boost_started.connect(_on_boost)
	if _director:
		_director.wave_started.connect(_on_wave_started)
		_director.wave_progress.connect(_on_wave_progress)
		_director.wave_completed.connect(_on_wave_completed)
		_director.wave_failed.connect(_on_wave_failed)
		_director.flower_collected.connect(_on_flower)
		_director.lives_changed.connect(_on_lives_changed)
		_director.run_over.connect(_on_run_over)


func _enter_title() -> void:
	_flow = Flow.TITLE
	if _director:
		_director.stop_run()
	_set_flying(false)
	if _hud:
		_hud.hide_screen()
	if _results:
		_results.hide_screen()
	if _customize:
		_customize.hide_screen()
	if _title:
		_title.show_screen()


func _enter_customize() -> void:
	if _flow != Flow.TITLE:
		return
	_flow = Flow.CUSTOMIZE
	if _title:
		_title.hide_screen()
	if _customize:
		_customize.show_screen()


func _start_run() -> void:
	_flow = Flow.PLAYING
	if _title:
		_title.hide_screen()
	if _customize:
		_customize.hide_screen()
	if _results:
		_results.hide_screen()
	if _hud:
		_hud.show_screen()
		_hud.begin_run(_glider.default_altitude if _glider else 0.4)
	if _steer:
		_steer.calibrate_tilt()
	_set_flying(true)
	if _director:
		_director.start_run()


func _set_flying(on: bool) -> void:
	if _glider:
		_glider.active = on
	if _steer:
		_steer.enabled = on
		if not on:
			_steer.clear()
	if _rig:
		_rig.menu_mode = not on
	if _fx and not on:
		_fx.set_speed_lines(0.0)


func _on_run_over(flowers: int) -> void:
	_flow = Flow.RESULTS
	_set_flying(false)
	var new_best: bool = flowers > _best
	if new_best:
		_best = flowers
		_save_best()
	if _hud:
		_hud.hide_screen()
	if _results:
		_results.show_results(flowers, _best, new_best)


func _on_wave_started(title: String, detail: String) -> void:
	if _hud:
		_hud.set_task(title, detail)


func _on_wave_progress(detail: String) -> void:
	if _hud:
		_hud.set_detail(detail)


func _on_wave_completed(_world_position: Vector3) -> void:
	if _hud:
		_hud.clear_task()
		_hud.show_banner("All collected!", Color("#ffe39a"))
	if _rig:
		_rig.punch_fov(wave_fov_punch)
		_rig.add_trauma(0.2)
	if _fx:
		_fx.flash(collect_flash, 0.28)


func _on_wave_failed() -> void:
	if _hud:
		_hud.clear_task()
		_hud.show_banner("Too late!", Color("#ff8a75"))
	if _rig:
		_rig.add_trauma(0.35)
	if _fx:
		_fx.flash(fail_flash, 0.35)


func _on_flower(world_position: Vector3, total: int) -> void:
	if _hud:
		_hud.set_flowers(total)
		_hud.popup("+1", _to_screen(world_position), Color("#ffe39a"))
	if _rig:
		_rig.punch_fov(collect_fov_punch)
	if _fx:
		_fx.flash(collect_flash, 0.12, 0.04, 0.25)


func _on_lives_changed(lives: int) -> void:
	if _hud:
		_hud.set_lives(lives)


func _on_bumped(strength: float) -> void:
	if _rig:
		_rig.add_trauma(bump_trauma * strength)
	if _fx:
		_fx.flash(bump_flash, 0.3 * strength)


func _on_boost() -> void:
	if _rig:
		_rig.punch_fov(boost_fov_punch)
		_rig.add_trauma(0.2)
	if _hud and _flow == Flow.PLAYING:
		_hud.show_banner("Super speed!", Color("#ffd27a"))


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
		_best = int(config.get_value("flight", "best_flowers", 0))


func _save_best() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("flight", "best_flowers", _best)
	config.save(SAVE_PATH)
