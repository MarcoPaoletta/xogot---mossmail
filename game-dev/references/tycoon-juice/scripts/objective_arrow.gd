class_name ObjectiveArrow
extends Node3D
## The bouncing arrow over the next thing to do. A tycoon has no menus, so the
## world tells the player where to go next: this arrow hovers over the target
## and disappears when the player is close enough that the target is obvious.
##
## The arrow mesh is a child authored in the scene (a chunky, bright, outlined
## mesh, big enough to read on a phone). The script only places and animates it.

@export var target: Node3D
@export var player: Node3D
@export var height: float = 2.6
@export var bob_height: float = 0.3
@export var bob_speed: float = 3.2
@export var hide_distance: float = 3.5
@export var spin_speed: float = 1.2

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if target == null or not is_instance_valid(target):
		visible = false
		return
	var near: bool = player != null and player.global_position.distance_to(target.global_position) < hide_distance
	visible = not near
	global_position = target.global_position + Vector3.UP * (height + sin(_time * bob_speed) * bob_height)
	rotation.y += spin_speed * delta


func point_at(new_target: Node3D) -> void:
	target = new_target
	if new_target != null:
		ItemFlight.pop_in(self, 0.3, 1.2)
