class_name CustomizeScreen
extends UIScreen
## Glider selection: the glider spins on the left, five colour squares below
## it, and a Play button on the right. The choice is saved and applied at once.

signal play_pressed
signal color_chosen(index: int)

@export var showcase_path: NodePath = ^"Left/Preview/Viewport/GliderShowcase"
@export var swatches_path: NodePath = ^"Left/Swatches"
@export var color_name_path: NodePath = ^"Left/ColorName"
@export var play_button_path: NodePath = ^"PlayButton"
@export var swatch_border: Color = Color("#f6ecd0")
@export var swatch_selected_border: Color = Color("#ffd27a")

var _showcase: GliderShowcase
var _swatches: Array[Button] = []
var _name: Label
var _play: Button
var _selected: int = 0


func _ready() -> void:
	super._ready()
	_showcase = get_node_or_null(showcase_path) as GliderShowcase
	_name = get_node_or_null(color_name_path) as Label
	_play = get_node_or_null(play_button_path) as Button
	if _play:
		_play.pressed.connect(func() -> void: play_pressed.emit())
	var row := get_node_or_null(swatches_path)
	if row:
		var i: int = 0
		for child: Node in row.get_children():
			var button := child as Button
			if button == null:
				continue
			_swatches.append(button)
			button.pressed.connect(_select.bind(i))
			i += 1
	_selected = GliderPalette.load_index()
	_refresh(false)


func show_screen() -> void:
	super.show_screen()
	if _play:
		_play.grab_focus.call_deferred()


func get_selected() -> int:
	return _selected


func _select(index: int) -> void:
	if index == _selected:
		UIJuice.pop(_swatches[index], 1.1)
		return
	_selected = index
	GliderPalette.save_index(index)
	_refresh(true)
	color_chosen.emit(index)


func _refresh(animate: bool) -> void:
	for i: int in _swatches.size():
		var button: Button = _swatches[i]
		var chosen: bool = i == _selected
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = GliderPalette.SWATCHES[i] if i < GliderPalette.SWATCHES.size() else Color.WHITE
			box.border_color = swatch_selected_border if chosen else swatch_border
			box.set_border_width_all(7 if chosen else 3)
			box.set_corner_radius_all(16)
			box.corner_detail = 8
			box.shadow_color = Color(0, 0, 0, 0.35)
			box.shadow_size = 6 if chosen else 3
			button.add_theme_stylebox_override(state, box)
		button.pivot_offset = button.size * 0.5
		if animate:
			var tween: Tween = create_tween()
			tween.tween_property(button, "scale", Vector2.ONE * (1.12 if chosen else 1.0), 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			button.scale = Vector2.ONE * (1.12 if chosen else 1.0)
	if _name and _selected < GliderPalette.NAMES.size():
		_name.text = GliderPalette.NAMES[_selected]
	if _showcase:
		_showcase.set_color_index(_selected, animate)
