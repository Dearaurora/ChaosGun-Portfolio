shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform int layer_mode : hint_range(0, 2) = 1;
uniform vec4 water_color : source_color = vec4(0.56, 0.96, 0.97, 0.18);
uniform float alpha_scale : hint_range(0.0, 1.0) = 1.0;
uniform float water_roughness : hint_range(0.02, 1.0) = 0.11;
uniform float water_specular : hint_range(0.0, 1.0) = 0.62;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.42;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec2 flow_a = vec2(0.028, -0.017);
uniform vec2 flow_b = vec2(-0.014, 0.024);
uniform float scale_a = 0.18;
uniform float scale_b = 0.29;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float phase_a = (p.x + TIME * flow_a.x * 30.0) * scale_a * 6.283
		+ (p.y + TIME * flow_a.y * 30.0) * scale_a * 3.2;
	float phase_b = (p.x + TIME * flow_b.x * 30.0) * scale_b * 2.7
		- (p.y + TIME * flow_b.y * 30.0) * scale_b * 6.283;
	float wave_a = sin(phase_a + sin(phase_b * 0.31) * 0.62);
	float wave_b = sin(phase_b + sin(phase_a * 0.27) * 0.54);
	float combined = wave_a * 0.54 + wave_b * 0.46;
	float crest = smoothstep(0.72, 1.02, combined);
	float broad_sheen = 0.5 + 0.5 * sin(phase_a * 0.13 - phase_b * 0.09);
	float glint = (crest * 0.48 + broad_sheen * 0.040) * highlight_strength;
	float crossing_caustic = 1.0 - smoothstep(
		0.045,
		0.26,
		abs(wave_a * 0.67 + wave_b * 0.52)
	);
	crossing_caustic *= 0.26 + crest * 0.48;
	float water_pattern = clamp(
		crest * 0.58 + crossing_caustic * 0.42,
		0.0,
		1.0
	);
	float water_read = water_pattern * (0.18 + highlight_strength * 1.12);

	vec3 tangent_normal = normalize(vec3(
		cos(phase_a) * 0.29 + cos(phase_b) * 0.13,
		sin(phase_a * 0.67 - phase_b * 0.38) * 0.10,
		1.0
	));
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	if (layer_mode == 0) {
		ALBEDO = mix(water_color.rgb, vec3(0.40, 0.78, 0.82), 0.08);
		ALPHA = water_color.a * alpha_scale;
		ROUGHNESS = water_roughness;
		SPECULAR = water_specular;
		EMISSION = water_color.rgb * 0.018;
		NORMAL_MAP_DEPTH *= 0.10;
	} else if (layer_mode == 2) {
		float edge_pulse = 0.95 + sin((p.x - p.y) * 0.36 + TIME * 0.66) * 0.05;
		ALBEDO = mix(vec3(0.96, 1.0, 1.0), water_color.rgb, 0.25) * edge_pulse;
		ALPHA = water_color.a * alpha_scale;
		ROUGHNESS = max(0.05, water_roughness - glint * 0.09);
		SPECULAR = water_specular;
		EMISSION = vec3(0.78, 0.99, 1.0) * glint * 0.034;
		NORMAL_MAP_DEPTH *= 0.24;
	} else {
		vec3 clear_aqua = mix(water_color.rgb, vec3(0.52, 0.92, 0.94), 0.07);
		ALBEDO = mix(clear_aqua, vec3(0.76, 0.99, 1.0), water_read * 0.20);
		ALPHA = clamp(water_color.a + water_read * 0.028, 0.0, 0.62) * alpha_scale;
		ROUGHNESS = clamp(water_roughness - (glint + water_read) * 0.10, 0.050, 0.56);
		SPECULAR = water_specular;
		EMISSION = water_color.rgb * 0.020
			+ vec3(0.70, 0.97, 1.0) * (glint * 0.026 + water_read * 0.040);
	}
}
