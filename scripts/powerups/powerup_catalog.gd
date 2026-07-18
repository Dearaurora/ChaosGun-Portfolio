extends RefCounted
class_name PowerupCatalog

const SPEED: StringName = &"speed"
const CLONE: StringName = &"clone"
const FURY: StringName = &"fury"

const SPEED_DURATION := 10.0
const CLONE_DURATION := 15.0
const FURY_DURATION := 10.0
const SPEED_MULTIPLIER := 2.0
const FURY_KNOCKBACK_MULTIPLIER := 1.5

static func get_center_powerups() -> Array[StringName]:
	return [SPEED, CLONE, FURY]

static func is_valid(powerup_id: StringName) -> bool:
	return powerup_id in get_center_powerups()

static func duration(powerup_id: StringName) -> float:
	match powerup_id:
		SPEED:
			return SPEED_DURATION
		CLONE:
			return CLONE_DURATION
		FURY:
			return FURY_DURATION
	return 0.0

static func color(powerup_id: StringName) -> Color:
	match powerup_id:
		SPEED:
			return Color("#55e46d")
		CLONE:
			return Color("#73d7ff")
		FURY:
			return Color("#ff4c3f")
	return Color.WHITE

static func display_name(powerup_id: StringName) -> String:
	match powerup_id:
		SPEED:
			return "加速"
		CLONE:
			return "分身"
		FURY:
			return "狂怒"
	return "未知道具"
