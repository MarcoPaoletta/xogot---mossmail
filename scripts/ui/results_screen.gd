class_name ResultsScreen
extends UIScreen
## End-of-shift card. Counts the score up, celebrates a new best.

signal again_pressed
signal menu_pressed

@export var score_label_path: NodePath = ^"Center/Card/Margin/Column/ScoreLabel"
@export var deliveries_label_path: NodePath = ^"Center/Card/Margin/Column/DeliveriesLabel"
@export var best_label_path: NodePath = ^"Center/Card/Margin/Column/BestLabel"
@export var again_button_path: NodePath = ^"Center/Card/Margin/Column/Buttons/AgainButton"
@export var menu_button_path: NodePath = ^"Center/Card/Margin/Column/Buttons/MenuButton"
@export var count_time: float = 1.2

var _score: Label
var _deliveries: Label
var _best: Label
var _shown_score: int = 0


func _ready() -> void:
	super._ready()
	_score = get_node_or_null(score_label_path) as Label
	_deliveries = get_node_or_null(deliveries_label_path) as Label
	_best = get_node_or_null(best_label_path) as Label
	var again := get_node_or_null(again_button_path) as Button
	var menu := get_node_or_null(menu_button_path) as Button
	if again:
		again.pressed.connect(func() -> void: again_pressed.emit())
	if menu:
		menu.pressed.connect(func() -> void: menu_pressed.emit())


func show_results(score: int, deliveries: int, best: int, new_best: bool) -> void:
	show_screen()
	if _deliveries:
		_deliveries.text = "1 delivery" if deliveries == 1 else "%d deliveries" % deliveries
	if _best:
		_best.text = "New best shift!" if new_best else "Best shift: %d" % best
		_best.modulate = Color("#ffd27a") if new_best else Color(1, 1, 1, 0.8)
	_shown_score = 0
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.25)
	tween.tween_method(_set_score_text, 0, score, count_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: UIJuice.pop(_score, 1.2))
	if new_best:
		tween.tween_callback(func() -> void: UIJuice.pop(_best, 1.25))
	var again := get_node_or_null(again_button_path) as Button
	if again:
		again.grab_focus.call_deferred()


func _set_score_text(value: int) -> void:
	_shown_score = value
	if _score:
		_score.text = str(value)
