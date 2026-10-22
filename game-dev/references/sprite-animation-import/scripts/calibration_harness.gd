extends Node2D
# Fast visual calibrator for per-animation scale + offset (Makko characters).
#
# RUN this scene (F6 / project_run). It lays out one AnimatedSprite2D per animation in a
# row, all playing, over a shared GROUND LINE (y = 0) and a TARGET-HEIGHT bar, so a
# mis-scaled or mis-offset animation is obvious at a glance: its feet leave the line or its
# height differs from the bar. Then tune live and copy the numbers into the resource.
#
# Controls (while running):
#   1..9 / 0     select an animation (0 = the 10th)
#   Left/Right   nudge selected offset.x        Up/Down   nudge selected offset.y
#   +/-          nudge selected scale (uniform)  [ / ]     nudge scale finer
#   Enter        print every entry as AnimFrameEntry-ready values (paste into the resource)
#
# Assign `sprite_frames` (the character's SpriteFrames .tres) in the inspector. Optionally
# assign `frame_transform` to start from existing values; leave null to start at identity.

@export var sprite_frames: SpriteFrames
@export var frame_transform: AnimFrameTransform          # optional starting values
@export var target_height_px: float = 300.0              # height every animation should read at
@export var spacing_px: float = 380.0
@export var scale_step: float = 0.02
@export var scale_step_fine: float = 0.005
@export var offset_step: float = 4.0

var _sprites: Array[AnimatedSprite2D] = []
var _labels: Array[Label] = []
var _names: Array = []
var _scales: Array[Vector2] = []
var _offsets: Array[Vector2] = []
var _selected := 0

func _ready() -> void:
	if sprite_frames == null:
		push_error("[CALIBRATE] Assign sprite_frames in the inspector.")
		return
	var start := {}
	if frame_transform != null:
		for e in frame_transform.entries:
			if e != null:
				start[e.anim] = e
	_names = sprite_frames.get_animation_names()
	for i in _names.size():
		var anim: StringName = _names[i]
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = sprite_frames
		spr.animation = anim
		spr.centered = true
		spr.position = Vector2(i * spacing_px, 0.0)
		var sc := Vector2.ONE
		var off := Vector2.ZERO
		if start.has(anim):
			sc = start[anim].scale
			off = start[anim].offset
		spr.scale = sc
		spr.offset = off
		add_child(spr)
		spr.play(anim)
		_sprites.append(spr)
		_scales.append(sc)
		_offsets.append(off)
		var lbl := Label.new()
		lbl.position = Vector2(i * spacing_px - spacing_px * 0.45, -target_height_px - 90.0)
		add_child(lbl)
		_labels.append(lbl)
	var cam := Camera2D.new()
	cam.position = Vector2((_names.size() - 1) * spacing_px * 0.5, -target_height_px * 0.5)
	cam.zoom = Vector2(0.5, 0.5)
	add_child(cam)
	cam.make_current()
	_refresh()

func _refresh() -> void:
	for i in _sprites.size():
		_sprites[i].scale = _scales[i]
		_sprites[i].offset = _offsets[i]
		var sel := "> " if i == _selected else "  "
		_labels[i].text = "%s%s\nscale %.3f, %.3f\noffset %d, %d" % [
			sel, _names[i], _scales[i].x, _scales[i].y, int(_offsets[i].x), int(_offsets[i].y)]
		_labels[i].modulate = Color.YELLOW if i == _selected else Color.WHITE
	queue_redraw()

func _draw() -> void:
	if _sprites.is_empty():
		return
	var w := _names.size() * spacing_px
	# ground line (feet must sit here)
	draw_line(Vector2(-spacing_px, 0), Vector2(w, 0), Color(1, 1, 1, 0.9), 3.0)
	# target-height bar per column
	for i in _names.size():
		var x := i * spacing_px
		var col := Color(0.2, 0.9, 1.0, 0.25 if i != _selected else 0.5)
		draw_rect(Rect2(x - 4, -target_height_px, 8, target_height_px), col, true)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var k := event as InputEventKey
	# select 1..9, 0 => index 9
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		_selected = mini(k.keycode - KEY_1, _sprites.size() - 1); _refresh(); return
	if k.keycode == KEY_0:
		_selected = mini(9, _sprites.size() - 1); _refresh(); return
	match k.keycode:
		KEY_LEFT:  _offsets[_selected].x -= offset_step; _refresh()
		KEY_RIGHT: _offsets[_selected].x += offset_step; _refresh()
		KEY_UP:    _offsets[_selected].y -= offset_step; _refresh()
		KEY_DOWN:  _offsets[_selected].y += offset_step; _refresh()
		KEY_EQUAL, KEY_KP_ADD:      _scales[_selected] += Vector2.ONE * scale_step; _refresh()
		KEY_MINUS, KEY_KP_SUBTRACT: _scales[_selected] -= Vector2.ONE * scale_step; _refresh()
		KEY_BRACKETLEFT:  _scales[_selected] -= Vector2.ONE * scale_step_fine; _refresh()
		KEY_BRACKETRIGHT: _scales[_selected] += Vector2.ONE * scale_step_fine; _refresh()
		KEY_ENTER, KEY_KP_ENTER:
			print("[CALIBRATE] entries (paste into the AnimFrameTransform):")
			for i in _names.size():
				print('  anim="%s"  scale=Vector2(%.3f, %.3f)  offset=Vector2(%d, %d)' % [
					_names[i], _scales[i].x, _scales[i].y, int(_offsets[i].x), int(_offsets[i].y)])
