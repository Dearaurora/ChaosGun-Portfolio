extends Area3D
class_name Projectile

## 由 Weapon 在发射时注入，不再硬编码
var speed: float = 60.0
var knockback_power: float = 18.0
var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null
var lifetime: float = 2.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction * knockback_power)
	queue_free()
