shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.12, 0.78, 0.86, 1.0);
uniform vec4 foam_color : source_color = vec4(0.86, 1.0, 1.0, 1.0);
uniform float alpha_scale : hint_range(0.0, 1.0) = 0.78;
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.58;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_position;
	float descent = p.y * 1.72 - TIME * 1.85;
	float broad_flow = 0.5 + 0.5 * sin(
		descent + p.x * 0.31 + sin(p.z * 0.47 - TIME * 0.42) * 0.88
	);
	float crossing_flow = 0.5 + 0.5 * sin(
		descent * 1.73 - p.z * 0.38 + sin(p.x * 0.29 + TIME * 0.31) * 0.76
	);
	float foam_streak = smoothstep(
		0.77,
		0.98,
		broad_flow * 0.62 + crossing_flow * 0.38
	);
	float soft_body = 0.90 + broad_flow * 0.10;
	vec3 body = mix(water_color.rgb, foam_color.rgb, foam_streak * 0.34);
	ALBEDO = body * soft_body;
	EMISSION = body * (0.08 + foam_streak * highlight_strength * 0.16);
	ALPHA = clamp(
		alpha_scale * (0.78 + broad_flow * 0.14) + foam_streak * 0.05,
		0.0,
		0.92
	);
}
