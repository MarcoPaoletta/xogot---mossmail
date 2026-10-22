class_name PaintSlime
extends CharacterBody3D

## The economy tax. Hops at you, body-checks you toward the void, never damages.
## Will happily chase you straight off an edge. That is a feature.

@export var data: EnemyData
@export var intensity: float = 0.2
## Seconds until a killed slime pops back at its spawn (0 = never).
@export var respawn_time: float = 12.0

var _health: float = 30.0
var _alive: bool = true
var _hop_cooldown: float = 0.0
var _shove_cooldown: float = 0.0
var _wobble_t: float = 0.0
var _spawn_transform: Transform3D
var _material: ShaderMaterial
var _flash: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _contact: Area3D = $ContactSensor
@onready var _collider: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if data == null:
		data = EnemyData.new()
	_spawn_transform = global_transform
	_health = data.health
	_wobble_t = randf() * TAU
	add_to_group("enemies")
	_contact.body_entered.connect(_on_contact)
	var mesh_instance: MeshInstance3D = MeshTint.find_mesh_instance(_visual)
	_material = MeshTint.apply_hue(mesh_instance, 0.0, 0.15, 0.6, 1.0)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_wobble_t += delta
	_hop_cooldown = maxf(0.0, _hop_cooldown - delta)
	_shove_cooldown = maxf(0.0, _shove_cooldown - delta)
	_flash = maxf(0.0, _flash - delta * 6.0)
	if _material != null:
		_material.set_shader_parameter("brightness", 1.0 + _flash * 1.2)

	# Idle breathing wobble
	var breathe: float = sin(_wobble_t * 2.4) * 0.05
	_visual.scale = Vector3(1.0 + breathe, 1.0 - breathe, 1.0 + breathe)

	# Gravity
	velocity.y -= 22.0 * delta

	var player: Player = _player()
	var aggro: bool = false
	if player != null and GameManager.state == GameManager.State.PLAYING:
		var dist: float = global_position.distance_to(player.global_position)
		aggro = dist < data.aggro_radius * (1.0 + 0.6 * intensity)

	if is_on_floor():
		if aggro and _hop_cooldown <= 0.0 and player != null:
			var dir: Vector3 = player.global_position - global_position
			dir.y = 0.0
			dir = dir.normalized()
			var speed: float = data.move_speed * (1.0 + 0.55 * intensity)
			# Edge guard: probe for floor at the hop's landing point. No floor
			# there = no chase hop; the slime holds the edge instead of diving.
			if not _floor_ahead(dir, speed):
				_hop_cooldown = 0.35
			else:
				velocity = dir * speed * 1.6
				velocity.y = 4.6
				_hop_cooldown = randf_range(0.55, 0.85)
				AudioDirector.play_3d(&"slime_hop", global_position, 1.0, -8.0, 0.15)
				var tween: Tween = create_tween()
				_visual.scale = Vector3(0.8, 1.25, 0.8)
				tween.tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)
	move_and_slide()

	if global_position.y < -60.0:
		_die(false)


func _floor_ahead(dir: Vector3, speed: float) -> bool:
	# Hop arc: vy 4.6 against g 22 -> ~0.42 s airtime. Ray down at the landing spot.
	var land: Vector3 = global_position + dir * speed * 1.6 * 0.42
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		land + Vector3.UP * 0.6, land + Vector3.DOWN * 3.0, 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _on_contact(body: Node3D) -> void:
	if not _alive or _shove_cooldown > 0.0 or not (body is Player):
		return
	var player: Player = body
	_shove_cooldown = 0.9
	var dir: Vector3 = player.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	var impulse_strength: float = data.knockback_impulse * (1.0 + 0.3 * intensity)
	var impulse: Vector3 = dir * impulse_strength
	impulse.y = impulse_strength * data.knockback_lift
	player.apply_knockback(KnockbackInfo.create(impulse, global_position, Color(0.94, 0.18, 0.65), 0.25, 3))
	# Recoil backward so it cannot chain-shove in one contact.
	velocity = -dir * 5.0
	velocity.y = 3.5
	AudioDirector.play_3d(&"slime_hit", global_position, 1.0, -2.0, 0.1)


func take_paint_hit(damage: float, pos: Vector3, _color: Color) -> void:
	if not _alive:
		return
	_health -= damage
	_flash = 1.0
	EventBus.hit_stop_requested.emit(2)
	var tween: Tween = create_tween()
	_visual.scale = Vector3(1.25, 0.75, 1.25)
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	AudioDirector.play_3d(&"slime_hurt", pos, 1.0, -4.0, 0.12)
	if _health <= 0.0:
		_die(true)


func _die(drop: bool) -> void:
	if not _alive:
		return
	_alive = false
	EventBus.enemy_died.emit(EnemyData.Kind.SLIME, global_position)
	AudioDirector.play_3d(&"slime_death", global_position, 1.0, 0.0, 0.08)
	EventBus.camera_trauma.emit(0.18)
	var fx: FxManager = get_tree().get_first_node_in_group("fx_manager") as FxManager
	if fx != null and drop:
		var color: Color = Color(0.94, 0.18, 0.65)
		fx.spawn_burst(global_position + Vector3(0, 0.5, 0), color, 22, 1.8)
		fx.spawn_decal(global_position, Vector3.UP, color, 2.6)
		for i in 5:
			var ang: float = randf() * TAU
			var offset: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * randf_range(0.8, 2.0)
			fx.spawn_decal(global_position + offset, Vector3.UP, color, 1.2)
		# Slick puddle where it died: your own kill makes the ground treacherous.
		if Pool.has_pool(&"puddle"):
			var puddle: SlickPuddle = Pool.acquire(&"puddle") as SlickPuddle
			if puddle != null:
				puddle.activate(global_position, data.puddle_duration)
		# Drop a Splash orb.
		if Pool.has_pool(&"orb") and data.drop_orb != null:
			var orb: PaintOrb = Pool.acquire(&"orb") as PaintOrb
			if orb != null:
				orb.mark_pooled()
				orb.set_data(data.drop_orb)
				orb.global_position = global_position + Vector3(0, 0.3, 0)
				orb.reset_physics_interpolation()
	visible = false
	_collider.set_deferred("disabled", true)
	set_physics_process(false)
	if respawn_time > 0.0:
		get_tree().create_timer(respawn_time).timeout.connect(_try_respawn)


func _try_respawn() -> void:
	# Infinite-loop world: pop back at the spawn point, but only mid-run.
	if _alive or GameManager.state != GameManager.State.PLAYING:
		return
	reset_run()
	var fx: FxManager = get_tree().get_first_node_in_group("fx_manager") as FxManager
	if fx != null:
		fx.spawn_burst(_spawn_transform.origin + Vector3(0, 0.5, 0), Color(0.94, 0.18, 0.65), 14, 1.3)
	AudioDirector.play_3d(&"slime_hop", _spawn_transform.origin, 1.0, -6.0, 0.1)


func reset_run() -> void:
	_alive = true
	_health = data.health if data != null else 30.0
	global_transform = _spawn_transform
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	visible = true
	_collider.disabled = false
	set_physics_process(true)
	_shove_cooldown = 0.0
	_hop_cooldown = randf_range(0.0, 0.5)
