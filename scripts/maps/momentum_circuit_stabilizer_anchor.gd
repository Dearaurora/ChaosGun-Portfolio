extends Node3D
class_name MomentumCircuitStabilizerAnchor

## Spatial definition for a cyan stabilizer.  It has no teleport or contact
## behavior; the gravity controller samples its smooth radial influence.

const DEFAULT_OUTER_RADIUS := 5.5
const DEFAULT_CORE_RADIUS := 2.75
const EPSILON := 0.0001

@export var outer_radius := DEFAULT_OUTER_RADIUS
@export var core_radius := DEFAULT_CORE_RADIUS

var controller: Node = null


func configure(
	gravity_controller: Node,
	outer_radius_value: float = DEFAULT_OUTER_RADIUS,
	core_radius_value: float = DEFAULT_CORE_RADIUS
) -> void:
	controller = gravity_controller
	outer_radius = maxf(EPSILON, outer_radius_value)
	core_radius = clampf(core_radius_value, 0.0, outer_radius)


func get_stabilization_strength(world_position: Vector3) -> float:
	var distance := _horizontal_distance(global_position, world_position)
	if distance >= outer_radius:
		return 0.0
	if distance <= core_radius:
		return 1.0
	var span := maxf(outer_radius - core_radius, EPSILON)
	var value := clampf((outer_radius - distance) / span, 0.0, 1.0)
	# Smoothstep avoids a visible/physical discontinuity at either radius.
	return value * value * (3.0 - 2.0 * value)


func contains_core(world_position: Vector3) -> bool:
	return _horizontal_distance(global_position, world_position) <= core_radius


func contains_outer_radius(world_position: Vector3) -> bool:
	return _horizontal_distance(global_position, world_position) <= outer_radius


func get_debug_state() -> Dictionary:
	return {
		"outer_radius": outer_radius,
		"core_radius": core_radius,
		"controller_valid": is_instance_valid(controller),
	}


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
