extends Area3D
class_name Projectile

const HitEffectScene: PackedScene = preload("res://scenes/effects/hit_effect.tscn")

## 由 Weapon 在发射时注入，不再硬编码
var speed: float = 60.0
var knockback_power: float = 18.0
var damage: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var lifetime: float = 2.0

var _trail: MeshInstance3D = null
var _hit := false  # 防止射线和 Area3D 信号重复触发

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	_create_trail()

func _physics_process(delta: float) -> void:
	if _hit:
		return

	var move_vec = direction * speed * delta
	var move_dist = move_vec.length()

	# --- 射线检测：防止高速弹穿模 ---
	if move_dist > 0.01:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			global_position, global_position + move_vec)
		# 排除射手的碰撞体
		if shooter:
			query.exclude = [shooter.get_rid()]
		var result = space_state.intersect_ray(query)
		if result:
			# 射线命中 → 移动到命中点并触发击中
			global_position = result.position
			_handle_hit(result.collider)
			return

	# 无命中，正常移动
	global_position += move_vec

	# 向后拉伸拖尾并保持前端锚定在中心
	if _trail:
		_trail.scale.z = min(_trail.scale.z + speed * delta * 3.0, 12.0)
		_trail.position.z = _trail.scale.z * 0.5

func _on_body_entered(body: Node3D) -> void:
	if _hit:
		return
	if body == shooter:
		return
	_handle_hit(body)

func _handle_hit(body: Node3D) -> void:
	if _hit:
		return
	_hit = true
	if body.has_method("apply_hit"):
		body.apply_hit(direction * knockback_power, damage)
	elif body.has_method("apply_knockback"):
		body.apply_knockback(direction * knockback_power)
	# 击中特效
	_spawn_hit_effect()
	queue_free()

func _create_trail() -> void:
	_trail = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.15, 0.15, 1.0) # 基础长度为 1
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 0.5, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.9, 0.3, 1)
	mat.emission_energy_multiplier = 3.0
	box.material = mat
	_trail.mesh = box
	add_child(_trail)
	_trail.scale.z = 0.1
	_trail.position.z = 0.05

func _spawn_hit_effect() -> void:

	var hit = HitEffectScene.instantiate()
	get_tree().current_scene.add_child(hit)
	hit.global_position = global_position
	var tw = hit.create_tween()
	tw.tween_property(hit, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(hit.queue_free)

