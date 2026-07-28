shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

// 0 = wet bed, 1 = shallow water, 2 = meniscus.
uniform int layer_mode : hint_range(0, 2) = 1;
uniform vec4 water_color : source_color = vec4(0.20, 0.80, 0.90, 0.42);
uniform float alpha_scale : hint_range(0.0, 1.0) = 1.0;
uniform float water_roughness : hint_range(0.02, 1.0) = 0.22;
uniform float water_specular : hint_range(0.0, 1.0) = 0.42;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.72;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.28;
uniform vec2 flow_a = vec2(0.032, -0.019);
uniform vec2 flow_b = vec2(-0.016, 0.028);
uniform float scale_a = 0.22;
uniform float scale_b = 0.37;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float phase_a = (p.x + TIME * flow_a.x * 32.0) * scale_a * 6.283
		+ (p.y + TIME * flow_a.y * 32.0) * scale_a * 3.7;
	float phase_b = (p.x + TIME * flow_b.x * 32.0) * scale_b * 3.1
		- (p.y + TIME * flow_b.y * 32.0) * scale_b * 6.283;
	float wave_a = sin(phase_a);
	float wave_b = sin(phase_b);
	float combined = wave_a * 0.52 + wave_b * 0.48;
	// Keep the flow readable through the normal and roughness response. Bright
	// color blobs read as soap spots from the fixed gameplay camera, so the
	// explicit sheen is deliberately broad and weak.
	float crest = smoothstep(0.56, 0.96, combined);
	float broad_sheen = 0.5 + 0.5 * sin(phase_a * 0.19 - phase_b * 0.13);
	float glint = (crest * 0.72 + broad_sheen * 0.08) * highlight_strength;

	vec3 tangent_normal = normalize(vec3(
		cos(phase_a) * 0.42 + cos(phase_b) * 0.18,
		sin(phase_a * 0.73 - phase_b * 0.41) * 0.16,
		1.0
	));
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	if (layer_mode == 0) {
		ALBEDO = water_color.rgb * 0.86;
		ALPHA = water_color.a * alpha_scale;
		ROUGHNESS = water_roughness;
		SPECULAR = water_specular * 0.55;
		NORMAL_MAP_DEPTH *= 0.18;
	} else if (layer_mode == 2) {
		float edge_pulse = 0.90 + sin((p.x - p.y) * 0.42 + TIME * 0.72) * 0.10;
		ALBEDO = water_color.rgb * edge_pulse + vec3(glint * 0.16);
		ALPHA = water_color.a * alpha_scale;
		ROUGHNESS = max(0.08, water_roughness - glint * 0.12);
		SPECULAR = water_specular;
		EMISSION = water_color.rgb * glint * 0.025;
		NORMAL_MAP_DEPTH *= 0.34;
	} else {
		ALBEDO = water_color.rgb + vec3(glint * 0.22);
		ALPHA = clamp(water_color.a + glint * 0.055, 0.0, 0.68) * alpha_scale;
		ROUGHNESS = clamp(water_roughness - glint * 0.20, 0.06, 0.72);
		SPECULAR = water_specular;
		EMISSION = water_color.rgb * glint * 0.018;
	}
}
