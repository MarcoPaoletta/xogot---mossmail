class_name SpeedClover
extends Collectible
## A golden four-leaf clover hovering over a forest clearing. Touching it gives
## the glider a burst of super speed. Its height above the ground comes from
## its position (stable per clearing) and is raised above any tree canopy.

@export var min_hover: float = 10.0
@export var max_hover: float = 40.0
@export var canopy_margin: float = 3.0
@export var boost_seconds: float = 4.0


func _ready() -> void:
	super._ready()
	_place.call_deferred()


func _place() -> void:
	# Wait until the streamer has seated the chunk on the terrain.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var anchor := get_parent() as Node3D
	var base_y: float = anchor.global_position.y if anchor else 0.0
	var p: Vector3 = global_position
	var h: float = fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0)
	var y: float = base_y + lerpf(min_hover, max_hover, h)
	var streamer := get_tree().get_first_node_in_group(&"chunk_streamer") as ChunkStreamer
	if streamer:
		var top: float = streamer.get_obstacle_top(Vector3(p.x, y, p.z), canopy_margin)
		if y < top + canopy_margin:
			y = top + canopy_margin
	global_position.y = y


func _on_collected(glider: Glider) -> void:
	if glider:
		glider.boost(boost_seconds)
