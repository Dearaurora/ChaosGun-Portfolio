extends Area3D
class_name TwinBaysPortal

signal character_teleported(character: BaseCharacter, from_portal: TwinBaysPortal, to_portal: TwinBaysPortal)

const COOLDOWN_META := &"twin_bays_portal_unlock_ms"

@export_range(0.1, 2.0, 0.05) var cooldown_seconds := 0.55

var paired_portal: TwinBaysPortal = null
var exit_marker: Marker3D = null
var destination_marker: Marker3D = null
var teleport_count := 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func configure_pair(destination_portal: TwinBaysPortal, destination_exit: Marker3D) -> void:
	paired_portal = destination_portal
	destination_marker = destination_exit

func _on_body_entered(body: Node3D) -> void:
	var character := body as BaseCharacter
	if character == null or character.is_dead or character.is_game_over:
		return
	if paired_portal == null or destination_marker == null:
		return

	var now_ms := Time.get_ticks_msec()
	var unlock_ms := int(character.get_meta(COOLDOWN_META, 0))
	if now_ms < unlock_ms:
		return

	character.set_meta(COOLDOWN_META, now_ms + int(cooldown_seconds * 1000.0))
	call_deferred("_teleport_character", character)

func _teleport_character(character: BaseCharacter) -> void:
	if not is_instance_valid(character) or not is_instance_valid(destination_marker):
		return

	var destination_transform := character.global_transform
	destination_transform.origin = destination_marker.global_position
	character.global_transform = destination_transform
	character.linear_velocity = Vector3.ZERO
	character.angular_velocity = Vector3.ZERO
	character.sleeping = false
	if character.is_inside_tree():
		PhysicsServer3D.body_set_state(character.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, destination_transform)
		PhysicsServer3D.body_set_state(character.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(character.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(character.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, false)
	character.reset_physics_interpolation()
	teleport_count += 1
	character_teleported.emit(character, self, paired_portal)
