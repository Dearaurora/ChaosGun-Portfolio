extends StaticBody3D
class_name MomentumCircuitGravityActivator

## Durable shoot-only switch for the shared Momentum Circuit gravity field.

signal activated(
	activator: MomentumCircuitGravityActivator,
	direction: int,
	attacker: Node3D,
	weapon_id: StringName
)
signal activation_failed(reason: StringName, attacker: Node3D)
signal cooldown_finished(activator: MomentumCircuitGravityActivator)

const DEFAULT_COOLDOWN_SECONDS := 8.0

@export var cooldown_seconds := DEFAULT_COOLDOWN_SECONDS

var controller: Node = null
var cooldown_remaining := 0.0
var hit_count := 0
var activation_count := 0
var rejected_hit_count := 0
var ignored_cooldown_hit_count := 0
var last_attacker_instance_id := 0
var last_weapon_id: StringName = &""
var last_hit_impulse := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return
	var previous := cooldown_remaining
	cooldown_remaining = maxf(0.0, cooldown_remaining - maxf(0.0, delta))
	if previous > 0.0 and cooldown_remaining <= 0.0:
		cooldown_finished.emit(self)


func configure(gravity_controller: Node, node_cooldown_seconds: float = DEFAULT_COOLDOWN_SECONDS) -> void:
	controller = gravity_controller
	cooldown_seconds = maxf(0.0, node_cooldown_seconds)


func is_ready_to_activate() -> bool:
	return cooldown_remaining <= 0.0


## Weapon/projectile compatibility contract.  Damage never destroys the node;
## contact and body entry do not call this method and therefore cannot toggle it.
func apply_hit(
	impulse: Vector3,
	damage: float = 0.0,
	attacker: Node3D = null,
	weapon_id: StringName = &""
) -> void:
	var _unused_damage := damage
	hit_count += 1
	last_hit_impulse = impulse
	last_weapon_id = weapon_id
	last_attacker_instance_id = attacker.get_instance_id() if is_instance_valid(attacker) else 0

	if not is_ready_to_activate():
		ignored_cooldown_hit_count += 1
		activation_failed.emit(&"node_cooldown", attacker)
		return
	if controller == null or not is_instance_valid(controller) or not controller.has_method("request_toggle"):
		rejected_hit_count += 1
		activation_failed.emit(&"missing_controller", attacker)
		return

	# The controller owns global guard/state validation.  A rejection leaves this
	# node ready, as required by the mechanism contract.
	var accepted := bool(controller.call("request_toggle", self, attacker))
	if not accepted:
		rejected_hit_count += 1
		activation_failed.emit(&"controller_rejected", attacker)
		return

	cooldown_remaining = cooldown_seconds
	activation_count += 1
	var controller_state := controller.call("get_debug_state") as Dictionary
	var direction := int(controller_state.get("pending_direction", 0))
	activated.emit(self, direction, attacker, weapon_id)


func get_debug_state() -> Dictionary:
	return {
		"ready": is_ready_to_activate(),
		"cooldown_seconds": cooldown_seconds,
		"cooldown_remaining": cooldown_remaining,
		"controller_valid": is_instance_valid(controller),
		"hit_count": hit_count,
		"activation_count": activation_count,
		"rejected_hit_count": rejected_hit_count,
		"ignored_cooldown_hit_count": ignored_cooldown_hit_count,
		"last_attacker_instance_id": last_attacker_instance_id,
		"last_weapon_id": last_weapon_id,
		"last_hit_impulse": last_hit_impulse,
	}
