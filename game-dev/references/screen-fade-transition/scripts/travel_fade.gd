extends CanvasLayer

signal phase_changed(value: StringName)
signal transition_finished

@onready var veil: ColorRect = $Veil
@onready var snapshot: TextureRect = $Snapshot

## Sea <-> town travel (feedback round 4): the leaving camera zooms towards the
## destination while the next scene loads on a thread, the last frame is kept
## as a snapshot over the new scene, and the snapshot cross-fades away while
## the arriving camera eases from the matching zoom back to its own.
const TRAVEL_ZOOM_TIME: float = 0.6
const ARRIVE_ZOOM_TIME: float = 0.75
const CROSSFADE_TIME: float = 0.5
var arrival_zoom: float = 1.0
## Scenes loaded ahead of time (feedback round 5: the camera used to reach the
## island and then sit there while Lilyport loaded). Held here so they stay
## in memory until the travel uses them.
var prefetched: Dictionary = {}
var prefetching: Array[String] = []

## Starts loading a scene on a thread; travel_to picks it up instantly later.
func prefetch(scene_path: String) -> void:
	if prefetched.has(scene_path) or prefetching.has(scene_path):
		return
	if ResourceLoader.load_threaded_request(scene_path) == OK:
		prefetching.append(scene_path)

func _process(_delta: float) -> void:
	for path in prefetching.duplicate():
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			prefetched[path] = ResourceLoader.load_threaded_get(path)
			prefetching.erase(path)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			prefetching.erase(path)

func _take_scene(scene_path: String) -> PackedScene:
	while prefetching.has(scene_path):
		await get_tree().process_frame
	if prefetched.has(scene_path):
		return prefetched[scene_path] as PackedScene
	return load(scene_path) as PackedScene

var phase: StringName = &"idle"
var serial: int = 0
var active_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	veil.modulate.a = 0.0
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snapshot.visible = false
	snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_opacity() -> float:
	return veil.modulate.a

func _set_phase(value: StringName) -> void:
	phase = value
	phase_changed.emit(value)

func fade_to_scene(scene_path: String) -> void:
	await fade_call(func() -> void:
		_set_phase(&"scene_change")
		var error: Error = get_tree().change_scene_to_file(scene_path)
		if error != OK:
			push_error("Scene change failed: " + scene_path)
	)

## Zoom travel between the sea and Lilyport. `camera` is the leaving scene's
## camera, `focus` the world point to zoom towards, `zoom_factor` how far to
## zoom (above 1 dives in, below 1 pulls out). The arriving scene starts at
## the inverse factor and settles, so the island grows into the town and the
## town shrinks back into the island.
func travel_to(scene_path: String, camera: Camera2D, focus: Vector2, zoom_factor: float) -> void:
	serial += 1
	var request_id: int = serial
	get_node("/root/ControlInput").set("locked", true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_phase(&"fade_out")
	prefetch(scene_path)
	var start: Vector2 = camera.get_screen_center_position()
	# The sea camera is a child of the hull; detaching it must keep what the
	# player sees (feedback round 5: a boat facing sideways turned the whole
	# view sideways). Its real on-screen rotation is kept and eased to north up
	# during the dive, so the town, which is always north up, lines up.
	var view_rotation: float = -get_viewport().get_canvas_transform().get_rotation()
	camera.top_level = true
	camera.ignore_rotation = false
	camera.position_smoothing_enabled = false
	camera.rotation_smoothing_enabled = false
	camera.global_position = start
	camera.global_rotation = view_rotation
	camera.offset = Vector2.ZERO
	var dive: Tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	dive.tween_property(camera, "rotation", 0.0, TRAVEL_ZOOM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dive.tween_property(camera, "global_position", focus, TRAVEL_ZOOM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dive.tween_property(camera, "zoom", camera.zoom * zoom_factor, TRAVEL_ZOOM_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dive.finished
	var packed: PackedScene = await _take_scene(scene_path)
	if request_id != serial:
		return
	await RenderingServer.frame_post_draw
	snapshot.texture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	snapshot.modulate.a = 1.0
	snapshot.visible = true
	arrival_zoom = 1.0 / zoom_factor
	_set_phase(&"scene_change")
	if packed == null or get_tree().change_scene_to_packed(packed) != OK:
		push_error("Scene change failed: " + scene_path)
		get_tree().change_scene_to_file(scene_path)
	_set_phase(&"fade_in")
	# The new scene's camera reads `arrival_zoom` in its first frames; wait a
	# couple of frames so it has drawn before the snapshot starts to go.
	await get_tree().process_frame
	await get_tree().process_frame
	var reveal: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(snapshot, "modulate:a", 0.0, CROSSFADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal.finished
	if request_id != serial:
		return
	snapshot.visible = false
	snapshot.texture = null
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("/root/ControlInput").set("locked", false)
	_set_phase(&"idle")
	transition_finished.emit()

## Called by an arriving scene's camera: starts it at the travel zoom and eases
## it to `rest_zoom`. Does nothing outside a zoom travel.
func settle_arrival(camera: Camera2D, rest_zoom: float) -> void:
	if is_equal_approx(arrival_zoom, 1.0):
		return
	camera.zoom = Vector2.ONE * rest_zoom * arrival_zoom
	arrival_zoom = 1.0
	var settle: Tween = camera.create_tween()
	settle.tween_property(camera, "zoom", Vector2.ONE * rest_zoom, ARRIVE_ZOOM_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func fade_call(action: Callable) -> void:
	serial += 1
	var request_id: int = serial
	if active_tween != null and active_tween.is_running():
		active_tween.kill()
	get_node("/root/ControlInput").set("locked", true)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_phase(&"fade_out")
	active_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.tween_property(veil, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await active_tween.finished
	if request_id != serial:
		return
	_set_phase(&"hold")
	await get_tree().create_timer(0.3, true).timeout
	if request_id != serial:
		return
	if action.is_valid():
		action.call()
	_set_phase(&"fade_in")
	active_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.tween_property(veil, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await active_tween.finished
	if request_id != serial:
		return
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("/root/ControlInput").set("locked", false)
	_set_phase(&"idle")
	transition_finished.emit()

func _exit_tree() -> void:
	var control: Node = get_node_or_null("/root/ControlInput")
	if control != null:
		control.set("locked", false)
