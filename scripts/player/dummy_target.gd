extends CharacterBody3D

@export var friction: float = 6.0
@export var gravity: float = 20.0

var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_resistance: float = 0.0

func _process(delta: float) -> void:
    if knockback_resistance > 0.0:
        knockback_resistance = max(0.0, knockback_resistance - delta * 0.5)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

    if knockback_velocity.length_squared() > 0.1:
        knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, friction * 0.8 * delta)
    else:
        knockback_velocity = Vector3.ZERO

    var current_move_vel = velocity - knockback_velocity
    current_move_vel.y = 0
    current_move_vel = current_move_vel.lerp(Vector3.ZERO, friction * delta)

    velocity.x = current_move_vel.x + knockback_velocity.x
    velocity.z = current_move_vel.z + knockback_velocity.z

    move_and_slide()

# --- 击退核心逻辑 ---
func apply_knockback(force: Vector3) -> void:
    var push_dir = force.normalized()
    var edge_damping = 1.0
    if _is_near_edge(push_dir):
        edge_damping = 0.4
        
    var actual_force = force * edge_damping * max(0.2, (1.0 - knockback_resistance))
    knockback_velocity += actual_force
    knockback_resistance = min(0.75, knockback_resistance + 0.3)
    
func _is_near_edge(push_dir: Vector3) -> bool:
    var space_state = get_world_3d().direct_space_state
    var check_pos = global_position + push_dir * 4.0 + Vector3.UP * 0.5
    var query = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 2.0)
    var result = space_state.intersect_ray(query)
    return result.is_empty()
