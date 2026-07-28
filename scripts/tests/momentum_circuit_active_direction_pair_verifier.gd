extends SceneTree

const MIN_DIFFERENCE_RATIO := 0.008
const PIXEL_THRESHOLD := 0.01


func _initialize() -> void:
	var plus_path := _argument_value("--plus=", "")
	var minus_path := _argument_value("--minus=", "")
	var plus_image := Image.load_from_file(ProjectSettings.globalize_path(plus_path))
	var minus_image := Image.load_from_file(ProjectSettings.globalize_path(minus_path))
	if plus_image == null or plus_image.is_empty() or minus_image == null or minus_image.is_empty():
		push_error("ACTIVE direction pair images could not be loaded")
		quit(1)
		return
	if plus_image.get_size() != minus_image.get_size():
		push_error("ACTIVE direction pair must use the same viewport")
		quit(1)
		return
	var changed_pixels := 0
	var pixel_count := plus_image.get_width() * plus_image.get_height()
	for y in range(plus_image.get_height()):
		for x in range(plus_image.get_width()):
			var plus_color := plus_image.get_pixel(x, y)
			var minus_color := minus_image.get_pixel(x, y)
			var maximum_difference := maxf(
				absf(plus_color.r - minus_color.r),
				maxf(absf(plus_color.g - minus_color.g), absf(plus_color.b - minus_color.b))
			)
			if maximum_difference > PIXEL_THRESHOLD:
				changed_pixels += 1
	var ratio := float(changed_pixels) / maxf(1.0, float(pixel_count))
	print("METRIC momentum_circuit_active_direction_difference ratio=%.6f threshold=%.6f" % [ratio, MIN_DIFFERENCE_RATIO])
	if ratio < MIN_DIFFERENCE_RATIO:
		push_error("ACTIVE direction pair is below the frozen difference threshold")
		quit(1)
		return
	print("RESULT momentum_circuit_active_direction_pair passed=true")
	quit(0)


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback
