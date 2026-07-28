shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.11, 0.61, 0.76, 1.0);
uniform vec4 light_color : source_color = vec4(0.48, 0.88, 0.92, 1.0);
uniform vec4 deep_color : source_color = vec4(0.025, 0.33, 0.52, 1.0);
uniform float tide_amount = 0.0;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.20;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float warped_line(vec2 point, vec2 direction, float phase) {
	float coordinate = dot(point, direction);
	float warp = sin(dot(point, vec2(-direction.y, direction.x)) * 0.86 + phase) * 0.72;
	return 1.0 - smoothstep(0.025, 0.105, abs(sin(coordinate + warp)));
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 slow = p * 0.34 + vec2(TIME * 0.045, -TIME * 0.032);
	vec2 fine = p * 0.58 + vec2(-TIME * 0.031, TIME * 0.041);
	float caustic_a = warped_line(slow, normalize(vec2(1.0, 0.58)), TIME * 0.19);
	float caustic_b = warped_line(slow, normalize(vec2(-0.42, 1.0)), -TIME * 0.15);
	float caustic_c = warped_line(fine, normalize(vec2(0.72, -1.0)), TIME * 0.12);
	float caustics = clamp(caustic_a * 0.52 + caustic_b * 0.42 + caustic_c * 0.24, 0.0, 1.0);

	float center_width = 1.0 - smoothstep(20.0, 31.0, abs(p.x));
	float north_bay = smoothstep(-34.0, -23.0, p.y) * (1.0 - smoothstep(-9.0, 1.0, p.y));
	float south_bay = smoothstep(0.0, 9.0, p.y) * (1.0 - smoothstep(27.0, 36.0, p.y));
	float bay_depth = center_width * max(north_bay, south_bay);
	float broad_wave = sin(p.x * 0.045 + TIME * 0.10) * sin(p.y * 0.052 - TIME * 0.075);

	vec3 base = mix(shallow_color.rgb, deep_color.rgb, bay_depth * 0.62);
	base *= 0.94 + broad_wave * 0.055;
	float visible_caustics = caustics * caustic_strength * (1.0 - bay_depth * 0.46);
	base = mix(base, light_color.rgb, visible_caustics);
	base = mix(base, light_color.rgb, tide_amount * 0.055);
	ALBEDO = base;
	EMISSION = base * 0.065 + light_color.rgb * visible_caustics * 0.055;
	ROUGHNESS = 0.68;
}
