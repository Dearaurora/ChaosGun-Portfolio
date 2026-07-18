extends AICharacter
class_name CloneCharacter

const CloneMistBreakScript = preload("res://scripts/effects/clone_mist_break.gd")

var source_character: BaseCharacter = null
var remaining_lifetime := PowerupCatalog.CLONE_DURATION
var _source_color := Color("#5da9ff")
var _split_target_position := Vector3.ZERO
var _dissolving := false

func configure_clone(owner: BaseCharacter, duration: float, color: Color, split_target: Vector3) -> void:
	source_character = owner
	combat_owner = owner.get_combat_identity() if owner else null
	remaining_lifetime = duration
	_source_color = color
	_split_target_position = split_target

func _ready() -> void:
	super._ready()
	add_to_group("player")
	add_to_group("ai")
	add_to_group("temporary_clone")
	lives = 1
	var visual := get_visual()
	if visual:
		visual.set_body_color(_source_color)
	_copy_source_combat_state()
	call_deferred("_begin_split_motion")

func _process(delta: float) -> void:
	if _dissolving:
		return
	super._process(delta)
	remaining_lifetime = maxf(0.0, remaining_lifetime - delta)
	if remaining_lifetime <= 0.0:
		_dissolve()

func _die() -> void:
	_dissolve()

func dismiss() -> void:
	_dissolve()

func get_clone_debug() -> Dictionary:
	return {
		"remaining_lifetime": remaining_lifetime,
		"is_dissolving": _dissolving,
		"owner_id": get_combat_identity().get_instance_id() if get_combat_identity() else 0,
		"source_color": _source_color,
	}

func _copy_source_combat_state() -> void:
	if source_character == null or not is_instance_valid(source_character):
		return
	var source_manager := source_character.weapon_manager
	if source_manager and source_manager.current_weapon and source_manager.current_weapon.weapon_data:
		var source_weapon := source_manager.current_weapon
		if source_weapon.weapon_data.weapon_id != &"pistol":
			weapon_manager.equip_weapon(source_weapon.weapon_data)
			weapon_manager.current_weapon.current_ammo = source_weapon.current_ammo
	var controller := get_node_or_null("PowerupController")
	if controller:
		controller.call("inherit_timed_state", source_character.get_powerup_state_debug())

func _begin_split_motion() -> void:
	if _dissolving:
		return
	freeze = true
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "global_position", _split_target_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_split_motion)

func _finish_split_motion() -> void:
	if _dissolving:
		return
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.disabled = false
	freeze = false
	set_physics_process(true)

func _dissolve() -> void:
	if _dissolving:
		return
	_dissolving = true
	is_dead = true
	set_process(false)
	set_physics_process(false)
	freeze = true
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision:
		collision.set_deferred("disabled", true)
	var scene_root := RuntimeGlobals.active_scene(get_tree())
	if scene_root:
		var mist := CloneMistBreakScript.new() as CloneMistBreak
		mist.name = "CloneMistBreak"
		mist.configure(_source_color)
		scene_root.add_child(mist)
		mist.global_position = global_position + Vector3.UP * 0.08
	queue_free()
