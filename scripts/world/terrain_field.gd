@tool
class_name TerrainField
extends Node
## Endless rolling hills shared by the ground shader and gameplay.
## [method height_at] mirrors forest_ground.gdshader exactly (same sine stack).
## Features (homes, ponds) register flat zones so they sit on
## level ground; the zones are pushed to the shader as a uniform array.

const MAX_ZONES: int = 32

## Ground mesh whose ShaderMaterial receives the flat zones.
@export var ground_path: NodePath
## Width of the blend from a flat zone back to the hills (metres). Keep equal
## to the shader's zone_blend uniform.
@export var zone_blend: float = 10.0

var _zones: Array[Vector4] = []
var _zone_owners: Array[Object] = []
var _material: ShaderMaterial


func _enter_tree() -> void:
	# Joined before any _ready() so the streamer and glider find it immediately.
	add_to_group(&"terrain")


func _ready() -> void:
	var ground := get_node_or_null(ground_path) as GeometryInstance3D
	if ground:
		_material = ground.material_override as ShaderMaterial
	_push()


## Raw hills without flat zones. Must match base_height() in the shader.
static func base_height(x: float, z: float) -> float:
	var h: float = 14.0 * sin(x * 0.012 + 1.3) * cos(z * 0.0096 - 0.7)
	h += 7.0 * sin((x * 0.6 + z * 0.8) * 0.021 + 2.1)
	h += 4.0 * cos((-x * 0.7 + z * 0.5) * 0.037 + 0.4) * sin(z * 0.0407 + 1.7)
	h += 1.5 * sin(x * 0.07 + z * 0.021 + 0.9)
	return h


## Ground height at a world position, including flat zones.
func height_at(x: float, z: float) -> float:
	var h: float = base_height(x, z)
	for zone: Vector4 in _zones:
		var d: float = Vector2(x - zone.x, z - zone.y).length()
		var w: float = 1.0 - smoothstep(zone.z, zone.z + zone_blend, d)
		h = lerpf(h, zone.w, w)
	return h


## Flattens a disc around [param world_position] for [param zone_owner].
func add_zone(zone_owner: Object, world_position: Vector3, radius: float) -> void:
	var level: float = base_height(world_position.x, world_position.z)
	_zones.append(Vector4(world_position.x, world_position.z, radius, level))
	_zone_owners.append(zone_owner)
	while _zones.size() > MAX_ZONES:
		_zones.remove_at(0)
		_zone_owners.remove_at(0)
	_push()


## Removes every zone registered by [param zone_owner].
func remove_zones(zone_owner: Object) -> void:
	var changed: bool = false
	for i: int in range(_zones.size() - 1, -1, -1):
		if _zone_owners[i] == zone_owner:
			_zones.remove_at(i)
			_zone_owners.remove_at(i)
			changed = true
	if changed:
		_push()


func _push() -> void:
	if _material == null:
		return
	var packed: PackedVector4Array = PackedVector4Array()
	packed.resize(MAX_ZONES)
	for i: int in _zones.size():
		packed[i] = _zones[i]
	_material.set_shader_parameter(&"flat_zones", packed)
	_material.set_shader_parameter(&"flat_zone_count", _zones.size())
	_material.set_shader_parameter(&"zone_blend", zone_blend)
