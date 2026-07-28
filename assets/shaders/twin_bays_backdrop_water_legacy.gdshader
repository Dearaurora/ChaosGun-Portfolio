shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.11, 0.61, 0.76, 1.0);
uniform vec4 light_color : source_color = vec4(0.48, 0.88, 0.92, 1.0);
uniform vec4 deep_color : source_color = vec4(0.025, 0.33, 0.52, 1.0);
uniform float tide_amount = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float layer_a = sin(p.x * 0.19 + TIME * 0.34) * sin(p.y * 0.23 - TIME * 0.26);
	float layer_b = sin((p.x + p.y) * 0.12 - TIME * 0.19) * sin((p.x - p.y) * 0.17 + TIME * 0.23);
	float caustics = pow(clamp(0.54 + layer_a * 0.23 + layer_b * 0.18, 0.0, 1.0), 4.0);
	float center_width = 1.0 - smoothstep(20.0, 31.0, abs(p.x));
	float north_bay = smoothstep(-34.0, -23.0, p.y) * (1.0 - smoothstep(-9.0, 1.0, p.y));
	float south_bay = smoothstep(0.0, 9.0, p.y) * (1.0 - smoothstep(27.0, 36.0, p.y));
	float bay_depth = center_width * max(north_bay, south_bay);
	float broad_wave = sin(p.x * 0.045 + TIME * 0.10) * sin(p.y * 0.052 - TIME * 0.075);
	vec3 base = mix(shallow_color.rgb, deep_color.rgb, bay_depth * 0.62);
	base *= 0.92 + broad_wave * 0.075;
	base = mix(base, light_color.rgb, caustics * (0.34 - bay_depth * 0.13));
	base = mix(base, light_color.rgb, tide_amount * 0.08);
	ALBEDO = base;
	EMISSION = base * 0.08 + light_color.rgb * caustics * 0.04;
	ROUGHNESS = 0.72;
}
