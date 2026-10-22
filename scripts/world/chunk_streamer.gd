@tool
class_name ChunkStreamer
extends Node3D
## Endless forest. Keeps a square ring of authored chunk scenes around the
## glider. Chunks already placed in main.tscn are adopted (so the editor shows
## the world before Play); new cells instance a saved chunk scene chosen by a
## stable hash of the cell and rotate it by a multiple of 90 degrees.
## Every prop is seated on the rolling terrain, features get flat ground, and
## small detail (grass, plants) is hidden in the outer ring to save draw calls.
## Cells holding an active task target can be pinned so they never unload.

signal chunk_loaded(chunk: Node3D)

@export var target_path: NodePath
@export var chunk_size: float = 48.0
## 2 keeps a 5x5 block, so chunk edges sit deep in the fog even when flying high.
@export var radius: int = 2
## Chunks within this ring show their grass and small plants.
@export var detail_radius: int = 1
@export var detail_groups: PackedStringArray = PackedStringArray(["Grass", "Plants"])
## Props sink this far into the ground so slopes never show floating bases.
@export var ground_sink: float = 0.25
## Flat-ground radius per feature, matched by node-name prefix in "Features".
@export var feature_radii: Dictionary = {"Home": 9.0, "Pond": 10.5}
## Canopy footprint per prop-name prefix: x = radius, y = top height (unscaled).
## Used to keep flowers out of the trees.
@export var canopy_sizes: Dictionary = {
	"TwistedTree": Vector2(6.5, 16.8), "TreeCommon": Vector2(2.5, 9.5), "Pine": Vector2(2.7, 8.8),
	"DeadTree": Vector2(3.0, 9.5), "Home": Vector2(7.5, 7.5),
}
@export var obstacle_groups: PackedStringArray = PackedStringArray(["Trees", "Giants", "Features"])
@export var world_seed: int = 7
@export var chunk_scene_paths: PackedStringArray = PackedStringArray([
	"res://scenes/world/chunk_grove.tscn",
	"res://scenes/world/chunk_pines.tscn",
	"res://scenes/world/chunk_pond.tscn",
	"res://scenes/world/chunk_meadow.tscn",
])
## Relative pick weight per scene path, same order.
@export var chunk_weights: PackedFloat32Array = PackedFloat32Array([0.3, 0.25, 0.2, 0.25])

var _target: Node3D
var _terrain: TerrainField
var _scenes: Array[PackedScene] = []
var _chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _pins: Dictionary = {}
var _center: Vector2i = Vector2i(999999, 999999)
var _needs_settle: bool = true


func _enter_tree() -> void:
	add_to_group(&"chunk_streamer")


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_terrain = get_tree().get_first_node_in_group(&"terrain") as TerrainField
	for child: Node in get_children():
		var chunk := child as Node3D
		if chunk:
			_chunks[world_to_cell(chunk.global_position)] = chunk
			_register_features(chunk)
	if Engine.is_editor_hint():
		# Editor preview (game-dev skill, Rule 1c): the authored starting chunks
		# sit on the hills while editing. Nothing is spawned and nothing is
		# saved: positions are reset before every save and re-seated after it.
		_settle_all.call_deferred()
		return
	for path: String in chunk_scene_paths:
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			_scenes.append(scene)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_reset_preview()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_settle_all()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _target == null:
		return
	var center: Vector2i = world_to_cell(_target.global_position)
	if center != _center:
		_center = center
		_refresh()
	if not _pending.is_empty():
		_spawn(_pending.pop_front())
	if _needs_settle:
		_needs_settle = false
		_settle_all()


## Grid cell that contains a world position.
func world_to_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(roundi(world_position.x / chunk_size), roundi(world_position.z / chunk_size))


## Keeps the chunk that owns [param node] loaded until [method unpin_node].
func pin_node(node: Node) -> void:
	var chunk: Node3D = _chunk_of(node)
	if chunk:
		_pins[world_to_cell(chunk.global_position)] = true


func unpin_node(node: Node) -> void:
	var chunk: Node3D = _chunk_of(node)
	if chunk:
		_pins.erase(world_to_cell(chunk.global_position))


func clear_pins() -> void:
	_pins.clear()


## World height of the highest canopy (or home roof) covering [param p]
## horizontally, or -INF when nothing covers it.
func get_obstacle_top(p: Vector3, margin: float = 0.0) -> float:
	var top: float = -INF
	var center: Vector2i = world_to_cell(p)
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var chunk: Node3D = _chunks.get(center + Vector2i(dx, dz)) as Node3D
			if chunk == null or not is_instance_valid(chunk):
				continue
			for group_name: String in obstacle_groups:
				var group: Node = chunk.get_node_or_null(NodePath(group_name))
				if group == null:
					continue
				for child: Node in group.get_children():
					var prop := child as Node3D
					if prop == null:
						continue
					var size: Vector2 = _canopy_of(prop)
					if size == Vector2.ZERO:
						continue
					var s: float = prop.global_transform.basis.get_scale().x
					var gp: Vector3 = prop.global_position
					if Vector2(p.x - gp.x, p.z - gp.z).length() < size.x * s + margin:
						top = maxf(top, gp.y + size.y * s)
	return top


## True when [param p] sits outside every canopy by at least [param margin].
func is_point_clear(p: Vector3, margin: float = 1.5) -> bool:
	return p.y > get_obstacle_top(p, margin) + margin


func _canopy_of(prop: Node3D) -> Vector2:
	var prop_name: String = String(prop.name)
	for prefix: String in canopy_sizes.keys():
		if prop_name.begins_with(prefix):
			return canopy_sizes[prefix]
	return Vector2.ZERO


func _chunk_of(node: Node) -> Node3D:
	var current: Node = node
	while current and current.get_parent() != self:
		current = current.get_parent()
	return current as Node3D


func _refresh() -> void:
	var wanted: Dictionary = {}
	for dz: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			wanted[_center + Vector2i(dx, dz)] = true
	for cell: Vector2i in _chunks.keys():
		if not wanted.has(cell) and not _pins.has(cell):
			var old: Node3D = _chunks[cell]
			_chunks.erase(cell)
			if _terrain:
				_terrain.remove_zones(old)
			old.queue_free()
	_pending.clear()
	var order: Array = wanted.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - _center).length_squared() < (b - _center).length_squared())
	for cell: Vector2i in order:
		if not _chunks.has(cell):
			_pending.append(cell)
	_needs_settle = true


func _spawn(cell: Vector2i) -> void:
	if _chunks.has(cell) or _scenes.is_empty():
		return
	var h: int = _hash(cell)
	var chunk: Node3D = _pick_scene(h).instantiate() as Node3D
	chunk.position = Vector3(cell.x * chunk_size, 0.0, cell.y * chunk_size)
	chunk.rotation.y = float((h >> 8) % 4) * PI * 0.5
	add_child(chunk)
	_chunks[cell] = chunk
	_register_features(chunk)
	_needs_settle = true
	chunk_loaded.emit(chunk)


func _register_features(chunk: Node3D) -> void:
	if _terrain == null:
		return
	var features: Node = chunk.get_node_or_null(^"Features")
	if features == null:
		return
	for child: Node in features.get_children():
		var feature := child as Node3D
		if feature == null:
			continue
		for prefix: String in feature_radii.keys():
			if String(feature.name).begins_with(prefix):
				_terrain.add_zone(chunk, feature.global_position, float(feature_radii[prefix]))
				break


## Seats every prop on the terrain and toggles far detail. Cheap enough to run
## for every loaded chunk whenever the set of chunks (and flat zones) changes.
func _settle_all() -> void:
	for cell: Vector2i in _chunks.keys():
		var chunk: Node3D = _chunks[cell]
		if not is_instance_valid(chunk):
			continue
		var near: bool = Engine.is_editor_hint() or maxi(absi(cell.x - _center.x), absi(cell.y - _center.y)) <= detail_radius
		for group: Node in chunk.get_children():
			var group_3d := group as Node3D
			if group_3d == null:
				continue
			if detail_groups.has(String(group.name)):
				group_3d.visible = near
			var sink: float = 0.0 if String(group.name) == "Features" else ground_sink
			for prop: Node in group.get_children():
				var p := prop as Node3D
				if p == null:
					continue
				var gp: Vector3 = p.global_position
				var ground: float = _terrain.height_at(gp.x, gp.z) if _terrain else 0.0
				p.global_position = Vector3(gp.x, ground - sink, gp.z)


func _pick_scene(h: int) -> PackedScene:
	var total: float = 0.0
	for i: int in _scenes.size():
		total += chunk_weights[i] if i < chunk_weights.size() else 1.0
	var roll: float = float(h % 10000) / 10000.0 * total
	for i: int in _scenes.size():
		roll -= chunk_weights[i] if i < chunk_weights.size() else 1.0
		if roll <= 0.0:
			return _scenes[i]
	return _scenes[_scenes.size() - 1]


func _hash(cell: Vector2i) -> int:
	var h: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (world_seed * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


## Editor only: puts every prop back at its authored height (y = 0 inside its
## chunk scene) so saving main.tscn never stores preview positions.
func _reset_preview() -> void:
	for cell: Vector2i in _chunks.keys():
		var chunk: Node3D = _chunks[cell]
		if not is_instance_valid(chunk):
			continue
		for group: Node in chunk.get_children():
			for prop: Node in group.get_children():
				var p := prop as Node3D
				if p:
					p.position.y = 0.0
