extends BaseCharacter

func _ready() -> void:
    friction = 6.0

func _process(delta: float) -> void:
    super._base_process(delta)

func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    _apply_movement(Vector3.ZERO, delta)
    move_and_slide()

# --- 靶子特有击退逻辑（覆盖基类） ---
func apply_knockback(force: Vector3) -> void:
    var push_dir = force.normalized()
    var edge_damping = 1.0
    if _is_near_edge(push_dir):
        edge_damping = 0.4
        
    var actual_force = force * edge_damping * max(0.2, (1.0 - knockback_resistance))
    knockback_velocity += actual_force
    knockback_resistance = min(0.75, knockback_resistance + 0.3)
