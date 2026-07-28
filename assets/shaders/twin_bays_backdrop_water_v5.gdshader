shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.16, 0.79, 0.85, 1.0);
uniform vec4 light_color : source_color = vec4(0.82, 1.0, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.0, 0.36, 0.47, 1.0);
uniform float tide_amount : hint_range(0.0, 1.0) = 0.0;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.32;
uniform float perimeter_depth : hint_range(0.0, 1.0) = 0.24;
uniform float bay_depth_strength : hint_range(0.0, 1.0) = 0.86;
uniform float caustic_world_scale : hint_range(0.02, 0.80) = 0.30;
uniform float caustic_softness : hint_range(0.02, 0.24) = 0.105;
uniform float caustic_detail_mix : hint_range(0.0, 1.0) = 0.38;
uniform float macro_swell_strength : hint_range(0.0, 0.20) = 0.055;
uniform float caustic_light_mix : hint_range(0.0, 0.80) = 0.24;
uniform float outer_darkening : hint_range(0.0, 0.12) = 0.018;
uniform float glint_strength : hint_range(0.0, 0.08) = 0.012;
uniform sampler2D caustic_texture : repeat_enable, filter_linear_mipmap, hint_default_black;
uniform float caustic_tile_world_size : hint_range(24.0, 160.0) = 64.0;
uniform vec2 caustic_scroll_a = vec2(0.0016, -0.0011);
uniform vec2 caustic_scroll_b = vec2(-0.0010, 0.0014);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float broad_caustics(vec2 point) {
	// The deterministic offline mask is the shape authority; the shader only
	// pans and cross-fades two inexpensive samples. This gives the same rounded
	// pool-cell language in every renderer and remains one material/one texture.
	float frequency_multiplier = caustic_world_scale / 0.30;
	vec2 primary_uv = point / caustic_tile_world_size * frequency_multiplier
		+ TIME * caustic_scroll_a;
	float broad = texture(caustic_texture, primary_uv).r;
	vec2 rotated = vec2(
		point.x * 0.77 - point.y * 0.64,
		point.x * 0.64 + point.y * 0.77
	);
	vec2 detail_uv = rotated / (caustic_tile_world_size * 0.64)
		* frequency_multiplier
		+ vec2(0.37, -0.21) + TIME * caustic_scroll_b;
	float detail = texture(caustic_texture, detail_uv).r;
	float broad_floor = clamp(0.515 - caustic_softness * 1.10, 0.28, 0.48);
	float detail_floor = clamp(0.635 - caustic_softness * 1.10, 0.38, 0.60);
	broad = smoothstep(broad_floor, 0.94, broad);
	detail = smoothstep(detail_floor, 0.96, detail);
	return max(broad, detail * caustic_detail_mix);
}

void fragment() {
	vec2 p = world_position.xz;
	float center_width = 1.0 - smoothstep(20.0, 31.0, abs(p.x));
	float north_bay = smoothstep(-34.0, -23.0, p.y) * (1.0 - smoothstep(-9.0, 1.0, p.y));
	float south_bay = smoothstep(0.0, 9.0, p.y) * (1.0 - smoothstep(27.0, 36.0, p.y));
	float bay_mask = center_width * max(north_bay, south_bay);
	float outer_mask = smoothstep(46.0, 116.0, length(p));
	float broad_depth = clamp(
		bay_mask * bay_depth_strength + outer_mask * perimeter_depth,
		0.0,
		0.92
	);

	float basin_rolloff = smoothstep(18.0, 90.0, length(p));
	float wave_a = sin(p.x * 0.041 + p.y * 0.017 + TIME * 0.10);
	float wave_b = sin(p.y * 0.037 - p.x * 0.013 - TIME * 0.073);
	vec3 base = mix(shallow_color.rgb, deep_color.rgb, broad_depth);
	float macro_swell = wave_a * wave_b;
	base *= 0.975 + macro_swell * macro_swell_strength - basin_rolloff * outer_darkening;

	float caustics = broad_caustics(p);
	float visibility = caustics * caustic_strength * (1.0 - broad_depth * 0.58);
	base = mix(base, light_color.rgb, visibility * caustic_light_mix);
	base = mix(base, light_color.rgb, tide_amount * 0.018);

	float glint_wave = max(0.0, sin(p.x * 0.24 - p.y * 0.19 + TIME * 0.22));
	float glint = pow(glint_wave, 18.0) * (1.0 - broad_depth) * glint_strength;
	ALBEDO = base + light_color.rgb * glint;
	EMISSION = base * 0.020 + light_color.rgb * (visibility * 0.010 + glint * 0.30);
	ROUGHNESS = 0.46;
}
