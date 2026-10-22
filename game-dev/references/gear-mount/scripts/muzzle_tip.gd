@tool
class_name MuzzleTip
extends MeshInstance3D

## Visible, grabbable spawn point for projectiles. In the editor it renders as
## a small bright ball: select it in the viewport and park it in the cannon
## mouth with the normal gizmo (world axes work). Projectiles and the muzzle
## flash spawn from this node's global position. Hidden automatically in game.


func _ready() -> void:
	visible = Engine.is_editor_hint()
