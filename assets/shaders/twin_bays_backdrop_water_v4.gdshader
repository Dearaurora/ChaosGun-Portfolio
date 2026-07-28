shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.15, 0.75, 0.82, 1.0);
uniform vec4 light_color : source_color = vec4(0.74, 0.99, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.0, 0.41, 0.52, 1.0);
uniform float tide_amount : hint_range(0.0, 1.0) = 0.0;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.23;
uniform float perimeter_depth : hint_range(0.0, 1.0) = 0.20;
uniform float bay_depth_strength : hint_range(0.0, 1.0) = 0.78;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float thin_ridge(float value, float width) {
	return 1.0 - smoothstep(width, width * 2.8, abs(sin(value)));
}

float caustic_network(vec2 point) {
	vec2 drift_a = vec2(TIME * 0.052, -TIME * 0.036);
	vec2 drift_b = vec2(-TIME * 0.031, TIME * 0.046);
	vec2 q = point * 0.29 + drift_a;
	vec2 r = point * 0.43 + drift_b;
	float warp_a = sin(q.y * 1.37 - TIME * 0.11) * 0.82 + sin(q.y * 0.43) * 0.36;
	float warp_b = sin(r.x * 0.91 + TIME * 0.08) * 0.68 + sin(r.x * 0.37) * 0.28;
	float line_a = thin_ridge(q.x + warp_a, 0.043);
	float line_b = thin_ridge(q.y * 1.08 + sin(q.x * 1.21) * 0.72, 0.041);
	float line_c = thin_ridge((r.x - r.y) * 0.76 + warp_b, 0.036);
	float intersections = max(line_a * line_b, max(line_a * line_c, line_b * line_c));
	float open_lines = max(max(line_a, line_b), line_c) * 0.12;
	return clamp(intersections * 0.92 + open_lines, 0.0, 1.0);
}

void fragment() {
	vec2 p = world_position.xz;
	float center_width = 1.0 - smoothstep(20.0, 31.0, abs(p.x));
	float north_bay = smoothstep(-34.0, -23.0, p.y) * (1.0 - smoothstep(-9.0, 1.0, p.y));
	float south_bay = smoothstep(0.0, 9.0, p.y) * (1.0 - smoothstep(27.0, 36.0, p.y));
	float bay_mask = center_width * max(north_bay, south_bay);
	float outer_mask = smoothstep(48.0, 118.0, length(p));
	float broad_depth = clamp(bay_mask * bay_depth_strength + outer_mask * perimeter_depth, 0.0, 0.88);

	float broad_wave = sin(p.x * 0.036 + TIME * 0.10) * sin(p.y * 0.044 - TIME * 0.074);
	float secondary_wave = sin((p.x + p.y) * 0.022 - TIME * 0.061);
	vec3 base = mix(shallow_color.rgb, deep_color.rgb, broad_depth);
	base *= 0.955 + broad_wave * 0.032 + secondary_wave * 0.018;

	float caustics = caustic_network(p);
	float caustic_visibility = caustics * caustic_strength * (1.0 - broad_depth * 0.58);
	base = mix(base, light_color.rgb, caustic_visibility * 0.44);
	base = mix(base, light_color.rgb, tide_amount * 0.025);

	float fine_sparkle = pow(max(0.0, sin((p.x * 0.73 - p.y * 0.61) + TIME * 0.42)), 18.0);
	fine_sparkle *= (1.0 - broad_depth) * 0.035;
	ALBEDO = base + light_color.rgb * fine_sparkle;
	EMISSION = base * 0.035 + light_color.rgb * (caustic_visibility * 0.035 + fine_sparkle * 0.45);
	ROUGHNESS = 0.64;
}
