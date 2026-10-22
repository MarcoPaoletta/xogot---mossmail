@tool
class_name AnimFrameTransform
extends Resource
# Per-animation scale + offset for a MAKKO-exported AnimatedSprite2D.
#
# Makko renders each animation on its own canvas, so within one character the frame size
# and aspect ratio differ per animation and the subject sits at a different offset. A
# single node scale + zero offset makes the character pop size and jump position on every
# animation change. Give each animation its own scale + offset and re-apply on change.
#
# Structure: a typed array of AnimFrameEntry (a struct of anim name + scale + offset), so
# each animation is an editable row in the inspector. Calibrate EACH entry against a fixed
# ground line and a target world height, one at a time. There is no correct global scale.
#
# NOT needed for pixel-art / uniformly-exported characters (e.g. SpriteCook) whose
# animations share one canvas.

@export var entries: Array[AnimFrameEntry] = []

var _by_anim: Dictionary = {}

func _build_index() -> void:
	_by_anim.clear()
	for e in entries:
		if e != null:
			_by_anim[e.anim] = e

func apply(sprite: AnimatedSprite2D, anim: StringName) -> void:
	if _by_anim.is_empty() and not entries.is_empty():
		_build_index()
	var e: AnimFrameEntry = _by_anim.get(anim)
	if e == null:
		return
	sprite.scale = e.scale
	sprite.offset = e.offset

# Which way the clip's art faces by default (unknown clip defaults to right). Callers combine
# this with the actor's facing to set flip_h, so a clip that ships facing the "wrong" way still
# points at the target. This replaces a per-actor match on animation name.
func faces_right(anim: StringName) -> bool:
	if _by_anim.is_empty() and not entries.is_empty():
		_build_index()
	var e: AnimFrameEntry = _by_anim.get(anim)
	return true if e == null else e.native_faces_right

# Wire it once on the character (e.g. in _ready), then it stays correct for every clip:
#
#   @export var frame_transform: AnimFrameTransform
#   @onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
#
#   func _ready() -> void:
#       sprite.animation_changed.connect(func() -> void:
#           frame_transform.apply(sprite, sprite.animation))
#       frame_transform.apply(sprite, sprite.animation)  # apply the autoplay animation now
#
# Facing combines the actor's facing with the clip's native facing:
#
#   sprite.flip_h = (facing < 0.0) if frame_transform.faces_right(anim) else (facing > 0.0)
