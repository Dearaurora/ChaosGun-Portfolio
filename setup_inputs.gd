extends SceneTree

func _init():
	var inputs = {
		"move_left": [KEY_A],
		"move_right": [KEY_D],
		"move_forward": [KEY_W],
		"move_backward": [KEY_S],
		"fire": [MOUSE_BUTTON_LEFT],
		"weapon_slot_1": [KEY_1],
		"weapon_slot_2": [KEY_2],
		"weapon_cycle": [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, KEY_TAB]
	}
	
	for action in inputs:
		var events = []
		for btn in inputs[action]:
			if btn == MOUSE_BUTTON_LEFT or btn == MOUSE_BUTTON_WHEEL_UP or btn == MOUSE_BUTTON_WHEEL_DOWN:
				var event = InputEventMouseButton.new()
				event.button_index = btn
				events.append(event)
			else:
				var event = InputEventKey.new()
				event.physical_keycode = btn
				events.append(event)
				
		var action_dict = {
			"deadzone": 0.5,
			"events": events
		}

		ProjectSettings.set_setting("input/" + action, action_dict)
		
	var err = ProjectSettings.save()
	if err != OK:
		print("Error saving project settings")
	else:
		print("Input map set successfully")
		
	quit()
