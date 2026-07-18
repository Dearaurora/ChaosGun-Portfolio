extends Node

## Keeps interactive/debug Godot tests in a small, normal window.
##
## Visual capture scripts are allowed to keep a larger internal viewport for
## image output, but no test is allowed to take over the user's desktop.
const TEST_WINDOW_SIZE := Vector2i(960, 540)


func _process(_delta: float) -> void:
	enforce_now()


func enforce_now() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	if not OS.is_debug_build():
		return

	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	if DisplayServer.window_get_size() != TEST_WINDOW_SIZE:
		DisplayServer.window_set_size(TEST_WINDOW_SIZE)
