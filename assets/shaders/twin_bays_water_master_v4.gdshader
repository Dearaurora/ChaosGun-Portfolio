shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Art V4 clarity variant. It keeps the V3 material contract and transparent
// batch count, but avoids dark RGB tint accumulating across the three residue
// layers on the cream combat deck.
uniform int layer_mode : hint_range(0, 2) = 1;
uniform vec4 water_color : source_color = vec4(0.55, 0.95, 0.97, 0.20);
uniform float alpha_scale : hint_range(0.0, 1.0) = 1.0;
uniform float water_roughness : hint_range(0.02, 1.0) = 0.14;
uniform float water_specular : hint_range(0.0, 1.0) = 0.56;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.48;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.24;
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
	float crest = smoothstep(0.64, 0.97, combined);
	float broad_sheen = 0.5 + 0.5 * sin(phase_a * 0.16 - phase_b * 0.11);
	float glint = (crest * 0.66 + broad_sheen * 0.06) * highlight_strength;

	vec3 tangent_normal = normalize(vec3(
		cos(phase_a) * 0.34 + cos(phase_b) * 0.15,
		sin(phase_a * 0.73 - phase_b * 0.41) * 0.12,
		1.0
	));
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	if (layer_mode == 0) {
		// A wet deck is read primarily through gloss, not a dark paint-like tint.
		ALBEDO = mix(vec3(0.96, 1.0, 1.0), water_color.rgb, 0.12);
		ALPHA = water_color.a * alpha_scale;
		ROUGHNESS = water_roughness;
		SPECULAR = water_specular;
		NORMAL_MAP_DEPTH *= 0.12;
	} else if (layer_mode == 2) {
		float edge_pulse = 0.93 + sin((p.x - p.y) * 0.42 + TIME * 0.72) * 0.07;
		ALBEDO = mix(vec3(0.94, 1.0, 1.0), water_color.rgb, 0.30) * edge_pulse;
		ALPHA = water_color.a * alpha_scale;
		ROUGHNESS = max(0.06, water_roughness - glint * 0.10);
		SPECULAR = water_specular;
		EMISSION = vec3(0.72, 0.98, 1.0) * glint * 0.035;
		NORMAL_MAP_DEPTH *= 0.28;
	} else {
		vec3 clear_aqua = mix(vec3(0.88, 0.99, 1.0), water_color.rgb, 0.42);
		ALBEDO = clear_aqua + vec3(glint * 0.22);
		ALPHA = clamp(water_color.a + glint * 0.032, 0.0, 0.52) * alpha_scale;
		ROUGHNESS = clamp(water_roughness - glint * 0.16, 0.05, 0.64);
		SPECULAR = water_specular;
		EMISSION = vec3(0.66, 0.96, 1.0) * glint * 0.060;
	}
}
