extends Node
class_name PowerupController

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const PowerupAuraScript = preload("res://scripts/effects/powerup_aura.gd")
const CloneMistBreakScript = preload("res://scripts/effects/clone_mist_break.gd")
const CloneCharacterScene: PackedScene = preload("res://scenes/characters/clone_character.tscn")

var character: BaseCharacter = null
var speed_remaining := 0.0
var fury_remaining := 0.0
var _speed_aura: PowerupAura = null
var _fury_aura: PowerupAura = null

func setup(owner: BaseCharacter) -> void:
	character = owner

func _process(delta: float) -> void:
	if character == null or not is_instance_valid(character):
		return
	if speed_remaining > 0.0:
		speed_remaining = maxf(0.0, speed_remaining - delta)
		if speed_remaining <= 0.0:
			_end_speed()
	if fury_remaining > 0.0:
		fury_remaining = maxf(0.0, fury_remaining - delta)
		if fury_remaining <= 0.0:
			_end_fury()

func apply_powerup(powerup_id: StringName) -> bool:
	if character == null or character.is_dead or character.is_game_over:
		return false
	match powerup_id:
		PowerupCatalog.SPEED:
			speed_remaining = PowerupCatalog.SPEED_DURATION
			character.movement_speed_multiplier = PowerupCatalog.SPEED_MULTIPLIER
			_speed_aura = _ensure_aura(_speed_aura, PowerupCatalog.SPEED, "SpeedPowerupAura")
			return true
		PowerupCatalog.FURY:
			fury_remaining = PowerupCatalog.FURY_DURATION
			character.outgoing_knockback_multiplier = PowerupCatalog.FURY_KNOCKBACK_MULTIPLIER
			_fury_aura = _ensure_aura(_fury_aura, PowerupCatalog.FURY, "FuryPowerupAura")
			return true
		PowerupCatalog.CLONE:
			return _spawn_clone()
	return false

func clear_timed_powerups() -> void:
	speed_remaining = 0.0
	fury_remaining = 0.0
	_end_speed()
	_end_fury()

func inherit_timed_state(state: Dictionary) -> void:
	var inherited_speed := float(state.get("speed_remaining", 0.0))
	if inherited_speed > 0.0:
		apply_powerup(PowerupCatalog.SPEED)
		speed_remaining = inherited_speed
	var inherited_fury := float(state.get("fury_remaining", 0.0))
	if inherited_fury > 0.0:
		apply_powerup(PowerupCatalog.FURY)
		fury_remaining = inherited_fury

func get_state_debug() -> Dictionary:
	return {
		"speed_remaining": speed_remaining,
		"fury_remaining": fury_remaining,
		"speed_multiplier": character.movement_speed_multiplier if character else 1.0,
		"knockback_multiplier": character.outgoing_knockback_multiplier if character else 1.0,
		"has_speed_aura": is_instance_valid(_speed_aura),
		"has_fury_aura": is_instance_valid(_fury_aura),
	}

func _ensure_aura(current: PowerupAura, powerup_id: StringName, aura_name: String) -> PowerupAura:
	if is_instance_valid(current):
		return current
	var aura := PowerupAuraScript.new() as PowerupAura
	aura.name = aura_name
	aura.configure(powerup_id)
	character.add_child(aura)
	return aura

func _end_speed() -> void:
	if character:
		character.movement_speed_multiplier = 1.0
	if is_instance_valid(_speed_aura):
		_speed_aura.queue_free()
	_speed_aura = null

func _end_fury() -> void:
	if character:
		character.outgoing_knockback_multiplier = 1.0
	if is_instance_valid(_fury_aura):
		_fury_aura.queue_free()
	_fury_aura = null

func _spawn_clone() -> bool:
	var tree := get_tree() if is_inside_tree() else character.get_tree()
	var scene_root := RuntimeGlobals.active_scene(tree)
	if scene_root == null:
		return false
	var clone := CloneCharacterScene.instantiate() as CloneCharacter
	if clone == null:
		return false
	var target_position := _find_clone_spawn_position()
	var visual := character.get_visual()
	var body_color := visual.body_color if visual else Color("#5da9ff")
	clone.name = "%s Echo" % character.name
	clone.configure_clone(character, PowerupCatalog.CLONE_DURATION, body_color, target_position)
	var clone_collision := clone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if clone_collision:
		clone_collision.disabled = true
	scene_root.add_child(clone)
	clone.global_position = character.global_position

	var split_mist := CloneMistBreakScript.new() as CloneMistBreak
	split_mist.name = "CloneSplitMist"
	split_mist.configure(body_color)
	scene_root.add_child(split_mist)
	split_mist.global_position = character.global_position + Vector3.UP * 0.15
	return true

func _find_clone_spawn_position() -> Vector3:
	var basis_right := character.global_transform.basis.x
	basis_right.y = 0.0
	if basis_right.length_squared() <= 0.01:
		basis_right = Vector3.RIGHT
	basis_right = basis_right.normalized()
	var candidates := [basis_right, -basis_right, Vector3.FORWARD, Vector3.BACK]
	var space_state := character.get_world_3d().direct_space_state
	for direction in candidates:
		var candidate: Vector3 = character.global_position + (direction as Vector3) * 2.4
		var query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 3.0, candidate + Vector3.DOWN * 7.0)
		query.exclude = [character.get_rid()]
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			return (hit.position as Vector3) + Vector3.UP * 0.08
	return character.global_position + basis_right * 2.4
