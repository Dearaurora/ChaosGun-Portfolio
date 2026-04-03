extends BaseCharacter

func _ready() -> void:
    friction = 6.0
    mass = 2.5

func _process(delta: float) -> void:
    super._base_process(delta)

func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    _apply_movement(Vector3.ZERO, delta)
    move_and_slide()
