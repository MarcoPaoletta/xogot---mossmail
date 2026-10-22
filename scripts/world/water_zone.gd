extends Area3D
## Pond water. Splashes when anything with a body touches it, and tells bodies
## that care (has set_in_water) when they enter or leave.

@export var splash_path: NodePath = ^"Splash"

var _splash: GPUParticles3D


func _ready() -> void:
	_splash = get_node_or_null(splash_path) as GPUParticles3D
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method(&"set_in_water"):
		body.call(&"set_in_water", true)
	_burst_at(body.global_position)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method(&"set_in_water"):
		body.call(&"set_in_water", false)


func _burst_at(world_position: Vector3) -> void:
	if _splash == null:
		return
	_splash.global_position = Vector3(world_position.x, global_position.y + 0.1, world_position.z)
	_splash.restart()
